// DOCS: docs/development-standards.md

import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform;

/// Picks the greeting name for a contact tap, falling back to [recipientName].
String resolveContactGreetingName({
  required String targetName,
  required String recipientName,
}) {
  final trimmedTarget = targetName.trim();
  if (trimmedTarget.isNotEmpty) return trimmedTarget;
  return recipientName.trim();
}

/// Pre-filled message when a courier contacts a delivery recipient.
String buildDeliveryContactMessage({
  required String recipientName,
  required String barcode,
}) {
  final name = recipientName.trim();
  final tracking = barcode.trim().isNotEmpty ? barcode.trim() : 'your delivery';
  final greeting = name.isNotEmpty ? 'Hi $name, ' : 'Hi, ';
  return '${greeting}FSI Courier here for $tracking. '
      'Please be ready or contact me to reschedule. Thank you.';
}

/// Encodes [text] for messaging-app deep-link query params.
///
/// [Uri.encodeQueryComponent] uses `+` for spaces (form-urlencoded). Viber,
/// WhatsApp, and some SMS handlers treat those as literal plus signs instead of
/// spaces, so this encoder substitutes `%20` for every `+`.
String encodeMessageForDeepLink(String text) {
  return Uri.encodeQueryComponent(text).replaceAll('+', '%20');
}

/// Strips non-digits from [phone] for SMS/chat deep links.
String phoneDigits(String phone) => phone.replaceAll(RegExp(r'\D'), '');

/// International digits (no `+`) for SMS/chat deep links.
///
/// Converts local Philippine `09XXXXXXXXX` numbers to `639XXXXXXXXX`.
String normalizePhoneForMessaging(String phone) {
  final digits = phoneDigits(phone);
  if (digits.isEmpty) return digits;
  if (digits.length == 11 && digits.startsWith('09')) {
    return '63${digits.substring(1)}';
  }
  return digits;
}

/// Local dial string for [tel:] URIs — strips `+`, spaces, and dashes.
///
/// Philippine `+63` / `639` numbers are shown as `09XXXXXXXXX`.
String normalizePhoneForTel(String phone) {
  final digits = phoneDigits(phone);
  if (digits.isEmpty) return digits;
  if (digits.length == 12 && digits.startsWith('639')) {
    return '0${digits.substring(2)}';
  }
  if (digits.length == 11 && digits.startsWith('09')) {
    return digits;
  }
  return digits;
}

/// User-facing phone label without `+` or grouping spaces.
String formatPhoneForDisplay(String phone) => normalizePhoneForTel(phone);

/// Builds an SMS deep link. Android uses [smsto] with digits-only phone so the
/// body is not truncated by '+' in the recipient number.
Uri buildSmsLaunchUri(String phone, {String? body, TargetPlatform? platform}) {
  final resolvedPlatform = platform ?? defaultTargetPlatform;
  final digits = normalizePhoneForMessaging(phone);
  if (body == null || body.isEmpty) {
    return Uri(scheme: 'sms', path: digits);
  }
  final encodedBody = encodeMessageForDeepLink(body);
  if (resolvedPlatform == TargetPlatform.android) {
    return Uri.parse('smsto:$digits?body=$encodedBody');
  }
  return Uri.parse('sms:$digits?body=$encodedBody');
}

Uri buildViberLaunchUri(String phone, {String? body}) {
  final digits = normalizePhoneForMessaging(phone);
  if (body == null || body.isEmpty) {
    return Uri.parse('viber://chat?number=$digits');
  }
  return Uri.parse(
    'viber://chat?number=$digits&text=${encodeMessageForDeepLink(body)}',
  );
}

Uri buildWhatsappLaunchUri(String phone, {String? body}) {
  final digits = normalizePhoneForMessaging(phone);
  if (body == null || body.isEmpty) {
    return Uri.parse('whatsapp://send?phone=$digits');
  }
  return Uri.parse(
    'whatsapp://send?phone=$digits&text=${encodeMessageForDeepLink(body)}',
  );
}

/// Builds a Telegram deep link using digits-only international format.
Uri buildTelegramLaunchUri(String phone) {
  final digits = normalizePhoneForMessaging(phone);
  return Uri.parse('tg://resolve?phone=$digits');
}
