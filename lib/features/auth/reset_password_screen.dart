import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:fsi_courier_app/core/api/api_client.dart';
import 'package:fsi_courier_app/core/api/api_result.dart';
import 'package:fsi_courier_app/shared/helpers/api_payload_helper.dart';
import 'package:fsi_courier_app/shared/helpers/snackbar_helper.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ResetPasswordScreen extends ConsumerStatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  ConsumerState<ResetPasswordScreen> createState() =>
      _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends ConsumerState<ResetPasswordScreen> {
  final _code = TextEditingController();
  final _newPassword = TextEditingController();
  final _confirmPassword = TextEditingController();
  final _errors = <String, String>{};

  bool _loading = false;

  @override
  void dispose() {
    _code.dispose();
    _newPassword.dispose();
    _confirmPassword.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    _errors.clear();
    if (_code.text.trim().isEmpty) {
      _errors['courier_code'] = 'This field is required.';
    }
    if (_newPassword.text.isEmpty) {
      _errors['new_password'] = 'This field is required.';
    }
    if (_confirmPassword.text.isEmpty) {
      _errors['new_password_confirmation'] = 'This field is required.';
    }
    if (_newPassword.text != _confirmPassword.text) {
      _errors['new_password_confirmation'] = 'Passwords do not match.';
    }
    if (_errors.isNotEmpty) {
      setState(() {});
      return;
    }

    setState(() => _loading = true);
    final api = ref.read(apiClientProvider);
    final result = await api.post<Map<String, dynamic>>(
      '/reset-password',
      data: {
        'courier_code': _code.text.trim(),
        'new_password': _newPassword.text,
        'new_password_confirmation': _confirmPassword.text,
      },
      parser: parseApiMap,
    );

    if (!mounted) return;

    switch (result) {
      case ApiSuccess<Map<String, dynamic>>():
        showAppSnackbar(
          context,
          'Password reset successful.',
          type: SnackbarType.success,
        );
        context.go('/login');
      case ApiValidationError<Map<String, dynamic>>(:final errors):
        errors.forEach((key, value) => _errors[key] = value.first);
      case ApiServerError<Map<String, dynamic>>(:final message):
        showAppSnackbar(context, message, type: SnackbarType.error);
      case ApiNetworkError<Map<String, dynamic>>(:final message):
        showAppSnackbar(context, message, type: SnackbarType.error);
      default:
        showAppSnackbar(
          context,
          'Unable to reset password.',
          type: SnackbarType.error,
        );
    }

    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(title: const Text('Reset Password')),
      body: Stack(
        fit: StackFit.expand,
        children: [
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
                      Container(
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF1E1E2E)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(isDark ? 0.25 : 0.06),
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
                              controller: _code,
                              decoration: InputDecoration(
                                labelText: 'Courier Code',
                                prefixIcon: const Icon(Icons.badge_outlined),
                                errorText: _errors['courier_code'],
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                            const SizedBox(height: 14),
                            TextField(
                              controller: _newPassword,
                              obscureText: true,
                              decoration: InputDecoration(
                                labelText: 'New Password',
                                prefixIcon: const Icon(Icons.lock_outline),
                                errorText: _errors['new_password'],
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                            const SizedBox(height: 14),
                            TextField(
                              controller: _confirmPassword,
                              obscureText: true,
                              decoration: InputDecoration(
                                labelText: 'Confirm New Password',
                                prefixIcon: const Icon(Icons.lock_outline),
                                errorText: _errors['new_password_confirmation'],
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),
                            FilledButton(
                              style: FilledButton.styleFrom(
                                backgroundColor: Theme.of(context).colorScheme.primary,
                                foregroundColor: Colors.white,
                                minimumSize: const Size(double.infinity, 52),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              onPressed: _loading ? null : _submit,
                              child: const Text(
                                'Submit',
                                style: TextStyle(
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
