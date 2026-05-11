// DOCS: docs/development-standards.md
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:fsi_courier_app/design_system/design_system.dart';
import 'package:fsi_courier_app/shared/widgets/app_header_bar.dart';
import 'package:fsi_courier_app/shared/widgets/delivery_card_components.dart';
import 'package:fsi_courier_app/shared/widgets/empty_state.dart';

/// A premium card representing a Bagsakan group, following the DeliveryCard UI style.
class BagsakanGroupCard extends StatelessWidget {
  const BagsakanGroupCard({
    super.key,
    required this.group,
    required this.isDark,
    required this.onTap,
    this.onDelete,
  });

  final Map<String, dynamic> group;
  final bool isDark;
  final VoidCallback onTap;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final name = group['name'] as String;
    final description = group['description'] as String?;
    final itemCount = group['item_count'] as int;
    final status = group['status'] as String? ?? 'draft';
    final isSubmitted = status == 'submitted';
    final pendingSyncCount = group['pending_sync_count'] as int? ?? 0;
    final createdAt = DateTime.fromMillisecondsSinceEpoch(
      group['created_at'] as int,
    );
    final submittedAtRaw = group['submitted_at'] as int?;
    final submittedAt = submittedAtRaw != null
        ? DateTime.fromMillisecondsSinceEpoch(submittedAtRaw)
        : null;

    final cardBg = isDark ? DSColors.cardDark : DSColors.cardLight;
    final cardBorder = isDark
        ? DSColors.separatorDark
        : DSColors.separatorLight;
    final subtextColor = isDark
        ? DSColors.labelSecondaryDark
        : DSColors.labelSecondary;

    return BouncingCardWrapper(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: DSStyles.cardRadius,
          border: Border.all(color: cardBorder, width: 1),
          boxShadow: DSStyles.shadowSM(context),
        ),
        clipBehavior: Clip.antiAlias,
        child: IntrinsicHeight(
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Left accent bar
                  Container(
                    width: DSSpacing.xs,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          isSubmitted ? DSColors.success : DSColors.primary,
                          (isSubmitted ? DSColors.success : DSColors.primary)
                              .withValues(alpha: DSStyles.alphaMuted),
                        ],
                      ),
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(DSSpacing.md),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Header Row: Status & Actions
                          Row(
                            children: [
                              if (isSubmitted)
                                DeliveryStatusBadge(
                                  label: 'bagsakan.status_submitted'.tr(),
                                  color: DSColors.success,
                                  icon: Icons.check_circle_rounded,
                                )
                              else
                                DeliveryStatusBadge(
                                  label: 'DRAFT',
                                  color: DSColors.primary,
                                  icon: Icons.edit_note_rounded,
                                ),
                              if (pendingSyncCount > 0) ...[
                                DSSpacing.wXs,
                                DeliveryTinyPill(
                                  label: 'UNSYNC',
                                  color: DSColors.warning,
                                ),
                              ],
                              const Spacer(),
                              if (onDelete != null && !isSubmitted)
                                IconButton(
                                  onPressed: onDelete,
                                  icon: const Icon(
                                    Icons.delete_outline_rounded,
                                  ),
                                  color: DSColors.error,
                                  style: IconButton.styleFrom(
                                    backgroundColor: DSColors.error.withValues(
                                      alpha: 0.1,
                                    ),
                                    padding: const EdgeInsets.all(DSSpacing.xs),
                                    minimumSize: Size.zero,
                                    tapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                  ),
                                ),
                            ],
                          ),
                          DSSpacing.hMd,

