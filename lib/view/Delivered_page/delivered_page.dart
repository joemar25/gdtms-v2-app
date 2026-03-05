import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../Dashboard/model/delivery_model.dart';
import 'components/upload_pod_section.dart';
import 'components/additional_images_section.dart';
import 'components/receiver_details_section.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class DeliveredPage extends StatefulWidget {
  final Delivery delivery;
  const DeliveredPage({super.key, required this.delivery});

  @override
  State<DeliveredPage> createState() => _DeliveredPageState();
}

class _DeliveredPageState extends State<DeliveredPage> {
  late Delivery delivery;
  Future<void> _updateStatus(String newStatus) async {
    try {
      final response = await http.put(
        Uri.parse(
          'http://YOUR_API_BASE_URL/api/deliveries/${widget.delivery.id}/status',
        ),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'status': newStatus,
        }), // <-- use 'status', not 'delivery_status'
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          // the delivery object is inside 'delivery' key
          delivery = Delivery.fromJson(data['delivery']);
        });
        debugPrint("Status updated to $newStatus");
      } else {
        debugPrint("Failed to update: HTTP ${response.statusCode}");
        debugPrint("Response body: ${response.body}");
      }
    } catch (e) {
      debugPrint("Error updating status: $e");
    }
  }

  final _receiverController = TextEditingController();
  final _codeController = TextEditingController();
  final _remarksController = TextEditingController();
  String? _selectedRelationship;

  final List<XFile> _additionalImages = [];
  XFile? _podImage;
  final ImagePicker _picker = ImagePicker();

  Future<void> _pickPOD() async {
    final image = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );
    if (image != null) setState(() => _podImage = image);
  }

  Future<void> _openCamera() async {
    final image = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 80,
    );
    if (image != null) setState(() => _podImage = image);
  }

  Future<void> _addAdditionalImage() async {
    if (_additionalImages.length >= 5) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("You can only upload up to 5 images.")),
      );
      return;
    }

    await showModalBottomSheet(
      context: context,
      barrierColor: Colors.transparent,
      backgroundColor: Colors.transparent,
      elevation: 0,
      builder: (context) {
        return Container(
          margin: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 12,
                spreadRadius: 2,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: SafeArea(
            child: Wrap(
              children: [
                ListTile(
                  leading: const Icon(Icons.photo_library, color: Colors.green),
                  title: const Text('Choose from Gallery'),
                  onTap: () async {
                    Navigator.pop(context);
                    final images = await _picker.pickMultiImage(
                      imageQuality: 80,
                    );
                    if (images.isNotEmpty) {
                      setState(() {
                        int remaining = 5 - _additionalImages.length;
                        _additionalImages.addAll(images.take(remaining));
                      });
                    }
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.camera_alt, color: Colors.green),
                  title: const Text('Take Photo'),
                  onTap: () async {
                    Navigator.pop(context);
                    final image = await _picker.pickImage(
                      source: ImageSource.camera,
                      imageQuality: 80,
                    );
                    if (image != null)
                      setState(() => _additionalImages.add(image));
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final delivery = widget.delivery;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "Delivered",
          style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ✅ Receiver Name at the Top
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFE8F5E9),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.person, color: Colors.green),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      delivery.name.isNotEmpty
                          ? delivery.name
                          : "No receiver name available",
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),
            UploadPODSection(
              podImage: _podImage,
              onPickGallery: _pickPOD,
              onOpenCamera: _openCamera,
            ),
            const SizedBox(height: 24),
            AdditionalImagesSection(
              images: _additionalImages,
              onAdd: _addAdditionalImage,
              onRemove: (img) => setState(() => _additionalImages.remove(img)),
            ),
            const SizedBox(height: 24),
            ReceiverDetailsSection(
              receiverController: _receiverController,
              codeController: _codeController,
              remarksController: _remarksController,
              selectedRelationship: _selectedRelationship,
              onRelationshipChanged: (v) =>
                  setState(() => _selectedRelationship = v),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: () async {
                  await _updateStatus("delivered");
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  "Submit",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}
