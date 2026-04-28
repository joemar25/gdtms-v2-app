// DOCS: docs/features/scan.md — update that file when you edit this one.

// =============================================================================
// scan_screen.dart
// =============================================================================
//
// Purpose:
//   Camera-based barcode scanner that provides a fast path for looking up or
//   acting on a specific delivery without navigating the full list. The courier
//   points the camera at a parcel barcode and is taken directly to that
//   delivery's detail screen.
//
// Key behaviours:
//   • Uses [MobileScanner] for real-time barcode detection (QR, Code128, etc.).
//   • On a successful scan, looks up the barcode in local SQLite first
//     (offline-first). If not found locally and the device is online, attempts
//     a server lookup.
//   • Flashlight toggle — hardware torch controlled via [MobileScannerController].
//   • Haptic feedback on successful scan to confirm to the courier without
//     requiring them to look at the screen.
//   • Camera permission is requested on mount; if denied, shows a guidance
//     message with a link to app settings.
//
// Navigation:
//   Route: /scan
//   Accessed via: FloatingBottomNavBar (Scan tab) and DashboardScreen SCAN card
//   Pushes to: DeliveryDetailScreen on successful barcode match
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:uuid/uuid.dart';

import 'package:fsi_courier_app/core/api/api_client.dart';
import 'package:fsi_courier_app/core/database/local_delivery_dao.dart';
import 'package:fsi_courier_app/core/models/local_delivery.dart';
import 'package:fsi_courier_app/core/device/device_info.dart';
import 'package:fsi_courier_app/core/providers/connectivity_provider.dart';
import 'package:fsi_courier_app/shared/helpers/delivery_helper.dart';
import 'package:fsi_courier_app/shared/widgets/app_header_bar.dart';
import 'package:fsi_courier_app/shared/helpers/delivery_identifier.dart';
import 'package:fsi_courier_app/core/settings/app_settings.dart';
import 'package:fsi_courier_app/shared/helpers/api_payload_helper.dart';
import 'package:fsi_courier_app/shared/helpers/snackbar_helper.dart';
import 'package:fsi_courier_app/core/providers/delivery_refresh_provider.dart';
import 'package:fsi_courier_app/shared/helpers/formatters.dart';
import 'package:fsi_courier_app/shared/widgets/loading_overlay.dart';
import 'package:fsi_courier_app/shared/widgets/success_overlay.dart';
import 'package:fsi_courier_app/design_system/design_system.dart';

enum ScanMode { dispatch, pod }

class ScanScreen extends ConsumerStatefulWidget {
  const ScanScreen({super.key, required this.mode});

  final ScanMode mode;

  @override
  ConsumerState<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends ConsumerState<ScanScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final MobileScannerController _scannerController;
  final _manualController = TextEditingController();
  late final AnimationController _lineController;
  late final Animation<double> _lineAnim;

  bool _hasPermission = false;
  bool _processing = false;
  bool _showAutoAcceptSuccess = false;
  String? _inlineError;
  // Track orientation axis to restart camera when it flips so CameraX
  // picks up the correct display rotation on Android.
  bool? _wasLandscape;

  bool get _isDispatch => widget.mode == ScanMode.dispatch;

  String get _title => _isDispatch ? 'Scan Dispatch' : 'Scan POD';

