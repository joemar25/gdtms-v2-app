// DOCS: docs/development-standards.md
// DOCS: docs/features/auth.md — update that file when you edit this one.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';

import 'package:fsi_courier_app/shared/widgets/contact_app_sheet.dart';

import 'package:fsi_courier_app/core/api/api_client.dart';
import 'package:fsi_courier_app/core/auth/auth_provider.dart';
import 'package:fsi_courier_app/core/auth/auth_storage.dart';
import 'package:fsi_courier_app/core/config.dart';
import 'package:fsi_courier_app/core/services/app_version_service.dart';
import 'package:fsi_courier_app/core/database/app_database.dart';
import 'package:fsi_courier_app/core/constants.dart';
import 'package:fsi_courier_app/shared/helpers/api_payload_helper.dart';
import 'package:fsi_courier_app/shared/helpers/snackbar_helper.dart';
import 'package:fsi_courier_app/design_system/design_system.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
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
    super.dispose();
  }

  void _startRateLimitCountdown(int seconds) {
    _rateLimitTimer?.cancel();
    setState(() {
      _rateLimitRemaining = seconds;
    });

    _rateLimitTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      if (_rateLimitRemaining <= 1) {
        timer.cancel();
        setState(() {
          _rateLimitRemaining = 0;
        });
        return;
      }

      setState(() {
        _rateLimitRemaining -= 1;
      });
    });
  }

  Future<void> _submit() async {
    setState(() {
      _errors.clear();
    });

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
          showAppSnackbar(
            context,
            'auth.login_screen.error_invalid_response'.tr(),
            type: SnackbarType.error,
          );
          break;
        }

        final user = mapFromKey(payload, 'user');
        final courier = mapFromKey(payload, 'courier');
        final mergedCourier = <String, dynamic>{...user, ...courier};

        // Session fingerprint check — wipe stale local data if courier or
        // server changed since the last session (safety net for force-quit).
        final courierId = mergedCourier['id']?.toString() ?? '';
        final newFingerprint = '${apiBaseUrl}_$courierId';
        final prefs = await SharedPreferences.getInstance();
        final prevFingerprint = prefs.getString('_session_fingerprint') ?? '';

        final lastCourierId = await authStorage.getLastCourierId();
        if ((prevFingerprint.isNotEmpty && prevFingerprint != newFingerprint) ||
            (lastCourierId != null && lastCourierId != courierId)) {
          await AppDatabase.clearAllDeliveryData();
        }
        await prefs.setString('_session_fingerprint', newFingerprint);

        await authStorage.setToken(token);
        await authStorage.setCourier(mergedCourier);
        await authStorage.setLastCourierId(courierId);
        await _saveCredentials();
        await ref.read(authProvider.notifier).initialize();
        if (mounted) context.go('/dashboard');
        break;
      case ApiValidationError<Map<String, dynamic>>(:final errors):
        errors.forEach((key, value) => _errors[key] = value.first);
        break;
      case ApiUnauthorized<Map<String, dynamic>>(:final message):
        showAppSnackbar(
          context,
          message != null && message.isNotEmpty
              ? message
              : 'auth.login_screen.error_invalid_credentials'.tr(),
          type: SnackbarType.error,
        );
        break;
      case ApiNetworkError<Map<String, dynamic>>():
        showAppSnackbar(
          context,
          'auth.login_screen.error_no_connection'.tr(),
          type: SnackbarType.error,
        );
        break;
      case ApiRateLimited<Map<String, dynamic>>(
        :final message,
        :final retryAfterSeconds,
      ):
        final seconds = retryAfterSeconds ?? 60;
        _startRateLimitCountdown(seconds);
        showAppSnackbar(
          context,
          '${message.isNotEmpty ? message : ''} ${'auth.login_screen.error_try_again_seconds'.tr(namedArgs: {'seconds': '$seconds'})}',
          type: SnackbarType.error,
        );
        break;
      case ApiServerError<Map<String, dynamic>>(:final message):
        showAppSnackbar(context, message, type: SnackbarType.error);
        break;
      default:
        showAppSnackbar(
          context,
          'auth.login_screen.error_login_failed'.tr(),
          type: SnackbarType.error,
        );
    }

    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final subtitleColor = colorScheme.onSurfaceVariant;

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isDark
                ? [DSColors.scaffoldDark, DSColors.cardElevatedDark]
                : [
                    DSColors.primary.withValues(alpha: DSStyles.alphaSoft),
                    DSColors.white,
                  ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // ── Theme Toggle (Top Right) ──────────────────────────────────
            Positioned(
              top: MediaQuery.of(context).padding.top + DSSpacing.sm,
              right: DSSpacing.sm,
              child: Material(
                color: DSColors.transparent,
                child: InkWell(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    final nextMode = isDark ? ThemeMode.light : ThemeMode.dark;
                    ref.read(authProvider.notifier).setThemeMode(nextMode);
                  },
                  borderRadius: BorderRadius.circular(100),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    padding: const EdgeInsets.all(DSSpacing.sm),
                    decoration: BoxDecoration(
                      color: isDark
                          ? DSColors.white.withValues(alpha: 0.12)
                          : DSColors.primary.withValues(alpha: 0.08),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isDark
                            ? DSColors.white.withValues(alpha: 0.1)
                            : DSColors.primary.withValues(alpha: 0.1),
                      ),
                    ),
                    child: Icon(
                      isDark
                          ? Icons.light_mode_rounded
                          : Icons.dark_mode_rounded,
                      size: DSIconSize.md,
                      color: isDark ? DSColors.white : DSColors.primary,
                    ),
                  ),
                ),
              ),
            ).dsFadeEntry(delay: const Duration(milliseconds: 600)),

            SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: EdgeInsets.symmetric(
                    horizontal: 28,
                    vertical: DSSpacing.xs,
                  ),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // ── Logo ──────────────────────────────────────────
                        Center(
                          child: Container(
                            width: DSIconSize.heroSm,
                            height: DSIconSize.heroSm,
                            decoration: BoxDecoration(
                              color: DSColors.primary,
                              borderRadius: DSStyles
                                  .sheetRadius, // 28.0 (Legacy radiusSheet)
                              boxShadow: [
                                BoxShadow(
                                  color: DSColors.primary.withValues(
                                    alpha: DSStyles.alphaMuted,
                                  ),
                                  blurRadius: DSStyles.radiusXL,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.local_shipping_rounded,
                              size: DSIconSize.xl,
                              color: DSColors.white,
                            ),
                          ),
                        ).dsHeroEntry(),
                        DSSpacing.hXl,

                        // ── Title ────────────────────────────────────────
                        Text(
                          'auth.login_screen.title'.tr(),
                          textAlign: TextAlign.center,
                          style: DSTypography.heading().copyWith(
                            fontSize: DSTypography.sizeXl,
                            fontWeight: FontWeight.w700,
                            color: colorScheme.onSurface,
                            letterSpacing: DSTypography.lsSlightlyTight,
                          ),
                        ).dsFadeEntry(
                          delay: DSAnimations.stagger(
                            1,
                            step: DSAnimations.staggerNormal,
                          ),
                        ),
                        DSSpacing.hSm,
                        Text(
                          'auth.login_screen.subtitle'.tr(),
                          textAlign: TextAlign.center,
                          style: DSTypography.body().copyWith(
                            fontSize: DSTypography.sizeMd,
                            color: subtitleColor,
                          ),
                        ).dsFadeEntry(
                          delay: DSAnimations.stagger(
                            2,
                            step: DSAnimations.staggerNormal,
                          ),
                        ),
                        DSSpacing.hXl,

                        // ── Phone Number ──────────────────────────────────
                        _fieldLabel(
                          'auth.login_screen.phone_number'.tr(),
                        ).dsFadeEntry(
                          delay: DSAnimations.stagger(
                            3,
                            step: DSAnimations.staggerNormal,
                          ),
                        ),
                        DSSpacing.hSm,
                        TextField(
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                          decoration: InputDecoration(
                            hintText: 'auth.login_screen.phone_hint'.tr(),
                            prefixIcon: const Icon(
                              Icons.phone_outlined,
                              size: DSIconSize.md,
                            ),
                            errorText: _errors['phone_number'],
                          ),
                        ).dsFieldEntry(
                          delay: DSAnimations.stagger(
                            4,
                            step: DSAnimations.staggerNormal,
                          ),
                        ),
                        DSSpacing.hMd,

                        // ── Password ──────────────────────────────────────
                        _fieldLabel(
                          'auth.login_screen.password'.tr(),
                        ).dsFadeEntry(
                          delay: DSAnimations.stagger(
                            5,
                            step: DSAnimations.staggerNormal,
                          ),
                        ),
                        DSSpacing.hSm,
                        TextField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          decoration: InputDecoration(
                            hintText: 'auth.login_screen.password_hint'.tr(),
                            prefixIcon: const Icon(
                              Icons.lock_outline,
                              size: DSIconSize.md,
                            ),
                            errorText: _errors['password'],
                            suffixIcon: IconButton(
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
                          delay: DSAnimations.stagger(
                            6,
                            step: DSAnimations.staggerNormal,
                          ),
                        ),

                        // ── Forgot Password ───────────────────────────────
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: () => context.push('/reset-password'),
                            style: TextButton.styleFrom(
                              foregroundColor: DSColors.primary,
                            ),
                            child: Text('auth.forgot_password'.tr()),
                          ),
                        ),
                        DSSpacing.hXs,

                        // ── Sign In Button ────────────────────────────────
                        FilledButton(
                          onPressed: _loading || _rateLimitRemaining > 0
                              ? null
                              : _submit,
                          style: FilledButton.styleFrom(
                            minimumSize: const Size(double.infinity, 52),
                            shape: RoundedRectangleBorder(
                              borderRadius: DSStyles.cardRadius, // 16.0
                            ),
                          ),
                          child: Text(
                            _rateLimitRemaining > 0
                                ? 'auth.login_screen.wait_seconds'.tr(
                                    namedArgs: {
                                      'seconds': '$_rateLimitRemaining',
                                    },
                                  )
                                : 'auth.login_screen.sign_in'.tr(),
                            style: DSTypography.button().copyWith(
                              fontSize: DSTypography.sizeMd,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ).dsCtaEntry(
                          delay: DSAnimations.stagger(
                            7,
                            step: DSAnimations.staggerNormal,
                          ),
                        ),
                        DSSpacing.hXl,

                        // ── Contact Admin Footer ──────────────────────────
                        Wrap(
                          alignment: WrapAlignment.center,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: DSSpacing.xs,
                          children: [
                            Text(
                              'auth.login_screen.having_trouble'.tr(),
                              style: DSTypography.body().copyWith(
                                fontSize: DSTypography.sizeMd,
                                color: subtitleColor,
                              ),
                            ),
                            GestureDetector(
                              onTap: _callAdmin,
                              child: Text(
                                'auth.login_screen.contact_admin'.tr(),
                                style: DSTypography.body().copyWith(
                                  fontSize: DSTypography.sizeMd,
                                  color: DSColors.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            if (_loading)
              ColoredBox(
                color: DSColors.black.withValues(alpha: DSStyles.alphaMuted),
                child: Center(child: CircularProgressIndicator()),
              ),
          ],
        ),
      ),
    );
  }

  Widget _fieldLabel(String text) {
    return Text(
      text,
      style: DSTypography.label().copyWith(
        fontSize: DSTypography.sizeMd,
        fontWeight: FontWeight.w600,
        color: Theme.of(context).colorScheme.onSurface,
      ),
    );
  }

  Future<void> _callAdmin() async {
    await showContactAppSheet(
      context,
      '09213920200',
      title: 'auth.login_screen.contact_admin'.tr(),
    );
  }
}
