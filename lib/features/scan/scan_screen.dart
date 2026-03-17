import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:uuid/uuid.dart';

import 'package:fsi_courier_app/core/api/api_client.dart';
import 'package:fsi_courier_app/core/api/api_result.dart';
import 'package:fsi_courier_app/core/database/local_delivery_dao.dart';
import 'package:fsi_courier_app/core/device/device_info.dart';
import 'package:fsi_courier_app/core/providers/connectivity_provider.dart';
import 'package:fsi_courier_app/shared/helpers/delivery_identifier.dart';
import 'package:fsi_courier_app/core/settings/app_settings.dart';
import 'package:fsi_courier_app/shared/helpers/api_payload_helper.dart';
import 'package:fsi_courier_app/shared/helpers/snackbar_helper.dart';
import 'package:fsi_courier_app/core/providers/delivery_refresh_provider.dart';
import 'package:fsi_courier_app/shared/helpers/formatters.dart';
import 'package:fsi_courier_app/shared/widgets/loading_overlay.dart';
import 'package:fsi_courier_app/shared/widgets/success_overlay.dart';
import 'package:fsi_courier_app/styles/color_styles.dart';

enum ScanMode { dispatch, pod }

class ScanScreen extends ConsumerStatefulWidget {
  const ScanScreen({super.key, required this.mode});

  final ScanMode mode;

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
  bool _showAutoAcceptSuccess = false;
  String? _inlineError;

  bool get _isDispatch => widget.mode == ScanMode.dispatch;

  String get _title => _isDispatch ? 'Scan Dispatch' : 'Scan POD';

  String get _hintText =>
      _isDispatch ? 'E.G. E-GEOFXXXXX1234' : 'Enter delivery barcode or account name';

  String get _submitLabel =>
      _isDispatch ? 'Check Eligibility' : 'Find Delivery';

