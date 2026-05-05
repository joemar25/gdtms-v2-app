// DOCS: docs/development-standards.md
// DOCS: docs/features/delivery.md — update that file when you edit this one.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:fsi_courier_app/shared/helpers/date_format_helper.dart';
import 'package:fsi_courier_app/shared/widgets/delivery_other_info.dart';
import 'package:fsi_courier_app/shared/helpers/snackbar_helper.dart';
import 'package:fsi_courier_app/shared/helpers/string_helper.dart';
import 'package:fsi_courier_app/shared/widgets/contact_app_sheet.dart';
import 'package:fsi_courier_app/design_system/design_system.dart';

// ─── Theme-aware field decoration ───────────────────────────────────────────
InputDecoration deliveryFieldDecoration(
  BuildContext context, {
  String? labelText,
  String? hintText,
  String? errorText,
}) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final fill = isDark
      ? DSColors.secondarySurfaceDark
      : DSColors.secondarySurfaceLight;
  final borderColor = isDark ? DSColors.separatorDark : DSColors.separatorLight;

  return InputDecoration(
    labelText: labelText,
    hintText: hintText,
    errorText: errorText,
    filled: true,
    fillColor: fill,
    contentPadding: EdgeInsets.symmetric(
      horizontal: DSSpacing.md,
      vertical: DSSpacing.md,
    ),
    labelStyle: DSTypography.body().copyWith(
      color: isDark ? DSColors.labelSecondaryDark : DSColors.labelSecondary,
      fontSize: DSTypography.sizeMd,
      fontWeight: FontWeight.w500,
    ),
    hintStyle: DSTypography.body().copyWith(
      color: isDark ? DSColors.labelTertiaryDark : DSColors.labelTertiary,
      fontSize: DSTypography.sizeMd,
    ),
    errorStyle: DSTypography.caption().copyWith(
      color: DSColors.error,
      fontSize: DSTypography.sizeSm,
      fontWeight: FontWeight.w500,
    ),
    border: OutlineInputBorder(
      borderRadius: DSStyles.cardRadius,
      borderSide: BorderSide(color: borderColor),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: DSStyles.cardRadius,
      borderSide: BorderSide(color: borderColor),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: DSStyles.cardRadius,
      borderSide: const BorderSide(
        color: DSColors.primary,
        width: DSStyles.borderWidth * 1.5,
      ),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: DSStyles.cardRadius,
      borderSide: const BorderSide(
        color: DSColors.error,
        width: DSStyles.borderWidth,
      ),
    ),
  );
}

