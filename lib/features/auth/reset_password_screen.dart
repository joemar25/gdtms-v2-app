// DOCS: docs/development-standards.md
// DOCS: docs/features/auth.md — update that file when you edit this one.

// =============================================================================
// reset_password_screen.dart
// =============================================================================
//
// Purpose:
//   Allows a courier to reset or change their account password.
//
// Modes:
//   • Unauthenticated (default) — from login when courier forgot password.
//     Requires courier code + new password. Success → /login.
//
//   • Authenticated (authenticatedMode: true) — from profile to change
//     password. Courier code auto-filled (read-only); current password required.
//     Success → dashboard.
//
// API:
//   POST /reset-password  (unauthenticated)
//   POST /change-password (authenticated)
//
// Navigation:
//   Route: /reset-password | /change-password
// =============================================================================

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:fsi_courier_app/core/api/api_client.dart';
import 'package:fsi_courier_app/core/auth/courier_session_provider.dart';
import 'package:fsi_courier_app/core/settings/debug_ui_provider.dart';
import 'package:fsi_courier_app/design_system/design_system.dart';
import 'package:fsi_courier_app/features/auth/widgets/auth_layout.dart';
import 'package:fsi_courier_app/shared/helpers/api_payload_helper.dart';
import 'package:fsi_courier_app/shared/helpers/post_submit_navigation.dart';
import 'package:fsi_courier_app/shared/helpers/snackbar_helper.dart';
import 'package:fsi_courier_app/shared/widgets/app_header_bar.dart';

class ResetPasswordScreen extends ConsumerStatefulWidget {
  const ResetPasswordScreen({super.key, this.authenticatedMode = false});

  /// When [true], accessed by a logged-in courier from profile.
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

  final _codeFocus = FocusNode();
  final _currentFocus = FocusNode();
  final _newFocus = FocusNode();
  final _confirmFocus = FocusNode();

  bool _loading = false;
  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;

  @override
  void initState() {
    super.initState();
    if (widget.authenticatedMode) {
      final courier = ref.read(courierSessionProvider).courier ?? {};
      _code = TextEditingController(
        text: courier['courier_code']?.toString() ?? '',
      );
    } else {
      _code = TextEditingController();
    }
    _newPassword.addListener(_onPasswordChanged);
  }

