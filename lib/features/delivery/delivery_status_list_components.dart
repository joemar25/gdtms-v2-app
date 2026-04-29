// DOCS: docs/development-standards.md
// DOCS: docs/features/delivery.md — update that file when you edit this one.

// =============================================================================
// delivery_status_list_components.dart
// =============================================================================
//
// Purpose:
//   Extracted UI components used exclusively by [DeliveryStatusListScreen].
//   Keeping them here prevents delivery_status_list_screen.dart from exceeding
//   the 600-line limit (Rule 01) while preserving single responsibility.
//
// Components:
//   • [DeliveryListEmptyState]      — empty / no-results placeholder
//   • [DeliveryStatusInfoBanner]    — immutable-status info strip (OSA / Delivered)
//   • [FailedDeliveryHelpSheet]     — bottom sheet explaining FD workflow & payments
//   • [_FailedDeliveryHelpItem]     — single row inside [FailedDeliveryHelpSheet]
// =============================================================================

import 'package:flutter/material.dart';
import 'package:fsi_courier_app/design_system/design_system.dart';
import 'package:fsi_courier_app/shared/widgets/delivery_card.dart';

// ─────────────────────────────────────────────────
// MARK: Empty State
// ─────────────────────────────────────────────────

/// Empty / no-results placeholder for delivery status list screens.
///
/// Wrapped in a scrollable [ListView] so pull-to-refresh works even when
/// there are zero items. Shows a status-coloured icon and a contextual
/// message; the icon switches to a search-off icon while [isSearching].
class DeliveryListEmptyState extends StatelessWidget {
  const DeliveryListEmptyState({
    super.key,
    required this.message,
    required this.status,
    required this.isSearching,
    required this.isDark,
  });

