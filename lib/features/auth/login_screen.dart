import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';

import 'package:fsi_courier_app/core/api/api_client.dart';
import 'package:fsi_courier_app/core/api/api_result.dart';
import 'package:fsi_courier_app/core/auth/auth_provider.dart';
import 'package:fsi_courier_app/core/auth/auth_storage.dart';
import 'package:fsi_courier_app/core/config.dart';
import 'package:fsi_courier_app/core/constants.dart';
import 'package:fsi_courier_app/core/device/device_info.dart';
import 'package:fsi_courier_app/shared/helpers/api_payload_helper.dart';
import 'package:fsi_courier_app/shared/helpers/snackbar_helper.dart';
import 'package:fsi_courier_app/styles/color_styles.dart';

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
    final device = ref.read(deviceInfoProvider);
    final authStorage = ref.read(authStorageProvider);

    final result = await api.post<Map<String, dynamic>>(
      '/login',
      data: {
        'phone_number': _phoneController.text.trim(),
        'password': _passwordController.text,
        'device_name': deviceName,
        'device_identifier': await device.deviceId,
        'device_type': kDeviceTypeLogin,
        'app_version': appVersion,
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

        await authStorage.setToken(token);
        await authStorage.setCourier(mergedCourier);
        await _saveCredentials();
        await ref.read(authProvider.notifier).initialize();
        if (mounted) context.go('/dashboard');
      case ApiValidationError<Map<String, dynamic>>(:final errors):
        errors.forEach((key, value) => _errors[key] = value.first);
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ─ Background ─────────────────────────────────────────────
          ColoredBox(
            color: isDark ? const Color(0xFF121212) : const Color(0xFFF0F4F0),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // ─ Header card ──────────────────────────────────
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              ColorStyles.grabGreen,
                              ColorStyles.grabGreen.withValues(
                                red: 0.1,
                                green: 0.55,
                                blue: 0.2,
                                alpha: 1.0,
                              ),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        padding: const EdgeInsets.fromLTRB(24, 32, 24, 32),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 64,
                              height: 64,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Icon(
                                Icons.mail_outline,
                                size: 40,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              appName,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.5,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Sign in to your account',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.75),
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // ─ Fields card ──────────────────────────────────
                      Container(
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF1E1E2E)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(
                                alpha: isDark ? 0.25 : 0.06,
                              ),
                              blurRadius: 16,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            TextField(
                              controller: _phoneController,
                              keyboardType: TextInputType.phone,
                              decoration: InputDecoration(
                                labelText: 'Phone Number',
                                prefixIcon: const Icon(Icons.phone_outlined),
                                errorText: _errors['phone_number'],
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                            const SizedBox(height: 14),
                            TextField(
                              controller: _passwordController,
                              obscureText: _obscurePassword,
                              decoration: InputDecoration(
                                labelText: 'Password',
                                prefixIcon: const Icon(Icons.lock_outline),
                                errorText: _errors['password'],
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                suffixIcon: AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 200),
                                  transitionBuilder: (child, anim) =>
                                      ScaleTransition(
                                        scale: anim,
                                        child: child,
                                      ),
                                  child: IconButton(
                                    key: ValueKey(_obscurePassword),
                                    icon: Icon(
                                      _obscurePassword
                                          ? Icons.visibility_off_outlined
                                          : Icons.visibility_outlined,
                                    ),
                                    onPressed: () => setState(
                                      () =>
                                          _obscurePassword = !_obscurePassword,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed: () =>
                                    context.push('/reset-password'),
                                child: const Text('Forgot password?'),
                              ),
                            ),
                            const SizedBox(height: 4),
                            FilledButton(
                              style: FilledButton.styleFrom(
                                backgroundColor: ColorStyles.grabGreen,
                                foregroundColor: Colors.white,
                                minimumSize: const Size(double.infinity, 52),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              onPressed: _loading || _rateLimitRemaining > 0
                                  ? null
                                  : _submit,
                              child: Text(
                                _rateLimitRemaining > 0
                                    ? 'Wait ($_rateLimitRemaining s)'
                                    : 'Sign In',
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (_loading)
            const ColoredBox(
              color: Colors.black26,
              child: Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }
}
