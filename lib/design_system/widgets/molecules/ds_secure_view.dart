// DOCS: docs/shared/widgets.md
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:screen_protector/screen_protector.dart';
import 'package:fsi_courier_app/design_system/tokens/ds_colors.dart';
import 'package:fsi_courier_app/design_system/tokens/ds_styles.dart';
import 'package:fsi_courier_app/core/config.dart';

/// A singleton manager to handle reference counting for screenshot protection.
/// This ensures that if multiple SecureViews are active (e.g. a sheet over a screen),
/// protection is only disabled when the last one is disposed.
/// Public façade for controlling screenshot protection from outside this library.
/// Use [SecureViewManager.setDeveloperModeOverride] to bypass protection in developer mode.
class SecureViewManager {
  SecureViewManager._();

  /// Apply or remove the developer-mode screenshot bypass.
  /// Call this in [RuntimeEnvironmentService.init] and [RuntimeEnvironmentService.setDeveloperMode].
  static Future<void> setDeveloperModeOverride(bool isDeveloper) {
    return _SecureManager.setDeveloperModeOverride(isDeveloper);
  }

  /// Whether protection is currently bypassed (debug build, developer mode,
  /// or the `SECURE_SCREENSHOTS` dart-define off). Test-only introspection.
  @visibleForTesting
  static bool get debugBypassProtection =>
      _SecureManager.instance._bypassProtection;
}

class _SecureManager {
  static final _SecureManager instance = _SecureManager._();
  _SecureManager._();

  int _counter = 0;

  /// When true, all screenshot protection is bypassed at runtime.
  /// Set via [setDeveloperModeOverride] during app init and when toggling developer mode.
  static bool _developerModeOverride = false;

  static Future<void> setDeveloperModeOverride(bool isDeveloper) async {
    _developerModeOverride = isDeveloper;
    // If developer mode just turned on while protection was active, disable it now.
    // No counter reset here: `_counter` only ever reflects widgets that
    // genuinely claimed a slot via [enable] (see [_SecureViewState]), so it
    // stays accurate across a toggle — resetting it would desync widgets
    // that mounted before the toggle from the count they legitimately hold.
    if (isDeveloper) {
      try {
        // Timeout: unmocked platform channel never completes in tests and
        // rare plugin failures on device must not block developer-mode toggle.
        await ScreenProtector.preventScreenshotOff().timeout(
          const Duration(seconds: 2),
        );
      } catch (e) {
        debugPrint(
          '[SECURE] Error clearing protection on developer-mode toggle: $e',
        );
      }
    }
  }

  bool get _bypassProtection =>
      !kSecureScreenshots || _developerModeOverride || kAppDebugMode;

  /// Synchronously claims a reference-count slot if protection is currently
  /// required, and returns whether it did. Callers (see [_SecureViewState])
  /// must call [disable] later **only** when this returned `true` — a widget
  /// that mounts while bypassed never held a slot and must not decrement one
  /// it never claimed.
  bool enable() {
    if (_bypassProtection) {
      // Re-assert rather than trust an earlier clear — closes the gap if a
      // prior preventScreenshotOff() call (e.g. from a developer-mode
      // toggle) didn't fully apply before this screen mounted.
      unawaited(_applyOff());
      return false;
    }
    _counter++;
    if (_counter == 1) {
      unawaited(_applyOn());
    }
    return true;
  }

  /// Releases a slot previously claimed by [enable] returning `true`.
  void disable() {
    _counter--;
    if (_counter <= 0) {
      _counter = 0;
      unawaited(_applyOff());
    }
  }

  Future<void> _applyOn() async {
    try {
      await ScreenProtector.preventScreenshotOn().timeout(
        const Duration(seconds: 2),
      );
    } catch (e) {
      debugPrint('[SECURE] Error enabling protection: $e');
    }
  }

  Future<void> _applyOff() async {
    try {
      await ScreenProtector.preventScreenshotOff().timeout(
        const Duration(seconds: 2),
      );
    } catch (e) {
      debugPrint('[SECURE] Error disabling protection: $e');
    }
  }
}

/// A wrapper widget that enables screenshot and screen recording protection
/// while it is active in the widget tree.
///
/// ## Screenshot policy (courier support)
///
/// **Allow screenshots** (do **not** wrap in [SecureView]):
/// - Wallet (overview, payout detail/request, payout history sheet)
/// - Dispatch eligibility / dispatch list
/// - Profile
/// - Sync / History
/// - Delivery lists: **DELIVERED** and **MISROUTED**
///
/// **Keep protected** (wrap in [SecureView]):
/// - Recipient **account details** sheets (`showDeliveryAccountDetails`)
/// - Delivery lists: **FOR_DELIVERY** / **FAILED_DELIVERY** (active recipient PII)
/// - Delivery update / signature capture (POD + recipient data)
///
/// Rationale: couriers may screenshot support-friendly screens, but must not
/// freely capture full recipient account name/address/contact sheets.
class SecureView extends StatefulWidget {
  final Widget child;
  const SecureView({super.key, required this.child});

  @override
  State<SecureView> createState() => _SecureViewState();
}

class _SecureViewState extends State<SecureView> {
  bool _holdsSlot = false;

  @override
  void initState() {
    super.initState();
    _holdsSlot = _SecureManager.instance.enable();
  }

  @override
  void dispose() {
    if (_holdsSlot) {
      _SecureManager.instance.disable();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// A premium visual indicator to inform the user that the current view is protected. (DO NOT USE ANYWHERE - BUT THIS CODE IS JUST FOR DOCUMENTATION)
class SecureBadge extends StatelessWidget {
  const SecureBadge({
    super.key,
    this.iconColor,
    this.backgroundColor,
    this.borderColor,
  });

  final Color? iconColor;
  final Color? backgroundColor;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    if (!kSecureScreenshots) return const SizedBox.shrink();

    return Tooltip(
      message: 'Screenshot Restricted',
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color:
              backgroundColor ??
              DSColors.success.withValues(alpha: DSStyles.alphaSubtle),
          shape: BoxShape.circle,
          border: Border.all(
            color:
                borderColor ??
                DSColors.success.withValues(alpha: DSStyles.alphaMuted),
          ),
        ),
        child: Icon(
          Icons.lock_rounded,
          size: 14,
          color: iconColor ?? DSColors.success,
        ),
      ),
    );
  }
}
