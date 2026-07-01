import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fsi_courier_app/shared/helpers/contact_launch_uri.dart';
import 'package:fsi_courier_app/shared/widgets/contact_app_sheet.dart'
    hide buildDeliveryContactMessage;

import '../../helpers/url_launcher_channel_mock.dart';

void main() {
  setUp(() => mockUrlLauncherChannel());
  tearDown(() => clearUrlLauncherChannelMock());

  Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

  group('showContactAppSheet', () {
    testWidgets('shows message preview when template is provided', (
      tester,
    ) async {
      final message = buildDeliveryContactMessage(
        recipientName: 'ROMEO CRIZALDO LANUZA',
        barcode: 'FSIEE586361',
      );

      await tester.pumpWidget(
        wrap(
          Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => showContactAppSheet(
                context,
                '+639609206186',
                messageTemplate: message,
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('Message Preview'), findsOneWidget);
      expect(find.text(message), findsOneWidget);
      expect(find.text('SMS'), findsOneWidget);
      expect(find.text('Call'), findsOneWidget);
      expect(find.text('Viber'), findsOneWidget);
      expect(find.text('WhatsApp'), findsOneWidget);
      expect(find.text('Telegram'), findsOneWidget);
    });

    testWidgets('hides message preview when template is omitted', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(
          Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => showContactAppSheet(context, '+639609206186'),
              child: const Text('Open'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('MESSAGE PREVIEW'), findsNothing);
      expect(find.text('+63 960 920 6186'), findsOneWidget);
    });

    testWidgets('shows spaced +63 international number for display', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(
          Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => showContactAppSheet(context, '+63 960 920 6186'),
              child: const Text('Open'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('+63 960 920 6186'), findsOneWidget);
    });

    testWidgets('does not open sheet for blank phone number', (tester) async {
      await tester.pumpWidget(
        wrap(
          Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => showContactAppSheet(
                context,
                '   ',
                messageTemplate: 'Hi test',
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('SMS'), findsNothing);
    });
  });
}