  void _onPasswordChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _newPassword.removeListener(_onPasswordChanged);
    _code.dispose();
    _currentPassword.dispose();
    _newPassword.dispose();
    _confirmPassword.dispose();
    _codeFocus.dispose();
    _currentFocus.dispose();
    _newFocus.dispose();
    _confirmFocus.dispose();
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
    } else if (_newPassword.text.length < 8) {
      _errors['new_password'] = 'Password must be at least 8 characters.';
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
        showSuccessNotification(
          context,
          widget.authenticatedMode
              ? 'Password changed successfully.'
              : 'Password reset successful.',
        );
        if (widget.authenticatedMode) {
          goToDashboardAfterSubmit(context);
        } else {
          context.go('/login');
        }
      case ApiValidationError<Map<String, dynamic>>(:final errors):
        errors.forEach((key, value) => _errors[key] = value.first);
        setState(() {});
      case ApiServerError<Map<String, dynamic>>(:final message):
        showErrorNotification(context, message);
      case ApiNetworkError<Map<String, dynamic>>(:final message):
        showErrorNotification(context, message);
      default:
        showErrorNotification(
          context,
          widget.authenticatedMode
              ? 'Unable to change password.'
              : 'Unable to reset password.',
        );
    }

    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.authenticatedMode
        ? 'Change Password'
        : 'Reset Password';
    final showDebugUi = ref.watch(showDebugUiProvider);
    final codeLabel = widget.authenticatedMode
        ? (showDebugUi
              ? 'Courier Code (${kDebugMode ? 'Debug' : 'Dev'})'
              : 'Courier Code')
        : 'Courier Code';

    final formBody = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AuthHeader(
          title: title,
          leadingIcon: widget.authenticatedMode
              ? Icons.shield_rounded
              : Icons.lock_reset_rounded,
        ),
        DSSpacing.hLg,
        AuthFormCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (!widget.authenticatedMode) ...[
                    const _CourierCodeInstruction()
                        .animate()
                        .fadeIn(duration: DSAnimations.dNormal)
                        .slideY(
                          begin: 0.06,
                          end: 0,
                          duration: DSAnimations.dNormal,
                          curve: Curves.easeOutCubic,
                        ),
                    DSSpacing.hFormField,
                  ],
                  TextField(
                    controller: _code,
                    focusNode: _codeFocus,
                    readOnly: widget.authenticatedMode,
                    textInputAction: TextInputAction.next,
                    textCapitalization: TextCapitalization.characters,
                    autofillHints: widget.authenticatedMode
                        ? null
                        : const [AutofillHints.username],
                    onSubmitted: (_) {
                      if (widget.authenticatedMode) {
                        _currentFocus.requestFocus();
                      } else {
                        _newFocus.requestFocus();
                      }
                    },
                    decoration: InputDecoration(
                      labelText: codeLabel,
                      prefixIcon: const Icon(
                        Icons.badge_outlined,
                        size: DSIconSize.md,
                      ),
                      errorText: _errors['courier_code'],
                      filled: true,
                      fillColor: widget.authenticatedMode
                          ? (Theme.of(context).brightness == Brightness.dark
                                ? DSColors.secondarySurfaceDark
                                : DSColors.secondarySurfaceLight)
                          : null,
                      suffixIcon: widget.authenticatedMode
                          ? Icon(
                              Icons.lock_outline,
                              size: DSIconSize.sm,
                              color:
                                  Theme.of(context).brightness ==
                                      Brightness.dark
                                  ? DSColors.labelTertiaryDark
                                  : DSColors.labelTertiary,
                            )
                          : null,
                    ),
                  ).dsFieldEntry(
                    delay: DSAnimations.stagger(
                      1,
                      step: DSAnimations.staggerCoarse,
                    ),
                    duration: DSAnimations.dNormal,
                  ),
                  DSSpacing.hFormField,
                  if (widget.authenticatedMode) ...[
                    TextField(
                      controller: _currentPassword,
                      focusNode: _currentFocus,
                      obscureText: _obscureCurrent,
                      textInputAction: TextInputAction.next,
                      autofillHints: const [AutofillHints.password],
                      onSubmitted: (_) => _newFocus.requestFocus(),
                      decoration: InputDecoration(
                        labelText: 'Current Password',
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
                        2,
                        step: DSAnimations.staggerCoarse,
                      ),
                      duration: DSAnimations.dNormal,
                    ),
                    DSSpacing.hFormField,
                  ],
                  TextField(
                    controller: _newPassword,
                    focusNode: _newFocus,
                    obscureText: _obscureNew,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.newPassword],
                    onSubmitted: (_) => _confirmFocus.requestFocus(),
                    decoration: InputDecoration(
                      labelText: 'New Password',
                      hintText: 'Min. 8 characters',
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
                      widget.authenticatedMode ? 3 : 2,
                      step: DSAnimations.staggerCoarse,
                    ),
                    duration: DSAnimations.dNormal,
                  ),
                  AuthPasswordStrengthMeter(password: _newPassword.text),
                  DSSpacing.hFormField,
                  TextField(
                    controller: _confirmPassword,
                    focusNode: _confirmFocus,
                    obscureText: _obscureConfirm,
                    textInputAction: TextInputAction.done,
                    autofillHints: const [AutofillHints.newPassword],
                    onSubmitted: (_) {
                      if (!_loading) _submit();
                    },
                    decoration: InputDecoration(
                      labelText: 'Confirm Password',
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
                      widget.authenticatedMode ? 4 : 3,
                      step: DSAnimations.staggerCoarse,
                    ),
                    duration: DSAnimations.dNormal,
                  ),
                  DSSpacing.hFormFieldToCta,
                  AuthPrimaryButton(
                    label: widget.authenticatedMode
                        ? 'Change Password'
                        : 'Submit',
                    onPressed: _loading ? null : _submit,
                  ).dsCtaEntry(
                    delay: DSAnimations.stagger(
                      widget.authenticatedMode ? 5 : 4,
                      step: DSAnimations.staggerCoarse,
                    ),
                    duration: DSAnimations.dNormal,
                  ),
                  if (!widget.authenticatedMode) ...[
                    DSSpacing.hSm,
                    TextButton(
                      onPressed: _loading ? null : () => context.go('/login'),
                      child: const Text('Back to Sign In'),
                    ).animate().fadeIn(
                      delay: DSAnimations.stagger(
                        5,
                        step: DSAnimations.staggerCoarse,
                      ),
                      duration: DSAnimations.dFast,
                    ),
                  ],
                ],
              ),
            )
            .animate()
            .fadeIn(delay: 80.ms, duration: DSAnimations.dSlow)
            .slideY(
              begin: 0.08,
              end: 0,
              delay: 80.ms,
              duration: DSAnimations.dSlow,
              curve: Curves.easeOutCubic,
            ),
      ],
    );

    // Unauthenticated: full AuthShell (no app bar). Authenticated: app bar.
    if (!widget.authenticatedMode) {
      return AuthShell(loading: _loading, child: formBody);
    }

    return Scaffold(
      appBar: AppHeaderBar(title: title, showNotificationBell: true),
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Soft scenery behind form (quieter than full login AuthShell).
          const DsBrandBackdrop(variant: DsBackdrop.gate),
          GestureDetector(
            onTap: () => FocusScope.of(context).unfocus(),
            behavior: HitTestBehavior.opaque,
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: EdgeInsets.fromLTRB(
                DSSpacing.lg,
                DSSpacing.md,
                DSSpacing.lg,
                DSSpacing.xl + MediaQuery.paddingOf(context).bottom,
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: formBody,
              ),
            ),
          ),
          if (_loading)
            ColoredBox(
              color: DSColors.black.withValues(alpha: DSStyles.alphaMuted),
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }
}

/// Soft DS callout: contact admin/manager if courier code unknown.
/// Unauthenticated reset only — authenticated mode already has the code.
class _CourierCodeInstruction extends StatelessWidget {
  const _CourierCodeInstruction();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = isDark ? DSColors.primaryDark : DSColors.primary;
    final bgColor = isDark
        ? accent.withValues(alpha: DSStyles.alphaSubtle)
        : DSColors.primarySurface;
    final textColor = isDark
        ? DSColors.labelSecondaryDark
        : DSColors.neutralText;

    return Container(
      padding: const EdgeInsets.all(DSSpacing.md),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: DSStyles.cardRadius,
        border: Border.all(
          color: accent.withValues(alpha: DSStyles.alphaMuted),
          width: DSStyles.borderWidth,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.support_agent_rounded, size: DSIconSize.md, color: accent),
          DSSpacing.wSm,
          Expanded(
            child: Text(
              'auth.reset_password.courier_code_hint'.tr(),
              style: DSTypography.caption(color: textColor).copyWith(
                fontSize: DSTypography.sizeSm,
                height: DSStyles.heightNormal,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
