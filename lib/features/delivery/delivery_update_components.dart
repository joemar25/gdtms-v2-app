// DOCS: docs/development-standards.md
// DOCS: docs/features/delivery.md — update that file when you edit this one.

// =============================================================================
// delivery_update_components.dart
// =============================================================================
//
// Purpose:
//   Extracted UI components and layout constants for [DeliveryUpdateScreen].
//   Splitting here keeps delivery_update_screen.dart under the 600-line rule
//   (Rule 01) and gives each component a single, debuggable responsibility.
//
// Components:
//   • [DeliveryPhotoSlot]           — captures / displays a single photo slot
//   • [DeliverySignatureSlot]       — captures / displays the optional signature
//   • [DeliveryNotePresets]         — scrollable row of quick-fill remark chips
//   • [_NotePresetChip]             — individual chip (private to this file)
//   • [DeliveryStatusSelector]      — animated 3-way status picker
//   • [DeliveryStatusSelectorState] — public so the screen can call markInteracted
// =============================================================================

import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:fsi_courier_app/core/constants.dart';
import 'package:fsi_courier_app/core/models/delivery_status.dart';
import 'package:fsi_courier_app/core/models/photo_entry.dart';
import 'package:fsi_courier_app/design_system/design_system.dart';

// ── Layout constants ─────────────────────────────────────────────────────────
const kPhotoSlotHeight = 160.0;
const kSignatureSlotHeight = 144.0;

// ── Status metadata ──────────────────────────────────────────────────────────
// Keys are API string values from DeliveryStatus.toApiString() so that
// _kStatusMeta[rawStatus] works with whatever string kUpdateStatuses holds.
final _kStatusMeta = {
  DeliveryStatus.delivered.toApiString(): (
    label: 'DELIVERED',
    icon: Icons.check_circle_rounded,
    color: DSColors.success,
  ),
  DeliveryStatus.failedDelivery.toApiString(): (
    label: 'FAILED',
    icon: Icons.keyboard_return_rounded,
    color: DSColors.error,
  ),
  DeliveryStatus.osa.toApiString(): (
    label: 'MISROUTED',
    icon: Icons.inbox_rounded,
    color: DSColors.warning,
  ),
};

// ─────────────────────────────────────────────────
// MARK: Photo Slot
// ─────────────────────────────────────────────────

/// Fixed-height slot that shows a camera placeholder when empty or a preview
/// image with a delete overlay when filled.
///
/// Always expands to fill available Row width via an internal [Expanded], so
/// it must be placed directly inside a [Row].
///
/// [onTap] opens the image picker. [onClear] removes the current photo.
class DeliveryPhotoSlot extends StatelessWidget {
  const DeliveryPhotoSlot({
    super.key,
    required this.label,
    required this.photo,
    required this.icon,
    required this.color,
    required this.isDark,
    required this.onTap,
    required this.onClear,
    this.hasError = false,
  });

  final String label;
  final PhotoEntry? photo;
  final IconData icon;
  final Color color;
  final bool isDark;

  /// Opens camera / gallery to capture or pick an image.
  final VoidCallback onTap;

  /// Removes the current photo (called from the delete overlay icon).
  final VoidCallback onClear;

  /// When true the slot border highlights in [DSColors.error].
  final bool hasError;

