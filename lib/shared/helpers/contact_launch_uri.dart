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

/// User-facing international phone label, e.g. `+63 920 801 9846`.
///
/// Shows the E.164 number ([normalizePhoneForSms]) so riders can see the exact
/// international number that will be dialled/texted. PH mobiles are grouped as
/// `+63 9XX XXX XXXX` for readability; other formats are shown as-is.
String formatPhoneForDisplay(String phone) {
  final e164 = normalizePhoneForSms(phone);
  if (e164.startsWith('+63') && e164.length == 13) {
    final national = e164.substring(3); // 9XXXXXXXXX
    return '+63 ${national.substring(0, 3)} '
        '${national.substring(3, 6)} ${national.substring(6)}';
  }
  return e164;
}

/// E.164 recipient for SMS deep links.
///
/// Philippine numbers are normalized to `+639XXXXXXXXX` (the international
/// standard). Numbers that already carry an explicit country code (leading
/// `+`) are respected as-is — we only rewrite numbers that are clearly local
/// PH format. A bare, non-PH number is returned digits-only, unchanged.
String normalizePhoneForSms(String phone) {
  final hasPlus = phone.trim().startsWith('+');
  if (hasPlus) {
    final digits = phoneDigits(phone);
    return '+$digits';
  }

  // Try to parse as PH mobile first to standardize different formats
  final localPh = _toPhLocalMobile(phone);
  if (localPh != null) {
    return '+63${localPh.substring(1)}';
  }

  // Unknown / other-country format: respect what the API gave us.
  final digits = phoneDigits(phone);
  return digits;
}

/// True when [nsn] is a PH mobile *national significant number*: `9XXXXXXXXX`
/// (10 digits, no country code, no trunk `0`).
bool _isPhMobileNsn(String nsn) => nsn.length == 10 && nsn.startsWith('9');

/// Reduces [phone] to a PH mobile in local `09XXXXXXXXX` form, or `null` if it
/// is not a recognizable PH mobile number.
///
/// Accepts the many shapes real imports/APIs produce and treats them all the
/// same — `+63 917 123 4567`, `0063-917-123-4567`, `639171234567`,
/// `(0917) 123 4567`, `9171234567` → `09171234567`.
String? _toPhLocalMobile(String phone) {
  var digits = phoneDigits(phone);
  if (digits.isEmpty) return null;

  // Collapse an international access prefix ('00' IDD) to bare country digits;
  // an explicit '+' is already stripped by [phoneDigits].
  if (digits.startsWith('00')) digits = digits.substring(2);

  // Strip the PH country code (63) when it wraps a valid mobile number, whether
  // the national part is `9XXXXXXXXX` or a redundant local `09XXXXXXXXX`.
  if (digits.startsWith('63')) {
    final nsn = digits.substring(2);
    if (_isPhMobileNsn(nsn)) return '0$nsn';
    if (nsn.length == 11 && nsn.startsWith('09')) return nsn;
  }

  // National forms.
  if (digits.length == 11 && digits.startsWith('09')) return digits;
  if (_isPhMobileNsn(digits)) return '0$digits';

  return null;
}

/// Recipient for SMS deep links.
///
/// Returns E.164 format (`+639XXXXXXXXX`) for PH numbers to ensure compatibility
/// with courier SMS routing/carriers that require international prefixes.
String normalizePhoneForSmsSend(String phone) {
  return normalizePhoneForSms(phone);
}

/// Builds an SMS deep link. Android uses [smsto], iOS uses [sms].
///
/// The recipient uses [normalizePhoneForSmsSend]: local `09XXXXXXXXX` for PH
/// numbers (a leading `+` in `smsto:`/`sms:` is unreliable on Android SMS apps),
/// falling back to E.164 for non-PH numbers. Note this differs from Viber, which
/// *requires* the `+` — each channel needs its own format.
Uri buildSmsLaunchUri(String phone, {String? body, TargetPlatform? platform}) {
  final resolvedPlatform = platform ?? defaultTargetPlatform;
  final recipient = normalizePhoneForSmsSend(phone);
  if (body == null || body.isEmpty) {
    return Uri(scheme: 'sms', path: recipient);
  }
  final encodedBody = encodeMessageForDeepLink(body);
  if (resolvedPlatform == TargetPlatform.android) {
    return Uri.parse('smsto:$recipient?body=$encodedBody');
  }
  return Uri.parse('sms:$recipient?body=$encodedBody');
}

/// Builds a Viber deep link. Viber's documented format **requires** the country
/// code with a leading `+` (E.164) — a bare `639…` number does not open the
/// chat. See https://developers.viber.com/docs/tools/deep-links/.
///
/// **Note:** Viber's mobile app only supports pre-filling the text composer
/// for official Chatbots (`viber://pa?chatURI=...&text=...`) or Viber Business Accounts
/// (`https://viber.me/...?draft=...`). For personal 1-on-1 chats opened via
/// `viber://chat?number=`, the Viber app ignores any `text` or `draft` query parameters
/// and opens the composer empty.
Uri buildViberLaunchUri(String phone, {String? body}) {
  final e164 = normalizePhoneForSms(phone); // +639XXXXXXXXX
  if (body == null || body.isEmpty) {
    return Uri.parse('viber://chat?number=$e164');
  }
  return Uri.parse(
    'viber://chat?number=$e164&text=${encodeMessageForDeepLink(body)}',
  );
}

/// Builds a WhatsApp deep link via the official `wa.me` URL. WhatsApp requires
/// the number in international format with **no** `+`, spaces, or leading zeros;
/// including a `+` triggers an "invalid number" error. `wa.me` also gracefully
/// falls back to the browser when WhatsApp is not installed.
Uri buildWhatsappLaunchUri(String phone, {String? body}) {
  final digits = normalizePhoneForMessaging(phone); // 639XXXXXXXXX (no '+')
  if (body == null || body.isEmpty) {
    return Uri.parse('https://wa.me/$digits');
  }
  return Uri.parse(
    'https://wa.me/$digits?text=${encodeMessageForDeepLink(body)}',
  );
}

/// Builds a Telegram deep link. `tg://resolve?phone=` needs digits only, with
/// **no** `+`. Telegram cannot pre-fill a message to a phone number.
Uri buildTelegramLaunchUri(String phone) {
  final digits = normalizePhoneForMessaging(phone);
  return Uri.parse('tg://resolve?phone=$digits');
}