  String get _hintText => _isDispatch
      ? 'E.G. E-GEOFXXXXX1234'
      : 'Enter delivery barcode or account name';

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
    WidgetsBinding.instance.addObserver(this);
    // 1. Force portrait so the camera always initialises upright.
    // 2. After the first frame, unlock all orientations so the user can
    //    freely rotate — this also prevents the "camera comes back sideways"
    //    regression because the camera inits in a known portrait state each
    //    time the screen is opened.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
      ]);
      if (!mounted) return;
      _requestPermission();
      // Small delay so the system settles in portrait before unlocking.
      await Future<void>.delayed(const Duration(milliseconds: 300));
      if (!mounted) return;
      await SystemChrome.setPreferredOrientations([]);
    });
  }

  @override
  void didChangeMetrics() {
    super.didChangeMetrics();
    if (!mounted || !_hasPermission || _processing) return;
    final physicalSize =
        WidgetsBinding.instance.platformDispatcher.views.first.physicalSize;
    final isLandscape = physicalSize.width > physicalSize.height;
    if (_wasLandscape != null && _wasLandscape != isLandscape) {
      // Orientation axis flipped — restart the camera so CameraX picks up
      // the correct display rotation and the preview is not sideways.
      _wasLandscape = isLandscape;
      _scannerController.stop().then((_) {
        if (!mounted || !_hasPermission || _processing) return;
        _scannerController.start();
      });
    } else {
      _wasLandscape ??= isLandscape;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
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
    if (granted) {
      final size =
          WidgetsBinding.instance.platformDispatcher.views.first.physicalSize;
      _wasLandscape = size.width > size.height;
    }
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

    // Strict pre-filter: if this barcode matches any local delivery (POD), do
    // not treat it as a dispatch scan. This avoids unnecessary network checks
    // and prevents navigating to the dispatch eligibility page for PODs.
    final localMatches = await LocalDeliveryDao.instance.searchByQuery(code);
    if (!mounted) return;
    if (localMatches.isNotEmpty) {
      final msg =
          'Scanned barcode belongs to a delivery (POD). Use POD scan mode.';
      setState(() => _inlineError = msg);
      showInfoNotification(context, msg);
      if (mounted && _hasPermission) await _scannerController.start();
      return;
    }

    final device = ref.read(deviceInfoProvider);
    final result = await ref
        .read(apiClientProvider)
        .post<Map<String, dynamic>>(
          '/check-dispatch-eligibility',
          data: {
            'dispatch_code': code,
            'client_request_id': requestId,
            'device_info': await device.toMap(),
          },
          parser: parseApiMap,
        );

    if (!mounted) return;

    if (result case ApiSuccess<Map<String, dynamic>>(:final data)) {
      final autoAccept = await ref
          .read(appSettingsProvider)
          .getAutoAcceptDispatch();
      if (!mounted) return;

      // Merge pending dispatches to enrich response (branch/tat/transmittal_date)
      var dispatchCode = data['dispatch_code']?.toString() ?? code;
      Map<String, dynamic> mergedData = data;
      final pendingResult = await ref
          .read(apiClientProvider)
          .get<Map<String, dynamic>>(
            '/pending-dispatches',
            queryParameters: {'page': 1, 'per_page': 50},
            parser: parseApiMap,
          );
      if (!mounted) return;
      if (pendingResult is ApiSuccess<Map<String, dynamic>>) {
        final list = pendingResult.data['pending_dispatches'];
        if (list is List) {
          final scanUpper = dispatchCode.toUpperCase();
          final match = list
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .firstWhere((d) {
                final dc = d['dispatch_code']?.toString().toUpperCase() ?? '';
                // Exact match, or the scanned QR embeds the dispatch code as a
                // prefix with a timestamp suffix (e.g. GEOFM001...2026041712345).
                return dc == scanUpper ||
                    scanUpper.startsWith(dc) ||
                    dc.startsWith(scanUpper);
              }, orElse: () => <String, dynamic>{});
          if (match.isNotEmpty) {
            // Merge: pending-list data provides display fields (branch, tat,
            // transmittal_date, volume); API response wins for flags (eligible).
            mergedData = {...match, ...mergedData};
            // Use the canonical dispatch code from the pending list (short form)
            // so accept/reject API calls use the correct identifier.
            dispatchCode = match['dispatch_code']?.toString() ?? dispatchCode;
          }
        }
      }

      // Do not push if not eligible — UX pre-filter.
      // The spread {…match, …mergedData} puts the eligibility API response last,
      // so mergedData['eligible'] is always the authoritative value from the API.
      // Accept booleans, numeric, and common string forms for backward compatibility.
      final dynamic eligibleRaw = mergedData['eligible'];
      final bool eligible =
          (eligibleRaw is bool && eligibleRaw == true) ||
          (eligibleRaw is num && eligibleRaw != 0) ||
          (eligibleRaw is String &&
              ['true', '1', 'yes'].contains(eligibleRaw.trim().toLowerCase()));
      if (!eligible) {
        final reason =
            mergedData['message']?.toString() ??
            'You are not eligible for this dispatch.';
        setState(() => _inlineError = reason);
        // Disable camera scanning for this session — do not restart the scanner.
        try {
          await _scannerController.stop();
        } catch (_) {}
        return;
      }

      // Auto-accept flow (only for genuine dispatches that are eligible)
      if (autoAccept) {
        final acceptResult = await ref
            .read(apiClientProvider)
            .post<Map<String, dynamic>>(
              '/accept-dispatch',
              data: {
                'dispatch_code': dispatchCode,
                'client_request_id': requestId,
                'device_info': await ref.read(deviceInfoProvider).toMap(),
              },
              parser: parseApiMap,
            );
        if (!mounted) return;
        if (acceptResult is ApiSuccess<Map<String, dynamic>>) {
          final rawDeliveries = mergedData['deliveries'];
          if (rawDeliveries is List) {
            final deliveries = rawDeliveries
                .whereType<Map>()
                .map((e) => Map<String, dynamic>.from(e))
                .toList();
            if (deliveries.isNotEmpty) {
              await LocalDeliveryDao.instance.insertAll(
                deliveries,
                dispatchCode: dispatchCode,
              );
            }
          }
          ref.read(deliveryRefreshProvider.notifier).increment();
          if (mounted) setState(() => _showAutoAcceptSuccess = true);
          if (mounted && _hasPermission) await _scannerController.start();
          return;
        } else {
          final acceptErrorMessage = switch (acceptResult) {
            ApiBadRequest(:final message) => message,
            ApiValidationError(:final message) => message ?? 'Validation error',
            ApiNetworkError(:final message) => message,
            ApiRateLimited(:final message) => message,
            ApiConflict(:final message) => message,
            ApiServerError(:final message) => message,
            _ => 'Unable to accept dispatch. Please try again.',
          };
          setState(() => _inlineError = acceptErrorMessage);
          showErrorNotification(context, acceptErrorMessage);
          if (_hasPermission) await _scannerController.start();
          return;
        }
      }

      // Otherwise, show eligibility screen (dispatch & eligible)
      await context.push(
        '/dispatches/eligibility',
        extra: {
          'dispatch_code': dispatchCode,
          'eligibility_response': mergedData,
          'auto_accept': autoAccept,
          'eligible': true,
          'show_full_code': true,
          'skip_accept_modal': true,
        },
      );
      if (mounted && _hasPermission) await _scannerController.start();
    } else {
      final errorMessage = switch (result) {
        ApiBadRequest(:final message) => message,
        ApiValidationError(:final message) => message ?? 'Validation error',
        ApiNetworkError(:final message) => message,
        ApiRateLimited(:final message) => message,
        ApiConflict(:final message) => message,
        ApiServerError(:final message) => message,
        _ => 'Unable to check eligibility. Please try again.',
      };

      setState(() => _inlineError = errorMessage);
      showErrorNotification(context, errorMessage);
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
    // ── SCAN GATE (pre-filter) ────────────────────────────────────────────────
    // Only PENDING and unverified FAILED_DELIVERY are valid delivery targets.
    // DELIVERED and OSA are excluded — they are not actionable here.
    // DeliveryDetailScreen._load() runs isVisibleToRider again as the canonical
    // HARD GATE — this pre-filter is a UX layer that gives a meaningful error
    // message before ever navigating, and avoids N+1 per-row checks.
    var matches = await LocalDeliveryDao.instance.searchVisibleByQuery(code);
    debugPrint(
      '[SCAN] searchVisibleByQuery($code) -> ${matches.length} matches',
    );
    if (matches.isNotEmpty) {
      try {
        debugPrint(
          '[SCAN]  results: ${matches.map((m) => '${m.barcode}|status=${m.deliveryStatus}|verif=${m.rtsVerificationStatus}|attempts=${getAttemptsCountFromMap(m.toDeliveryMap())}').toList()}',
        );
      } catch (e) {
        debugPrint('[SCAN]  results: (failed to stringify) $e');
      }
    }
    if (!mounted) return;

    // If no visible matches were found, do a broader local search as a fallback.
    // This catches cases where the row exists locally but the visible-only SQL
    // excluded it (e.g. completed_at missing or other edge cases). We then
    // validate visibility per-row using the canonical isVisibleToRider gate.
    if (matches.isEmpty) {
      final fallback = await LocalDeliveryDao.instance.searchByQuery(code);
      debugPrint(
        '[SCAN] fallback searchByQuery($code) -> ${fallback.length} results',
      );
      if (!mounted) return;
      if (fallback.isNotEmpty) {
        final visibilityFutures = fallback
            .map((d) => LocalDeliveryDao.instance.isVisibleToRider(d.barcode))
            .toList();
        final visibilityResults = await Future.wait(visibilityFutures);
        final actionable = <LocalDelivery>[];
        for (var i = 0; i < fallback.length; i++) {
          if (visibilityResults[i] == true) actionable.add(fallback[i]);
        }
        debugPrint('[SCAN] actionable fallback -> ${actionable.length}');
        if (actionable.isNotEmpty) {
          matches = actionable;
        } else {
          // Local record(s) exist but none are actionable — show blocked reason.
          final anyLocal = fallback.first;
          final msg = _blockedMessage(
            anyLocal.deliveryStatus,
            anyLocal.rtsVerificationStatus,
          );
          setState(() => _inlineError = msg);
          showInfoNotification(context, msg);
          if (_hasPermission) await _scannerController.start();
          return;
        }
      }
    }

    if (matches.length == 1) {
      final match = matches.first;
      final isLocked = checkIsLockedFromMap(match.toDeliveryMap());

      if (isLocked) {
        final msg = _blockedMessage(
          match.deliveryStatus,
          match.rtsVerificationStatus,
        );
        setState(() => _inlineError = msg);
        showInfoNotification(context, msg);
        if (_hasPermission) await _scannerController.start();
        return;
      }
      await context.push('/deliveries/${match.barcode}/update');
      if (mounted && _hasPermission) await _scannerController.start();
      return;
    }

    if (matches.length > 1) {
      // Multiple hits — all results are already PENDING/FAILED_DELIVERY actionable,
      // so show the picker directly.
      final chosen = await _showSearchResults(
        code,
        matches.map((m) => m.toDeliveryMap()).toList(),
      );
      if (!mounted) return;
      if (chosen != null) {
        final barcode = resolveDeliveryIdentifier(chosen);
        if (barcode.isNotEmpty) context.go('/deliveries/$barcode/update');
      } else {
        if (_hasPermission) await _scannerController.start();
      }
      return;
    }

    // 0 visible local results.
    // Before giving up, check if the barcode exists locally but is non-visible
    // (e.g. verified Failed Delivery, paid delivered, old window) so we can give a better
    // error message than just "not found".
    final anyLocal = await LocalDeliveryDao.instance.getByBarcode(code);
    if (!mounted) return;
    if (anyLocal != null) {
      // Item exists locally but is blocked — show status-specific reason.
      final msg = _blockedMessage(
        anyLocal.deliveryStatus,
        anyLocal.rtsVerificationStatus,
      );
      setState(() => _inlineError = msg);
      showInfoNotification(context, msg);
      if (_hasPermission) await _scannerController.start();
      return;
    }

    // Genuinely not in local DB — try the API as a last resort.
    // If the API returns data it still means the item was not assigned to this
    // courier for today, so we block it regardless.
    final result = await ref
        .read(apiClientProvider)
        .get<Map<String, dynamic>>('/deliveries/$code', parser: parseApiMap);

    if (!mounted) return;

    if (result is ApiSuccess<Map<String, dynamic>>) {
      // Item exists on server but is not in the courier's active local list.
      // The hard gate in DeliveryDetailScreen would catch it anyway, but we
      // block here to avoid a confusing navigation + immediate pop experience.
      setState(() => _inlineError = 'No active delivery found for "$code".');
      if (_hasPermission) await _scannerController.start();
    } else {
      setState(() => _inlineError = 'No delivery found for "$code".');
      if (_hasPermission) await _scannerController.start();
    }
  }

  /// Returns a human-readable error message for a delivery that failed the
  /// visibility check, based on its [status] and [failedDeliveryVerifStatus].
  ///
  /// Rule mapping (mirrors isVisibleToRider):
  ///   OSA                          → locked, never tappable
  ///   FAILED_DELIVERY + verified (any) → fully settled, no action needed
  ///   anything else / out-of-date  → not in today's active window
  String _blockedMessage(String status, String? failedDeliveryVerifStatus) {
    final s = status.toUpperCase();
    final v = (failedDeliveryVerifStatus ?? 'unvalidated').toLowerCase();
    if (s == 'OSA') {
      return 'This item is marked OSA and cannot be opened.';
    }
    if (s == 'DELIVERED') {
      return 'This item has already been delivered and is sealed.';
    }
    if (s == 'FAILED_DELIVERY' &&
        (v == 'verified_with_pay' || v == 'verified_no_pay')) {
      return 'This failed delivery has already been verified and is no longer actionable.';
    }
    return 'This delivery is not in your active list.';
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
        appBar: AppHeaderBar(
          titleWidget: Text(
            _title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          backgroundColor: Colors.transparent,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          actions: [
            ValueListenableBuilder<MobileScannerState>(
              valueListenable: _scannerController,
              builder: (context, state, child) {
                final isTorchOn = state.torchState == TorchState.on;
                return IconButton(
                  icon:
                      Icon(
                            isTorchOn
                                ? Icons.flashlight_on_rounded
                                : Icons.flashlight_off_rounded,
                            color: isTorchOn ? DSColors.primary : Colors.white,
                          )
                          .animate(key: ValueKey(isTorchOn))
                          .scaleXY(
                            begin: 1.2,
                            end: 1.0,
                            duration: 150.ms,
                            curve: Curves.easeOutBack,
                          )
                          .rotate(
                            begin: isTorchOn ? 0.1 : -0.1,
                            end: 0,
                            duration: 150.ms,
                            curve: Curves.easeOutBack,
                          ),
                  onPressed: () => _scannerController.toggleTorch(),
                );
              },
            ),
            const SizedBox(width: 8),
          ],
          showNotificationBell: false,
        ),
        body: LoadingOverlay(
          isLoading: _processing,
          child: Stack(
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
                  builder: (_, _) => Positioned(
                    top: vfTop + _lineAnim.value * (viewfinderH - 4),
                    left: viewfinderMargin + 4,
                    right: viewfinderMargin + 4,
                    child: Container(
                      height: 2,
                      decoration: BoxDecoration(
                        color: DSColors.primary.withValues(
                          alpha: DSStyles.alphaGlass,
                        ),
                        borderRadius: DSStyles.pillRadius,
                        boxShadow: [
                          BoxShadow(
                            color: DSColors.primary.withValues(
                              alpha: DSStyles.alphaBorder,
                            ),
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
                  painter: _CornerPainter(color: DSColors.primary),
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
                          Colors.black.withValues(alpha: DSStyles.alphaGlass),
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
                                  builder: (_, ref, _) {
                                    final isOnline = ref.watch(
                                      isOnlineProvider,
                                    );
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
                                color: Colors.red.withValues(
                                  alpha: DSStyles.alphaActiveAccent,
                                ),
                                borderRadius: DSStyles.cardRadius,
                                border: Border.all(
                                  color: Colors.red.withValues(
                                    alpha: DSStyles.alphaBorder,
                                  ),
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
                          icon: const Icon(
                            Icons.keyboard_alt_outlined,
                            size: 18,
                          ),
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
                              color: Colors.white.withValues(
                                alpha: DSStyles.alphaBorder,
                              ),
                            ),
                            minimumSize: const Size(double.infinity, 48),
                            shape: RoundedRectangleBorder(
                              borderRadius: DSStyles.cardRadius,
                            ),
                          ),
                          onPressed: _openManualSheet,
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Loading state handled by wrapper
              if (_showAutoAcceptSuccess)
                SuccessOverlay(
                  onDone: () {
                    if (!mounted) return;
                    showAppSnackbar(
                      context,
                      'Dispatch accepted successfully!',
                      type: SnackbarType.success,
                    );
                    context.go('/dashboard');
                  },
                ),
            ],
          ),
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
                borderRadius: DSStyles.pillRadius,
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
                  color: Colors.red.withValues(
                    alpha: DSStyles.alphaActiveAccent,
                  ),
                  borderRadius: DSStyles.cardRadius,
                  border: Border.all(
                    color: Colors.red.withValues(alpha: DSStyles.alphaBorder),
                  ),
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
              hintStyle: TextStyle(
                color: Colors.white.withValues(alpha: DSStyles.alphaDarkShadow),
              ),
              filled: true,
              fillColor: Colors.white.withValues(alpha: DSStyles.alphaSoft),
              border: OutlineInputBorder(
                borderRadius: DSStyles.cardRadius,
                borderSide: BorderSide(
                  color: Colors.white.withValues(
                    alpha: DSStyles.alphaActiveAccent,
                  ),
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: DSStyles.cardRadius,
                borderSide: BorderSide(
                  color: Colors.white.withValues(
                    alpha: DSStyles.alphaActiveAccent,
                  ),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: DSStyles.cardRadius,
                borderSide: const BorderSide(
                  color: DSColors.primary,
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
              backgroundColor: DSColors.primary,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 50),
              shape: RoundedRectangleBorder(borderRadius: DSStyles.cardRadius),
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
                  borderRadius: DSStyles.pillRadius,
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
                separatorBuilder: (_, _) =>
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
                  final status =
                      d['delivery_status']?.toString() ?? 'FOR_DELIVERY';

                  return ListTile(
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: DSColors.primary.withValues(
                          alpha: DSStyles.alphaSoft,
                        ),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.qr_code_rounded,
                        color: DSColors.primary,
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
                        color: Colors.grey.withValues(
                          alpha: DSStyles.alphaSoft,
                        ),
                        borderRadius: DSStyles.pillRadius,
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
