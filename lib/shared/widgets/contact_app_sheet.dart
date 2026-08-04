// DOCS: docs/development-standards.md
export 'package:fsi_courier_app/shared/helpers/contact_launch_uri.dart'
    show buildDeliveryContactMessage;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:fsi_courier_app/design_system/design_system.dart';
import 'package:fsi_courier_app/shared/helpers/contact_launch_uri.dart';
import 'package:fsi_courier_app/shared/helpers/snackbar_helper.dart';

/// Shows a bottom sheet with various communication apps (SMS, Call, Viber, WhatsApp, Telegram)
/// for a given phone number.
Future<void> showContactAppSheet(
  BuildContext context,
  String phone, {
  String? messageTemplate,
  String Function(String schedule)? messageBuilder,
  List<String>? scheduleOptions,
  String title = 'CONTACT RECIPIENT',
}) async {
  final cleaned = phone.trim();
  if (phoneDigits(cleaned).isEmpty) return;

  final displayPhone = formatPhoneForDisplay(cleaned);
  final telPhone = normalizePhoneForTel(cleaned);

  if (!context.mounted) return;

  final selectedApp = await showModalBottomSheet<_CommApp>(
    context: context,
    backgroundColor: DSColors.transparent,
    isScrollControlled: true,
    builder: (ctx) => _ContactAppSheet(
      phone: displayPhone,
      telPhone: telPhone,
      cleanedPhone: cleaned,
      title: title,
      initialMessageTemplate: messageTemplate,
      messageBuilder: messageBuilder,
      scheduleOptions: scheduleOptions,
    ),
  );

  if (selectedApp != null && context.mounted) {
    // We launch after the bottom sheet has fully closed. This prevents the
    // "stuck pointer events" bug where the app goes to background mid-animation.
    final launched = await launchUrl(
      selectedApp.uri,
      mode: LaunchMode.externalApplication,
    );
    if (!launched && context.mounted) {
      showErrorNotification(
        context,
        '${selectedApp.label} is not installed or could not be opened.',
      );
    }
  }
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

class _ContactAppSheet extends StatefulWidget {
  const _ContactAppSheet({
    required this.phone,
    required this.telPhone,
    required this.cleanedPhone,
    required this.title,
    this.initialMessageTemplate,
    this.messageBuilder,
    this.scheduleOptions,
  });
  final String phone;
  final String telPhone;
  final String cleanedPhone;
  final String title;
  final String? initialMessageTemplate;
  final String Function(String)? messageBuilder;
  final List<String>? scheduleOptions;

  @override
  State<_ContactAppSheet> createState() => _ContactAppSheetState();
}

class _ContactAppSheetState extends State<_ContactAppSheet> {
  late String _selectedSchedule;
  late String? _currentMessage;

  @override
  void initState() {
    super.initState();
    _selectedSchedule = widget.scheduleOptions?.first ?? 'TOMORROW';
    _currentMessage = widget.messageBuilder != null
        ? widget.messageBuilder!(_selectedSchedule)
        : widget.initialMessageTemplate;
  }

  void _onScheduleChanged(String newSchedule) {
    setState(() {
      _selectedSchedule = newSchedule;
      if (widget.messageBuilder != null) {
        _currentMessage = widget.messageBuilder!(_selectedSchedule);
      }
    });
  }

  List<_CommApp> _buildApps() {
    return [
      _CommApp(
        label: 'SMS',
        icon: Icons.message_rounded,
        color: DSColors.socialSms,
        uri: buildSmsLaunchUri(widget.cleanedPhone, body: _currentMessage),
      ),
      _CommApp(
        label: 'Call',
        icon: Icons.phone_rounded,
        color: DSColors.socialCall,
        uri: Uri(scheme: 'tel', path: widget.telPhone),
      ),
      _CommApp(
        label: 'Viber',
        icon: Icons.chat_bubble_rounded,
        color: DSColors.socialViber,
        uri: buildViberLaunchUri(widget.cleanedPhone, body: _currentMessage),
      ),
      _CommApp(
        label: 'WhatsApp',
        icon: Icons.chat_bubble_rounded,
        color: DSColors.socialWhatsApp,
        uri: buildWhatsappLaunchUri(widget.cleanedPhone, body: _currentMessage),
      ),
      _CommApp(
        label: 'Telegram',
        icon: Icons.near_me_rounded,
        color: DSColors.socialTelegram,
        uri: buildTelegramLaunchUri(widget.cleanedPhone),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? DSColors.cardDark : DSColors.cardLight;
    final title = widget.title;
    final phone = widget.phone;
    final telPhone = widget.telPhone;
    final messageTemplate = _currentMessage;
    final apps = _buildApps();

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
              final uri = Uri(scheme: 'tel', path: telPhone);
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri);
              }
            },
            onLongPress: () async {
              await Clipboard.setData(ClipboardData(text: phone));
              if (context.mounted) {
                showSuccessNotification(
                  context,
                  'Phone number copied to clipboard',
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
          if (widget.scheduleOptions != null &&
              widget.scheduleOptions!.isNotEmpty) ...[
            DSSpacing.hMd,
            Text(
              'Delivery Schedule',
              style:
                  DSTypography.caption(
                    color: isDark
                        ? DSColors.labelTertiaryDark
                        : DSColors.labelTertiary,
                  ).copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: DSTypography.sizeSm,
                    letterSpacing: 0.5,
                  ),
            ),
            DSSpacing.hXs,
            Wrap(
              spacing: DSSpacing.sm,
              runSpacing: DSSpacing.sm,
              children: widget.scheduleOptions!.map((opt) {
                final isSelected = opt == _selectedSchedule;
                return ChoiceChip(
                  label: Text(opt),
                  selected: isSelected,
                  onSelected: (_) => _onScheduleChanged(opt),
                  selectedColor: Theme.of(context).primaryColor,
                  labelStyle: TextStyle(
                    color: isSelected ? DSColors.white : null,
                  ),
                );
              }).toList(),
            ),
          ],
          if (messageTemplate != null && messageTemplate.isNotEmpty) ...[
            DSSpacing.hMd,
            Text(
              'Message Preview',
              style:
                  DSTypography.caption(
                    color: isDark
                        ? DSColors.labelTertiaryDark
                        : DSColors.labelTertiary,
                  ).copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: DSTypography.sizeSm,
                    letterSpacing: 0.5,
                  ),
            ),
            Text(
              'Long press the message to copy.',
              style: DSTypography.caption(
                color: isDark
                    ? DSColors.labelTertiaryDark
                    : DSColors.labelTertiary,
              ).copyWith(fontSize: DSTypography.sizeXs),
            ),
            DSSpacing.hXs,
            GestureDetector(
              onLongPress: () async {
                await Clipboard.setData(ClipboardData(text: messageTemplate));
                if (context.mounted) {
                  showSuccessNotification(
                    context,
                    'Message copied to clipboard',
                  );
                }
              },
              child: Text(
                messageTemplate,
                style: DSTypography.body(
                  color: isDark
                      ? DSColors.labelSecondaryDark
                      : DSColors.labelSecondary,
                ).copyWith(fontSize: DSTypography.sizeMd),
              ),
            ),
          ],
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
      onTap: () => Navigator.pop(context, app),
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