  @override
  void initState() {
    super.initState();
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
    // Unlock all orientations for scanning — barcodes can be long and
    // landscape gives a wider viewfinder.  Portrait is restored on dispose.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
      if (mounted) _requestPermission();
    });
  }

  @override
  void dispose() {
    // Restore portrait for every other screen in the app.
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
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
    // Normalize input: always uppercase
    final normalizedCode = code.trim().toUpperCase();
    setState(() {
      _processing = true;
      _inlineError = null;
    });
    await _scannerController.stop();

    if (_isDispatch) {
      await _handleDispatch(normalizedCode);
    } else {
      await _handlePod(normalizedCode);
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
          data: {'partial_code': code, 'client_request_id': requestId},
          parser: parseApiMap,
        );

    if (!mounted) return;

    if (result case ApiSuccess<Map<String, dynamic>>(:final data)) {
      final autoAccept = await ref
          .read(appSettingsProvider)
          .getAutoAcceptDispatch();
      if (!mounted) return;
      final partialCode = data['partial_code']?.toString() ?? code;

      // If scanned, show full dispatch code and skip modal
      if (autoAccept && data['eligible'] == true) {
        // Auto-accept dispatch if eligible and autoAccept is enabled
        final acceptResult = await ref
            .read(apiClientProvider)
            .post<Map<String, dynamic>>(
              '/accept-dispatch',
              data: {
                'partial_code': partialCode,
                'client_request_id': requestId,
                'device_info': await ref.read(deviceInfoProvider).toMap(),
              },
              parser: parseApiMap,
            );
        if (!mounted) return;
        if (acceptResult is ApiSuccess<Map<String, dynamic>>) {
          final rawDeliveries = data['deliveries'];
          if (rawDeliveries is List) {
            final deliveries = rawDeliveries
                .whereType<Map>()
                .map((e) => Map<String, dynamic>.from(e))
                .toList();
            if (deliveries.isNotEmpty) {
              await LocalDeliveryDao.instance.insertAll(
                deliveries,
                dispatchCode: partialCode,
              );
            }
          }
          ref.read(deliveryRefreshProvider.notifier).state++;
          if (mounted) setState(() => _showAutoAcceptSuccess = true);
        } else {
          setState(() => _inlineError = 'Unable to accept dispatch. Please try again.');
          showAppSnackbar(
            context,
            'Unable to accept dispatch.',
            type: SnackbarType.error,
          );
          await _scannerController.start();
        }
        return;
      }

      // Otherwise, show eligibility screen with full code, skip modal
      await context.push(
        '/dispatches/eligibility',
        extra: {
          'dispatch_code': partialCode,
          'eligibility_response': data,
          'auto_accept': autoAccept,
          'eligible': data['eligible'] == true,
          'show_full_code': true,
          'skip_accept_modal': true,
        },
      );
      if (mounted && _hasPermission) await _scannerController.start();
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

  void _openManualSheet() async {
    await _scannerController.stop();
    if (!mounted) return;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: _ManualInputArea(
          controller: _manualController,
          hintText: _hintText,
          submitLabel: _submitLabel,
          error: _inlineError,
          onSubmit: () {
            Navigator.of(context).pop();
            // Normalize manual input to uppercase
            _handleCode(_manualController.text.toUpperCase());
          },
        ),
      ),
    );
    if (mounted && _hasPermission) await _scannerController.start();
  }

  Future<void> _handlePod(String code) async {
    // Search locally first — barcode substring OR recipient name substring.
    final matches = await LocalDeliveryDao.instance.searchByQuery(code);
    if (!mounted) return;

    if (matches.length == 1) {
      final match = matches.first;
      if (match.deliveryStatus.toLowerCase() == 'osa') {
        setState(() => _inlineError = '"${match.barcode}" is marked OSA and cannot be opened.');
        if (_hasPermission) await _scannerController.start();
        return;
      }
      await context.push('/deliveries/${match.barcode}');
      if (mounted && _hasPermission) await _scannerController.start();
      return;
    }

    if (matches.length > 1) {
      // Multiple hits — let the courier pick the correct one.
      // Filter out OSA entries before showing the picker.
      final nonOsa = matches.where(
        (m) => m.deliveryStatus.toLowerCase() != 'osa',
      ).toList();
      if (nonOsa.isEmpty) {
        setState(() => _inlineError = '"$code" is marked OSA and cannot be opened.');
        if (_hasPermission) await _scannerController.start();
        return;
      }
      final chosen = await _showSearchResults(
        code,
        nonOsa.map((m) => m.toDeliveryMap()).toList(),
      );
      if (!mounted) return;
      if (chosen != null) {
        final barcode = resolveDeliveryIdentifier(chosen);
        if (barcode.isNotEmpty) context.go('/deliveries/$barcode');
      } else {
        if (_hasPermission) await _scannerController.start();
      }
      return;
    }

    // 0 local results — fall back to exact API lookup.
    final result = await ref
        .read(apiClientProvider)
        .get<Map<String, dynamic>>('/deliveries/$code', parser: parseApiMap);

    if (!mounted) return;

    if (result is ApiSuccess<Map<String, dynamic>>) {
      final deliveryStatus =
          result.data['delivery_status']?.toString().toLowerCase() ?? '';
      if (deliveryStatus == 'osa') {
        setState(() => _inlineError = '"$code" is marked OSA and cannot be opened.');
        if (_hasPermission) await _scannerController.start();
        return;
      }
      await context.push('/deliveries/$code');
      if (mounted && _hasPermission) await _scannerController.start();
    } else {
      setState(() => _inlineError = 'No delivery found for "$code".');
      if (_hasPermission) await _scannerController.start();
    }
  }

  Future<Map<String, dynamic>?> _showSearchResults(
    String query,
    List<Map<String, dynamic>> results,
  ) {
    return showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _SearchResultsSheet(query: query, results: results),
    );
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
                final code = capture.barcodes.firstOrNull?.rawValue;
                if (code != null && code.isNotEmpty) _handleCode(code);
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
            if (_hasPermission)
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
                          color: ColorStyles.grabGreen.withValues(alpha: 0.5),
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
                          style: TextStyle(color: Colors.white60, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            // ── Fixed bottom action bar ───────────────────────────
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: SafeArea(
                child: Container(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.9),
                        Colors.transparent,
                      ],
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Static hint for dispatch mode so the user always knows
                      // connectivity is required before they even attempt a scan.
                      if (_isDispatch)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Consumer(
                                builder: (_, ref, __) {
                                  final isOnline = ref.watch(isOnlineProvider);
                                  return Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        isOnline
                                            ? Icons.wifi_rounded
                                            : Icons.wifi_off_rounded,
                                        size: 12,
                                        color: isOnline
                                            ? Colors.white54
                                            : Colors.orange,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        isOnline
                                            ? 'Dispatch scanning requires an internet connection.'
                                            : 'You are offline — dispatch scanning unavailable.',
                                        style: TextStyle(
                                          color: isOnline
                                              ? Colors.white54
                                              : Colors.orange,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      if (_inlineError != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.red.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: Colors.red.withValues(alpha: 0.4),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.error_outline_rounded,
                                  color: Colors.redAccent,
                                  size: 16,
                                ),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: Text(
                                    _inlineError!,
                                    style: const TextStyle(
                                      color: Colors.redAccent,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.keyboard_alt_outlined, size: 18),
                        label: const Text(
                          'ENTER MANUALLY',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.8,
                            fontSize: 13,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: BorderSide(
                            color: Colors.white.withValues(alpha: 0.4),
                          ),
                          minimumSize: const Size(double.infinity, 48),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        onPressed: _openManualSheet,
                      ),
                    ],
                  ),
                ),
              ),
            ),

            if (_processing) const LoadingOverlay(),
            if (_showAutoAcceptSuccess)
              SuccessOverlay(
                onDone: () {
                  if (!mounted) return;
                  context.go('/dashboard');
                },
              ),
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
    canvas.drawRect(Rect.fromLTRB(0, vfBottom, size.width, size.height), paint);
    canvas.drawRect(Rect.fromLTRB(0, vfTop, vfLeft, vfBottom), paint);
    canvas.drawRect(Rect.fromLTRB(vfRight, vfTop, size.width, vfBottom), paint);
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
      decoration: const BoxDecoration(
        color: Color(0xFF1A1A2E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
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
          const SizedBox(height: 16),
          const Text(
            'MANUAL BARCODE/ACCOUNT NAME ENTRY',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 12),
          if (error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.red.withValues(alpha: 0.4)),
                ),
                child: Text(
                  error!,
                  style: const TextStyle(color: Colors.redAccent, fontSize: 13),
                ),
              ),
            ),
          TextField(
            controller: controller,
            style: const TextStyle(color: Colors.white),
            autofocus: true,
            textCapitalization: TextCapitalization.characters,
            inputFormatters: [UpperCaseFormatter()],
            decoration: InputDecoration(
              hintText: hintText,
              hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.35)),
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.08),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: Colors.white.withValues(alpha: 0.15),
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: Colors.white.withValues(alpha: 0.15),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                  color: ColorStyles.grabGreen,
                  width: 1.5,
                ),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
            ),
            onSubmitted: (_) => onSubmit(),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            icon: const Icon(Icons.search_rounded, size: 18),
            label: Text(
              submitLabel.toUpperCase(),
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
              ),
            ),
            style: FilledButton.styleFrom(
              backgroundColor: ColorStyles.grabGreen,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 50),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: onSubmit,
          ),
        ],
      ),
    );
  }
}

