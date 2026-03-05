import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_result.dart';
import '../../shared/helpers/api_payload_helper.dart';
import '../../shared/widgets/loading_overlay.dart';

class DeliveryScanScreen extends ConsumerStatefulWidget {
  const DeliveryScanScreen({super.key});

  @override
  ConsumerState<DeliveryScanScreen> createState() => _DeliveryScanScreenState();
}

class _DeliveryScanScreenState extends ConsumerState<DeliveryScanScreen> {
  final _manualController = TextEditingController();
  final _scannerController = MobileScannerController(
    formats: [
      BarcodeFormat.qrCode,
      BarcodeFormat.code128,
      BarcodeFormat.code39,
      BarcodeFormat.ean13,
    ],
    detectionSpeed: DetectionSpeed.noDuplicates,
  );

  bool _hasPermission = false;
  bool _loading = false;
  String? _inlineError;

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    _requestPermission();
  }

  @override
  void dispose() {
    _manualController.dispose();
    _scannerController.dispose();
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    super.dispose();
  }

  Future<void> _requestPermission() async {
    final status = await Permission.camera.request();
    if (!mounted) return;
    setState(() => _hasPermission = status.isGranted);
  }

  Future<void> _handleCode(String code) async {
    if (_loading || code.trim().isEmpty) return;
    setState(() {
      _loading = true;
      _inlineError = null;
    });
    await _scannerController.stop();

    final result = await ref
        .read(apiClientProvider)
        .get<Map<String, dynamic>>(
          '/deliveries/${code.trim()}',
          parser: parseApiMap,
        );

    if (!mounted) return;

    if (result is ApiSuccess<Map<String, dynamic>>) {
      context.go('/deliveries/${code.trim()}');
    } else {
      setState(() => _inlineError = 'Delivery not found or unavailable.');
      await _scannerController.start();
    }

    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scan Delivery')),
      body: Stack(
        children: [
          if (_hasPermission)
            MobileScanner(
              controller: _scannerController,
              onDetect: (capture) {
                final code = capture.barcodes.firstOrNull?.rawValue;
                if (code != null && code.isNotEmpty) {
                  _handleCode(code);
                }
              },
            )
          else
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Camera permission is required.'),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: openAppSettings,
                    child: const Text('Open Settings'),
                  ),
                ],
              ),
            ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_inlineError != null)
                    Card(
                      color: Colors.red.shade100,
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: Text(
                          _inlineError!,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),
                    ),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _manualController,
                          decoration: const InputDecoration(
                            hintText: 'Enter delivery barcode',
                            filled: true,
                            fillColor: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: () => _handleCode(_manualController.text),
                        child: const Text('Submit'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (_loading) const LoadingOverlay(),
        ],
      ),
    );
  }
}
