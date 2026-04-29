// DOCS: docs/development-standards.md
// DOCS: docs/features/delivery.md — update that file when you edit this one.

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:fsi_courier_app/core/models/photo_entry.dart';
import 'package:fsi_courier_app/design_system/design_system.dart';
import 'package:fsi_courier_app/features/delivery/delivery_update_components.dart';

/// PROOF OF DELIVERY section for [DeliveryUpdateScreen] (DELIVERED status only).
///
/// Contains POD + SELFIE photo slots, a signature checkbox, and the signature
/// slot (visible only when the checkbox is checked). The confirmation dialog
/// is shown internally; the result is surfaced via [onSignatureSlotToggled].
class DeliveryProofSection extends StatelessWidget {
  const DeliveryProofSection({
    super.key,
    required this.podPhoto,
    required this.selfiePhoto,
    required this.signaturePath,
    required this.showSignatureSlot,
    required this.errors,
    required this.isDark,
    required this.onPodTap,
    required this.onPodClear,
    required this.onSelfieTap,
    required this.onSelfieClear,
    required this.onSignatureSlotToggled,
    required this.onSignatureCapture,
    required this.onSignatureClear,
  });

  final PhotoEntry? podPhoto;
  final PhotoEntry? selfiePhoto;
  final String? signaturePath;
  final bool showSignatureSlot;
  final Map<String, String> errors;
  final bool isDark;

  final VoidCallback onPodTap;
  final VoidCallback onPodClear;
  final VoidCallback onSelfieTap;
  final VoidCallback onSelfieClear;

  /// Called after the checkbox is resolved.
  /// [show] — whether to reveal the slot; [clearPath] — whether to discard the signature.
  final void Function(bool show, bool clearPath) onSignatureSlotToggled;

  final VoidCallback onSignatureCapture;
  final VoidCallback onSignatureClear;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── POD + SELFIE photo slots ────────────────────────────────────────
        Row(
          children: [
            DeliveryPhotoSlot(
              label: 'POD',
              photo: podPhoto,
              icon: Icons.inventory_2_rounded,
              color: DSColors.primary,
              isDark: isDark,
              hasError: errors['pod_photo'] != null,
              onTap: onPodTap,
              onClear: onPodClear,
            ),
            DSSpacing.wMd,
            DeliveryPhotoSlot(
              label: 'SELFIE',
              photo: selfiePhoto,
              icon: Icons.face_rounded,
              color: DSColors.labelSecondary,
              isDark: isDark,
              hasError: errors['selfie_photo'] != null,
              onTap: onSelfieTap,
              onClear: onSelfieClear,
            ),
          ],
        ),
        DSSpacing.hMd,

        // ── Signature checkbox ──────────────────────────────────────────────
        Row(
          children: [
            Checkbox(
              value: showSignatureSlot,
              activeColor: DSColors.primary,
              onChanged: (checked) async {
                if (checked == true) {
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: Text(
                        'delivery_update.signature.add_signature'.tr(),
                        style: DSTypography.heading().copyWith(
                          fontWeight: FontWeight.w800,
                          fontSize: DSTypography.sizeMd,
                        ),
                      ),
                      content: Text(
                        'delivery_update.signature.capture_prompt'.tr(),
                        style: DSTypography.body().copyWith(
                          fontSize: DSTypography.sizeMd,
                        ),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(ctx).pop(false),
                          child: Text('delivery_update.signature.cancel'.tr()),
                        ),
                        FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: DSColors.primary,
                          ),
                          onPressed: () => Navigator.of(ctx).pop(true),
                          child: Text('delivery_update.signature.yes'.tr()),
                        ),
                      ],
                    ),
                  );
                  if (confirmed == true) onSignatureSlotToggled(true, false);
                } else {
                  onSignatureSlotToggled(false, true);
                }
              },
            ),
            Text(
              'delivery_update.signature.include_recipient_signature'.tr(),
              style: DSTypography.body().copyWith(
                fontSize: DSTypography.sizeMd,
              ),
            ),
          ],
        ),

        if (showSignatureSlot) ...[
          DSSpacing.hSm,
          DeliverySignatureSlot(
            isDark: isDark,
            signaturePath: signaturePath,
            hasError: errors['recipient_signature'] != null,
            onCapture: onSignatureCapture,
            onClear: onSignatureClear,
          ),
        ],
      ],
    );
  }
}
