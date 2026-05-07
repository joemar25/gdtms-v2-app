// DOCS: docs/development-standards.md
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:fsi_courier_app/design_system/design_system.dart';
import 'package:fsi_courier_app/shared/widgets/delivery_card_components.dart';

/// A premium card representing a Bagsakan group, following the DeliveryCard UI style.
class BagsakanGroupCard extends StatelessWidget {
  const BagsakanGroupCard({
    super.key,
    required this.group,
    required this.isDark,
    required this.onTap,
    required this.onDelete,
  });

  final Map<String, dynamic> group;
  final bool isDark;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final name = group['name'] as String;
    final description = group['description'] as String?;
    final itemCount = group['item_count'] as int;
    final createdAt = DateTime.fromMillisecondsSinceEpoch(
      group['created_at'] as int,
    );

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
          boxShadow: [
            BoxShadow(
              color: isDark
                  ? DSColors.black.withValues(alpha: DSStyles.alphaMuted)
                  : DSColors.black.withValues(alpha: DSStyles.alphaSoft),
              blurRadius: DSStyles.elevationNone,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            child: IntrinsicHeight(
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
                          DSColors.primary,
                          DSColors.primary.withValues(
                            alpha: DSStyles.alphaMuted,
                          ),
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
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
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
                                        style: DSTypography.caption(
                                          color: subtextColor,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              DSSpacing.wSm,
                              IconButton(
                                onPressed: onDelete,
                                icon: const Icon(Icons.delete_outline_rounded),
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
                          Row(
                            children: [
                              Icon(
                                Icons.list_alt_rounded,
                                size: DSIconSize.xs,
                                color: subtextColor,
                              ),
                              DSSpacing.wXs,
                              Text(
                                'bagsakan.group_card_items'.tr(
                                  namedArgs: {'count': itemCount.toString()},
                                ),
                                style: DSTypography.caption(
                                  color: subtextColor,
                                ).copyWith(fontWeight: FontWeight.w600),
                              ),
                              const Spacer(),
                              Text(
                                DateFormat('MMM d, h:mm a').format(createdAt),
                                style: DSTypography.caption(
                                  color: subtextColor,
                                ),
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
