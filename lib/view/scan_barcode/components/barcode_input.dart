import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../Dashboard/model/delivery_model.dart';
import '../../Delivery_Details/delivery_details_page.dart';

class BarcodeInput extends StatefulWidget {
  const BarcodeInput({super.key});

  @override
  State<BarcodeInput> createState() => _BarcodeInputState();
}

class _BarcodeInputState extends State<BarcodeInput> {
  final TextEditingController _controller = TextEditingController();
  bool _isProcessing = false;

  Future<void> _submitBarcode() async {
    final input = _controller.text.trim();
    if (input.isEmpty) return;

    setState(() => _isProcessing = true);

    try {
      const bool isEmulator = false; // set to true if testing on emulator
      final String baseUrl = isEmulator
          ? 'http://10.0.2.2:8001/api'
          : 'http://YOUR_API_BASE_URL/api';

      late Uri requestUri;

      // ✅ Detect whether input is numeric (ID) or barcode string
      if (int.tryParse(input) != null) {
        // Input is numeric → treat as ID
        requestUri = Uri.parse('$baseUrl/deliveries/$input');
      } else {
        // Input is not numeric → treat as barcode
        final response = await http.get(Uri.parse('$baseUrl/deliveries'));

        if (response.statusCode != 200) {
          throw Exception("Failed to fetch deliveries list");
        }

        final List<dynamic> deliveriesData = json.decode(response.body);
        final normalizedInput = input.toLowerCase(); // ✅ normalize input

        // ✅ Case-insensitive barcode comparison
        final found = deliveriesData.firstWhere(
          (d) =>
              (d['barcode_value'] ?? '').toString().toLowerCase() ==
              normalizedInput,
          orElse: () => null,
        );

        if (found == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("No delivery found for barcode $input"),
              backgroundColor: Colors.redAccent,
            ),
          );
          setState(() => _isProcessing = false);
          return;
        }

        requestUri = Uri.parse('$baseUrl/deliveries/${found['id']}');
      }

      // ✅ Fetch delivery details
      final detailsResponse = await http.get(requestUri);

      if (detailsResponse.statusCode == 200) {
        final data = json.decode(detailsResponse.body);
        final delivery = Delivery.fromJson(data);

        _controller.clear();
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => DeliveryDetailsPage(delivery: delivery),
          ),
        );
      } else if (detailsResponse.statusCode == 404) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Delivery not found"),
            backgroundColor: Colors.redAccent,
          ),
        );
      } else {
        throw Exception(
          "Failed to fetch delivery (status ${detailsResponse.statusCode})",
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e"), backgroundColor: Colors.redAccent),
      );
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            /// Info Text
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Icon(Icons.info_outline, color: Colors.white, size: 18),
                SizedBox(width: 6),
                Flexible(
                  child: Text(
                    "Please Scan or input the Package Barcode",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            /// Floating Card
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 20,
                        offset: Offset(0, 8),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 20,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      /// Barcode TextField
                      TextField(
                        controller: _controller,
                        decoration: InputDecoration(
                          hintText: "Barcode",
                          prefixIcon: const Icon(
                            Icons.qr_code_2_rounded,
                            color: Colors.black54,
                          ),
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 14,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: Colors.green,
                              width: 1.5,
                            ),
                          ),
                        ),
                        onSubmitted: (_) => _submitBarcode(),
                      ),
                      const SizedBox(height: 14),

                      /// Submit Button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isProcessing ? null : _submitBarcode,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green.shade700,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: _isProcessing
                              ? const SizedBox(
                                  height: 18,
                                  width: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text(
                                  "Enter Barcode",
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                        ),
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