  @override
  Widget build(BuildContext context) {
    final hasPhoto = photo != null;

    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: kPhotoSlotHeight,
          decoration: BoxDecoration(
            color: hasPhoto
                ? DSColors.transparent
                : (isDark ? DSColors.cardElevatedDark : DSColors.cardLight),
            borderRadius: DSStyles.cardRadius,
            border: Border.all(
              color: hasError
                  ? DSColors.error
                  : hasPhoto
                  ? (isDark
                        ? DSColors.separatorDark
                        : DSColors.secondarySurfaceLight)
                  : color.withValues(alpha: DSStyles.alphaMuted),
              width: hasError ? 1.5 : 1.2,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            switchInCurve: Curves.easeOutBack,
            switchOutCurve: Curves.easeInBack,
            child: hasPhoto
                ? Stack(
                    key: const ValueKey('has_photo'),
                    fit: StackFit.expand,
                    children: [
                      Image.file(
                        File(photo!.file),
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => Container(
                          color: isDark
                              ? DSColors.cardElevatedDark
                              : DSColors.secondarySurfaceLight,
                          child: const Icon(
                            Icons.broken_image_rounded,
                            size: DSIconSize.xl,
                            color: DSColors.labelTertiary,
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        child: Container(
                          color: DSColors.black.withValues(
                            alpha: DSStyles.alphaDisabled,
                          ),
                          padding: EdgeInsets.symmetric(
                            horizontal: DSSpacing.md,
                            vertical: DSSpacing.sm,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                label,
                                style: DSTypography.label(color: DSColors.white)
                                    .copyWith(
                                      fontSize: DSTypography.sizeSm,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: DSTypography.lsLoose,
                                    ),
                              ),
                              GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: onClear,
                                child: const Padding(
                                  padding: EdgeInsets.all(DSSpacing.xs),
                                  child: Icon(
                                    Icons.delete_outline_rounded,
                                    size: DSIconSize.sm,
                                    color: DSColors.error,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  )
                : Column(
                    key: const ValueKey('no_photo'),
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(icon, size: DSIconSize.xl, color: color),
                      DSSpacing.hSm,
                      Text(
                        label,
                        style: DSTypography.label(color: color).copyWith(
                          fontSize: DSTypography.sizeSm,
                          fontWeight: FontWeight.w800,
                          letterSpacing: DSTypography.lsLoose,
                        ),
                      ),
                      DSSpacing.hXs,
                      Text(
                        'delivery_update.photo_slot.tap_to_capture'.tr(),
                        style:
                            DSTypography.label(
                              color: isDark
                                  ? DSColors.labelTertiaryDark
                                  : DSColors.labelTertiary,
                            ).copyWith(
                              fontSize: DSTypography.sizeXs,
                              letterSpacing: DSTypography.lsLoose,
                            ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────
// MARK: Signature Slot
// ─────────────────────────────────────────────────

/// Tappable slot for capturing an optional recipient signature.
///
/// Shows a draw-prompt when empty; a preview with Re-sign / Clear controls
/// when [signaturePath] is set.
class DeliverySignatureSlot extends StatelessWidget {
  const DeliverySignatureSlot({
    super.key,
    required this.isDark,
    required this.signaturePath,
    required this.onCapture,
    required this.onClear,
    this.hasError = false,
  });

  final bool isDark;

  /// Absolute path to the PNG on disk. Null when no signature has been captured.
  final String? signaturePath;

  /// Launches [SignatureCaptureScreen] to draw or redraw a signature.
  final VoidCallback onCapture;

  /// Discards the current signature.
  final VoidCallback onClear;

  final bool hasError;

  @override
  Widget build(BuildContext context) {
    final hasSignature = signaturePath != null;

    return GestureDetector(
      onTap: onCapture,
      child: Container(
        height: kSignatureSlotHeight,
        decoration: BoxDecoration(
          borderRadius: DSStyles.cardRadius,
          border: Border.all(
            color: hasError
                ? DSColors.error
                : hasSignature
                ? (isDark ? DSColors.separatorDark : DSColors.separatorLight)
                : DSColors.primary.withValues(alpha: DSStyles.alphaMuted),
            width: hasError ? 1.5 : 1.2,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          switchInCurve: Curves.easeOutBack,
          switchOutCurve: Curves.easeInBack,
          child: hasSignature
              ? Stack(
                  key: const ValueKey('has_signature'),
                  fit: StackFit.expand,
                  children: [
                    Padding(
                      padding: EdgeInsets.all(DSSpacing.md),
                      child: Image.file(
                        File(signaturePath!),
                        fit: BoxFit.contain,
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: Container(
                        color: DSColors.black.withValues(
                          alpha: DSStyles.alphaDisabled,
                        ),
                        padding: EdgeInsets.symmetric(
                          horizontal: DSSpacing.md,
                          vertical: DSSpacing.sm,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'delivery_update.signature.signature'.tr(),
                              style: DSTypography.label(color: DSColors.white)
                                  .copyWith(
                                    fontSize: DSTypography.sizeSm,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: DSTypography.lsLoose,
                                  ),
                            ),
                            Row(
                              children: [
                                GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onTap: onCapture,
                                  child: Padding(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: DSSpacing.sm,
                                      vertical: DSSpacing.xs,
                                    ),
                                    child: Text(
                                      'delivery_update.signature.re_sign'.tr(),
                                      style: DSTypography.label(
                                        color: DSColors.white.withValues(
                                          alpha: DSStyles.alphaDisabled,
                                        ),
                                      ).copyWith(fontSize: DSTypography.sizeSm),
                                    ),
                                  ),
                                ),
                                GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onTap: onClear,
                                  child: Padding(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: DSSpacing.sm,
                                      vertical: DSSpacing.xs,
                                    ),
                                    child: Text(
                                      'delivery_update.signature.clear'.tr(),
                                      style:
                                          DSTypography.label(
                                            color: DSColors.error,
                                          ).copyWith(
                                            fontSize: DSTypography.sizeSm,
                                            fontWeight: FontWeight.w700,
                                          ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                )
              : Column(
                  key: const ValueKey('no_signature'),
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.draw_rounded,
                      size: DSIconSize.xl,
                      color: DSColors.primary.withValues(
                        alpha: DSStyles.alphaDisabled,
                      ),
                    ),
                    DSSpacing.hSm,
                    Text(
                      'delivery_update.signature.signature'.tr(),
                      style:
                          DSTypography.label(
                            color: DSColors.primary.withValues(
                              alpha: DSStyles.alphaDisabled,
                            ),
                          ).copyWith(
                            fontSize: DSTypography.sizeSm,
                            letterSpacing: DSTypography.lsLoose,
                          ),
                    ),
                    DSSpacing.hXs,
                    Text(
                      'delivery_update.signature.tap_to_sign_optional'.tr(),
                      style:
                          DSTypography.label(
                            color: isDark
                                ? DSColors.labelTertiaryDark
                                : DSColors.labelTertiary,
                          ).copyWith(
                            fontSize: DSTypography.sizeXs,
                            letterSpacing: DSTypography.lsLoose,
                          ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────
// MARK: Note Presets
// ─────────────────────────────────────────────────

/// Horizontally scrollable row of quick-fill remark preset chips.
///
/// The screen computes [presets] from the current status and selected reason;
/// this widget only renders and dispatches taps back via [onPresetTapped].
class DeliveryNotePresets extends StatelessWidget {
  const DeliveryNotePresets({
    super.key,
    required this.presets,
    required this.activePreset,
    required this.isDark,
    required this.onPresetTapped,
  });

  final List<String> presets;
  final String? activePreset;
  final bool isDark;

  /// Called with the tapped preset. The screen decides whether to activate or
  /// deactivate it and updates the note controller accordingly.
  final void Function(String preset) onPresetTapped;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: EdgeInsets.only(bottom: DSSpacing.xs),
      child: Row(
        children: [
          for (final preset in presets) ...[
            _NotePresetChip(
              label: preset,
              selected: activePreset == preset,
              isDark: isDark,
              onTap: () => onPresetTapped(preset),
            ),
            DSSpacing.wSm,
          ],
        ],
      ),
    );
  }
}

// ── Note preset chip (private to this file) ──────────────────────────────────

class _NotePresetChip extends StatelessWidget {
  const _NotePresetChip({
    required this.label,
    required this.selected,
    required this.isDark,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final bool isDark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final selectedColor = DSColors.primary;
    final unselectedBg = isDark
        ? DSColors.white.withValues(alpha: DSStyles.alphaSoft)
        : DSColors.secondarySurfaceLight;
    final unselectedBorder = isDark
        ? DSColors.white.withValues(alpha: DSStyles.alphaSubtle)
        : DSColors.separatorLight;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: EdgeInsets.symmetric(horizontal: DSSpacing.md, vertical: 7),
        decoration: BoxDecoration(
          color: selected
              ? selectedColor.withValues(alpha: DSStyles.alphaSubtle)
              : unselectedBg,
          borderRadius: DSStyles.cardRadius,
          border: Border.all(
            color: selected
                ? selectedColor.withValues(alpha: DSStyles.alphaDisabled)
                : unselectedBorder,
            width: selected ? 1.4 : 1.0,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (selected) ...[
              Icon(
                Icons.check_rounded,
                size: DSIconSize.xs,
                color: selectedColor,
              ),
              DSSpacing.wXs,
            ],
            Text(
              label,
              style: DSTypography.label().copyWith(
                fontSize: DSTypography.sizeSm,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected
                    ? selectedColor
                    : (isDark
                          ? DSColors.labelSecondaryDark
                          : DSColors.labelSecondary),
                letterSpacing: DSTypography.lsLoose,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────
// MARK: Status Selector
// ─────────────────────────────────────────────────

/// Animated 3-way status picker: DELIVERED / FAILED / MISROUTED.
///
/// A gradient pill slides to the active segment on each tap or swipe.
/// [DeliveryUpdateScreen] holds a [GlobalKey<DeliveryStatusSelectorState>]
/// so it can call [markInteracted] after a swipe-triggered status change.
class DeliveryStatusSelector extends StatefulWidget {
  const DeliveryStatusSelector({
    super.key,
    required this.currentStatus,
    required this.onStatusChanged,
  });

  final String currentStatus;
  final Future<void> Function(String) onStatusChanged;

  @override
  State<DeliveryStatusSelector> createState() => DeliveryStatusSelectorState();
}

/// Public so [DeliveryUpdateScreen] can call [markInteracted] via [GlobalKey].
class DeliveryStatusSelectorState extends State<DeliveryStatusSelector> {
  bool _hasInteracted = false;

  /// Hides the swipe-hint label once the user has interacted with the selector.
  void markInteracted() {
    if (mounted) setState(() => _hasInteracted = true);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final selectedIndex = kUpdateStatuses.indexOf(widget.currentStatus);
    final activeStatus = selectedIndex >= 0
        ? widget.currentStatus
        : kUpdateStatuses[0];
    final activeMeta = _kStatusMeta[activeStatus]!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: 80,
          decoration: BoxDecoration(
            color: isDark
                ? DSColors.white.withValues(alpha: DSStyles.alphaSubtle)
                : DSColors.secondarySurfaceLight,
            borderRadius: DSStyles.cardRadius,
            border: Border.all(
              color: isDark
                  ? DSColors.white.withValues(alpha: DSStyles.alphaSubtle)
                  : DSColors.separatorLight,
              width: DSStyles.borderWidth,
            ),
          ),
          child: Stack(
            children: [
              // Animated gradient pill
              AnimatedAlign(
                alignment: selectedIndex == 0
                    ? Alignment.centerLeft
                    : selectedIndex == 1
                    ? Alignment.center
                    : Alignment.centerRight,
                duration: const Duration(milliseconds: 400),
                curve: Curves.elasticOut,
                child: FractionallySizedBox(
                  widthFactor: 1 / 3,
                  heightFactor: 1.0,
                  child: Padding(
                    padding: EdgeInsets.all(DSSpacing.sm),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            activeMeta.color,
                            activeMeta.color.withValues(
                              alpha: DSStyles.alphaOpaque,
                            ),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: DSStyles.cardRadius,
                        boxShadow: [
                          BoxShadow(
                            color: activeMeta.color.withValues(
                              alpha: DSStyles.alphaMuted,
                            ),
                            blurRadius: DSStyles.radiusMD,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              // Tappable status options
              Row(
                children: kUpdateStatuses.map((rawStatus) {
                  final meta = _kStatusMeta[rawStatus]!;
                  final selected = widget.currentStatus == rawStatus;

                  return Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () async {
                        markInteracted();
                        await widget.onStatusChanged(rawStatus);
                      },
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            AnimatedScale(
                              scale: selected ? 1.15 : 1.0,
                              duration: const Duration(milliseconds: 250),
                              curve: Curves.easeOutBack,
                              child: Icon(
                                meta.icon,
                                color: selected
                                    ? DSColors.white
                                    : (isDark
                                          ? DSColors.white.withValues(
                                              alpha: DSStyles.alphaDisabled,
                                            )
                                          : DSColors.labelSecondary),
                                size: selected ? DSIconSize.xl : DSIconSize.lg,
                              ),
                            ),
                            DSSpacing.hXs,
                            AnimatedDefaultTextStyle(
                              duration: const Duration(milliseconds: 250),
                              style: DSTypography.label().copyWith(
                                fontWeight: selected
                                    ? FontWeight.w800
                                    : FontWeight.w600,
                                fontSize: selected ? 11 : 10,
                                color: selected
                                    ? DSColors.white
                                    : (isDark
                                          ? DSColors.labelSecondaryDark
                                          : DSColors.labelSecondary),
                                letterSpacing: DSTypography.lsLoose,
                              ),
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  meta.label,
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
        if (!_hasInteracted)
          Padding(
            padding: EdgeInsets.only(top: DSSpacing.sm),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.touch_app_rounded,
                  size: DSIconSize.xs,
                  color: isDark
                      ? DSColors.white.withValues(alpha: DSStyles.alphaMuted)
                      : DSColors.labelTertiary,
                ),
                DSSpacing.wXs,
                Text(
                  'delivery_update.header.tap_swipe_change_status'.tr(),
                  style: DSTypography.label().copyWith(
                    fontSize: DSTypography.sizeXs,
                    color: isDark
                        ? DSColors.labelTertiaryDark
                        : DSColors.labelTertiary,
                    letterSpacing: DSTypography.lsLoose,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
