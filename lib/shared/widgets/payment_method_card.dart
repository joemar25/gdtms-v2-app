// =============================================================================
// payment_method_card.dart
// =============================================================================
//
// Displays the courier's active payout bank account details.
//
// API: GET /api/mbl/me/payment-method
//
// States:
//   • has_active_payment_method: true  — green "Active" bank card
//   • has_active_payment_method: false, bank_status != null — amber warning
//     (bank on file but inactive; GCash fallback will be auto-provisioned)
//   • has_active_payment_method: false, bank_name: null — amber info
//     (no bank on file; GCash auto-provisioned on first payout request)
//   • null data — skeleton / loading placeholder
// =============================================================================

import 'package:flutter/material.dart';
import 'package:fsi_courier_app/styles/color_styles.dart';

class PaymentMethodCard extends StatelessWidget {
  /// Pass `null` while loading to show a skeleton.
  const PaymentMethodCard({
    super.key,
    required this.data,
    this.isTransparent = false,
  });

  final Map<String, dynamic>? data;
  final bool isTransparent;

  @override
  Widget build(BuildContext context) {
    final d = data;
    if (d == null) return _buildSkeleton(context);

    final hasActive = d['has_active_payment_method'] == true;
    final bankName = d['bank_name'] as String?;
    final accountName = d['account_name'] as String?;
    final accountNumber = d['account_number'] as String?;
    final bankStatus = d['bank_status'] as String?;
    final message = d['message'] as String?;

    // ── Active bank ────────────────────────────────────────────────────────
    if (hasActive) {
      return _buildCard(
        context: context,
        borderColor: isTransparent
            ? Colors.transparent
            : ColorStyles.grabGreen.withValues(alpha: 0.35),
        bgColor: isTransparent
            ? Colors.transparent
            : ColorStyles.grabGreen.withValues(alpha: 0.06),
        icon: Icons.account_balance_rounded,
        iconColor: isTransparent ? Colors.white70 : ColorStyles.grabGreen,
        label: 'Payout Account',
        labelColor: isTransparent ? Colors.white70 : ColorStyles.grabGreen,
        badge: _Badge(
          text: 'ACTIVE',
          color: isTransparent ? Colors.white : ColorStyles.grabGreen,
          isTransparent: isTransparent,
        ),
        bankName: bankName ?? '—',
        accountName: accountName,
        accountNumber: accountNumber,
      );
    }

    // ── Inactive bank (on file but inactive) ──────────────────────────────
    if (bankStatus != null) {
      return _buildCard(
        context: context,
        borderColor: isTransparent
            ? Colors.transparent
            : Colors.amber.withValues(alpha: 0.4),
        bgColor: isTransparent
            ? Colors.transparent
            : Colors.amber.withValues(alpha: 0.06),
        icon: Icons.account_balance_rounded,
        iconColor: isTransparent ? Colors.white70 : Colors.amber.shade700,
        label: 'Payout Account',
        labelColor: isTransparent ? Colors.white70 : Colors.amber.shade700,
        badge: _Badge(
          text: 'INACTIVE',
          color: isTransparent ? Colors.white : Colors.amber.shade700,
          isTransparent: isTransparent,
        ),
        bankName: bankName ?? '—',
        accountName: accountName,
        accountNumber: accountNumber,
        footerMessage: message,
        footerIcon: Icons.info_outline_rounded,
      );
    }

    // ── No bank on file ───────────────────────────────────────────────────
    return _buildNoBank(
      context: context,
      message: message,
      isTransparent: isTransparent,
    );
  }

  Widget _buildCard({
    required BuildContext context,
    required Color borderColor,
    required Color bgColor,
    required IconData icon,
    required Color iconColor,
    required String label,
    required Color labelColor,
    required _Badge badge,
    required String bankName,
    String? accountName,
    String? accountNumber,
    String? footerMessage,
    IconData? footerIcon,
  }) {
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header row
        Row(
          children: [
            Icon(icon, size: 16, color: iconColor),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
                color: labelColor,
              ),
            ),
            const Spacer(),
            badge,
          ],
        ),
        const SizedBox(height: 10),
        // Bank name
        Text(
          bankName,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: isTransparent ? Colors.white : null,
          ),
        ),
        // Account details
        if (accountName != null || accountNumber != null) ...[
          const SizedBox(height: 4),
          Row(
            children: [
              if (accountName != null)
                Expanded(
                  child: Text(
                    accountName,
                    style: TextStyle(
                      fontSize: 12,
                      color: isTransparent
                          ? Colors.white.withValues(alpha: 0.7)
                          : Colors.grey.shade600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              if (accountNumber != null) ...[
                if (accountName != null) const SizedBox(width: 8),
                Text(
                  _maskAccount(accountNumber),
                  style: TextStyle(
                    fontSize: 12,
                    color: isTransparent
                        ? Colors.white.withValues(alpha: 0.6)
                        : Colors.grey.shade500,
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ],
          ),
        ],
        // Footer message
        if (footerMessage != null) ...[
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                footerIcon ?? Icons.info_outline_rounded,
                size: 13,
                color: isTransparent
                    ? Colors.white.withValues(alpha: 0.8)
                    : Colors.amber.shade700,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  footerMessage,
                  style: TextStyle(
                    fontSize: 11,
                    color: isTransparent
                        ? Colors.white.withValues(alpha: 0.8)
                        : Colors.amber.shade700,
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );

    if (isTransparent) return content;

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: content,
    );
  }

  Widget _buildNoBank({
    required BuildContext context,
    String? message,
    bool isTransparent = false,
  }) {
    final content = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          Icons.account_balance_outlined,
          size: 18,
          color: isTransparent ? Colors.white70 : Colors.amber.shade700,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'No Bank Account on File',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: isTransparent ? Colors.white : Colors.amber.shade800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                message ??
                    'A default GCash account will be automatically set up when you submit a payout request.',
                style: TextStyle(
                  fontSize: 12,
                  color: isTransparent
                      ? Colors.white.withValues(alpha: 0.7)
                      : Colors.amber.shade700,
                ),
              ),
            ],
          ),
        ),
      ],
    );

    if (isTransparent) return content;

    return Container(
      decoration: BoxDecoration(
        color: Colors.amber.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: content,
    );
  }

  Widget _buildSkeleton(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final base = isDark ? Colors.white12 : Colors.black12;
    return Container(
      height: 78,
      decoration: BoxDecoration(
        color: base,
        borderRadius: BorderRadius.circular(14),
      ),
    );
  }

  /// Shows last 4 digits and masks the rest: ••••••6789
  String _maskAccount(String raw) {
    if (raw.length <= 4) return raw;
    final suffix = raw.substring(raw.length - 4);
    return '••••••$suffix';
  }
}

class _Badge extends StatelessWidget {
  const _Badge({
    required this.text,
    required this.color,
    this.isTransparent = false,
  });
  final String text;
  final Color color;
  final bool isTransparent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isTransparent
            ? Colors.white.withValues(alpha: 0.15)
            : color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: isTransparent
            ? Border.all(color: Colors.white.withValues(alpha: 0.3))
            : null,
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: color,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}