                          // Body: Name & Description
                          Text(
                            name,
                            style:
                                DSTypography.title(
                                  color: isDark
                                      ? DSColors.white
                                      : DSColors.labelPrimary,
                                ).copyWith(
                                  fontWeight: FontWeight.w800,
                                  fontSize: DSTypography.sizeMd,
                                  letterSpacing: DSTypography.lsLoose,
                                ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (description != null &&
                              description.isNotEmpty) ...[
                            DSSpacing.hXs,
                            Text(
                              description,
                              style: DSTypography.caption(color: subtextColor)
                                  .copyWith(
                                    fontSize: DSTypography.sizeSm,
                                    height: 1.2,
                                  ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],

                          DSSpacing.hLg,

                          // Footer Row: Stats & Timestamps
                          Row(
                            children: [
                              InfoChip(
                                icon: Icons.inventory_2_rounded,
                                label: 'bagsakan.group_card_items'.tr(
                                  namedArgs: {'count': itemCount.toString()},
                                ),
                                isDark: isDark,
                              ),
                              const Spacer(),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.add_circle_outline_rounded,
                                        size: DSIconSize.xs,
                                        color: subtextColor,
                                      ),
                                      DSSpacing.wXs,
                                      Text(
                                        DateFormat(
                                          'MMM d, h:mm a',
                                        ).format(createdAt),
                                        style:
                                            DSTypography.caption(
                                              color: subtextColor,
                                            ).copyWith(
                                              fontSize: DSTypography.sizeXs,
                                            ),
                                      ),
                                    ],
                                  ),
                                  if (isSubmitted && submittedAt != null) ...[
                                    DSSpacing.hXs,
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.check_circle_outline_rounded,
                                          size: DSIconSize.xs,
                                          color: DSColors.success,
                                        ),
                                        DSSpacing.wXs,
                                        Text(
                                          DateFormat(
                                            'MMM d, h:mm a',
                                          ).format(submittedAt),
                                          style:
                                              DSTypography.caption(
                                                color: DSColors.success,
                                              ).copyWith(
                                                fontSize: DSTypography.sizeXs,
                                                fontWeight: FontWeight.w600,
                                              ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Reusable header action for showing contextual Bagsakan help.
class BagsakanHeaderInfoButton extends StatelessWidget {
  const BagsakanHeaderInfoButton({
    super.key,
    required this.onTap,
    this.tooltip,
  });

  final VoidCallback onTap;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip ?? 'bagsakan.propagation_help_title'.tr(),
      child: HeaderIconButton(
        icon: Icons.help_outline_rounded,
        onTap: onTap,
        isFlat: true,
      ),
    );
  }
}

/// Help sheet explaining how propagation works when submitting a Bagsakan.
class BagsakanPropagationHelpSheet extends StatelessWidget {
  const BagsakanPropagationHelpSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? DSColors.cardDark : DSColors.cardLight,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: DSColors.black.withValues(alpha: isDark ? 0.4 : 0.1),
            blurRadius: DSStyles.radiusXL,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      padding: EdgeInsets.fromLTRB(
        DSSpacing.lg,
        DSSpacing.sm,
        DSSpacing.lg,
        MediaQuery.of(context).padding.bottom + DSSpacing.lg,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: DSIconSize.heroSm,
                height: 5,
                decoration: BoxDecoration(
                  color: isDark
                      ? DSColors.separatorDark
                      : DSColors.separatorLight,
                  borderRadius: DSStyles.cardRadius,
                ),
              ),
            ),
            DSSpacing.hMd,
            DSSectionHeader(
              title: 'bagsakan.propagation_help_title'.tr(),
              padding: EdgeInsets.zero,
            ),
            Text(
              'bagsakan.propagation_help_subtitle'.tr(),
              style: DSTypography.caption().copyWith(
                fontSize: DSTypography.sizeMd,
                color: isDark
                    ? DSColors.labelSecondaryDark
                    : DSColors.labelSecondary,
              ),
            ),
            DSSpacing.hLg,
            DSCard(
              padding: const EdgeInsets.all(DSSpacing.lg),
              child: Column(
                children: [
                  _BagsakanHelpItem(
                    icon: Icons.compare_arrows_rounded,
                    title: 'bagsakan.propagation_item_source_title'.tr(),
                    description: 'bagsakan.propagation_item_source_desc'.tr(),
                    isDark: isDark,
                  ).dsCardEntry(delay: DSAnimations.stagger(0)),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: DSSpacing.md),
                    child: Divider(height: 1),
                  ),
                  _BagsakanHelpItem(
                    icon: Icons.report_problem_outlined,
                    title: 'bagsakan.propagation_item_failed_title'.tr(),
                    description: 'bagsakan.propagation_item_failed_desc'.tr(),
                    isDark: isDark,
                  ).dsCardEntry(delay: DSAnimations.stagger(1)),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: DSSpacing.md),
                    child: Divider(height: 1),
                  ),
                  _BagsakanHelpItem(
                    icon: Icons.sync_alt_rounded,
                    title: 'bagsakan.propagation_item_sync_title'.tr(),
                    description: 'bagsakan.propagation_item_sync_desc'.tr(),
                    isDark: isDark,
                  ).dsCardEntry(delay: DSAnimations.stagger(2)),
                ],
              ),
            ),
            DSSpacing.hMd,
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(DSSpacing.md),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    DSColors.primary.withValues(alpha: DSStyles.alphaSubtle),
                    DSColors.primary.withValues(alpha: DSStyles.alphaSoft),
                  ],
                ),
                borderRadius: DSStyles.cardRadius,
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.info_outline_rounded,
                    size: DSIconSize.md,
                    color: DSColors.primary,
                  ),
                  DSSpacing.wMd,
                  Expanded(
                    child: Text(
                      'bagsakan.propagation_help_footer'.tr(),
                      style: DSTypography.body().copyWith(
                        fontSize: DSTypography.sizeSm,
                        color: DSColors.primary.withValues(
                          alpha: DSStyles.alphaDisabled,
                        ),
                        height: DSStyles.heightNormal,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ).dsCardEntry(delay: DSAnimations.stagger(3)),
          ],
        ),
      ),
    );
  }
}

class _BagsakanHelpItem extends StatelessWidget {
  const _BagsakanHelpItem({
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
                style: DSTypography.body().copyWith(
                  fontWeight: FontWeight.w700,
                  color: isDark ? DSColors.white : DSColors.labelPrimary,
                ),
              ),
              DSSpacing.hXs,
              Text(
                description,
                style: DSTypography.caption().copyWith(
                  fontSize: DSTypography.sizeSm,
                  color: isDark
                      ? DSColors.labelSecondaryDark
                      : DSColors.labelSecondary,
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

// ─────────────────────────────────────────────────
// MARK: Empty State
// ─────────────────────────────────────────────────

/// Empty / no-results placeholder for Bagsakan screens.
///
/// Wrapped in a scrollable [ListView] so pull-to-refresh works even when
/// there are zero items. Matches the standard [DeliveryListEmptyState] style.
class BagsakanListEmptyState extends StatelessWidget {
  const BagsakanListEmptyState({
    super.key,
    required this.message,
    this.subMessage,
    this.isSearching = false,
  });

  final String message;
  final String? subMessage;
  final bool isSearching;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final statusColor = DSColors.primary;
    final iconData = isSearching
        ? Icons.search_off_rounded
        : Icons.inventory_2_outlined;

    return ListView(
      padding: EdgeInsets.zero,
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(
          height: MediaQuery.of(context).size.height * 0.6,
          child: EmptyState(
            message: message,
            subMessage: subMessage ?? 'empty_states.pull_to_refresh'.tr(),
            icon: iconData,
            iconColor: isDark ? DSColors.primaryDark : statusColor,
          ).dsFadeEntry(),
        ),
      ],
    );
  }
}
