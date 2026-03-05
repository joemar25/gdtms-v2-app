import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:uuid/uuid.dart';

import 'package:fsi_courier_app/core/api/api_client.dart';
import 'package:fsi_courier_app/core/api/api_result.dart';
import 'package:fsi_courier_app/core/settings/app_settings.dart';
import 'package:fsi_courier_app/shared/helpers/api_payload_helper.dart';
import 'package:fsi_courier_app/shared/helpers/snackbar_helper.dart';
import 'package:fsi_courier_app/shared/widgets/loading_overlay.dart';
import 'package:fsi_courier_app/styles/color_styles.dart';

enum ScanMode { dispatch, pod }

class ScanScreen extends ConsumerStatefulWidget {
  const ScanScreen({
    super.key,
    required this.mode,
    this.allowLandscape = false,
  });

  final ScanMode mode;
  final bool allowLandscape;

  @override
  ConsumerState<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends ConsumerState<ScanScreen>
    with SingleTickerProviderStateMixin {
  late final MobileScannerController _scannerController;
  final _manualController = TextEditingController();
  late final AnimationController _lineController;
  late final Animation<double> _lineAnim;

  bool _hasPermission = false;
  bool _processing = false;
  String? _inlineError;
  bool _manualSheetOpen = false;

  bool get _isDispatch => widget.mode == ScanMode.dispatch;

  String get _title => _isDispatch ? 'Scan Dispatch' : 'Scan POD';

  String get _hintText =>
      _isDispatch ? 'E.G. E-GEOFXXXXX1234' : 'Enter delivery barcode';

  String get _submitLabel => _isDispatch ? 'Check Eligibility' : 'Find Delivery';

  @override
  void initState() {
    super.initState();
    // Lock orientation to landscape only if allowed
    if (widget.allowLandscape) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    } else {
      // Otherwise lock to portrait (fullscreen mode)
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
      ]);
    }
    _scannerController = MobileScannerController(
      formats: [
        BarcodeFormat.qrCode,
        BarcodeFormat.code128,
        BarcodeFormat.code39,
        BarcodeFormat.ean13,
      ],
      detectionSpeed: DetectionSpeed.noDuplicates,
      autoStart: false,
    );
    _lineController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _lineAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _lineController, curve: Curves.easeInOut),
    );
    // Defer permission/camera start until after first frame (ensures camera surface exists)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _requestPermission();
    });
  }

  @override
  void dispose() {
    // Restore portrait orientation when leaving scan screen
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);
    _manualController.dispose();
    _scannerController.dispose();
    _lineController.dispose();
    super.dispose();
  }

  Future<void> _requestPermission() async {
    final status = await Permission.camera.request();
    if (!mounted) return;
    final granted = status.isGranted;
    setState(() => _hasPermission = granted);
    if (granted) await _scannerController.start();
  }

  Future<void> _handleCode(String code) async {
    if (_processing || code.trim().isEmpty) return;
    setState(() {
      _processing = true;
      _inlineError = null;
    });
    await _scannerController.stop();

    if (_isDispatch) {
      await _handleDispatch(code.trim());
    } else {
      await _handlePod(code.trim());
    }

    if (mounted) setState(() => _processing = false);
  }

  Future<void> _handleDispatch(String code) async {
    const uuid = Uuid();
    final requestId = uuid.v4();

    final result = await ref
        .read(apiClientProvider)
        .post<Map<String, dynamic>>(
          '/check-dispatch-eligibility',
          data: {'dispatch_code': code, 'client_request_id': requestId},
          parser: parseApiMap,
        );

    if (!mounted) return;

    if (result case ApiSuccess<Map<String, dynamic>>(:final data)) {
      final autoAccept = await ref
          .read(appSettingsProvider)
          .getAutoAcceptDispatch();
      if (!mounted) return;
      context.push('/dispatches/eligibility', extra: {
        'dispatch_code': code,
        'eligibility_response': data,
        'auto_accept': autoAccept,
        'eligible': data['eligible'] == true,
      });
    } else {
      setState(
        () => _inlineError = 'Unable to check eligibility. Please try again.',
      );
      showAppSnackbar(
        context,
        'Unable to check eligibility.',
        type: SnackbarType.error,
      );
      await _scannerController.start();
    }
  }

  Future<void> _handlePod(String code) async {
    final result = await ref
        .read(apiClientProvider)
        .get<Map<String, dynamic>>('/deliveries/$code', parser: parseApiMap);

    if (!mounted) return;

    if (result is ApiSuccess<Map<String, dynamic>>) {
      context.go('/deliveries/$code');
    } else {
      setState(() => _inlineError = 'Delivery not found or unavailable.');
      await _scannerController.start();
    }
  }

  @override
  Widget build(BuildContext context) {
    const double viewfinderH = 200.0;
    const double viewfinderMargin = 32.0;
    final double screenH = MediaQuery.of(context).size.height;
    final double vfTop = (screenH - viewfinderH) * 0.42;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: Colors.black,
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          elevation: 0,
          title: Text(
            _title,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: Stack(
          fit: StackFit.expand,
          children: [
            // ── Camera feed – always in tree so hardware never re-inits ──
            MobileScanner(
              controller: _scannerController,
              onDetect: (capture) {
                if (!_manualSheetOpen) {
                  final code = capture.barcodes.firstOrNull?.rawValue;
                  if (code != null && code.isNotEmpty) _handleCode(code);
                }
              },
            ),

            // ── Dark scrim with transparent viewfinder window ─────────
            CustomPaint(
              size: Size.infinite,
              painter: _ScanScrimPainter(
                viewfinderH: viewfinderH,
                viewfinderMargin: viewfinderMargin,
              ),
            ),

            // ── Animated scan line (inside viewfinder) ────────────────
            if (_hasPermission && !_manualSheetOpen)
              AnimatedBuilder(
                animation: _lineAnim,
                builder: (_, __) => Positioned(
                  top: vfTop + _lineAnim.value * (viewfinderH - 4),
                  left: viewfinderMargin + 4,
                  right: viewfinderMargin + 4,
                  child: Container(
                    height: 2,
                    decoration: BoxDecoration(
                      color: ColorStyles.grabGreen.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(2),
                      boxShadow: [
                        BoxShadow(
                          color:
                              ColorStyles.grabGreen.withValues(alpha: 0.5),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            // ── Corner brackets ───────────────────────────────────────
            Positioned(
              top: vfTop,
              left: viewfinderMargin,
              right: viewfinderMargin,
              height: viewfinderH,
              child: CustomPaint(
                painter: _CornerPainter(color: ColorStyles.grabGreen),
              ),
            ),

            // ── Permission overlay (on top of camera) ─────────────────
            if (!_hasPermission)
              GestureDetector(
                onTap: _requestPermission,
                child: Container(
                  color: Colors.black87,
                  child: const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.camera_alt_outlined,
                          color: Colors.white,
                          size: 54,
                        ),
                        SizedBox(height: 16),
                        Text(
                          'Camera permission required',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Tap to grant camera access',
                          style: TextStyle(
                            color: Colors.white60,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            // ── Draggable manual input sheet ─────────────────────────
            DraggableScrollableSheet(
              initialChildSize: 0.12,
              minChildSize: 0.12,
              maxChildSize: 0.45,
              snap: true,
              builder: (context, scrollController) {
                return NotificationListener<DraggableScrollableNotification>(
                  onNotification: (notification) {
                    final open = notification.extent > 0.18;
                    if (open != _manualSheetOpen) {
                      setState(() => _manualSheetOpen = open);
                      if (open) {
                        _scannerController.stop();
                      } else {
                        if (_hasPermission) _scannerController.start();
                      }
                    }
                    return false;
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.85),
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(24),
                      ),
                    ),
                    child: ListView(
                      controller: scrollController,
                      padding: EdgeInsets.zero,
                      children: [
                        const SizedBox(height: 14),
                        Center(
                          child: Container(
                            width: 36,
                            height: 4,
                            decoration: BoxDecoration(
                              color: Colors.white24,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Center(
                          child: Text(
                            _manualSheetOpen
                                ? 'Manual barcode entry'
                                : 'Slide up to enter manually',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        if (_manualSheetOpen)
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            child: _ManualInputArea(
                              controller: _manualController,
                              hintText: _hintText,
                              submitLabel: _submitLabel,
                              error: _inlineError,
                              onSubmit: () => _handleCode(_manualController.text),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),

            if (_processing) const LoadingOverlay(),
          ],
        ),
      ),
    );
  }
}

// ─── Scrim painter ────────────────────────────────────────────────────────────
// Paints a dark overlay everywhere EXCEPT the viewfinder rectangle so the
// camera feed "punches through" cleanly without conditionally removing the
// MobileScanner widget (which would restart the camera hardware).
class _ScanScrimPainter extends CustomPainter {
  const _ScanScrimPainter({
    required this.viewfinderH,
    required this.viewfinderMargin,
  });

  final double viewfinderH;
  final double viewfinderMargin;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0xAA000000);
    final vfTop = (size.height - viewfinderH) * 0.42;
    final vfBottom = vfTop + viewfinderH;
    final vfLeft = viewfinderMargin;
    final vfRight = size.width - viewfinderMargin;

    canvas.drawRect(Rect.fromLTRB(0, 0, size.width, vfTop), paint);
    canvas.drawRect(
        Rect.fromLTRB(0, vfBottom, size.width, size.height), paint);
    canvas.drawRect(Rect.fromLTRB(0, vfTop, vfLeft, vfBottom), paint);
    canvas.drawRect(
        Rect.fromLTRB(vfRight, vfTop, size.width, vfBottom), paint);
  }

  @override
  bool shouldRepaint(_ScanScrimPainter old) =>
      old.viewfinderH != viewfinderH ||
      old.viewfinderMargin != viewfinderMargin;
}

// ─── Corner brackets ──────────────────────────────────────────────────────────
class _CornerPainter extends CustomPainter {
  const _CornerPainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    const len = 22.0;
    const radius = 8.0;
    const strokeW = 3.0;
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeW
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // Top-left
    canvas.drawPath(
      Path()
        ..moveTo(radius, 0)
        ..lineTo(len, 0)
        ..moveTo(0, radius)
        ..lineTo(0, len),
      paint,
    );
    // Top-right
    canvas.drawPath(
      Path()
        ..moveTo(size.width - len, 0)
        ..lineTo(size.width - radius, 0)
        ..moveTo(size.width, radius)
        ..lineTo(size.width, len),
      paint,
    );
    // Bottom-left
    canvas.drawPath(
      Path()
        ..moveTo(0, size.height - len)
        ..lineTo(0, size.height - radius)
        ..moveTo(radius, size.height)
        ..lineTo(len, size.height),
      paint,
    );
    // Bottom-right
    canvas.drawPath(
      Path()
        ..moveTo(size.width - len, size.height)
        ..lineTo(size.width - radius, size.height)
        ..moveTo(size.width, size.height - len)
        ..lineTo(size.width, size.height - radius),
      paint,
    );
  }

  @override
  bool shouldRepaint(_CornerPainter old) => old.color != color;
}

// ─── Manual Input Area ────────────────────────────────────────────────────────

class _ManualInputArea extends StatelessWidget {
  const _ManualInputArea({
    required this.controller,
    required this.hintText,
    required this.submitLabel,
    required this.error,
    required this.onSubmit,
  });

  final TextEditingController controller;
  final String hintText;
  final String submitLabel;
  final String? error;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 36),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(child: Divider(color: Colors.white.withValues(alpha: 0.15))),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  'or enter manually',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.35),
                    fontSize: 12,
                  ),
                ),
              ),
              Expanded(child: Divider(color: Colors.white.withValues(alpha: 0.15))),
            ],
          ),
          const SizedBox(height: 16),
          if (error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(
                error!,
                style: TextStyle(color: Colors.red.shade300, fontSize: 13),
                textAlign: TextAlign.center,
              ),
            ),
          TextField(
            controller: controller,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: hintText,
              hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.35)),
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: ColorStyles.grabGreen,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: onSubmit,
              child: Text(
                submitLabel,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
