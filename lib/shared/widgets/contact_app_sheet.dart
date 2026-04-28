import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:fsi_courier_app/design_system/design_system.dart';

/// Shows a bottom sheet with various communication apps (SMS, Call, Viber, WhatsApp, Telegram)
/// for a given phone number.
Future<void> showContactAppSheet(
  BuildContext context,
  String phone, {
  String? messageTemplate,
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
      color: const Color(0xFF34C759),
      uri: encodedMsg != null
          ? Uri.parse('sms:$cleaned?body=$encodedMsg')
          : Uri(scheme: 'sms', path: cleaned),
    ),
    _CommApp(
      label: 'Call',
      icon: Icons.phone_rounded,
      color: const Color(0xFF007AFF),
      uri: Uri(scheme: 'tel', path: cleaned),
    ),
    _CommApp(
      label: 'Viber',
      icon: Icons.chat_bubble_rounded,
      color: const Color(0xFF7360F2),
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
      color: const Color(0xFF25D366),
      uri: Uri.parse(
        encodedMsg != null
            ? 'whatsapp://send?phone=$noPlus&text=$encodedMsg'
            : 'whatsapp://send?phone=$noPlus',
      ),
    ),
    _CommApp(
      label: 'Telegram',
      icon: Icons.near_me_rounded,
      color: const Color(0xFF229ED9),
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
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (ctx) => _ContactAppSheet(phone: cleaned, apps: apps),
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
  const _ContactAppSheet({required this.phone, required this.apps});
  final String phone;
  final List<_CommApp> apps;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? DSColors.cardDark : DSColors.cardLight;

    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(
        24,
        12,
        24,
        24 + MediaQuery.of(context).padding.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: isDark
                    ? DSColors.separatorDark
                    : DSColors.separatorLight,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Text(
            'CONTACT RECIPIENT',
            style: DSTypography.caption(color: DSColors.primary).copyWith(
              fontWeight: FontWeight.w900,
              fontSize: DSTypography.sizeSm,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            phone,
            style: DSTypography.title(
              color: isDark ? DSColors.labelPrimaryDark : DSColors.labelPrimary,
              fontSize: DSTypography.sizeLg,
            ),
          ),
          const SizedBox(height: 24),
          Wrap(
            spacing: 16,
            runSpacing: 16,
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
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 80,
        padding: const EdgeInsets.symmetric(vertical: DSSpacing.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(DSSpacing.md),
              decoration: BoxDecoration(
                color: app.color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(app.icon, color: app.color, size: 28),
            ),
            const SizedBox(height: 8),
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