// ─── Search Results Sheet ─────────────────────────────────────────────────────

/// Shown in POD scan mode when the barcode/name query matches multiple local
/// deliveries. Displays all hits so the courier can select the right one.
/// Returns the selected delivery map, or `null` if the user dismisses.
class _SearchResultsSheet extends StatelessWidget {
  const _SearchResultsSheet({required this.query, required this.results});

  final String query;
  final List<Map<String, dynamic>> results;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF1E1E2E) : Colors.white;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.55,
      minChildSize: 0.35,
      maxChildSize: 0.9,
      builder: (_, scrollController) => Container(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${results.length} RESULT${results.length == 1 ? '' : 'S'} FOUND',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: Colors.grey.shade500,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Tap one to open delivery details',
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark ? Colors.white70 : Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.separated(
                controller: scrollController,
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: results.length,
                separatorBuilder: (_, __) =>
                    const Divider(height: 1, indent: 16, endIndent: 16),
                itemBuilder: (_, i) {
                  final d = results[i];
                  final barcode =
                      d['barcode_value']?.toString() ??
                      d['barcode']?.toString() ??
                      '';
                  final name =
                      d['name']?.toString() ??
                      d['recipient_name']?.toString() ??
                      '';
                  final address = d['address']?.toString() ?? '';
                  final status = d['delivery_status']?.toString() ?? 'pending';

                  return ListTile(
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: ColorStyles.grabGreen.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.qr_code_rounded,
                        color: ColorStyles.grabGreen,
                        size: 20,
                      ),
                    ),
                    title: Text(
                      barcode,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (name.isNotEmpty)
                          Text(
                            name,
                            style: const TextStyle(fontSize: 12),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        if (address.isNotEmpty)
                          Text(
                            address,
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.grey.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        status.toUpperCase(),
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: Colors.blueGrey,
                        ),
                      ),
                    ),
                    onTap: () => Navigator.pop(context, d),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
