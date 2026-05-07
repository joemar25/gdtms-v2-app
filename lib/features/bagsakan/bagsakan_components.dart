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

/// A simplified version of DeliveryCard used specifically for Bagsakan lists.
/// Follows the premium DeliveryCard UI but with a simplified layout.
class BagsakanItemCard extends StatelessWidget {
  const BagsakanItemCard({
    super.key,
    required this.delivery,
    required this.isDark,
    required this.isAdded,
    this.onAdd,
    this.onRemove,
    this.onTap,
  });

  final Map<String, dynamic> delivery;
  final bool isDark;
  final bool isAdded;
  final VoidCallback? onAdd;
  final VoidCallback? onRemove;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final barcode = (delivery['barcode'] ?? '').toString();
    final name = (delivery['recipient_name'] ?? '').toString();
    final address = (delivery['recipient_address'] ?? '').toString();
    final status = (delivery['delivery_status'] ?? '').toString().toUpperCase();

    final cardBg = isDark ? DSColors.cardDark : DSColors.cardLight;
    final cardBorder = isDark
        ? DSColors.separatorDark
        : DSColors.separatorLight;
    final subtextColor = isDark
        ? DSColors.labelSecondaryDark
        : DSColors.labelSecondary;
    final statusColor = DSColors.statusColor(status);

    return Container(
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
                        statusColor,
                        statusColor.withValues(alpha: DSStyles.alphaMuted),
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
                                    barcode,
                                    style:
                                        DSTypography.title(
                                          color: isDark
                                              ? DSColors.white
                                              : DSColors.labelPrimary,
                                        ).copyWith(
                                          fontFamily: 'monospace',
                                          fontWeight: FontWeight.w800,
                                          fontSize: DSTypography.sizeMd,
                                          letterSpacing:
                                              DSTypography.lsExtraLoose,
                                        ),
                                  ),
                                  if (name.isNotEmpty) ...[
                                    DSSpacing.hXs,
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.person_outline_rounded,
                                          size: DSIconSize.xs,
                                          color: subtextColor,
                                        ),
                                        DSSpacing.wXs,
                                        Flexible(
                                          child: Text(
                                            name,
                                            style:
                                                DSTypography.body(
                                                  color: isDark
                                                      ? DSColors
                                                            .labelPrimaryDark
                                                      : DSColors.labelPrimary,
                                                ).copyWith(
                                                  fontSize: DSTypography.sizeSm,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            DSSpacing.wSm,
                            if (isAdded)
                              IconButton(
                                onPressed: onRemove,
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
                              )
                            else
                              IconButton(
                                onPressed: onAdd,
                                icon: const Icon(Icons.add_rounded),
                                color: DSColors.primary,
                                style: IconButton.styleFrom(
                                  backgroundColor: DSColors.primary.withValues(
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
                        if (address.isNotEmpty) ...[
                          DSSpacing.hSm,
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.location_on_outlined,
                                size: DSIconSize.xs,
                                color: subtextColor,
                              ),
                              DSSpacing.wXs,
                              Expanded(
                                child: Text(
                                  address,
                                  style: DSTypography.caption(
                                    color: subtextColor,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
