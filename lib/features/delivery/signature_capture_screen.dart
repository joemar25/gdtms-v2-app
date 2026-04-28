// DOCS: docs/features/delivery.md — update that file when you edit this one.

// =============================================================================
// signature_capture_screen.dart
// =============================================================================
//
// Purpose:
//   Full-screen freehand signature pad used during the DELIVERED update flow.
//   The courier hands the device to the recipient to sign, then taps DONE.
//
// Usage:
//   Push via Navigator.push and await the result:
//   ```dart
//   final bytes = await Navigator.push<Uint8List?>(
//     context,
//     MaterialPageRoute(builder: (_) => const SignatureCaptureScreen()),
//   );
//   ```
//   Returns the PNG bytes when the courier taps DONE, or null when cancelled.
//   The PNG is stored locally and uploaded to S3/API during the next sync.
//
// Navigation:
//   Not a GoRouter route — pushed imperatively from DeliveryUpdateScreen.
// =============================================================================

import 'package:flutter/material.dart';

import 'package:flutter/services.dart';
import 'package:signature/signature.dart';

import 'package:fsi_courier_app/shared/widgets/app_header_bar.dart';
import 'package:fsi_courier_app/design_system/design_system.dart';

/// Full-screen signature capture screen (portrait default, auto-rotate enabled).
///
/// Push via [Navigator.push] and await the result:
/// ```dart
/// final bytes = await Navigator.push<Uint8List?>(
///   context,
///   MaterialPageRoute(builder: (_) => const SignatureCaptureScreen()),
/// );
/// ```
/// Returns the PNG bytes when the user taps DONE, or `null` when cancelled.
class SignatureCaptureScreen extends StatefulWidget {
  const SignatureCaptureScreen({super.key});

  @override
  State<SignatureCaptureScreen> createState() => _SignatureCaptureScreenState();
}

class _SignatureCaptureScreenState extends State<SignatureCaptureScreen> {
  late final SignatureController _controller;

  @override
  void initState() {
    super.initState();
    _controller = SignatureController(
      penStrokeWidth: 2.5,
      penColor: DSColors.black,
      exportBackgroundColor: DSColors.white,
      onDrawEnd: () => setState(() {}),
    );
    SystemChrome.setPreferredOrientations([]);
  }

  @override
  void dispose() {
    // Restore portrait-only for the rest of the app.
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    _controller.dispose();
    super.dispose();
  }

  Future<void> _done() async {
    if (!_controller.isNotEmpty) return;
    final bytes = await _controller.toPngBytes();
    if (mounted) Navigator.of(context).pop(bytes);
  }

  void _clear() => _controller.clear();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasStrokes = _controller.isNotEmpty;

    return Scaffold(
      backgroundColor: isDark ? DSColors.scaffoldDark : DSColors.scaffoldLight,
      appBar: AppHeaderBar(
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          color: isDark ? DSColors.white : DSColors.black,
          tooltip: 'Cancel',
          onPressed: () => Navigator.of(context).pop(null),
        ),
        titleWidget: Text(
          'RECIPIENT SIGNATURE',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: DSTypography.heading().copyWith(
            fontSize: DSTypography.sizeMd,
            fontWeight: FontWeight.w800,
            letterSpacing: DSTypography.lsMegaLoose,
            color: isDark ? DSColors.labelPrimaryDark : DSColors.labelPrimary,
          ),
        ),
        actions: [
          TextButton.icon(
            onPressed: hasStrokes ? _clear : null,
            icon: Icon(
              Icons.refresh_rounded,
              size: 16,
              color: hasStrokes
                  ? DSColors.labelSecondary
                  : DSColors.separatorLight,
            ),
            label: Text(
              'CLEAR',
              style: DSTypography.label().copyWith(
                fontSize: DSTypography.sizeSm,
                fontWeight: FontWeight.w700,
                color: hasStrokes ? DSColors.error : DSColors.separatorLight,
              ),
            ),
          ),
          DSSpacing.wXs,
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: FilledButton.icon(
              icon: const Icon(Icons.check_rounded, size: 16),
              label: Text(
                'DONE',
                style: DSTypography.button().copyWith(
                  fontSize: DSTypography.sizeSm,
                  fontWeight: FontWeight.w800,
                ),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: hasStrokes
                    ? DSColors.primary
                    : DSColors.separatorLight,
                foregroundColor: hasStrokes
                    ? DSColors.white
                    : DSColors.labelSecondary,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: DSSpacing.sm,
                ),
                minimumSize: Size.zero,
                shape: RoundedRectangleBorder(
                  borderRadius: DSStyles.cardRadius,
                ),
              ),
              onPressed: hasStrokes ? _done : null,
            ),
          ),
        ],
        backgroundColor: isDark ? DSColors.cardDark : DSColors.cardLight,
        showNotificationBell: false,
      ),
      body: Stack(
        children: [
          // Full-screen white canvas
          Positioned.fill(
            child: Container(
              color: DSColors.white,
              child: Signature(
                controller: _controller,
                backgroundColor: DSColors.white,
              ),
            ),
          ),
          // Baseline hint
          Positioned(
            left: 0,
            right: 0,
            bottom: 60,
            child: IgnorePointer(
              child: Center(
                child: Container(
                  height: 1,
                  margin: const EdgeInsets.symmetric(
                    horizontal: DSSpacing.xxxl,
                  ),
                  color: DSColors.separatorLight,
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 36,
            child: IgnorePointer(
              child: Center(
                child: Text(
                  'Sign above the line',
                  style: DSTypography.caption().copyWith(
                    fontSize: DSTypography.sizeSm,
                    color: DSColors.separatorLight,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
