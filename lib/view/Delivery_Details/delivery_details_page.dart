import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:fsi_courier_app/core/config.dart';
import 'package:fsi_courier_app/view/Delivered_failed_page/delivered_failed.dart';
import 'package:fsi_courier_app/view/Delivered_page/delivered_page.dart';
import 'package:fsi_courier_app/view/Delivered_rts_page/delivered_rts.dart';
import '../Dashboard/model/delivery_model.dart';
import 'components/delivery_info_card.dart';
import 'components/rep_card.dart';
import 'package:http/http.dart' as http;
import 'components/section_title.dart';
import 'components/action_button.dart';

class DeliveryDetailsPage extends StatefulWidget {
  final Delivery delivery;

  const DeliveryDetailsPage({super.key, required this.delivery});

  @override
  State<DeliveryDetailsPage> createState() => _DeliveryDetailsPageState();
}

class _DeliveryDetailsPageState extends State<DeliveryDetailsPage> {
  late Delivery delivery;

  @override
  void initState() {
    super.initState();
    delivery = widget.delivery;
  }

  Future<void> _reloadDelivery() async {
    await Future.delayed(const Duration(milliseconds: 400));

    try {
      final response = await http.get(
        Uri.parse('$apiBaseUrl/deliveries'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final List data = json.decode(response.body);

        final List<Delivery> deliveries = data
            .map((e) => Delivery.fromJson(e))
            .toList();

        final updated = deliveries.firstWhere(
          (d) => d.barcodeValue == delivery.barcodeValue,
          orElse: () => delivery,
        );

        setState(() => delivery = updated);
      } else {
        debugPrint("Failed to reload delivery: HTTP ${response.statusCode}");
      }
    } catch (e) {
      debugPrint("Error reloading delivery: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.of(context).pop(),
        ),
        centerTitle: true,
        title: const Text(
          "Delivery Information",
          style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _reloadDelivery,
        color: const Color(0xFF2E7D32),
        displacement: 30,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            DeliveryInfoCard(delivery: delivery),
            if ((delivery.authorizedRep1?.isNotEmpty ?? false) ||
                (delivery.authorizedRep2?.isNotEmpty ?? false) ||
                (delivery.authorizedRep3?.isNotEmpty ?? false)) ...[
              const SectionTitle("Authorized Representatives"),
              if (delivery.authorizedRep1?.isNotEmpty ?? false)
                RepCard(
                  name: delivery.authorizedRep1!,
                  contact: delivery.contactRep1,
                ),
              if (delivery.authorizedRep2?.isNotEmpty ?? false)
                RepCard(
                  name: delivery.authorizedRep2!,
                  contact: delivery.contactRep2,
                ),
              if (delivery.authorizedRep3?.isNotEmpty ?? false)
                RepCard(
                  name: delivery.authorizedRep3!,
                  contact: delivery.contactRep3,
                ),
            ],
            const SizedBox(height: 20),
            if (delivery.status != "delivered") ...[
              ActionButton(
                text: "Return to Sender",
                color: Colors.grey.shade600,
                onPressed: () async {
                  await Future.delayed(const Duration(milliseconds: 150));
                  Navigator.push(
                    context,
                    PageRouteBuilder(
                      pageBuilder: (context, _, __) =>
                          DeliveredRTS(delivery: delivery),
                      transitionDuration: Duration.zero,
                      reverseTransitionDuration: Duration.zero,
                    ),
                  );
                },
              ),
              const SizedBox(height: 8),

              ActionButton(
                text: "Failed Delivery",
                color: Colors.red,
                onPressed: () async {
                  await Future.delayed(const Duration(milliseconds: 150));
                  Navigator.push(
                    context,
                    PageRouteBuilder(
                      pageBuilder: (context, _, __) =>
                          DeliveredFailed(delivery: delivery),
                      transitionDuration: Duration.zero,
                      reverseTransitionDuration: Duration.zero,
                    ),
                  );
                },
              ),
              const SizedBox(height: 8),

              ActionButton(
                text: "Delivered",
                color: Colors.green,
                onPressed: () async {
                  await Future.delayed(const Duration(milliseconds: 150));
                  Navigator.push(
                    context,
                    PageRouteBuilder(
                      pageBuilder: (context, _, __) =>
                          DeliveredPage(delivery: delivery),
                      transitionDuration: Duration.zero,
                      reverseTransitionDuration: Duration.zero,
                    ),
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}
