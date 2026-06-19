import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fsi_courier_app/shared/helpers/contact_launch_uri.dart';

void main() {
  group('resolveContactGreetingName', () {
    test('uses target name when provided', () {
      expect(
        resolveContactGreetingName(
          targetName: 'MA ELIZA CRIZALDO LANUZA',
          recipientName: 'ROMEO CRIZALDO LANUZA',
        ),
        'MA ELIZA CRIZALDO LANUZA',
      );
    });

    test('falls back to recipient name when target is blank', () {
      expect(
        resolveContactGreetingName(
          targetName: '   ',
          recipientName: 'ROMEO CRIZALDO LANUZA',
        ),
        'ROMEO CRIZALDO LANUZA',
      );
    });
  });

  group('buildDeliveryContactMessage', () {
    test('includes recipient name and barcode', () {
      final message = buildDeliveryContactMessage(
        recipientName: 'ROMEO CRIZALDO LANUZA',
        barcode: 'FSIEE586361',
      );

      expect(message, contains('Hi ROMEO CRIZALDO LANUZA,'));
      expect(message, contains('FSI Courier here for FSIEE586361'));
      expect(message, contains('Please be ready or contact me to reschedule'));
    });

    test('trims recipient name whitespace', () {
      final message = buildDeliveryContactMessage(
        recipientName: '  JUAN DELA CRUZ  ',
        barcode: 'FSIEE123456',
      );

      expect(message, startsWith('Hi JUAN DELA CRUZ,'));
    });

    test('uses generic greeting when recipient name is empty', () {
      final message = buildDeliveryContactMessage(
        recipientName: '',
        barcode: 'FSIEE586361',
      );

      expect(message, startsWith('Hi, FSI Courier here for FSIEE586361'));
      expect(message, isNot(contains('Hi ,')));
    });

    test('falls back to your delivery when barcode is empty', () {
      final message = buildDeliveryContactMessage(
        recipientName: 'MARIA SANTOS',
        barcode: '',
      );

      expect(message, contains('FSI Courier here for your delivery'));
    });

    test('avoids apostrophes and exclamation marks in body', () {
      final message = buildDeliveryContactMessage(
        recipientName: 'ROMEO CRIZALDO LANUZA',
        barcode: 'FSIEE586361',
      );

      expect(message, isNot(contains("'")));
      expect(message, isNot(contains('!')));
    });
  });

  group('phoneDigits', () {
    test('strips plus sign and separators', () {
      expect(phoneDigits('+63 960-920-6186'), '639609206186');
      expect(phoneDigits('09208019846'), '09208019846');
    });
  });

  group('buildSmsLaunchUri', () {
    const body =
        'Hi ROMEO CRIZALDO LANUZA, FSI Courier here for FSIEE586361. '
        'Please be ready or contact me to reschedule. Thank you.';

    test('android uses smsto scheme with digits-only phone', () {
      final uri = buildSmsLaunchUri(
        '+639609206186',
        body: body,
        platform: TargetPlatform.android,
      );

      expect(uri.scheme, 'smsto');
      expect(uri.path, '639609206186');
      expect(uri.queryParameters['body'], body);
      expect(uri.toString(), isNot(contains("'")));
      expect(uri.toString(), startsWith('smsto:639609206186?body='));
    });

    test('ios uses sms scheme with encoded body', () {
      final uri = buildSmsLaunchUri(
        '+639609206186',
        body: body,
        platform: TargetPlatform.iOS,
      );

      expect(uri.scheme, 'sms');
      expect(uri.toString(), startsWith('sms:639609206186?body='));
      expect(uri.queryParameters['body'], body);
    });

    test('omits body query when message is empty', () {
      final uri = buildSmsLaunchUri(
        '+639609206186',
        platform: TargetPlatform.android,
      );

      expect(uri.scheme, 'sms');
      expect(uri.path, '639609206186');
      expect(uri.queryParameters, isEmpty);
    });

    test('encodes special characters in body', () {
      const trickyBody = "Hi O'Brien, test message & more";
      final uri = buildSmsLaunchUri(
        '+639609206186',
        body: trickyBody,
        platform: TargetPlatform.android,
      );

      expect(uri.toString(), isNot(contains("O'Brien")));
      expect(uri.queryParameters['body'], trickyBody);
    });
  });

  group('buildViberLaunchUri', () {
    test('includes encoded text when body is provided', () {
      const body = 'Hi MARIA, FSI Courier here for FSIEE586361.';
      final uri = buildViberLaunchUri('+639355349832', body: body);

      expect(uri.toString(), startsWith('viber://chat?number=639355349832&text='));
      expect(uri.queryParameters['text'], body);
    });
  });

  group('buildWhatsappLaunchUri', () {
    test('includes encoded text when body is provided', () {
      const body = 'Hi MARIA, FSI Courier here for FSIEE586361.';
      final uri = buildWhatsappLaunchUri('+639355349832', body: body);

      expect(
        uri.toString(),
        startsWith('whatsapp://send?phone=639355349832&text='),
      );
      expect(uri.queryParameters['text'], body);
    });
  });
}