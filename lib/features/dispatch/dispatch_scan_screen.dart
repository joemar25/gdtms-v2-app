import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:uuid/uuid.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_result.dart';
import '../../core/settings/app_settings.dart';
import '../../shared/helpers/api_payload_helper.dart';
import '../../shared/helpers/snackbar_helper.dart';
import '../../shared/widgets/loading_overlay.dart';

class DispatchScanScreen extends ConsumerStatefulWidget {
  const DispatchScanScreen({super.key});

  @override
  ConsumerState<DispatchScanScreen> createState() => _DispatchScanScreenState();
}

class _DispatchScanScreenState extends ConsumerState<DispatchScanScreen> {
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
  bool _processing = false;

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
    if (_processing || code.trim().isEmpty) return;
    setState(() => _processing = true);
    await _scannerController.stop();

    const uuid = Uuid();
    final requestId = uuid.v4();
    final result = await ref
        .read(apiClientProvider)
        .post<Map<String, dynamic>>(
          '/check-dispatch-eligibility',
          data: {'dispatch_code': code.trim(), 'client_request_id': requestId},
          parser: parseApiMap,
        );

    if (!mounted) return;

    if (result case ApiSuccess<Map<String, dynamic>>(:final data)) {
      final eligible = data['eligible'] == true;
      final autoAccept = await ref
          .read(appSettingsProvider)
          .getAutoAcceptDispatch();
      if (!mounted) return;
      context.push(
        '/dispatches/eligibility',
        extra: {
          'dispatch_code': code.trim(),
          'eligibility_response': data,
          'auto_accept': autoAccept,
          'eligible': eligible,
        },
      );
    } else {
      showAppSnackbar(
        context,
        'Unable to check eligibility.',
        type: SnackbarType.error,
      );
      await _scannerController.start();
    }

    if (mounted) setState(() => _processing = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scan Dispatch')),
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
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _manualController,
                      decoration: const InputDecoration(
                        hintText: 'Enter dispatch code',
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
            ),
          ),
          if (_processing) const LoadingOverlay(),
        ],
      ),
    );
  }
}
