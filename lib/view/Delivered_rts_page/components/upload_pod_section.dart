import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class UploadPODSection extends StatelessWidget {
  final XFile? podImage;
  final VoidCallback onPickGallery;
  final VoidCallback onOpenCamera;

  const UploadPODSection({
    super.key,
    required this.podImage,
    required this.onPickGallery,
    required this.onOpenCamera,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Upload POD",
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        const Text(
          "Upload a Proof of Delivery for verification.",
          style: TextStyle(color: Colors.grey, fontSize: 13),
        ),
        const SizedBox(height: 12),
        GestureDetector(
          onTap: onPickGallery,
          child: CustomPaint(
            painter: LineBorderPainter(
              color: Colors.grey,
              strokeWidth: 1.5,
              dashLength: 10,
              gapLength: 5,
              borderRadius: 10,
            ),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 24),
              color: Colors.grey.withOpacity(0.02),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.cloud_upload, color: Colors.grey, size: 40),
                  const SizedBox(height: 6),
                  TextButton(
                    onPressed: onPickGallery,
                    child: const Text(
                      "Tap to upload photo",
                      style: TextStyle(color: Colors.blue, fontSize: 14),
                    ),
                  ),
                  ElevatedButton(
                    onPressed: onOpenCamera,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      "Open Camera",
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (podImage != null) ...[
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.file(
              File(podImage!.path),
              fit: BoxFit.cover,
              width: double.infinity,
              height: 200,
            ),
          ),
        ],
      ],
    );
  }
}

// Custom painter for dashed/line border
class LineBorderPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double dashLength;
  final double gapLength;
  final double borderRadius;

  LineBorderPainter({
    required this.color,
    this.strokeWidth = 1.5,
    this.dashLength = 10,
    this.gapLength = 5,
    this.borderRadius = 10,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Radius.circular(borderRadius),
    );

    // Draw dashed lines along the path
    final path = Path()..addRRect(rrect);
    final metrics = path.computeMetrics();
    for (final metric in metrics) {
      double distance = 0.0;
      while (distance < metric.length) {
        final len = dashLength;
        canvas.drawPath(metric.extractPath(distance, distance + len), paint);
        distance += dashLength + gapLength;
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
