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

/// Strips non-digits from [phone] for SMS/chat deep links.
String phoneDigits(String phone) => phone.replaceAll(RegExp(r'\D'), '');

/// Builds an SMS deep link. Android uses [smsto] with digits-only phone so the
/// body is not truncated by '+' in the recipient number.
Uri buildSmsLaunchUri(
  String phone, {
  String? body,
  TargetPlatform? platform,
}) {
  final resolvedPlatform = platform ?? defaultTargetPlatform;
  final digits = phoneDigits(phone);
  if (body == null || body.isEmpty) {
    return Uri(scheme: 'sms', path: digits);
  }
  final encodedBody = Uri.encodeQueryComponent(body);
  if (resolvedPlatform == TargetPlatform.android) {
    return Uri.parse('smsto:$digits?body=$encodedBody');
  }
  return Uri.parse('sms:$digits?body=$encodedBody');
}

Uri buildViberLaunchUri(String phone, {String? body}) {
  final digits = phoneDigits(phone);
  if (body == null || body.isEmpty) {
    return Uri.parse('viber://chat?number=$digits');
  }
  return Uri.parse(
    'viber://chat?number=$digits&text=${Uri.encodeQueryComponent(body)}',
  );
}

Uri buildWhatsappLaunchUri(String phone, {String? body}) {
  final digits = phoneDigits(phone);
  if (body == null || body.isEmpty) {
    return Uri.parse('whatsapp://send?phone=$digits');
  }
  return Uri.parse(
    'whatsapp://send?phone=$digits&text=${Uri.encodeQueryComponent(body)}',
  );
}