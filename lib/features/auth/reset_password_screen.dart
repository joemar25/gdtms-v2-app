// DOCS: docs/features/auth.md — update that file when you edit this one.

// =============================================================================
// reset_password_screen.dart
// =============================================================================
//
// Purpose:
//   Allows a courier to reset or change their account password.
//
// Modes:
//   • Unauthenticated (default) — accessed from the login screen when a courier
//     has forgotten their password. Requires the courier code and a new password.
//     On success, the user is redirected to the login screen.
//
//   • Authenticated (authenticatedMode: true) — accessed from the profile page
//     by a logged-in courier who wants to change their current password. The
//     courier code is auto-filled and read-only; an additional "Current Password"
//     field is shown. On success, the user is sent back to the dashboard.
//
// API:
//   PATCH /auth/reset-password
//
// Navigation:
//   Route: /reset-password
//   Pushed from: LoginScreen (unauthenticated), ProfileScreen (authenticated)
// =============================================================================

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fsi_courier_app/core/api/api_client.dart';
import 'package:fsi_courier_app/core/auth/auth_provider.dart';
import 'package:fsi_courier_app/shared/helpers/api_payload_helper.dart';
import 'package:fsi_courier_app/shared/helpers/snackbar_helper.dart';
import 'package:fsi_courier_app/shared/widgets/app_header_bar.dart';
import 'package:fsi_courier_app/design_system/design_system.dart';

class ResetPasswordScreen extends ConsumerStatefulWidget {
  const ResetPasswordScreen({super.key, this.authenticatedMode = false});

  /// When [true], the screen is accessed by an authenticated courier from the
  /// profile page. The courier code is auto-filled and read-only, a
  /// "Current Password" field is shown, and on success the user is sent back
  /// to the dashboard instead of the login screen.
  final bool authenticatedMode;