// ─── Section header ──────────────────────────────────────────────────────────
class DeliverySectionHeader extends StatelessWidget {
  const DeliverySectionHeader({super.key, required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      children: [
        Container(
          width: DSSpacing.xs,
          height: DSIconSize.sm,
          decoration: BoxDecoration(
            color: DSColors.primary,
            borderRadius: BorderRadius.circular(DSStyles.radiusSM),
          ),
        ),
        DSSpacing.wSm,
        Expanded(
          child: Text(
            label.toUpperCase(),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
            style: DSTypography.label().copyWith(
              fontSize: DSTypography.sizeSm,
              fontWeight: FontWeight.w900,
              letterSpacing: DSTypography.lsExtraLoose,
              color: isDark
                  ? DSColors.labelTertiaryDark
                  : DSColors.labelSecondary,
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Photo source button ──────────────────────────────────────────────────────
class DeliveryPhotoSourceButton extends StatelessWidget {
  const DeliveryPhotoSourceButton({
    super.key,
    required this.icon,
    required this.label,
    required this.color,
    required this.enabled,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final bool enabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 14, horizontal: DSSpacing.md),
        decoration: BoxDecoration(
          color: enabled
              ? color.withValues(alpha: DSStyles.alphaSubtle)
              : (isDark
                    ? DSColors.white.withValues(alpha: DSStyles.alphaSoft)
                    : DSColors.secondarySurfaceLight),
          borderRadius: DSStyles.cardRadius,
          border: Border.all(
            color: enabled
                ? color.withValues(alpha: DSStyles.alphaMuted)
                : (isDark ? DSColors.separatorDark : DSColors.separatorLight),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: enabled
                  ? color
                  : (isDark ? DSColors.white : DSColors.labelTertiary),
              size: DSIconSize.lg,
            ),
            DSSpacing.hSm,
            Text(
              label,
              style: DSTypography.label().copyWith(
                fontSize: DSTypography.sizeSm,
                fontWeight: FontWeight.w800,
                color: enabled
                    ? color
                    : (isDark
                          ? DSColors.labelTertiaryDark
                          : DSColors.labelTertiary),
                letterSpacing: DSTypography.lsExtraLoose,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Shared account details sheet ───────────────────────────────────────────
// ─── Shared account details sheet trigger ────────────────────────────────────
/// Shows the "Account Details" bottom sheet for [delivery].
/// Used by DeliveryUpdateScreen (info button) and DeliveryCard (hold action).
Future<void> showDeliveryAccountDetails(
  BuildContext context,
  Map<String, dynamic> delivery,
  String barcode,
) async {
  final isDark = Theme.of(context).brightness == Brightness.dark;

  final name =
      delivery['recipient_name']?.toString() ??
      delivery['name']?.toString() ??
      '';
  final authRepName =
      (delivery['authorized_rep']?.toString() ??
              delivery['recipient']?.toString() ??
              '')
          .trim();
  // Ensure authRepName is not just the same as name
  final effectiveAuthRepName =
      (authRepName.isNotEmpty &&
          authRepName.toLowerCase() != name.toLowerCase())
      ? authRepName
      : '';
  final address =
      delivery['recipient_address']?.toString() ??
      delivery['delivery_address']?.toString() ??
      delivery['address']?.toString() ??
      '';
  final contact =
      delivery['recipient_phone']?.toString() ??
      delivery['contact']?.toString() ??
      '';
  final authRepNumber =
      delivery['contact_rep']?.toString() ??
      delivery['auth_rep_number']?.toString() ??
      '';
  final product = delivery['product']?.toString() ?? '';
  final specialInstruction = delivery['special_instruction']?.toString() ?? '';
  final transmittalDate = delivery['transmittal_date']?.toString() ?? '';
  final tat = delivery['tat']?.toString() ?? '';

  final hasShownAuthRepInContact = contact.split('/').any((n) {
    final cn = n.trim();
    return authRepNumber.isNotEmpty && cn.contains(authRepNumber);
  });

  void copyToClipboard(String text, String label) {
    if (text.isEmpty) return;
    Clipboard.setData(ClipboardData(text: text));
    HapticFeedback.mediumImpact();
    if (context.mounted) {
      showSuccessNotification(context, 'Copied $label to clipboard');
    }
  }

  Future<void> launchMaps(String addr) async {
    if (addr.trim().isEmpty) return;
    final url =
        'https://www.google.com/maps/dir/?api=1&destination=${Uri.encodeComponent(addr.trim())}';
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }

  Future<void> onPhoneTap(String phone, String targetName) async {
    final template =
        'Hi $targetName! '
        "I'm your FSI courier "
        '${barcode.isNotEmpty ? 'with tracking number $barcode' : 'with your delivery'}. '
        'Please be ready or contact me for re-scheduling. Thank you!';
    await showContactAppSheet(context, phone, messageTemplate: template);
  }

  if (!context.mounted) return;

  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: DSColors.transparent,
    builder: (ctx) {
      return SecureView(
        child: DraggableScrollableSheet(
          initialChildSize: 0.55,
          minChildSize: 0.35,
          maxChildSize: 0.92,
          expand: false,
          builder: (_, scrollController) {
            return Container(
              decoration: BoxDecoration(
                color: isDark ? DSColors.cardDark : DSColors.cardLight,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(28),
                ),
                boxShadow: [
                  BoxShadow(
                    color: DSColors.black.withValues(
                      alpha: isDark ? 0.4 : 0.1,
                    ),
                    blurRadius: DSStyles.radiusXL,
                    offset: const Offset(0, -5),
                  ),
                ],
              ),
              padding: EdgeInsets.fromLTRB(
                DSSpacing.lg,
                DSSpacing.sm,
                DSSpacing.lg,
                DSSpacing.xl,
              ),
              child: SingleChildScrollView(
                controller: scrollController,
                physics: const BouncingScrollPhysics(),
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
                      title: 'Account Details',
                      padding: EdgeInsets.zero,
                      trailing: const SecureBadge(),
                    ),

                    DSCard(
                      margin: EdgeInsets.only(top: DSSpacing.sm),
                      child: Column(
                        children: [
                          if (name.isNotEmpty)
                            DSInfoTile(
                              label: 'Recipient Name',
                              value: name,
                              onLongPress: () =>
                                  copyToClipboard(name, 'Name'),
                            ),
                          if (effectiveAuthRepName.isNotEmpty)
                            DSInfoTile(
                              label: 'Auth Rep Name',
                              value: effectiveAuthRepName,
                              onLongPress: () => copyToClipboard(
                                effectiveAuthRepName,
                                'Auth rep name',
                              ),
                            ),
                          if (address.isNotEmpty)
                            DSInfoTile(
                              label: 'Delivery Address',
                              value: address,
                              onTap: () => launchMaps(address),
                              onLongPress: () =>
                                  copyToClipboard(address, 'Address'),
                            ),
                          if (contact.isNotEmpty)
                            ...contact.split('/').asMap().entries.map((entry) {
                              final idx = entry.key;
                              final cleanContact = entry.value.trim();
                              if (cleanContact.isEmpty) {
                                return const SizedBox.shrink();
                              }
                              final isAuthRepNum =
                                  authRepNumber.isNotEmpty &&
                                  cleanContact.contains(authRepNumber);
                              final nextEntry =
                                  contact.split('/').length > idx + 1
                                      ? contact.split('/')[idx + 1].trim()
                                      : null;
                              final nextIsAuthRep =
                                  nextEntry != null &&
                                  authRepNumber.isNotEmpty &&
                                  nextEntry.contains(authRepNumber);

                              final hasExtraTile =
                                  authRepNumber.isNotEmpty &&
                                  !contact.contains(authRepNumber);

                              final showDivider =
                                  (nextEntry != null &&
                                      isAuthRepNum != nextIsAuthRep) ||
                                  (nextEntry == null &&
                                      hasExtraTile &&
                                      !isAuthRepNum);

                              final previousEntry = idx > 0
                                  ? contact.split('/')[idx - 1].trim()
                                  : null;
                              final previousIsAuthRep =
                                  previousEntry != null &&
                                  authRepNumber.isNotEmpty &&
                                  previousEntry.contains(authRepNumber);

                              final isFirstOfParty =
                                  idx == 0 ||
                                  (isAuthRepNum != previousIsAuthRep);

                              return DSInfoTile(
                                label: isFirstOfParty
                                    ? (isAuthRepNum
                                          ? 'Auth Rep Contact'
                                          : 'Recipient Number')
                                    : '',
                                value: cleanContact,
                                onTap: () => onPhoneTap(
                                  cleanContact,
                                  isAuthRepNum
                                      ? effectiveAuthRepName
                                      : name,
                                ),
                                onLongPress: () => copyToClipboard(
                                  cleanContact,
                                  'Contact number',
                                ),
                                showDivider: showDivider,
                                padding: isFirstOfParty
                                    ? null
                                    : EdgeInsets.only(
                                        top: 0,
                                        bottom: DSSpacing.md,
                                        left: DSSpacing.md,
                                        right: DSSpacing.md,
                                      ),
                              );
                            }),
                          if (authRepNumber.isNotEmpty &&
                              !contact.contains(authRepNumber))
                            DSInfoTile(
                              label: hasShownAuthRepInContact
                                  ? ''
                                  : 'Auth Rep Contact',
                              value: authRepNumber,
                              onTap: () => onPhoneTap(
                                authRepNumber,
                                effectiveAuthRepName,
                              ),
                              onLongPress: () => copyToClipboard(
                                authRepNumber,
                                'Auth rep number',
                              ),
                              showDivider: false,
                              padding: hasShownAuthRepInContact
                                  ? EdgeInsets.only(
                                      top: 0,
                                      bottom: DSSpacing.md,
                                      left: DSSpacing.md,
                                      right: DSSpacing.md,
                                    )
                                  : null,
                            ),
                        ],
                      ),
                    ),

                    DeliveryOtherInfoSection(
                      product: product,
                      specialInstruction: specialInstruction.isNotEmpty
                          ? specialInstruction
                          : null,
                      transmittalDate: transmittalDate.isNotEmpty
                          ? formatDate(transmittalDate)
                          : null,
                      tat: tat.isNotEmpty ? formatDate(tat) : null,
                      isDark: isDark,
                    ),
                    DSSpacing.hLg,
                  ],
                ),
              ),
            );
          },
        ),
      );
    },
  );
}
