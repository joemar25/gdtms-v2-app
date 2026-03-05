import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../Dashboard/model/delivery_model.dart';
import '../../Delivery_Details/delivery_details_page.dart';

class ConfirmBarcodeDialog extends StatelessWidget {
  final String barcode;
  final VoidCallback onCancel;
  final bool isLandscape;

  const ConfirmBarcodeDialog({
    super.key,
    required this.barcode,
    required this.onCancel,
    this.isLandscape = false,
  });

  Future<void> _acceptBarcode(BuildContext context) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token') ?? '';

      if (token.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Not authenticated. Please log in."),
            backgroundColor: Colors.redAccent,
          ),
        );
        return;
      }

      // 🔹 Fetch all deliveries
      final response = await http.get(
        Uri.parse('https://staging-gdtms-v2.skyward.com.ph/api/mbl/deliveries'),
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final List data = json.decode(response.body)['data'];
        final deliveries = data.map((e) => Delivery.fromJson(e)).toList();

        final matchedDelivery = deliveries.cast<Delivery?>().firstWhere(
          (d) => d?.barcodeValue == barcode,
          orElse: () => null,
        );

        if (matchedDelivery != null) {
          // 🔹 Save to cached recently scanned deliveries
          const String cacheKey = 'recently_scanned_deliveries';
          final jsonString = prefs.getString(cacheKey);
          List<Delivery> currentList = [];

          if (jsonString != null) {
            final List<dynamic> cachedData = json.decode(jsonString);
            currentList = cachedData.map((e) => Delivery.fromJson(e)).toList();
          }

          // Remove duplicate if exists and insert at top
          currentList.removeWhere((d) => d.id == matchedDelivery.id);
          currentList.insert(0, matchedDelivery);

          // Save back to SharedPreferences
          await prefs.setString(
            cacheKey,
            json.encode(currentList.map((d) => d.toJson()).toList()),
          );

          Navigator.of(context).pop(); // Close dialog
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => DeliveryDetailsPage(delivery: matchedDelivery),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("No delivery found for barcode $barcode"),
              backgroundColor: Colors.redAccent,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } else if (response.statusCode == 401) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Unauthorized. Please log in again."),
            backgroundColor: Colors.redAccent,
          ),
        );
      } else {
        throw Exception("Failed to fetch deliveries: ${response.statusCode}");
      }
    } catch (e) {
      debugPrint("Error fetching deliveries: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error connecting to server: $e"),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final screen = MediaQuery.of(context).size;
    final isSmall = screen.width < 360 || screen.height < 600;

    return Positioned.fill(
      child: GestureDetector(
        onTap: () {}, // block taps on camera
        child: Stack(
          children: [
            BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
              child: Container(color: Colors.black.withOpacity(0.5)),
            ),
            Center(
              child: FractionallySizedBox(
                widthFactor: isLandscape ? 0.5 : (isSmall ? 0.9 : 0.85),
                child: Container(
                  padding: EdgeInsets.all(
                    isSmall ? 14 : (isLandscape ? 16 : 20),
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(isSmall ? 16 : 20),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 20,
                        offset: Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      CircleAvatar(
                        backgroundColor: Colors.green.withOpacity(0.1),
                        radius: isSmall ? 24 : (isLandscape ? 26 : 30),
                        child: Icon(
                          Icons.qr_code_2_rounded,
                          color: Colors.green,
                          size: isSmall ? 24 : (isLandscape ? 26 : 32),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        "Confirm Barcode",
                        style: TextStyle(
                          fontSize: isSmall ? 16 : (isLandscape ? 17 : 20),
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        "Do you want to accept this barcode?",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: isSmall ? 13 : (isLandscape ? 14 : 15),
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        margin: const EdgeInsets.only(top: 8),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Text(
                          barcode,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: isSmall ? 13 : (isLandscape ? 14 : 15),
                            letterSpacing: 0.5,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: onCancel,
                            child: Text(
                              "Cancel",
                              style: TextStyle(fontSize: isSmall ? 13 : 14),
                            ),
                          ),
                          const SizedBox(width: 10),
                          ElevatedButton.icon(
                            onPressed: () => _acceptBarcode(context),
                            icon: const Icon(Icons.check_rounded, size: 18),
                            label: Text(
                              "Accept",
                              style: TextStyle(fontSize: isSmall ? 13 : 14),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                              padding: EdgeInsets.symmetric(
                                horizontal: isSmall
                                    ? 12
                                    : (isLandscape ? 14 : 18),
                                vertical: isSmall ? 8 : 10,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