  @override
  ConsumerState<ResetPasswordScreen> createState() =>
      _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends ConsumerState<ResetPasswordScreen> {
  late final TextEditingController _code;
  final _currentPassword = TextEditingController();
  final _newPassword = TextEditingController();
  final _confirmPassword = TextEditingController();
  final _errors = <String, String>{};

  bool _loading = false;
  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;

  @override
  void initState() {
    super.initState();
    // Pre-fill courier code for authenticated users (read-only).
    if (widget.authenticatedMode) {
      final courier = ref.read(authProvider).courier ?? {};
      _code = TextEditingController(
        text: courier['courier_code']?.toString() ?? '',
      );
    } else {
      _code = TextEditingController();
    }
  }

  @override
  void dispose() {
    _code.dispose();
    _currentPassword.dispose();
    _newPassword.dispose();
    _confirmPassword.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    _errors.clear();

    if (!widget.authenticatedMode && _code.text.trim().isEmpty) {
      _errors['courier_code'] = 'This field is required.';
    }
    if (widget.authenticatedMode && _currentPassword.text.isEmpty) {
      _errors['current_password'] = 'This field is required.';
    }
    if (_newPassword.text.isEmpty) {
      _errors['new_password'] = 'This field is required.';
    }
    if (_confirmPassword.text.isEmpty) {
      _errors['new_password_confirmation'] = 'This field is required.';
    }
    if (_newPassword.text.isNotEmpty &&
        _confirmPassword.text.isNotEmpty &&
        _newPassword.text != _confirmPassword.text) {
      _errors['new_password_confirmation'] = 'Passwords do not match.';
    }
    if (_errors.isNotEmpty) {
      setState(() {});
      return;
    }

    setState(() => _loading = true);
    final api = ref.read(apiClientProvider);

    final ApiResult<Map<String, dynamic>> result;

    if (widget.authenticatedMode) {
      result = await api.post<Map<String, dynamic>>(
        '/change-password',
        data: {
          'current_password': _currentPassword.text,
          'new_password': _newPassword.text,
          'new_password_confirmation': _confirmPassword.text,
        },
        parser: parseApiMap,
      );
    } else {
      result = await api.post<Map<String, dynamic>>(
        '/reset-password',
        data: {
          'courier_code': _code.text.trim(),
          'new_password': _newPassword.text,
          'new_password_confirmation': _confirmPassword.text,
        },
        parser: parseApiMap,
      );
    }

    if (!mounted) return;

    switch (result) {
      case ApiSuccess<Map<String, dynamic>>():
        showAppSnackbar(
          context,
          widget.authenticatedMode
              ? 'Password changed successfully.'
              : 'Password reset successful.',
          type: SnackbarType.success,
        );
        if (widget.authenticatedMode) {
          context.go('/dashboard');
        } else {
          context.go('/login');
        }
      case ApiValidationError<Map<String, dynamic>>(:final errors):
        errors.forEach((key, value) => _errors[key] = value.first);
        setState(() {});
      case ApiServerError<Map<String, dynamic>>(:final message):
        showAppSnackbar(context, message, type: SnackbarType.error);
      case ApiNetworkError<Map<String, dynamic>>(:final message):
        showAppSnackbar(context, message, type: SnackbarType.error);
      default:
        showAppSnackbar(
          context,
          widget.authenticatedMode
              ? 'Unable to change password.'
              : 'Unable to reset password.',
          type: SnackbarType.error,
        );
    }

    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.authenticatedMode
        ? 'Change Password'
        : 'Reset Password';

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppHeaderBar(
        title: title,
        showNotificationBell: widget.authenticatedMode,
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              DSSpacing.lg,
              DSSpacing.xl,
              DSSpacing.lg,
              DSSpacing.xl,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: DSIconSize.heroSm),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── Icon + heading ─────────────────────────────────
                  Center(
                    child: Container(
                      width: DSIconSize.heroLg,
                      height: DSIconSize.heroLg,
                      decoration: BoxDecoration(
                        color: DSColors.error.withValues(
                          alpha: DSStyles.alphaSubtle,
                        ),
                        borderRadius: DSStyles.cardRadius,
                      ),
                      child: const Icon(
                        Icons.lock_reset_rounded,
                        size: DSIconSize.xl,
                        color: DSColors.error,
                      ),
                    ),
                  ).dsHeroEntry(),
                  DSSpacing.hLg,
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: DSTypography.heading().copyWith(
                      fontSize: DSTypography.sizeLg,
                      fontWeight: FontWeight.w700,
                      color: isDark
                          ? DSColors.labelPrimaryDark
                          : DSColors.labelPrimary,
                      letterSpacing: -0.3,
                    ),
                  ).dsFadeEntry(
                    delay: DSAnimations.stagger(
                      1,
                      step: DSAnimations.staggerNormal,
                    ),
                  ),
                  DSSpacing.hSm,
                  Text(
                    widget.authenticatedMode
                        ? 'Update your current password securely.'
                        : 'Enter your courier code and new password.',
                    textAlign: TextAlign.center,
                    style: DSTypography.body().copyWith(
                      fontSize: DSTypography.sizeMd,
                      color: isDark
                          ? DSColors.labelSecondaryDark
                          : DSColors.labelSecondary,
                    ),
                  ).dsFadeEntry(
                    delay: DSAnimations.stagger(
                      2,
                      step: DSAnimations.staggerNormal,
                    ),
                  ),
                  DSSpacing.hXl,

                  // ── Courier Code ───────────────────────────────────
                  // Only visible in Debug mode (completely removed in Production)
                  if (kDebugMode) ...[
                    // Label changes dynamically based on authenticatedMode
                    _fieldLabel(
                      context,
                      isDark,
                      widget.authenticatedMode
                          ? 'Courier Code (Debug)'
                          : 'Courier Code',
                    ),
                    DSSpacing.hSm,

                    widget.authenticatedMode
                        ? TextField(
                            controller: _code,
                            readOnly: true,
                            decoration: InputDecoration(
                              hintText: 'Your courier code',
                              prefixIcon: const Icon(
                                Icons.badge_outlined,
                                size: DSIconSize.md,
                              ),
                              errorText: _errors['courier_code'],
                              filled: true,
                              fillColor: isDark
                                  ? DSColors.secondarySurfaceDark
                                  : DSColors.secondarySurfaceLight,
                              suffixIcon: Icon(
                                Icons.lock_outline,
                                size: DSIconSize.sm,
                                color: isDark
                                    ? DSColors.labelTertiaryDark
                                    : DSColors.labelTertiary,
                              ),
                            ),
                          )
                        : TextField(
                            controller: _code,
                            readOnly:
                                false, // Editable input when not authenticated
                            decoration: InputDecoration(
                              hintText: 'Your courier code',
                              prefixIcon: const Icon(
                                Icons.badge_outlined,
                                size: DSIconSize.md,
                              ),
                              errorText: _errors['courier_code'],
                              filled: false,
                              suffixIcon: null,
                            ),
                          ),

                    DSSpacing.hMd,
                  ],

                  // ── Current Password (auth mode only) ──────────────
                  if (widget.authenticatedMode) ...[
                    _fieldLabel(context, isDark, 'Current Password'),
                    DSSpacing.hSm,
                    TextField(
                      controller: _currentPassword,
                      obscureText: _obscureCurrent,
                      decoration: InputDecoration(
                        hintText: 'Your current password',
                        prefixIcon: const Icon(
                          Icons.lock_outline,
                          size: DSIconSize.md,
                        ),
                        errorText: _errors['current_password'],
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscureCurrent
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            size: DSIconSize.md,
                          ),
                          onPressed: () => setState(
                            () => _obscureCurrent = !_obscureCurrent,
                          ),
                        ),
                      ),
                    ).dsFieldEntry(
                      delay: DSAnimations.stagger(
                        widget.authenticatedMode && kDebugMode ? 6 : 4,
                        step: DSAnimations.staggerNormal,
                      ),
                    ),
                    DSSpacing.hMd,
                  ],

                  // ── New Password ───────────────────────────────────
                  _fieldLabel(context, isDark, 'New Password').dsFadeEntry(
                    delay: DSAnimations.stagger(
                      widget.authenticatedMode ? (kDebugMode ? 7 : 5) : 3,
                      step: DSAnimations.staggerNormal,
                    ),
                  ),
                  DSSpacing.hSm,
                  TextField(
                    controller: _newPassword,
                    obscureText: _obscureNew,
                    decoration: InputDecoration(
                      hintText: 'At least 8 characters',
                      prefixIcon: const Icon(
                        Icons.lock_outline,
                        size: DSIconSize.md,
                      ),
                      errorText: _errors['new_password'],
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureNew
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          size: DSIconSize.md,
                        ),
                        onPressed: () =>
                            setState(() => _obscureNew = !_obscureNew),
                      ),
                    ),
                  ).dsFieldEntry(
                    delay: DSAnimations.stagger(
                      widget.authenticatedMode ? (kDebugMode ? 8 : 6) : 4,
                      step: DSAnimations.staggerNormal,
                    ),
                  ),
                  DSSpacing.hMd,

                  // ── Confirm New Password ───────────────────────────
                  _fieldLabel(
                    context,
                    isDark,
                    'Confirm New Password',
                  ).dsFadeEntry(
                    delay: DSAnimations.stagger(
                      widget.authenticatedMode ? (kDebugMode ? 9 : 7) : 5,
                      step: DSAnimations.staggerNormal,
                    ),
                  ),
                  DSSpacing.hSm,
                  TextField(
                    controller: _confirmPassword,
                    obscureText: _obscureConfirm,
                    decoration: InputDecoration(
                      hintText: 'Re-enter your new password',
                      prefixIcon: const Icon(
                        Icons.lock_outline,
                        size: DSIconSize.md,
                      ),
                      errorText: _errors['new_password_confirmation'],
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureConfirm
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          size: DSIconSize.md,
                        ),
                        onPressed: () =>
                            setState(() => _obscureConfirm = !_obscureConfirm),
                      ),
                    ),
                  ).dsFieldEntry(
                    delay: DSAnimations.stagger(
                      widget.authenticatedMode ? (kDebugMode ? 10 : 8) : 6,
                      step: DSAnimations.staggerNormal,
                    ),
                  ),
                  DSSpacing.hXl,

                  // ── Submit Button ──────────────────────────────────
                  FilledButton(
                    onPressed: _loading ? null : _submit,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(double.infinity, 52),
                      shape: RoundedRectangleBorder(
                        borderRadius: DSStyles.cardRadius, // 16.0
                      ),
                    ),
                    child: Text(
                      widget.authenticatedMode ? 'Change Password' : 'Submit',
                      style: DSTypography.button().copyWith(
                        fontSize: DSTypography.sizeMd,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ).dsCtaEntry(
                    delay: DSAnimations.stagger(
                      widget.authenticatedMode ? (kDebugMode ? 11 : 9) : 7,
                      step: DSAnimations.staggerNormal,
                    ),
                  ),
                ],
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
    );
  }

  Widget _fieldLabel(BuildContext context, bool isDark, String text) {
    return Text(
      text,
      style: DSTypography.label().copyWith(
        fontSize: DSTypography.sizeMd,
        fontWeight: FontWeight.w600,
        color: isDark ? DSColors.labelSecondaryDark : DSColors.labelSecondary,
      ),
    );
  }
}
