import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../Dashboard/model/delivery_model.dart';
import '../Delivery_Details/delivery_details_page.dart';
import '../scan_barcode/components/barcode_input.dart';
import '../scan_barcode/components/scan_overlay.dart';
import '../scan_barcode/components/confirm_barcode_dialog.dart';
import '../scan_barcode/components/scan_page_header.dart';

class ScanPackageBarcodePage extends StatefulWidget {
  const ScanPackageBarcodePage({super.key});

  @override
  State<ScanPackageBarcodePage> createState() => _ScanPackageBarcodePageState();
}

class _ScanPackageBarcodePageState extends State<ScanPackageBarcodePage>
    with SingleTickerProviderStateMixin {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
    facing: CameraFacing.back,
    torchEnabled: false,
  );

  bool _isDialogOpen = false;
  bool _pauseDetection = false;
  bool _torchOn = false;
  String? _pendingBarcode;

  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    _animationController.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_pauseDetection || _isDialogOpen) return;

    final barcode = capture.barcodes.first.rawValue;
    if (barcode == null) return;

    setState(() {
      _pauseDetection = true;
      _isDialogOpen = true;
      _pendingBarcode = barcode;
    });
  }

  void _closeDialog() {
    setState(() {
      _isDialogOpen = false;
      _pauseDetection = false;
      _pendingBarcode = null;
    });
  }

  void _toggleFlash() async {
    await _controller.toggleTorch();
    setState(() => _torchOn = !_torchOn);
  }

  @override
  Widget build(BuildContext context) {
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;
    final bool isKeyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;

    if (isKeyboardOpen && !_pauseDetection) _pauseDetection = true;
    if (!isKeyboardOpen && _pauseDetection && !_isDialogOpen)
      _pauseDetection = false;

    return WillPopScope(
      onWillPop: () async {
        if (isKeyboardOpen) {
          FocusScope.of(context).unfocus();
          return false;
        }
        return true;
      },
      child: Scaffold(
        appBar: ScanPageHeader(
          torchOn: _torchOn,
          onBack: () {
            if (isKeyboardOpen) {
              FocusScope.of(context).unfocus();
            } else {
              Navigator.pop(context);
            }
          },
          onToggleFlash: _toggleFlash,
          title: "Scan Barcode",
        ),
        body: Stack(
          children: [
            MobileScanner(
              controller: _controller,
              onDetect: (capture) {
                if (!_pauseDetection) _onDetect(capture);
              },
              fit: BoxFit.cover,
            ),
            if (!isKeyboardOpen)
              ScannerOverlay(animation: _animationController),
            if (!isLandscape) const BarcodeInput(),
            if (_isDialogOpen && _pendingBarcode != null)
              ConfirmBarcodeDialog(
                barcode: _pendingBarcode!,
                isLandscape: isLandscape,
                onCancel: _closeDialog,
              ),
          ],
        ),
      ),
    );
  }
}
