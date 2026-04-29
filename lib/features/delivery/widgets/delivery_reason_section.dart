// DOCS: docs/development-standards.md
// DOCS: docs/features/delivery.md — update that file when you edit this one.

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fsi_courier_app/core/constants.dart';
import 'package:fsi_courier_app/design_system/design_system.dart';
import 'package:fsi_courier_app/features/delivery/widgets/delivery_form_helpers.dart';

/// REASON FOR NON-DELIVERY section for [DeliveryUpdateScreen] (FAILED_DELIVERY only).
///
/// Contains: reason picker, optional specify-reason field (Others), and
/// optional informant-name field (reasons with requiresAccordingTo).
class DeliveryReasonSection extends StatelessWidget {
  const DeliveryReasonSection({
    super.key,
    required this.reason,
    required this.reasonSpecifyController,
    required this.accordingToController,
    required this.errors,
    required this.isDark,
    required this.onReasonPickerTap,
    required this.onReasonSpecifyChanged,
    required this.onAccordingToChanged,
  });

  final String? reason;
  final TextEditingController reasonSpecifyController;
  final TextEditingController accordingToController;
  final Map<String, String> errors;
  final bool isDark;

  /// Opens the searchable reason picker sheet.
  final VoidCallback onReasonPickerTap;

  /// Clears the reason-specify validation error.
  final VoidCallback onReasonSpecifyChanged;

  /// Clears the according-to validation error.
  final VoidCallback onAccordingToChanged;

  @override
  Widget build(BuildContext context) {
    const fieldGap = DSSpacing.hMd;
    final requiresAccordingTo =
        reason != null &&
        (kReasonConfigs[reason]?.requiresAccordingTo ?? false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Reason picker ───────────────────────────────────────────────────
        GestureDetector(
          onTap: onReasonPickerTap,
          child: AbsorbPointer(
            child: TextFormField(
              key: ValueKey(reason),
              initialValue: reason,
              style: DSTypography.body().copyWith(
                color: isDark
                    ? DSColors.labelPrimaryDark
                    : DSColors.labelPrimary,
                fontWeight: FontWeight.w600,
              ),
              decoration:
                  deliveryFieldDecoration(
                    context,
                    labelText: 'delivery_update.header.select_reason'.tr(),
                    errorText: errors['reason'],
                  ).copyWith(
                    suffixIcon: Icon(
                      Icons.search_rounded,
                      size: DSIconSize.md,
                      color: isDark
                          ? DSColors.labelTertiaryDark
                          : DSColors.labelTertiary,
                    ),
                  ),
            ),
          ),
        ),

        // ── Others → specify reason ─────────────────────────────────────────
        if (reason == 'Others') ...[
          fieldGap,
          TextFormField(
            controller: reasonSpecifyController,
            decoration:
                deliveryFieldDecoration(
                  context,
                  labelText: 'delivery_update.header.specify_reason'.tr(),
                  hintText: 'delivery_update.hint.specify_reason_example'.tr(),
                  errorText: errors['reason_specify'],
                ).copyWith(
                  prefixIcon: const Icon(
                    Icons.edit_note_rounded,
                    size: DSIconSize.md,
                  ),
                ),
            textCapitalization: TextCapitalization.characters,
            maxLength: kMaxReasonLength,
            maxLengthEnforcement: MaxLengthEnforcement.enforced,
            buildCounter:
                (_, {required currentLength, required isFocused, maxLength}) =>
                    null,
            onChanged: (_) => onReasonSpecifyChanged(),
          ),
        ],

        // ── According to (informant name) ───────────────────────────────────
        if (requiresAccordingTo) ...[
          fieldGap,
          TextFormField(
            controller: accordingToController,
            decoration:
                deliveryFieldDecoration(
                  context,
                  labelText: 'delivery_update.header.according_to_name'.tr(),
                  hintText: 'delivery_update.hint.according_to_example'.tr(),
                  errorText: errors['according_to'],
                ).copyWith(
                  prefixIcon: const Icon(
                    Icons.person_outline_rounded,
                    size: DSIconSize.md,
                  ),
                ),
            textCapitalization: TextCapitalization.characters,
            inputFormatters: [
              TextInputFormatter.withFunction(
                (old, newVal) =>
                    newVal.copyWith(text: newVal.text.toUpperCase()),
              ),
            ],
            maxLength: 255,
            maxLengthEnforcement: MaxLengthEnforcement.enforced,
            buildCounter:
                (_, {required currentLength, required isFocused, maxLength}) =>
                    null,
            onChanged: (_) => onAccordingToChanged(),
          ),
        ],
      ],
    );
  }
}
