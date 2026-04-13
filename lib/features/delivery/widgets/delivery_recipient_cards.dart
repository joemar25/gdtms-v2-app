// DOCS: docs/features/delivery.md — update that file when you edit this one.

import 'package:flutter/material.dart';

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
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (recipientName.isNotEmpty)
          GestureDetector(
            onTap: () => onSelectRecipient(recipientName, 'OWNER'),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF007A36).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: const Color(0xFF007A36).withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.person_rounded,
                    size: 16,
                    color: Color(0xFF007A36),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Recipient',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey.shade500,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          recipientName,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 18,
                    color: Colors.grey.shade400,
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
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.purple.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.purple.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.person_add_rounded,
                    size: 16,
                    color: Colors.purple,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Auth. Rep',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey.shade500,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          authorizedRep,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 18,
                    color: Colors.grey.shade400,
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
