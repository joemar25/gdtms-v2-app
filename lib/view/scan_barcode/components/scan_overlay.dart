import 'dart:ui';
import 'package:flutter/material.dart';

class ScannerOverlay extends StatelessWidget {
  final Animation<double> animation;
  const ScannerOverlay({super.key, required this.animation});

  @override
  Widget build(BuildContext context) {
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

    return LayoutBuilder(
      builder: (context, constraints) {
        final double scanBoxHeight = isLandscape
            ? constraints.maxHeight * 0.7
            : 220;
        final double scanBoxWidth = isLandscape
            ? constraints.maxWidth * 0.9
            : constraints.maxWidth * 0.85;

        final scanRect = Rect.fromCenter(
          center: Offset(constraints.maxWidth / 2, constraints.maxHeight / 2),
          width: scanBoxWidth,
          height: scanBoxHeight,
        );

        return Stack(
          children: [
            CustomPaint(
              size: Size(constraints.maxWidth, constraints.maxHeight),
              painter: _ScannerOverlayPainter(scanRect),
            ),
            Positioned.fromRect(
              rect: scanRect,
              child: AnimatedBuilder(
                animation: animation,
                builder: (context, _) {
                  final position = Tween<double>(
                    begin: 0,
                    end: scanRect.height - 2,
                  ).evaluate(animation);

                  return Stack(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.white, width: 2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      Positioned(
                        top: position,
                        left: 0,
                        right: 0,
                        child: Container(
                          height: 3,
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          decoration: BoxDecoration(
                            color: Colors.greenAccent,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ScannerOverlayPainter extends CustomPainter {
  final Rect scanRect;
  _ScannerOverlayPainter(this.scanRect);

  @override
  void paint(Canvas canvas, Size size) {
    final background = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
    final cutout = Path()..addRRect(RRect.fromRectXY(scanRect, 12, 12));
    final path = Path.combine(PathOperation.difference, background, cutout);

    final paint = Paint()
      ..color = Colors.black.withOpacity(0.6)
      ..style = PaintingStyle.fill;

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
