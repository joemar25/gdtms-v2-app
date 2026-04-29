// DOCS: docs/development-standards.md
// DOCS: docs/features/delivery.md — update that file when you edit this one.

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fsi_courier_app/core/constants.dart';
import 'package:fsi_courier_app/design_system/design_system.dart';
import 'package:fsi_courier_app/features/delivery/widgets/delivery_form_helpers.dart';
import 'package:fsi_courier_app/features/delivery/widgets/delivery_recipient_cards.dart';

/// RECIPIENT INFO section for [DeliveryUpdateScreen] (DELIVERED status only).
///
/// Contains recipient name, relationship picker, optional specify-relationship
/// field (OTHERS), delivery confirmation code, and placement type dropdown.
class DeliveryRecipientSection extends StatelessWidget {
  const DeliveryRecipientSection({
    super.key,
    required this.delivery,
    required this.recipientController,
    required this.relationshipSpecifyController,
    required this.confirmationCodeController,
    required this.confirmationCodeFocusNode,
    required this.relationship,
    required this.recipientIsOwner,
    required this.placement,
    required this.errors,
    required this.isDark,
    required this.onSelectRecipient,
    required this.onRecipientManuallyChanged,
    required this.onRecipientCleared,
    required this.onRelationshipPickerTap,
    required this.onRelationshipSpecifyChanged,
    required this.onConfirmationCodeChanged,
    required this.onConfirmationCodeCleared,
    required this.onPlacementChanged,
  });

  final Map<String, dynamic> delivery;
  final TextEditingController recipientController;
  final TextEditingController relationshipSpecifyController;
  final TextEditingController confirmationCodeController;
  final FocusNode confirmationCodeFocusNode;
  final String? relationship;
  final bool recipientIsOwner;
  final String placement;
  final Map<String, String> errors;
  final bool isDark;

  /// Called when a recipient card is tapped (pre-fills name + relationship).
  final void Function(String name, String? relationship) onSelectRecipient;

  /// Called when the user manually edits the recipient field (clears owner lock).
  final VoidCallback onRecipientManuallyChanged;

  /// Clears the recipient field and resets owner/relationship state.
  final VoidCallback onRecipientCleared;

  /// Opens the searchable relationship picker sheet.
  final VoidCallback onRelationshipPickerTap;

  /// Clears the relationship-specify validation error.
  final VoidCallback onRelationshipSpecifyChanged;

  /// Clears the confirmation-code validation error.
  final VoidCallback onConfirmationCodeChanged;

  /// Clears the confirmation-code text field.
  final VoidCallback onConfirmationCodeCleared;

  /// Called when placement dropdown value changes.
  final void Function(String?) onPlacementChanged;

