// DOCS: docs/development-standards.md
// DOCS: docs/features/delivery.md — update that file when you edit this one.

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:fsi_courier_app/core/constants.dart';
import 'package:fsi_courier_app/design_system/design_system.dart';
import 'package:fsi_courier_app/features/delivery/delivery_update_components.dart';
import 'package:fsi_courier_app/features/delivery/widgets/delivery_form_helpers.dart';

/// REMARKS section for [DeliveryUpdateScreen] (all statuses).
///
/// Renders preset chips computed by the screen, a hint caption, and a
/// multi-line note text field. All mutations are dispatched via callbacks so
/// the parent state retains ownership of [noteController] and [activeNotePreset].
class DeliveryRemarksSection extends StatelessWidget {
  const DeliveryRemarksSection({
    super.key,
    required this.noteController,
    required this.notePresets,
    required this.activeNotePreset,
    required this.errors,
    required this.isDark,
    required this.onPresetTapped,
    required this.onNoteCleared,
  });

  final TextEditingController noteController;
  final List<String> notePresets;
  final String? activeNotePreset;
  final Map<String, String> errors;
  final bool isDark;

  /// Called when a preset chip is tapped; parent decides activate/deactivate.
  final void Function(String preset) onPresetTapped;

  /// Called when the note clear button is tapped.
  final VoidCallback onNoteCleared;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DeliveryNotePresets(
          presets: notePresets,
          activePreset: activeNotePreset,
          isDark: isDark,
          onPresetTapped: onPresetTapped,
        ),
        DSSpacing.hSm,

        Padding(
          padding: EdgeInsets.only(bottom: DSSpacing.sm),
          child: Text(
            'delivery_update.header.preset_hint'.tr(),
            style: DSTypography.label().copyWith(
              fontSize: DSTypography.sizeXs,
              color: isDark
                  ? DSColors.labelTertiaryDark
                  : DSColors.labelTertiary,
              letterSpacing: DSTypography.lsLoose,
            ),
          ),
        ),

        ValueListenableBuilder<TextEditingValue>(
          valueListenable: noteController,
          builder: (context, value, _) => TextFormField(
            controller: noteController,
            maxLength: kMaxNoteLength,
            minLines: 3,
            maxLines: 6,
            textCapitalization: TextCapitalization.sentences,
            style: DSTypography.body().copyWith(
              color: isDark ? DSColors.labelPrimaryDark : DSColors.labelPrimary,
              fontWeight: FontWeight.w500,
            ),
            decoration:
                deliveryFieldDecoration(
                  context,
                  hintText: 'delivery_update.header.remarks_optional'.tr(),
                  errorText: errors['note'],
                ).copyWith(
                  suffixIconConstraints: const BoxConstraints(
                    minWidth: DSIconSize.heroSm,
                    minHeight: DSIconSize.heroSm,
                  ),
                  suffixIcon: value.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(
                            Icons.clear_rounded,
                            size: DSIconSize.md,
                          ),
                          color: isDark
                              ? DSColors.labelTertiaryDark
                              : DSColors.labelTertiary,
                          onPressed: onNoteCleared,
                        )
                      : null,
                ),
          ),
        ),
      ],
    );
  }
}
