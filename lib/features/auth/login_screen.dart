import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'dart:async';

import '../../core/api/api_client.dart';
import '../../core/api/api_result.dart';
import '../../core/auth/auth_provider.dart';
import '../../core/auth/auth_storage.dart';
import '../../core/config.dart';
import '../../core/constants.dart';
import '../../core/device/device_info.dart';
import '../../shared/helpers/api_payload_helper.dart';
import '../../shared/helpers/snackbar_helper.dart';

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
  int _rateLimitRemaining = 0;
  Timer? _rateLimitTimer;

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
    return Scaffold(
      body: Stack(
        children: [
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const FlutterLogo(size: 88),
                      const SizedBox(height: 16),
                      Text(
                        'Courier Field App',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 24),
                      TextField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        decoration: InputDecoration(
                          labelText: 'Phone Number',
                          errorText: _errors['phone_number'],
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _passwordController,
                        obscureText: true,
                        decoration: InputDecoration(
                          labelText: 'Password',
                          errorText: _errors['password'],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () => context.push('/reset-password'),
                          child: const Text('Forgot password?'),
                        ),
                      ),
                      const SizedBox(height: 8),
                      FilledButton(
                        onPressed: _loading || _rateLimitRemaining > 0
                            ? null
                            : _submit,
                        child: Text(
                          _rateLimitRemaining > 0
                              ? 'Login ($_rateLimitRemaining)'
                              : 'Login',
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
