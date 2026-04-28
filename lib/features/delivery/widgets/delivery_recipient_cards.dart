// DOCS: docs/features/delivery.md — update that file when you edit this one.

import 'package:flutter/material.dart';
import 'package:fsi_courier_app/design_system/design_system.dart';

/// Renders quick-tap cards for the consignee (recipient) and authorized rep.
///
/// [onSelectRecipient] is called with the tapped person's name and a
/// relationship hint: `'OWNER'` for the primary recipient, `null` for the
/// authorized rep (relationship stays unchanged by the caller).
class DeliveryRecipientCards extends StatelessWidget {
  const DeliveryRecipientCards({
    super.key,
    required this.recipientName,
    required this.authorizedRep,
    required this.onSelectRecipient,
  });

  final String recipientName;
  final String authorizedRep;

  /// Called with `(name, relationship?)`.  Relationship is `'OWNER'` when the
  /// recipient card is tapped, and `null` when the authorized-rep card is tapped
  /// — callers should reset the relationship field to blank (null) so the user
  /// must choose a relationship manually.
  final void Function(String name, String? relationship) onSelectRecipient;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (recipientName.isNotEmpty)
          GestureDetector(
            onTap: () => onSelectRecipient(recipientName, 'OWNER'),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: DSSpacing.md,
                vertical: DSSpacing.md,
              ),
              decoration: BoxDecoration(
                color: DSColors.success.withValues(alpha: DSStyles.alphaSoft),
                borderRadius: DSStyles.cardRadius,
                border: Border.all(
                  color: DSColors.success.withValues(
                    alpha: DSStyles.alphaDarkShadow,
                  ),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.person_rounded,
                    size: 16,
                    color: DSColors.success,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Recipient',
                          style: DSTypography.caption().copyWith(
                            fontSize: DSTypography.sizeXs,
                            color: isDark
                                ? DSColors.labelSecondaryDark
                                : DSColors.labelTertiary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          recipientName,
                          style: DSTypography.body().copyWith(
                            fontSize: DSTypography.sizeSm,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 18,
                    color: DSColors.labelTertiary,
                  ),
                ],
              ),
            ),
          ),
        if (recipientName.isNotEmpty && authorizedRep.isNotEmpty)
          const SizedBox(height: 6),
        if (authorizedRep.isNotEmpty)
          GestureDetector(
            onTap: () => onSelectRecipient(authorizedRep, null),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: DSSpacing.md,
                vertical: DSSpacing.md,
              ),
              decoration: BoxDecoration(
                color: DSColors.primary.withValues(alpha: DSStyles.alphaSoft),
                borderRadius: DSStyles.cardRadius,
                border: Border.all(
                  color: DSColors.primary.withValues(
                    alpha: DSStyles.alphaDarkShadow,
                  ),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.person_add_rounded,
                    size: 16,
                    color: DSColors.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Auth. Rep',
                          style: DSTypography.caption().copyWith(
                            fontSize: DSTypography.sizeXs,
                            color: isDark
                                ? DSColors.labelSecondaryDark
                                : DSColors.labelTertiary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          authorizedRep,
                          style: DSTypography.body().copyWith(
                            fontSize: DSTypography.sizeSm,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 18,
                    color: DSColors.labelTertiary,
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
