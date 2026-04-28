// DOCS: docs/shared/widgets.md — update that file when you edit this one.

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
import 'package:fsi_courier_app/design_system/design_system.dart';

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
            ? DSColors.transparent
            : DSColors.primary.withValues(alpha: DSStyles.alphaMuted),
        bgColor: isTransparent
            ? DSColors.transparent
            : DSColors.primary.withValues(alpha: DSStyles.alphaSoft),
        icon: Icons.account_balance_rounded,
        iconColor: isTransparent
            ? DSColors.white.withValues(alpha: DSStyles.alphaDisabled)
            : DSColors.primary,
        label: 'Payout Account',
        labelColor: isTransparent
            ? DSColors.white.withValues(alpha: DSStyles.alphaDisabled)
            : DSColors.primary,
        badge: _Badge(
          text: 'ACTIVE',
          color: isTransparent ? DSColors.white : DSColors.primary,
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
            ? DSColors.transparent
            : DSColors.warning.withValues(alpha: DSStyles.alphaMuted),
        bgColor: isTransparent
            ? DSColors.transparent
            : DSColors.warning.withValues(alpha: DSStyles.alphaSoft),
        icon: Icons.account_balance_rounded,
        iconColor: isTransparent
            ? DSColors.white.withValues(alpha: DSStyles.alphaDisabled)
            : DSColors.warning,
        label: 'Payout Account',
        labelColor: isTransparent
            ? DSColors.white.withValues(alpha: DSStyles.alphaDisabled)
            : DSColors.warning,
        badge: _Badge(
          text: 'INACTIVE',
          color: isTransparent ? DSColors.white : DSColors.warning,
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
            Icon(icon, size: DSIconSize.sm, color: iconColor),
            DSSpacing.wSm,
            Text(
              label,
              style: DSTypography.label(color: labelColor).copyWith(
                fontSize: DSTypography.sizeSm,
                fontWeight: FontWeight.w700,
                letterSpacing: DSTypography.lsExtraLoose,
              ),
            ),
            const Spacer(),
            badge,
          ],
        ),
        DSSpacing.hSm,
        // Bank name
        Text(
          bankName,
          style:
              DSTypography.label(
                color: isTransparent ? DSColors.white : null,
              ).copyWith(
                fontSize: DSTypography.sizeMd,
                fontWeight: FontWeight.w800,
              ),
        ),
        // Account details
        if (accountName != null || accountNumber != null) ...[
          DSSpacing.hXs,
          Row(
            children: [
              if (accountName != null)
                Expanded(
                  child: Text(
                    accountName,
                    style: DSTypography.caption(
                      color: isTransparent
                          ? DSColors.white.withValues(
                              alpha: DSStyles.alphaDisabled,
                            )
                          : (Theme.of(context).brightness == Brightness.dark
                                ? DSColors.labelSecondaryDark
                                : DSColors.labelSecondary),
                    ).copyWith(fontSize: DSTypography.sizeSm),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              if (accountNumber != null) ...[
                if (accountName != null) DSSpacing.wSm,
                Text(
                  _maskAccount(accountNumber),
                  style:
                      DSTypography.caption(
                        color: isTransparent
                            ? DSColors.white.withValues(
                                alpha: DSStyles.alphaDisabled,
                              )
                            : (Theme.of(context).brightness == Brightness.dark
                                  ? DSColors.labelSecondaryDark
                                  : DSColors.labelSecondary),
                      ).copyWith(
                        fontSize: DSTypography.sizeSm,
                        fontFamily: 'monospace',
                      ),
                ),
              ],
            ],
          ),
        ],
        // Footer message
        if (footerMessage != null) ...[
          DSSpacing.hSm,
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                footerIcon ?? Icons.info_outline_rounded,
                size: DSIconSize.xs,
                color: isTransparent
                    ? DSColors.white.withValues(alpha: DSStyles.alphaDisabled)
                    : DSColors.warningText,
              ),
              DSSpacing.wSm,
              Expanded(
                child: Text(
                  footerMessage,
                  style: DSTypography.caption(
                    color: isTransparent
                        ? DSColors.white.withValues(
                            alpha: DSStyles.alphaDisabled,
                          )
                        : DSColors.warning,
                  ).copyWith(fontSize: DSTypography.sizeSm),
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
        borderRadius: DSStyles.cardRadius,
        border: Border.all(color: borderColor),
      ),
      padding: EdgeInsets.symmetric(horizontal: DSSpacing.md, vertical: 14),
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
          size: DSIconSize.md,
          color: isTransparent
              ? DSColors.white.withValues(alpha: DSStyles.alphaDisabled)
              : DSColors.warning,
        ),
        DSSpacing.wSm,
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'No Bank Account on File',
                style:
                    DSTypography.label(
                      color: isTransparent ? DSColors.white : DSColors.warning,
                    ).copyWith(
                      fontSize: DSTypography.sizeMd,
                      fontWeight: FontWeight.w700,
                    ),
              ),
              DSSpacing.hXs,
              Text(
                message ??
                    'A default GCash account will be automatically set up when you submit a payout request.',
                style: DSTypography.caption(
                  color: isTransparent
                      ? DSColors.white.withValues(alpha: DSStyles.alphaDisabled)
                      : DSColors.warning,
                ).copyWith(fontSize: DSTypography.sizeSm),
              ),
            ],
          ),
        ),
      ],
    );

    if (isTransparent) return content;

    return Container(
      decoration: BoxDecoration(
        color: DSColors.warning.withValues(alpha: DSStyles.alphaSoft),
        borderRadius: DSStyles.cardRadius,
        border: Border.all(
          color: DSColors.warning.withValues(alpha: DSStyles.alphaMuted),
        ),
      ),
      padding: EdgeInsets.symmetric(horizontal: DSSpacing.md, vertical: 14),
      child: content,
    );
  }

  Widget _buildSkeleton(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final base = isDark
        ? DSColors.white.withValues(alpha: DSStyles.alphaSubtle)
        : DSColors.black.withValues(alpha: DSStyles.alphaSubtle);
    return Container(
      height: DSIconSize.xs,
      decoration: BoxDecoration(color: base, borderRadius: DSStyles.cardRadius),
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
      padding: EdgeInsets.symmetric(horizontal: DSSpacing.sm, vertical: 3),
      decoration: BoxDecoration(
        color: isTransparent
            ? DSColors.white.withValues(alpha: DSStyles.alphaSubtle)
            : color.withValues(alpha: DSStyles.alphaSubtle),
        borderRadius: DSStyles.cardRadius,
        border: isTransparent
            ? Border.all(
                color: DSColors.white.withValues(alpha: DSStyles.alphaMuted),
              )
            : null,
      ),
      child: Text(
        text,
        style: DSTypography.label(color: color).copyWith(
          fontSize: DSTypography.sizeXs,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}