  final String message;
  final String status;
  final bool isSearching;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final statusColor = DeliveryCard.statusColor(status);
    final iconData = isSearching
        ? Icons.search_off_rounded
        : DeliveryCard.statusIcon(status);
    final subtextColor = isDark
        ? DSColors.labelTertiaryDark
        : DSColors.labelTertiary;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(
          height: MediaQuery.of(context).size.height * 0.6,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: DSIconSize.heroMd,
                  height: DSIconSize.heroMd,
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: DSStyles.alphaSoft),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: statusColor.withValues(
                        alpha: DSStyles.alphaSubtle,
                      ),
                      width: DSStyles.borderWidth * 1.5,
                    ),
                  ),
                  child: Icon(
                    iconData,
                    size: DSIconSize.xl,
                    color: statusColor.withValues(alpha: DSStyles.alphaMuted),
                  ),
                ),
                DSSpacing.hMd,
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: DSTypography.label().copyWith(
                    fontSize: DSTypography.sizeMd,
                    fontWeight: FontWeight.w600,
                    color: isDark
                        ? DSColors.labelPrimaryDark
                        : DSColors.labelPrimary,
                  ),
                ),
                DSSpacing.hSm,
                Text(
                  'Pull down to refresh',
                  style: DSTypography.caption().copyWith(
                    fontSize: DSTypography.sizeSm,
                    color: subtextColor,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────
// MARK: Status Info Banner
// ─────────────────────────────────────────────────

/// Inline banner shown at the top of a delivery list to communicate that
/// items in that status are immutable (OSA, Delivered).
class DeliveryStatusInfoBanner extends StatelessWidget {
  const DeliveryStatusInfoBanner({
    super.key,
    required this.icon,
    required this.message,
    required this.statusColor,
    required this.isDark,
  });

  final IconData icon;
  final String message;
  final Color statusColor;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final bg = isDark
        ? DSColors.cardDark
        : statusColor.withValues(alpha: DSStyles.alphaSoft);
    final border = statusColor.withValues(alpha: DSStyles.alphaMuted);
    final textColor = statusColor.withValues(alpha: DSStyles.alphaDisabled);

    return Container(
      margin: EdgeInsets.only(bottom: DSSpacing.sm),
      padding: EdgeInsets.symmetric(horizontal: 14, vertical: DSSpacing.md),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: DSStyles.cardRadius,
        border: Border.all(color: border),
      ),
      child: Row(
        children: [
          Icon(icon, size: DSIconSize.sm, color: textColor),
          DSSpacing.wSm,
          Expanded(
            child: Text(
              message,
              style: DSTypography.body().copyWith(
                fontSize: DSTypography.sizeSm,
                fontWeight: FontWeight.w500,
                color: textColor,
                height: DSStyles.heightNormal,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────
// MARK: Failed Delivery Help Sheet
// ─────────────────────────────────────────────────

/// Bottom sheet shown from the FAILED_DELIVERY list explaining the
/// redelivery eligibility rules, RTS flow, and payment processing.
///
/// Self-contained — derives theme from [BuildContext]. Call via
/// [showModalBottomSheet] with [backgroundColor] set to transparent.
class FailedDeliveryHelpSheet extends StatelessWidget {
  const FailedDeliveryHelpSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final failedDeliveryColor = DeliveryCard.statusColor('FAILED_DELIVERY');

    return Container(
      decoration: BoxDecoration(
        color: isDark ? DSColors.cardDark : DSColors.white,
        borderRadius: DSStyles.cardRadius,
        boxShadow: [
          BoxShadow(
            color: DSColors.black.withValues(alpha: DSStyles.alphaMuted),
            blurRadius: DSStyles.radiusXL,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DSSpacing.hMd,
          // Handle bar
          Container(
            width: DSIconSize.heroSm,
            height: 4,
            decoration: BoxDecoration(
              color: isDark
                  ? DSColors.labelTertiaryDark
                  : DSColors.labelTertiary,
              borderRadius: DSStyles.pillRadius,
            ),
          ),
          DSSpacing.hLg,

          // Header icon & title
          Padding(
            padding: EdgeInsets.symmetric(horizontal: DSSpacing.xl),
            child: Row(
              children: [
                Container(
                  width: DSIconSize.heroMd,
                  height: DSIconSize.heroMd,
                  decoration: BoxDecoration(
                    color: failedDeliveryColor.withValues(
                      alpha: DSStyles.alphaSoft,
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.assignment_return_rounded,
                    color: failedDeliveryColor,
                    size: DSIconSize.xl,
                  ),
                ),
                DSSpacing.wMd,
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Failed Delivery & Payments',
                        style: DSTypography.heading().copyWith(
                          fontSize: DSTypography.sizeMd,
                          fontWeight: FontWeight.w700,
                          color: isDark
                              ? DSColors.labelPrimaryDark
                              : DSColors.labelPrimary,
                          letterSpacing: DSTypography.lsSlightlyTight,
                        ),
                      ),
                      Text(
                        'How things work in the system',
                        style: DSTypography.caption().copyWith(
                          fontSize: DSTypography.sizeMd,
                          color: isDark
                              ? DSColors.labelSecondaryDark
                              : DSColors.labelSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(
                    Icons.close_rounded,
                    color: isDark
                        ? DSColors.labelSecondaryDark
                        : DSColors.labelSecondary,
                  ),
                ),
              ],
            ),
          ),

          DSSpacing.hLg,

          // Help content
          Padding(
            padding: EdgeInsets.symmetric(horizontal: DSSpacing.xl),
            child: Container(
              padding: EdgeInsets.all(DSSpacing.lg),
              decoration: BoxDecoration(
                color: isDark
                    ? DSColors.white.withValues(alpha: DSStyles.alphaSoft)
                    : DSColors.secondarySurfaceLight,
                borderRadius: DSStyles.cardRadius,
                border: Border.all(
                  color: isDark
                      ? DSColors.separatorDark
                      : DSColors.separatorLight,
                ),
              ),
              child: Column(
                children: [
                  _FailedDeliveryHelpItem(
                    icon: Icons.replay_outlined,
                    title: 'Re-delivery of Failed Attempts',
                    description:
                        'Failed deliveries may be attempted again if still eligible and not yet verified on-site. After 3 unsuccessful attempts, the item may be marked for return.',
                    isDark: isDark,
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: DSSpacing.md),
                    child: Divider(height: 1),
                  ),
                  _FailedDeliveryHelpItem(
                    icon: Icons.inventory_2_outlined,
                    title: 'Return to FSI',
                    description:
                        'If a delivery is returned to FSI, it will be reviewed by the site team for validation.',
                    isDark: isDark,
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: DSSpacing.md),
                    child: Divider(height: 1),
                  ),
                  _FailedDeliveryHelpItem(
                    icon: Icons.account_balance_wallet_outlined,
                    title: 'Payment Processing',
                    description:
                        'Validated items may be included in a payment request, subject to review and existing payment processes. Inclusion is not guaranteed.',
                    isDark: isDark,
                  ),
                ],
              ),
            ),
          ),

          DSSpacing.hMd,

          // Footer note
          Padding(
            padding: EdgeInsets.all(DSSpacing.xl),
            child: Container(
              width: double.infinity,
              padding: EdgeInsets.all(DSSpacing.md),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    failedDeliveryColor.withValues(alpha: DSStyles.alphaSubtle),
                    failedDeliveryColor.withValues(alpha: DSStyles.alphaSoft),
                  ],
                ),
                borderRadius: DSStyles.cardRadius,
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    size: DSIconSize.md,
                    color: failedDeliveryColor,
                  ),
                  DSSpacing.wMd,
                  Expanded(
                    child: Text(
                      'This ensures your payments are tracked accurately without manual intervention.',
                      style: DSTypography.body().copyWith(
                        fontSize: DSTypography.sizeSm,
                        color: failedDeliveryColor.withValues(
                          alpha: DSStyles.alphaDisabled,
                        ),
                        height: DSStyles.heightNormal,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────
// MARK: Help Item (private to this file)
// ─────────────────────────────────────────────────

/// Single icon + title + description row inside [FailedDeliveryHelpSheet].
class _FailedDeliveryHelpItem extends StatelessWidget {
  const _FailedDeliveryHelpItem({
    required this.icon,
    required this.title,
    required this.description,
    required this.isDark,
  });

  final IconData icon;
  final String title;
  final String description;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: DSIconSize.md,
          color: isDark
              ? DSColors.white.withValues(alpha: DSStyles.alphaDisabled)
              : DSColors.black.withValues(alpha: DSStyles.alphaOpaque),
        ),
        DSSpacing.wMd,
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: DSTypography.label().copyWith(
                  fontSize: DSTypography.sizeMd,
                  fontWeight: FontWeight.w600,
                  color: isDark
                      ? DSColors.labelPrimaryDark
                      : DSColors.labelPrimary,
                ),
              ),
              DSSpacing.hXs,
              Text(
                description,
                style: DSTypography.body().copyWith(
                  fontSize: DSTypography.sizeMd,
                  color: isDark
                      ? DSColors.labelSecondaryDark
                      : DSColors.black.withValues(
                          alpha: DSStyles.alphaDisabled,
                        ),
                  height: DSStyles.heightNormal,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
