import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_result.dart';
import '../../shared/helpers/api_payload_helper.dart';
import '../../shared/helpers/snackbar_helper.dart';
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
    return Scaffold(
      appBar: AppBar(title: const Text('Reset Password')),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.all(16),
            children: [
              TextField(
                controller: _code,
                decoration: InputDecoration(
                  labelText: 'Courier Code',
                  errorText: _errors['courier_code'],
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _newPassword,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'New Password',
                  errorText: _errors['new_password'],
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _confirmPassword,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'Confirm New Password',
                  errorText: _errors['new_password_confirmation'],
                ),
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _loading ? null : _submit,
                child: const Text('Submit'),
              ),
            ],
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
