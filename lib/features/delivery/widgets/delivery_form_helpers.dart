// DOCS: docs/development-standards.md
// DOCS: docs/features/delivery.md — update that file when you edit this one.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:fsi_courier_app/shared/helpers/date_format_helper.dart';
import 'package:fsi_courier_app/shared/helpers/delivery_helper.dart';
import 'package:fsi_courier_app/shared/widgets/delivery_other_info.dart';
import 'package:fsi_courier_app/shared/helpers/snackbar_helper.dart';
import 'package:fsi_courier_app/shared/helpers/contact_launch_uri.dart';
import 'package:fsi_courier_app/shared/helpers/string_helper.dart';
import 'package:fsi_courier_app/shared/widgets/contact_app_sheet.dart'
    hide buildDeliveryContactMessage;
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
      fontWeight: FontWeight.w900,
    ),
    hintStyle: DSTypography.body().copyWith(
      color: isDark ? DSColors.labelTertiaryDark : DSColors.labelTertiary,
      fontSize: DSTypography.sizeMd,
      fontWeight: FontWeight.w900,
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
  if (checkIsPrivacyLockedFromMap(delivery)) return;

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
  final contactNumbers = resolveDeliveryContactNumbers(delivery);
  final product = delivery['product']?.toString() ?? '';
  final mailType = delivery['mail_type']?.toString() ?? '';
  final specialInstruction = delivery['special_instruction']?.toString() ?? '';
  final transmittalDate = delivery['transmittal_date']?.toString() ?? '';
  final tat = delivery['tat']?.toString() ?? '';
  final sequenceNumber = delivery['sequence_number']?.toString() ?? '';

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
    final greetingName = resolveContactGreetingName(
      targetName: targetName,
      recipientName: name,
    );
    await showContactAppSheet(
      context,
      phone,
      messageTemplate: buildDeliveryContactMessage(
        recipientName: greetingName,
        barcode: barcode,
      ),
    );
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
                    ),

                    DSCard(
                      margin: EdgeInsets.only(top: DSSpacing.sm),
                      child: Column(
                        children: [
                          if (name.isNotEmpty)
                            DSInfoTile(
                              label: 'Recipient Name',
                              value: name,
                              onLongPress: () => copyToClipboard(name, 'Name'),
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
                          ..._buildContactPartyTiles(
                            label: 'Recipient Number',
                            numbers: contactNumbers.recipient,
                            greetingName: name,
                            hasFollowingParty:
                                contactNumbers.authRep.isNotEmpty,
                            onPhoneTap: onPhoneTap,
                            copyToClipboard: copyToClipboard,
                          ),
                          ..._buildContactPartyTiles(
                            label: 'Auth Rep Contact',
                            numbers: contactNumbers.authRep,
                            greetingName: effectiveAuthRepName.isNotEmpty
                                ? effectiveAuthRepName
                                : authRepName,
                            hasFollowingParty: false,
                            onPhoneTap: onPhoneTap,
                            copyToClipboard: copyToClipboard,
                          ),
                        ],
                      ),
                    ),

                    DeliveryOtherInfoSection(
                      product: product,
                      mailType: mailType,
                      sequenceNumber: sequenceNumber,
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

/// Builds [DSInfoTile] rows for one contact owner (recipient or auth rep).
List<Widget> _buildContactPartyTiles({
  required String label,
  required List<String> numbers,
  required String greetingName,
  required bool hasFollowingParty,
  required Future<void> Function(String phone, String targetName) onPhoneTap,
  required void Function(String text, String clipboardLabel) copyToClipboard,
}) {
  if (numbers.isEmpty) return const [];

  return [
    for (var i = 0; i < numbers.length; i++)
      DSInfoTile(
        label: i == 0 ? label : '',
        value: formatPhoneForDisplay(numbers[i]),
        // Tapping opens a sheet of contact options (SMS/Call/Viber/etc.), not a
        // direct call — use a "more options" icon so it does not read as a
        // one-tap dial.
        icon: Icons.more_horiz_rounded,
        onTap: () => onPhoneTap(numbers[i], greetingName),
        onLongPress: () => copyToClipboard(numbers[i], 'Contact number'),
        showDivider: i == numbers.length - 1 && hasFollowingParty,
        padding: i == 0
            ? null
            : EdgeInsets.only(
                top: 0,
                bottom: DSSpacing.md,
                left: DSSpacing.md,
                right: DSSpacing.md,
              ),
      ),
  ];
}