  @override
  Widget build(BuildContext context) {
    const fieldGap = DSSpacing.hMd;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DeliveryRecipientCards(
          recipientName: delivery['name']?.toString() ?? '',
          authorizedRep: delivery['authorized_rep']?.toString() ?? '',
          onSelectRecipient: onSelectRecipient,
        ),
        fieldGap,

        // ── Recipient name ──────────────────────────────────────────────────
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: recipientController,
          builder: (context, value, _) => TextFormField(
            controller: recipientController,
            readOnly: recipientIsOwner,
            maxLength: kMaxRecipientLength,
            maxLengthEnforcement: MaxLengthEnforcement.enforced,
            buildCounter:
                (_, {required currentLength, required isFocused, maxLength}) =>
                    null,
            textCapitalization: TextCapitalization.characters,
            style: DSTypography.body().copyWith(
              color: isDark ? DSColors.labelPrimaryDark : DSColors.labelPrimary,
              fontWeight: FontWeight.w600,
            ),
            inputFormatters: [
              TextInputFormatter.withFunction(
                (old, newValue) =>
                    newValue.copyWith(text: newValue.text.toUpperCase()),
              ),
            ],
            onChanged: (_) {
              if (recipientIsOwner) onRecipientManuallyChanged();
            },
            decoration:
                deliveryFieldDecoration(
                  context,
                  labelText: recipientIsOwner
                      ? 'delivery_update.header.recipient_name_locked_owner'
                            .tr()
                      : 'delivery_update.header.recipient_name'.tr(),
                  errorText: errors['recipient'],
                ).copyWith(
                  suffixIcon: value.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(
                            Icons.clear_rounded,
                            size: DSIconSize.md,
                          ),
                          color: isDark
                              ? DSColors.labelTertiaryDark
                              : DSColors.labelTertiary,
                          onPressed: onRecipientCleared,
                        )
                      : null,
                ),
          ),
        ),
        fieldGap,

        // ── Relationship picker ─────────────────────────────────────────────
        GestureDetector(
          onTap: recipientIsOwner ? null : onRelationshipPickerTap,
          child: AbsorbPointer(
            child: TextFormField(
              key: ValueKey(relationship),
              initialValue: kRelationshipOptions.firstWhere(
                (e) => e['value'] == relationship,
                orElse: () => {'label': ''},
              )['label'],
              style: DSTypography.body().copyWith(
                color: isDark
                    ? DSColors.labelPrimaryDark
                    : DSColors.labelPrimary,
                fontWeight: FontWeight.w600,
              ),
              decoration:
                  deliveryFieldDecoration(
                    context,
                    labelText: recipientIsOwner
                        ? 'delivery_update.header.relationship_locked_owner'
                              .tr()
                        : 'delivery_update.header.relationship'.tr(),
                    errorText: errors['relationship'],
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

        // ── Others → specify relationship ───────────────────────────────────
        if (relationship == 'OTHERS') ...[
          fieldGap,
          TextFormField(
            controller: relationshipSpecifyController,
            style: DSTypography.body().copyWith(
              color: isDark ? DSColors.labelPrimaryDark : DSColors.labelPrimary,
              fontWeight: FontWeight.w600,
            ),
            decoration:
                deliveryFieldDecoration(
                  context,
                  labelText: 'delivery_update.header.specify_relationship'.tr(),
                  errorText: errors['relationship_specify'],
                ).copyWith(
                  prefixIcon: const Icon(
                    Icons.edit_note_rounded,
                    size: DSIconSize.md,
                  ),
                ),
            textCapitalization: TextCapitalization.characters,
            maxLength: kMaxRelationshipLength,
            maxLengthEnforcement: MaxLengthEnforcement.enforced,
            buildCounter:
                (_, {required currentLength, required isFocused, maxLength}) =>
                    null,
            onChanged: (_) => onRelationshipSpecifyChanged(),
          ),
        ],

        // ── Delivery confirmation code ───────────────────────────────────────
        fieldGap,
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: confirmationCodeController,
          builder: (context, value, _) => TextFormField(
            controller: confirmationCodeController,
            focusNode: confirmationCodeFocusNode,
            maxLength: 6,
            maxLengthEnforcement: MaxLengthEnforcement.enforced,
            buildCounter:
                (_, {required currentLength, required isFocused, maxLength}) =>
                    null,
            textCapitalization: TextCapitalization.characters,
            style: DSTypography.body().copyWith(
              color: isDark ? DSColors.labelPrimaryDark : DSColors.labelPrimary,
              fontWeight: FontWeight.w700,
              letterSpacing: 2.0,
            ),
            inputFormatters: [
              TextInputFormatter.withFunction(
                (old, newVal) =>
                    newVal.copyWith(text: newVal.text.toUpperCase()),
              ),
              FilteringTextInputFormatter.allow(RegExp(r'[A-Z0-9]')),
            ],
            keyboardType: TextInputType.text,
            decoration:
                deliveryFieldDecoration(
                  context,
                  labelText: 'delivery_update.header.delivery_confirmation_code'
                      .tr(),
                  hintText: 'delivery_update.hint.confirmation_code_example'
                      .tr(),
                  errorText: errors['confirmation_code'],
                ).copyWith(
                  suffixIcon: value.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(
                            Icons.clear_rounded,
                            size: DSIconSize.md,
                          ),
                          color: isDark
                              ? DSColors.labelTertiaryDark
                              : DSColors.labelTertiary,
                          onPressed: onConfirmationCodeCleared,
                        )
                      : null,
                ),
            onChanged: (_) => onConfirmationCodeChanged(),
          ),
        ),

        // ── Placement type ──────────────────────────────────────────────────
        fieldGap,
        DropdownButtonFormField<String>(
          initialValue: placement,
          decoration: deliveryFieldDecoration(
            context,
            labelText: 'delivery_update.header.placement_type'.tr(),
            errorText: errors['placement'],
          ),
          items: kPlacementOptions
              .map(
                (e) => DropdownMenuItem(
                  value: e['value'],
                  child: Text(e['label']!),
                ),
              )
              .toList(),
          onChanged: onPlacementChanged,
        ),
      ],
    );
  }
}
