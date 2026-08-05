// DOCS: docs/development-standards.md
// DOCS: docs/features/auth.md — update that file when you edit this one.

import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fsi_courier_app/core/api/api_client.dart';
import 'package:fsi_courier_app/core/auth/auth_provider.dart';
import 'package:fsi_courier_app/core/auth/auth_storage.dart';
import 'package:fsi_courier_app/core/config.dart';
import 'package:fsi_courier_app/core/constants.dart';
import 'package:fsi_courier_app/core/database/app_database.dart';
import 'package:fsi_courier_app/core/providers/update_provider.dart';
import 'package:fsi_courier_app/core/services/app_version_service.dart';
import 'package:fsi_courier_app/core/services/runtime_environment_service.dart';
import 'package:fsi_courier_app/core/settings/debug_ui_provider.dart';
import 'package:fsi_courier_app/design_system/design_system.dart';
import 'package:fsi_courier_app/features/auth/widgets/auth_layout.dart';
import 'package:fsi_courier_app/models/update_info.dart';
import 'package:fsi_courier_app/shared/helpers/api_payload_helper.dart';
import 'package:fsi_courier_app/shared/helpers/post_submit_navigation.dart';
import 'package:fsi_courier_app/shared/helpers/snackbar_helper.dart';
import 'package:fsi_courier_app/shared/widgets/contact_app_sheet.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _phoneFocus = FocusNode();
  final _passwordFocus = FocusNode();
  final Map<String, String> _errors = {};

  bool _loading = false;
  bool _obscurePassword = true;
  int _rateLimitRemaining = 0;
  Timer? _rateLimitTimer;

  static const _kPhone = 'remembered_phone';
  static const _kPassword = 'remembered_password';

  @override
  void initState() {
    super.initState();
    _loadSavedCredentials();
  }

  Future<void> _loadSavedCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    final phone = prefs.getString(_kPhone) ?? '';
    if (phone.isNotEmpty) _phoneController.text = phone;
    if (kAppDebugMode) {
      final password = prefs.getString(_kPassword) ?? '';
      if (password.isNotEmpty) _passwordController.text = password;
    }
  }

  Future<void> _saveCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kPhone, _phoneController.text.trim());
    if (kAppDebugMode) {
      await prefs.setString(_kPassword, _passwordController.text);
    } else {
      await prefs.remove(_kPassword);
    }
  }

  @override
  void dispose() {
    _rateLimitTimer?.cancel();
    _phoneController.dispose();
    _passwordController.dispose();
    _phoneFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  void _startRateLimitCountdown(int seconds) {
    _rateLimitTimer?.cancel();
    setState(() => _rateLimitRemaining = seconds);

    _rateLimitTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_rateLimitRemaining <= 1) {
        timer.cancel();
        setState(() => _rateLimitRemaining = 0);
        return;
      }
      setState(() => _rateLimitRemaining -= 1);
    });
  }

  Future<void> _submit() async {
    setState(() => _errors.clear());

    if (_phoneController.text.trim().isEmpty) {
      _errors['phone_number'] = 'common.field_required'.tr();
    }
    if (_passwordController.text.isEmpty) {
      _errors['password'] = 'common.field_required'.tr();
    }
    if (_errors.isNotEmpty) {
      setState(() {});
      return;
    }

    setState(() => _loading = true);
    final api = ref.read(apiClientProvider);
    final authStorage = ref.read(authStorageProvider);

    final result = await api.post<Map<String, dynamic>>(
      '/login',
      data: {
        'phone_number': _phoneController.text.trim(),
        'password': _passwordController.text,
        'device_name': deviceName,
        'device_identifier': await authStorage.getDeviceId(),
        'device_type': kDeviceTypeLogin,
        'app_version': AppVersionService.version,
      },
      parser: parseApiMap,
    );

    if (!mounted) return;

    switch (result) {
      case ApiSuccess<Map<String, dynamic>>(:final data):
        final payload = mapFromKey(data, 'data');
        final token = payload['token']?.toString().trim() ?? '';
        if (token.isEmpty) {
          showErrorNotification(
            context,
            'auth.login_screen.error_invalid_response'.tr(),
          );
          break;
        }

        final user = mapFromKey(payload, 'user');
        final courier = mapFromKey(payload, 'courier');
        final mergedCourier = <String, dynamic>{...user, ...courier};

        // Session fingerprint — wipe stale local data if courier/server changed.
        final courierId = mergedCourier['id']?.toString() ?? '';
        final runtimeBaseUrl =
            RuntimeEnvironmentService.instance.activeApiBaseUrl;
        final newFingerprint = '${runtimeBaseUrl}_$courierId';
        final prefs = await SharedPreferences.getInstance();
        final prevFingerprint = prefs.getString('_session_fingerprint') ?? '';

        final lastCourierId = await authStorage.getLastCourierId();
        // P4: first install or courier/server identity change → full wipe.
        final isFirstInstall = prevFingerprint.isEmpty && lastCourierId == null;
        final identityChanged =
            (prevFingerprint.isNotEmpty && prevFingerprint != newFingerprint) ||
            (lastCourierId != null && lastCourierId != courierId);
        final needsFullResync = isFirstInstall || identityChanged;
        if (needsFullResync) {
          await AppDatabase.clearAllDeliveryData();
          await authStorage.setLastSyncTime(0);
        }
        await authStorage.setNeedsFullResync(needsFullResync);
        await prefs.setString('_session_fingerprint', newFingerprint);

        await authStorage.setToken(token);
        await authStorage.setCourier(mergedCourier);
        await authStorage.setLastCourierId(courierId);
        await _saveCredentials();
        await ref.read(authProvider.notifier).initialize();
        if (mounted) goToDashboardAfterSubmit(context);
        break;
      case ApiValidationError<Map<String, dynamic>>(:final errors):
        errors.forEach((key, value) => _errors[key] = value.first);
        break;
      case ApiUnauthorized<Map<String, dynamic>>(:final message):
        showErrorNotification(
          context,
          message != null && message.isNotEmpty
              ? message
              : 'auth.login_screen.error_invalid_credentials'.tr(),
        );
        break;
      case ApiNetworkError<Map<String, dynamic>>():
        showErrorNotification(
          context,
          'auth.login_screen.error_no_connection'.tr(),
        );
        break;
      case ApiRateLimited<Map<String, dynamic>>(
        :final message,
        :final retryAfterSeconds,
      ):
        final seconds = retryAfterSeconds ?? 60;
        _startRateLimitCountdown(seconds);
        showErrorNotification(
          context,
          '${message.isNotEmpty ? message : ''} ${'auth.login_screen.error_try_again_seconds'.tr(namedArgs: {'seconds': '$seconds'})}',
        );
        break;
      case ApiServerError<Map<String, dynamic>>(:final message):
        showErrorNotification(context, message);
        break;
      default:
        showErrorNotification(
          context,
          'auth.login_screen.error_login_failed'.tr(),
        );
    }

    if (mounted) setState(() => _loading = false);
  }

  Future<void> _callAdmin() async {
    await showContactAppSheet(
      context,
      '09213920200',
      title: 'auth.login_screen.contact_admin'.tr(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    final updateState = ref.watch(updateProvider);
    final hasUpdate = updateState.hasUpdate;
    final canSubmit = !_loading && _rateLimitRemaining == 0 && !hasUpdate;

    final fieldStep = DSAnimations.staggerCoarse;

    return AuthShell(
      loading: _loading,
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AuthHeader(
              showLogo: true,
              logoAssetPath: AppAssets.fsiIcon,
              logoSize: 92,
            ),
            DSSpacing.hXl,

            AuthFormCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextField(
                        controller: _phoneController,
                        focusNode: _phoneFocus,
                        keyboardType: TextInputType.phone,
                        textInputAction: TextInputAction.next,
                        autofillHints: const [
                          AutofillHints.telephoneNumber,
                          AutofillHints.username,
                        ],
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'[0-9+ ]')),
                        ],
                        onSubmitted: (_) => _passwordFocus.requestFocus(),
                        decoration: InputDecoration(
                          labelText: 'auth.login_screen.phone_number'.tr(),
                          hintText: 'auth.login_screen.phone_hint'.tr(),
                          prefixIcon: const Icon(
                            Icons.phone_outlined,
                            size: DSIconSize.md,
                          ),
                          errorText: _errors['phone_number'],
                        ),
                      ).dsFieldEntry(
                        delay: DSAnimations.stagger(1, step: fieldStep),
                        duration: DSAnimations.dNormal,
                      ),
                      DSSpacing.hFormField,
                      TextField(
                        controller: _passwordController,
                        focusNode: _passwordFocus,
                        obscureText: _obscurePassword,
                        textInputAction: TextInputAction.done,
                        autofillHints: const [AutofillHints.password],
                        onSubmitted: (_) {
                          if (canSubmit) _submit();
                        },
                        decoration: InputDecoration(
                          labelText: 'auth.login_screen.password'.tr(),
                          prefixIcon: const Icon(
                            Icons.lock_outline,
                            size: DSIconSize.md,
                          ),
                          errorText: _errors['password'],
                          suffixIcon: IconButton(
                            tooltip: _obscurePassword
                                ? 'Show password'
                                : 'Hide password',
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                              size: DSIconSize.md,
                            ),
                            onPressed: () => setState(
                              () => _obscurePassword = !_obscurePassword,
                            ),
                          ),
                        ),
                      ).dsFieldEntry(
                        delay: DSAnimations.stagger(2, step: fieldStep),
                        duration: DSAnimations.dNormal,
                      ),
                      // DS form rhythm: field → formFieldToAction → link → formActionToCta → CTA
                      DSFormActionLink(
                        label: 'auth.forgot_password'.tr(),
                        onPressed: () => context.push('/reset-password'),
                      ).animate().fadeIn(
                        delay: DSAnimations.stagger(3, step: fieldStep),
                        duration: DSAnimations.dFast,
                      ),
                      if (hasUpdate) ...[
                        _LoginUpdateBanner(
                              info: updateState.updateInfo!,
                              isDark: isDark,
                            )
                            .animate()
                            .fadeIn(duration: DSAnimations.dNormal)
                            .slideY(
                              begin: -0.08,
                              end: 0,
                              duration: DSAnimations.dNormal,
                              curve: Curves.easeOutCubic,
                            ),
                        DSSpacing.hFormField,
                      ],
                      AuthPrimaryButton(
                        label: hasUpdate
                            ? 'auth.login_screen.update_to_sign_in'.tr()
                            : _rateLimitRemaining > 0
                            ? 'auth.login_screen.wait_seconds'.tr(
                                namedArgs: {'seconds': '$_rateLimitRemaining'},
                              )
                            : 'auth.login_screen.sign_in'.tr(),
                        onPressed: canSubmit ? _submit : null,
                      ).dsCtaEntry(
                        delay: DSAnimations.stagger(4, step: fieldStep),
                        duration: DSAnimations.dNormal,
                      ),
                    ],
                  ),
                )
                .animate()
                .fadeIn(
                  delay: DSAnimations.stagger(1, step: fieldStep),
                  duration: DSAnimations.dSlow,
                )
                .slideY(
                  begin: 0.08,
                  end: 0,
                  delay: DSAnimations.stagger(1, step: fieldStep),
                  duration: DSAnimations.dSlow,
                  curve: Curves.easeOutCubic,
                )
                .scale(
                  begin: const Offset(0.97, 0.97),
                  end: const Offset(1, 1),
                  delay: DSAnimations.stagger(1, step: fieldStep),
                  duration: DSAnimations.dSlow,
                  curve: Curves.easeOutCubic,
                ),

            DSSpacing.hLg,
            TextButton.icon(
                  onPressed: _callAdmin,
                  icon: const Icon(
                    Icons.support_agent_rounded,
                    size: DSIconSize.md,
                  ),
                  label: Text('auth.login_screen.contact_admin'.tr()),
                  style: TextButton.styleFrom(
                    foregroundColor: DSColors.primary,
                  ),
                )
                .animate()
                .fadeIn(
                  delay: DSAnimations.stagger(5, step: fieldStep),
                  duration: DSAnimations.dNormal,
                )
                .slideY(
                  begin: 0.12,
                  end: 0,
                  delay: DSAnimations.stagger(5, step: fieldStep),
                  duration: DSAnimations.dNormal,
                ),
            DSSpacing.hSm,
            _LoginBuildFooter(isDark: isDark, muted: muted).animate().fadeIn(
              delay: DSAnimations.stagger(6, step: fieldStep),
              duration: DSAnimations.dNormal,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Build / environment footer (version always; API only when debug UI on) ────

class _LoginBuildFooter extends ConsumerWidget {
  const _LoginBuildFooter({required this.isDark, required this.muted});

  final bool isDark;
  final Color muted;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final showApi = ref.watch(showDebugUiProvider);
    final apiUrl = RuntimeEnvironmentService.instance.activeApiBaseUrl;
    final uri = Uri.tryParse(apiUrl);
    final host = (uri != null && uri.host.isNotEmpty) ? uri.host : apiUrl;
    final path = uri?.path ?? '';
    final isDevMode = RuntimeEnvironmentService.instance.isDeveloperMode;
    final modeLabel = kAppDebugMode
        ? (isDevMode ? 'DEBUG · DEV' : 'DEBUG')
        : 'DEVELOPER';

    final soft = muted.withValues(alpha: isDark ? 0.55 : 0.5);
    final surface = isDark
        ? DSColors.white.withValues(alpha: 0.06)
        : DSColors.primary.withValues(alpha: 0.06);
    final border = isDark
        ? DSColors.white.withValues(alpha: 0.10)
        : DSColors.primary.withValues(alpha: 0.12);
    final accent = isDark ? DSColors.warningDark : DSColors.warningText;

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: DSSpacing.sm + 2,
            vertical: DSSpacing.xs,
          ),
          decoration: BoxDecoration(
            color: surface,
            borderRadius: DSStyles.fullRadius,
            border: Border.all(color: border),
          ),
          child: Text(
            AppVersionService.displayVersion,
            style: DSTypography.caption(color: soft).copyWith(
              fontWeight: FontWeight.w600,
              letterSpacing: DSTypography.lsWide,
            ),
          ),
        ),
        if (showApi) ...[
          DSSpacing.hSm,
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
              horizontal: DSSpacing.md,
              vertical: DSSpacing.sm + 2,
            ),
            decoration: BoxDecoration(
              color: surface,
              borderRadius: DSStyles.cardRadius,
              border: Border.all(color: border),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: DSColors.success,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: DSColors.success.withValues(alpha: 0.45),
                            blurRadius: 6,
                          ),
                        ],
                      ),
                    ),
                    DSSpacing.wSm,
                    Text(
                      modeLabel,
                      style: DSTypography.label(color: accent).copyWith(
                        fontSize: DSTypography.sizeXs,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                DSSpacing.hSm,
                Row(
                  children: [
                    Icon(
                      Icons.cloud_outlined,
                      size: DSIconSize.sm,
                      color: isDark ? DSColors.primaryDark : DSColors.primary,
                    ),
                    DSSpacing.wSm,
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            host,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style:
                                DSTypography.caption(
                                  color: isDark
                                      ? DSColors.white.withValues(alpha: 0.85)
                                      : DSColors.black.withValues(alpha: 0.75),
                                ).copyWith(
                                  fontWeight: FontWeight.w600,
                                  fontSize: DSTypography.sizeSm,
                                ),
                          ),
                          if (path.isNotEmpty && path != '/')
                            Text(
                              path,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: DSTypography.caption(color: soft).copyWith(
                                fontSize: DSTypography.sizeXs,
                                fontFamily: 'ui-monospace',
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                DSSpacing.hSm,
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => context.go('/splash'),
                    icon: const Icon(
                      Icons.restart_alt_rounded,
                      size: DSIconSize.sm,
                    ),
                    label: Text('auth.login_screen.debug_view_splash'.tr()),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: accent,
                      side: BorderSide(color: border),
                      minimumSize: const Size(0, 40),
                      padding: const EdgeInsets.symmetric(
                        horizontal: DSSpacing.md,
                        vertical: DSSpacing.xs,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: DSStyles.cardRadius,
                      ),
                      textStyle: DSTypography.label(color: accent).copyWith(
                        fontSize: DSTypography.sizeXs,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

// ── Update banner shown inline on the login screen ───────────────────────────

class _LoginUpdateBanner extends StatelessWidget {
  const _LoginUpdateBanner({required this.info, required this.isDark});

  final UpdateInfo info;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final isMandatory = info.isMandatory;
    final accentColor = isMandatory ? DSColors.error : DSColors.warning;
    final bgColor = isMandatory
        ? accentColor.withValues(alpha: isDark ? 0.12 : 0.07)
        : (isDark
              ? DSColors.warning.withValues(alpha: 0.12)
              : DSColors.warningSurface);

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: DSStyles.cardRadius,
        border: Border.all(color: accentColor.withValues(alpha: 0.35)),
      ),
      padding: const EdgeInsets.all(DSSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                isMandatory
                    ? Icons.warning_rounded
                    : Icons.system_update_rounded,
                size: DSIconSize.md,
                color: accentColor,
              ),
              DSSpacing.wSm,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isMandatory ? 'Update Required' : 'Update Available',
                      style: DSTypography.label(color: accentColor).copyWith(
                        fontWeight: FontWeight.w700,
                        fontSize: DSTypography.sizeMd,
                      ),
                    ),
                    Text(
                      'v${info.latestVersion} is ready to install',
                      style: DSTypography.caption(
                        color: isDark
                            ? DSColors.labelSecondaryDark
                            : DSColors.labelSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (info.releaseNotes.isNotEmpty) ...[
            DSSpacing.hSm,
            Text(
              info.releaseNotes,
              style: DSTypography.caption(
                color: isDark
                    ? DSColors.labelSecondaryDark
                    : DSColors.labelSecondary,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          DSSpacing.hMd,
          FilledButton.icon(
            onPressed: () => context.push('/update'),
            icon: const Icon(
              Icons.system_update_alt_rounded,
              size: DSIconSize.sm,
            ),
            label: Text('auth.login_screen.update_now'.tr()),
            style: FilledButton.styleFrom(
              backgroundColor: accentColor,
              foregroundColor: DSColors.white,
              minimumSize: const Size(double.infinity, 48),
              shape: RoundedRectangleBorder(borderRadius: DSStyles.cardRadius),
            ),
          ),
        ],
      ),
    );
  }
}
