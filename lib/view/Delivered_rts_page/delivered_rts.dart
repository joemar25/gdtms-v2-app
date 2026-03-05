import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../Dashboard/model/delivery_model.dart';
import 'components/upload_pod_section.dart';
import 'components/additional_images_section.dart';
import 'components/styled_drop_down.dart';
import 'components/styled_text_box.dart';

class DeliveredRTS extends StatefulWidget {
  final Delivery delivery;
  const DeliveredRTS({super.key, required this.delivery});

  @override
  State<DeliveredRTS> createState() => _DeliveredFailedState();
}

class _DeliveredFailedState extends State<DeliveredRTS> {
  // Controllers
  final _receiverController = TextEditingController();
  final _codeController = TextEditingController();
  final _remarksController = TextEditingController();

  // Dropdown selections
  String? _selectedAttempt;
  String? _selectedReason;

  // Images
  final List<XFile> _additionalImages = [];
  XFile? _podImage;
  final ImagePicker _picker = ImagePicker();

  // ✅ Pick POD from gallery
  Future<void> _pickPOD() async {
    final image = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );
    if (!mounted) return;
    if (image != null) setState(() => _podImage = image);
  }

  // ✅ Take POD photo
  Future<void> _openCamera() async {
    final image = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 80,
    );
    if (!mounted) return;
    if (image != null) setState(() => _podImage = image);
  }

  // ✅ Add up to 5 additional images (safe + clean)
  Future<void> _addAdditionalImage() async {
    if (_additionalImages.length >= 5) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("You can only upload up to 5 images.")),
      );
      return;
    }

    final rootContext = context;

    await showModalBottomSheet(
      context: rootContext,
      barrierColor: Colors.transparent,
      backgroundColor: Colors.transparent,
      elevation: 0,
      builder: (sheetContext) {
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
                  leading: const Icon(Icons.photo_library, color: Colors.grey),
                  title: const Text('Choose from Gallery'),
                  onTap: () async {
                    Navigator.pop(sheetContext);
                    final images = await _picker.pickMultiImage(
                      imageQuality: 80,
                    );
                    if (!mounted) return;
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
                  leading: const Icon(Icons.camera_alt, color: Colors.grey),
                  title: const Text('Take Photo'),
                  onTap: () async {
                    Navigator.pop(sheetContext);
                    final image = await _picker.pickImage(
                      source: ImageSource.camera,
                      imageQuality: 80,
                    );
                    if (!mounted) return;
                    if (image != null) {
                      setState(() => _additionalImages.add(image));
                    }
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ✅ Dispose controllers
  @override
  void dispose() {
    _receiverController.dispose();
    _codeController.dispose();
    _remarksController.dispose();
    super.dispose();
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
          "Return to Sender",
          style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ✅ Receiver section
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color.fromARGB(255, 241, 241, 241),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.person, color: Colors.grey),
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

            // ✅ POD upload
            UploadPODSection(
              podImage: _podImage,
              onPickGallery: _pickPOD,
              onOpenCamera: _openCamera,
            ),

            const SizedBox(height: 24),

            // ✅ Additional images
            AdditionalImagesSection(
              images: _additionalImages,
              onAdd: _addAdditionalImage,
              onRemove: (img) => setState(() => _additionalImages.remove(img)),
            ),

            const SizedBox(height: 24),

            // ✅ Failed Delivery Details Section
            const Text(
              "Return to Sender Details",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            const Text(
              "Enter the necessary details to process the Return.",
              style: TextStyle(color: Colors.grey, fontSize: 13),
            ),
            const SizedBox(height: 16),

            // Reason dropdown
            StyledDropDown(
              label: "Reason",
              activeLabel: "Reason",
              items: const [
                "Receiver not available",
                "Address not found",
                "Customer refused",
                "Other",
              ],
              onChanged: (value) => setState(() => _selectedReason = value),
            ),
            const SizedBox(height: 12),

            // Remarks box
            StyledTextBox(
              label: "Remarks",
              activeLabel: "Remarks",
              controller: _remarksController,
              keyboardType: TextInputType.multiline,
              minLines: 4, // ✅ taller input box
              maxLines: 6, // optional expansion
            ),

            const SizedBox(height: 20),

            // ✅ Submit button
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _handleSubmit,
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

  // ✅ Form submit handler
  void _handleSubmit() {
    if (_selectedAttempt == null || _selectedReason == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please fill out all required fields.")),
      );
      return;
    }

    // Example: Handle your form logic
    debugPrint("Attempt: $_selectedAttempt");
    debugPrint("Reason: $_selectedReason");
    debugPrint("Remarks: ${_remarksController.text}");
    debugPrint("POD: ${_podImage?.path ?? "None"}");
    debugPrint("Additional images: ${_additionalImages.length}");

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Failed delivery details submitted.")),
    );
  }
}
