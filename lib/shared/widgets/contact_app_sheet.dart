// DOCS: docs/development-standards.md
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:fsi_courier_app/design_system/design_system.dart';
import 'package:fsi_courier_app/shared/helpers/snackbar_helper.dart';

/// Shows a bottom sheet with various communication apps (SMS, Call, Viber, WhatsApp, Telegram)
/// for a given phone number.
Future<void> showContactAppSheet(
  BuildContext context,
  String phone, {
  String? messageTemplate,
  String title = 'CONTACT RECIPIENT',
}) async {
  final cleaned = phone.trim();
  if (cleaned.isEmpty) return;
  final noPlus = cleaned.replaceAll('+', '');

  final encodedMsg = messageTemplate != null
      ? Uri.encodeComponent(messageTemplate)
      : null;

  final apps = <_CommApp>[
    _CommApp(
      label: 'SMS',
      icon: Icons.message_rounded,
      color: DSColors.socialSms,
      uri: encodedMsg != null
          ? Uri.parse('sms:$cleaned?body=$encodedMsg')
          : Uri(scheme: 'sms', path: cleaned),
    ),
    _CommApp(
      label: 'Call',
      icon: Icons.phone_rounded,
      color: DSColors.socialCall,
      uri: Uri(scheme: 'tel', path: cleaned),
    ),
    _CommApp(
      label: 'Viber',
      icon: Icons.chat_bubble_rounded,
      color: DSColors.socialViber,
      uri: Uri.parse(
        encodedMsg != null
            ? 'viber://chat?number=$noPlus&text=$encodedMsg'
            : 'viber://chat?number=$noPlus',
      ),
    ),
  ];

  final optionalCandidates = [
    _CommApp(
      label: 'WhatsApp',
      icon: Icons.chat_bubble_rounded,
      color: DSColors.socialWhatsApp,
      uri: Uri.parse(
        encodedMsg != null
            ? 'whatsapp://send?phone=$noPlus&text=$encodedMsg'
            : 'whatsapp://send?phone=$noPlus',
      ),
    ),
    _CommApp(
      label: 'Telegram',
      icon: Icons.near_me_rounded,
      color: DSColors.socialTelegram,
      uri: Uri.parse('tg://resolve?phone=$cleaned'),
    ),
  ];

  for (final app in optionalCandidates) {
    if (await canLaunchUrl(app.uri)) {
      apps.add(app);
    }
  }

  if (!context.mounted) return;

  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: DSColors.transparent,
    isScrollControlled: true,
    builder: (ctx) =>
        _ContactAppSheet(phone: cleaned, apps: apps, title: title),
  );
}

class _CommApp {
  const _CommApp({
    required this.label,
    required this.icon,
    required this.color,
    required this.uri,
  });
  final String label;
  final IconData icon;
  final Color color;
  final Uri uri;
}

class _ContactAppSheet extends StatelessWidget {
  const _ContactAppSheet({
    required this.phone,
    required this.apps,
    required this.title,
  });
  final String phone;
  final List<_CommApp> apps;
  final String title;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? DSColors.cardDark : DSColors.cardLight;

    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(DSSpacing.xl),
        ),
      ),
      padding: EdgeInsets.fromLTRB(
        DSSpacing.xl,
        DSSpacing.md,
        DSSpacing.xl,
        DSSpacing.xl + MediaQuery.of(context).padding.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: DSSpacing.xl,
              height: DSSpacing.xs,
              margin: EdgeInsets.only(bottom: DSSpacing.md),
              decoration: BoxDecoration(
                color: isDark
                    ? DSColors.separatorDark
                    : DSColors.separatorLight,
                borderRadius: BorderRadius.circular(DSStyles.radiusXS),
              ),
            ),
          ),
          Text(
            title,
            style: DSTypography.caption(color: DSColors.primary).copyWith(
              fontWeight: FontWeight.w900,
              fontSize: DSTypography.sizeSm,
            ),
          ),
          DSSpacing.hXs,
          GestureDetector(
            onTap: () async {
              final uri = Uri(scheme: 'tel', path: phone);
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri);
              }
            },
            onLongPress: () async {
              await Clipboard.setData(ClipboardData(text: phone));
              if (context.mounted) {
                showAppSnackbar(
                  context,
                  'Phone number copied to clipboard',
                  type: SnackbarType.success,
                );
              }
            },
            child: Text(
              phone,
              style: DSTypography.title(
                color: isDark
                    ? DSColors.labelPrimaryDark
                    : DSColors.labelPrimary,
                fontSize: DSTypography.sizeLg,
              ),
            ),
          ),
          DSSpacing.hXl,
          Wrap(
            spacing: DSSpacing.md,
            runSpacing: DSSpacing.md,
            children: apps.map((app) => _AppButton(app: app)).toList(),
          ),
        ],
      ),
    );
  }
}

class _AppButton extends StatelessWidget {
  const _AppButton({required this.app});
  final _CommApp app;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        Navigator.pop(context);
        launchUrl(app.uri, mode: LaunchMode.externalApplication);
      },
      borderRadius: DSStyles.cardRadius,
      child: Container(
        width:
            DSIconSize.heroMd, // Keeping fixed width for layout grid symmetry
        padding: EdgeInsets.symmetric(vertical: DSSpacing.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: EdgeInsets.all(DSSpacing.md),
              decoration: BoxDecoration(
                color: app.color.withValues(alpha: DSStyles.alphaSubtle),
                shape: BoxShape.circle,
              ),
              child: Icon(app.icon, color: app.color, size: DSIconSize.xl),
            ),
            DSSpacing.hSm,
            Text(
              app.label,
              style: DSTypography.button(
                color: Theme.of(context).textTheme.bodyMedium?.color,
              ).copyWith(fontSize: DSTypography.sizeMd),
            ),
          ],
        ),
      ),
    );
  }
}
