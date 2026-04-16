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

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 28,
                  vertical: 40,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // ── Logo ──────────────────────────────────────────
                      Center(
                        child: Container(
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            color: const Color(0xFF00B14F),
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(
                                  0xFF00B14F,
                                ).withValues(alpha: 0.30),
                                blurRadius: 20,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.local_shipping_rounded,
                            size: 36,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(height: 28),

                      // ── Title ────────────────────────────────────────
                      Text(
                        'Sign In',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w700,
                          color: colorScheme.onSurface,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Enter your credentials to continue',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          color: subtitleColor,
                        ),
                      ),
                      const SizedBox(height: 36),

                      // ── Phone Number ──────────────────────────────────
                      _fieldLabel('Phone Number'),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        decoration: InputDecoration(
                          hintText: 'e.g. 09XXXXXXXXX',
                          prefixIcon: const Icon(
                            Icons.phone_outlined,
                            size: 20,
                          ),
                          errorText: _errors['phone_number'],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // ── Password ──────────────────────────────────────
                      _fieldLabel('Password'),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        decoration: InputDecoration(
                          hintText: 'Your password',
                          prefixIcon: const Icon(Icons.lock_outline, size: 20),
                          errorText: _errors['password'],
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                              size: 20,
                            ),
                            onPressed: () => setState(
                              () => _obscurePassword = !_obscurePassword,
                            ),
                          ),
                        ),
                      ),

                      // ── Forgot Password ───────────────────────────────
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () => context.push('/reset-password'),
                          child: const Text('Forgot password?'),
                        ),
                      ),
                      const SizedBox(height: 4),

                      // ── Sign In Button ────────────────────────────────
                      FilledButton(
                        onPressed: _loading || _rateLimitRemaining > 0
                            ? null
                            : _submit,
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(double.infinity, 52),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
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
                      const SizedBox(height: 32),

                      // ── Contact Admin Footer ──────────────────────────
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Having trouble? ',
                            style: TextStyle(
                              fontSize: 13,
                              color: subtitleColor,
                            ),
                          ),
                          GestureDetector(
                            onTap: _callAdmin,
                            child: const Text(
                              'Contact your admin',
                              style: TextStyle(
                                fontSize: 13,
                                color: Color(0xFF00B14F),
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
            const ColoredBox(
              color: Colors.black26,
              child: Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }

  Widget _fieldLabel(String text) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 13,
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
