// DOCS: docs/shared/widgets.md
import 'package:flutter/material.dart';
import 'package:screen_protector/screen_protector.dart';
import 'package:fsi_courier_app/design_system/design_system.dart';
import 'package:fsi_courier_app/core/config.dart';

/// A singleton manager to handle reference counting for screenshot protection.
/// This ensures that if multiple SecureViews are active (e.g. a sheet over a screen),
/// protection is only disabled when the last one is disposed.
class _SecureManager {
  static final _SecureManager instance = _SecureManager._();
  _SecureManager._();

  int _counter = 0;

  Future<void> enable() async {
    if (!kSecureScreenshots) return;
    _counter++;
    if (_counter == 1) {
      try {
        await ScreenProtector.preventScreenshotOn();
      } catch (e) {
        debugPrint('[SECURE] Error enabling protection: $e');
      }
    }
  }

  Future<void> disable() async {
    if (!kSecureScreenshots) return;
    _counter--;
    if (_counter <= 0) {
      _counter = 0;
      try {
        await ScreenProtector.preventScreenshotOff();
      } catch (e) {
        debugPrint('[SECURE] Error disabling protection: $e');
      }
    }
  }
}

/// A wrapper widget that enables screenshot and screen recording protection
/// while it is active in the widget tree.
class SecureView extends StatefulWidget {
  final Widget child;
  const SecureView({super.key, required this.child});

  @override
  State<SecureView> createState() => _SecureViewState();
}

class _SecureViewState extends State<SecureView> {
  @override
  void initState() {
    super.initState();
    _SecureManager.instance.enable();
  }

  @override
  void dispose() {
    _SecureManager.instance.disable();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// A premium visual indicator to inform the user that the current view is protected.
class SecureBadge extends StatelessWidget {
  const SecureBadge({super.key});

  @override
  Widget build(BuildContext context) {
    if (!kSecureScreenshots) return const SizedBox.shrink();

    return Tooltip(
      message: 'Screenshot Restricted',
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: DSColors.success.withValues(alpha: DSStyles.alphaSubtle),
          shape: BoxShape.circle,
          border: Border.all(
            color: DSColors.success.withValues(alpha: DSStyles.alphaMuted),
          ),
        ),
        child: const Icon(
          Icons.lock_rounded,
          size: 14,
          color: DSColors.success,
        ),
      ),
    );
  }
}
