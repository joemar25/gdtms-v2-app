// DOCS: docs/features/auth.md — update that file when you edit this one.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';

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
      _errors['phone_number'] = 'This field is required.';
    }
    if (_passwordController.text.isEmpty) {
      _errors['password'] = 'This field is required.';
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
            'Invalid login response. Please try again.',
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
      case ApiValidationError<Map<String, dynamic>>(:final errors):
        errors.forEach((key, value) => _errors[key] = value.first);
      case ApiUnauthorized<Map<String, dynamic>>(:final message):
        showAppSnackbar(
          context,
          message ?? 'Invalid phone number or password.',
          type: SnackbarType.error,
        );
      case ApiNetworkError<Map<String, dynamic>>():
        showAppSnackbar(
          context,
          'No connection. Please check your internet.',
          type: SnackbarType.error,
        );
      case ApiRateLimited<Map<String, dynamic>>(
        :final message,
        :final retryAfterSeconds,
      ):
        final seconds = retryAfterSeconds ?? 60;
        _startRateLimitCountdown(seconds);
        showAppSnackbar(
          context,
          '$message Try again in $seconds seconds.',
          type: SnackbarType.error,
        );
      case ApiServerError<Map<String, dynamic>>(:final message):
        showAppSnackbar(context, message, type: SnackbarType.error);
      default:
        showAppSnackbar(context, 'Login failed.', type: SnackbarType.error);
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
                              color: DSColors.error,
                              borderRadius: DSStyles
                                  .sheetRadius, // 28.0 (Legacy radiusSheet)
                              boxShadow: [
                                BoxShadow(
                                  color: DSColors.error.withValues(
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
                          'Sign In',
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
                          'Enter your credentials to continue',
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
                        _fieldLabel('Phone Number').dsFadeEntry(
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
                            hintText: 'e.g. 09XXXXXXXXX',
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
                        _fieldLabel('Password').dsFadeEntry(
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
                            hintText: 'Your password',
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
                              foregroundColor: DSColors.error,
                            ),
                            child: const Text('Forgot password?'),
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
                                ? 'Wait ($_rateLimitRemaining s)'
                                : 'Sign In',
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
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Having trouble? ',
                              style: DSTypography.body().copyWith(
                                fontSize: DSTypography.sizeMd,
                                color: subtitleColor,
                              ),
                            ),
                            GestureDetector(
                              onTap: _callAdmin,
                              child: Text(
                                'Contact your admin',
                                style: DSTypography.body().copyWith(
                                  fontSize: DSTypography.sizeMd,
                                  color: DSColors.error,
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
    final uri = Uri.parse('tel:09213920200');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }
}
