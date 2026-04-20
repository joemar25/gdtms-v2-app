// DOCS: docs/features/delivery.md — update that file when you edit this one.

// =============================================================================
// delivery_update_screen.dart
// =============================================================================
//
// Purpose:
//   The primary action screen where a courier marks a delivery as DELIVERED,
//   FAILED_DELIVERY (Failed Delivery), or OSA (Out of Serviceable Area). All form data is
//   immediately persisted to the local sync queue — no live network call is
//   made at submission time — making the flow fully offline-capable.
//
// Form fields (vary by status):
//   DELIVERED — Recipient name, relationship, placement type, POD photo,
//               selfie photo, recipient signature (optional), note.
//   FAILED_DELIVERY — Reason, selfie photo, note.
//   OSA             — Reason, selfie photo, note.
//
// Offline-first flow:
//   1. Courier fills the form and taps SUBMIT.
//   2. A [SyncOperation] record is inserted into `delivery_update_queue` with
//      status = "pending". Media paths are stored alongside the payload.
//   3. [SyncManager] picks up the operation next time the device is online and
//      uploads the payload + media to the server.
//   4. On success, rawJson is refreshed from the server response.
//
// Media:
//   Images are compressed to 600 px / quality 70 before queuing.
//   Signatures are captured via [SignatureCaptureScreen] and saved as PNG.
//   Media is uploaded to S3 (or API fallback) during sync.
//
// Navigation:
//   Route: /deliveries/:barcode/update
//   Pushed from: DeliveryDetailScreen (UPDATE FAB)
// =============================================================================

import 'dart:convert';
import 'dart:io';
// 'dart:typed_data' is available through flutter/services when needed

import 'package:flutter/material.dart';

import 'package:flutter/services.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:uuid/uuid.dart';
import 'package:path_provider/path_provider.dart';

import 'package:fsi_courier_app/core/api/api_client.dart';
import 'package:fsi_courier_app/core/services/review_prompt_service.dart';
import 'package:fsi_courier_app/core/services/time_validation_service.dart';
import 'package:fsi_courier_app/core/auth/auth_provider.dart';
import 'package:fsi_courier_app/core/constants.dart';
import 'package:fsi_courier_app/core/models/delivery_status.dart';
import 'package:fsi_courier_app/core/database/local_delivery_dao.dart';
import 'package:fsi_courier_app/core/database/sync_operations_dao.dart';
import 'package:fsi_courier_app/core/models/sync_operation.dart';
import 'package:fsi_courier_app/core/models/photo_entry.dart';
import 'package:fsi_courier_app/core/providers/connectivity_provider.dart';
import 'package:fsi_courier_app/core/providers/delivery_refresh_provider.dart';
import 'package:fsi_courier_app/core/providers/sync_provider.dart';
import 'package:fsi_courier_app/features/delivery/signature_capture_screen.dart';
import 'package:fsi_courier_app/shared/widgets/app_header_bar.dart';
import 'package:fsi_courier_app/features/delivery/widgets/delivery_form_helpers.dart';
import 'package:fsi_courier_app/features/delivery/widgets/delivery_geo_location_field.dart';
import 'package:fsi_courier_app/features/delivery/widgets/delivery_recipient_cards.dart';
import 'package:fsi_courier_app/features/delivery/widgets/searchable_selection_sheet.dart';
import 'package:fsi_courier_app/shared/helpers/api_payload_helper.dart';
import 'package:fsi_courier_app/shared/helpers/delivery_helper.dart';
import 'package:fsi_courier_app/shared/helpers/snackbar_helper.dart';
import 'package:fsi_courier_app/shared/widgets/loading_overlay.dart';
import 'package:fsi_courier_app/shared/widgets/offline_banner.dart';
import 'package:fsi_courier_app/shared/widgets/sync_progress_bar.dart';
import 'package:fsi_courier_app/design_system/design_system.dart';

// ─── Consistent spacing constants ───────────────────────────────────────────
const _kSectionGap = SizedBox(height: 24); // between major sections
const _kFieldGap = SizedBox(height: 12); // between fields within a section
const _kInnerGap = SizedBox(height: 8); // header → first field
const _kPhotoHeight = 160.0; // photo slot height
const _kSignatureHeight = 144.0; // signature slot height

// ─── Status metadata ────────────────────────────────────────────────────────
// Keys are the API string values (from DeliveryStatus.toApiString()) so that
// _kStatusMeta[_status] still works when _status holds the raw API string.
final _kStatusMeta = {
  DeliveryStatus.delivered.toApiString(): (
    label: 'DELIVERED',
    icon: Icons.check_circle_rounded,
    color: const Color(0xFF00B14F),
  ),
  DeliveryStatus.failedDelivery.toApiString(): (
    label: 'FAILED',
    icon: Icons.keyboard_return_rounded,
    color: Colors.purple,
  ),
  DeliveryStatus.osa.toApiString(): (
    label: 'MISROUTED',
    icon: Icons.inbox_rounded,
    color: Colors.amber,
  ),
};

class DeliveryUpdateScreen extends ConsumerStatefulWidget {
  const DeliveryUpdateScreen({super.key, required this.barcode});

  final String barcode;

  @override
  ConsumerState<DeliveryUpdateScreen> createState() =>
      _DeliveryUpdateScreenState();
}

class _DeliveryUpdateScreenState extends ConsumerState<DeliveryUpdateScreen> {
  bool _loadingDelivery = true;
  Map<String, dynamic> _delivery = {};
  final _note = TextEditingController();
  final _recipient = TextEditingController();
  final _relationshipSpecify = TextEditingController();
  final _reasonSpecify = TextEditingController(); // for reason == 'Others'
  final _statusSelectorKey = GlobalKey<_StatusSelectorState>();
  final _errors = <String, String>{};
  final _uuid = const Uuid();

  final _picker = ImagePicker();

  String _status = 'DELIVERED';
  String? _relationship;
  bool _recipientIsOwner = false;
  String _placement = 'RECEIVED';
  String? _reason;
  bool _loading = false;
  bool _isPickerActive = false;
  bool _forcePop = false;
  double _dragStart = 0;

  // ── Typed status helpers ─────────────────────────────────────────────────
  DeliveryStatus get _ds => DeliveryStatus.fromString(_status);
  bool get _isDelivered => _ds == DeliveryStatus.delivered;
  bool get _isFailedDelivery => _ds == DeliveryStatus.failedDelivery;
  bool get _isOsa => _ds == DeliveryStatus.osa;

  /// True for statuses that require a non-delivery reason + selfie.
  bool get _isNonDelivered => _isFailedDelivery || _isOsa;

  void _cycleStatus(int direction) {
    if (_loadingDelivery || _loading) return;
    final statuses = kUpdateStatuses;
    final current = statuses.indexOf(_status);
    if (current < 0) return;
    final next = (current + direction).clamp(0, statuses.length - 1);
    if (next == current) return;
    HapticFeedback.selectionClick();
    _onStatusTap(statuses[next]).then((_) {
      _statusSelectorKey.currentState?.markInteracted();
    });
  }

  // ── Note preset state ────────────────────────────────────────────────────
  /// The preset chip that is currently active (null = none selected / user typed freely).
  String? _activeNotePreset;

  // Delivered-specific: two fixed photo slots (POD + SELFIE)
  PhotoEntry? _podPhoto;
  PhotoEntry? _selfiePhoto;

  // Non-delivered photos (failed delivery / osa) — camera + gallery, free type
  final _photos = <PhotoEntry>[];

  // Signature file path for delivered status
  String? _signaturePath;

  // Signature slot visibility (hidden by default; shown when checkbox is ticked)
  bool _showSignatureSlot = false;

  // "According to" informant name (required for FAILED_DELIVERY reasons with requiresAccordingTo)
  final _accordingTo = TextEditingController();

  // OSA mailpack photo (required for MISROUTED)
  PhotoEntry? _mailpackPhoto;

  // Delivery confirmation code (required for DELIVERED, 6-char alphanumeric, all caps)
  final _confirmationCode = TextEditingController();
  final _confirmationCodeFocus = FocusNode();

  // Geo location
  double? _latitude;
  double? _longitude;
  double? _geoAccuracy;
  bool _gettingLocation = false;

  @override
  void initState() {
    super.initState();
    _loadDelivery();
    _captureLocation();
    _handleLostData(); // Handle cases where Android kills the activity during camera use

    // Listen to text field changes so _isDirty is recalculated immediately
    // when the user types and presses Back without another interaction.
    _note.addListener(_onFieldChanged);
    _recipient.addListener(_onFieldChanged);
    _relationshipSpecify.addListener(_onFieldChanged);
    _reasonSpecify.addListener(_onFieldChanged);
    _accordingTo.addListener(_onFieldChanged);
    _confirmationCode.addListener(_onFieldChanged);
  }

  void _onFieldChanged() {
    // Trigger a rebuild to ensure `_isDirty` is re-evaluated before pop.
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _loadDelivery() async {
    // Try API first if online; fall back to local SQLite.
    final isOnline = ref.read(isOnlineProvider);
    if (isOnline) {
      final result = await ref
          .read(apiClientProvider)
          .get<Map<String, dynamic>>(
            '/deliveries/${widget.barcode}',
            parser: parseApiMap,
          );

      if (!mounted) return;

      if (result case ApiSuccess<Map<String, dynamic>>(:final data)) {
        _delivery = mapFromKey(data, 'data');
        final currentStatus =
            _delivery['delivery_status']?.toString().toUpperCase() ??
            'DELIVERED';
        setState(() {
          if (kUpdateStatuses.contains(currentStatus)) {
            _status = currentStatus;
          }
          _loadingDelivery = false;
        });
        return;
      }
    }

    // Offline fallback.
    final local = await LocalDeliveryDao.instance.getByBarcode(widget.barcode);
    if (!mounted) return;
    if (local != null) {
      _delivery = local.toDeliveryMap();
    }
    final currentStatus =
        _delivery['delivery_status']?.toString().toUpperCase() ?? 'DELIVERED';
    setState(() {
      if (kUpdateStatuses.contains(currentStatus)) {
        _status = currentStatus;
      }
      _loadingDelivery = false;
    });
  }

  @override
  void dispose() {
    _note.removeListener(_onFieldChanged);
    _recipient.removeListener(_onFieldChanged);
    _relationshipSpecify.removeListener(_onFieldChanged);
    _reasonSpecify.removeListener(_onFieldChanged);
    _accordingTo.removeListener(_onFieldChanged);
    _confirmationCode.removeListener(_onFieldChanged);

    _note.dispose();
    _recipient.dispose();
    _relationshipSpecify.dispose();
    _reasonSpecify.dispose();
    _accordingTo.dispose();
    _confirmationCode.dispose();
    _confirmationCodeFocus.dispose();
    super.dispose();
  }

  // ── Geo location ──────────────────────────────────────────────────────────
  Future<void> _captureLocation() async {
    setState(() => _gettingLocation = true);
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          showAppSnackbar(
            context,
            'Please enable GPS / Location Services and try again.',
            type: SnackbarType.error,
          );
        }
        return;
      }

      var status = await Permission.location.status;
      if (status.isDenied) {
        status = await Permission.location.request();
      }
      if (status.isPermanentlyDenied) {
        if (mounted) {
          showAppSnackbar(
            context,
            'Location permission permanently denied. Enable it in Settings.',
            type: SnackbarType.error,
          );
          await openAppSettings();
        }
        return;
      }
      if (!status.isGranted) {
        if (mounted) {
          showAppSnackbar(
            context,
            'Location permission is required to capture your position.',
            type: SnackbarType.error,
          );
        }
        return;
      }

      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      if (mounted) {
        setState(() {
          _latitude = pos.latitude;
          _longitude = pos.longitude;
          _geoAccuracy = pos.accuracy;
        });
      }
    } on LocationServiceDisabledException {
      if (mounted) {
        showAppSnackbar(
          context,
          'GPS is disabled. Please turn on Location Services.',
          type: SnackbarType.error,
        );
      }
    } catch (_) {
      if (mounted) {
        showAppSnackbar(
          context,
          'Could not get location. Ensure GPS is on and try again.',
          type: SnackbarType.error,
        );
      }
    } finally {
      if (mounted) setState(() => _gettingLocation = false);
    }
  }

  // ── Camera Permission ──────────────────────────────────────────────────────
  Future<bool> _handleCameraPermission() async {
    var status = await Permission.camera.status;
    if (status.isGranted) return true;

    if (status.isDenied) {
      status = await Permission.camera.request();
      if (status.isGranted) return true;
    }

    if (status.isPermanentlyDenied) {
      if (mounted) {
        showAppSnackbar(
          context,
          'Camera permission is required. Please enable it in Settings.',
          type: SnackbarType.error,
        );
        await openAppSettings();
      }
      return false;
    }

    if (mounted) {
      showAppSnackbar(
        context,
        'Camera permission is required to take photos.',
        type: SnackbarType.error,
      );
    }
    return false;
  }

  // ── Handle Lost Data (Android) ─────────────────────────────────────────────
  Future<void> _handleLostData() async {
    if (!Platform.isAndroid) return;

    try {
      final response = await _picker.retrieveLostData();
      if (response.isEmpty || response.file == null || !mounted) return;

      // Since we don't know which slot (POD or Selfie) the user was intenting to
      // fill before the activity was killed, we'll try to guess or just
      // notify them. In this screen, POD is usually first, but it's safer to
      // just show a message or let them re-pick if we can't be sure.
      // However, to be helpful, if both are empty, we can put it in POD.

      final rawBytes = await response.file!.readAsBytes();
      await FlutterImageCompress.compressWithList(
        rawBytes,
        minWidth: 600,
        quality: 70,
        format: CompressFormat.jpeg,
      );

      final entry = PhotoEntry(
        id: _uuid.v4(),
        file: response.file!.path,
        type: 'recovered', // Temporary type
      );

      setState(() {
        // Default to POD if empty, otherwise we just have the file ready
        _podPhoto ??= entry.type == 'recovered'
            ? PhotoEntry(id: entry.id, file: entry.file, type: 'pod')
            : entry;
      });

      if (!mounted) return;
      showAppSnackbar(
        context,
        'Successfully recovered image from camera.',
        type: SnackbarType.success,
      );
    } catch (e) {
      debugPrint('Error recovering lost data: $e');
    }
  }

  // ── Pick photo for a pre-defined slot ──────────────────────────────────────
  Future<void> _pickPhotoForSlot(
    String slotType, {
    ImageSource source = ImageSource.camera,
  }) async {
    if (_isPickerActive) return;

    if (source == ImageSource.camera) {
      final hasPermission = await _handleCameraPermission();
      if (!hasPermission) return;
    }

    setState(() => _isPickerActive = true);

    try {
      final isSelfie = slotType == 'selfie';
      final picked = await _picker
          .pickImage(
            source: source,
            preferredCameraDevice: isSelfie
                ? CameraDevice.front
                : CameraDevice.rear,
          )
          .timeout(const Duration(seconds: 30));

      if (picked == null || !mounted) {
        setState(() => _isPickerActive = false);
        return;
      }

      final rawBytes = await picked.readAsBytes();

      // Compression can sometimes fail on certain devices or in release mode
      // due to Proguard/native issues. Wrap in try-catch to allow fallback.
      Uint8List bytes;
      try {
        bytes = await FlutterImageCompress.compressWithList(
          rawBytes,
          minWidth: 600,
          quality: 70,
          format: CompressFormat.jpeg,
        );
      } catch (e) {
        debugPrint('Image compression failed: $e');
        bytes = rawBytes; // Fallback to original bytes
      }

      if (bytes.isEmpty || !mounted) {
        setState(() => _isPickerActive = false);
        return;
      }

      // Map slot names to standard backend media types.
      final apiType = slotType == 'pod' ? 'pod' : 'selfie';

      final dir = await getApplicationDocumentsDirectory();
      final filename = '${widget.barcode}_${_uuid.v4()}_$apiType.jpg';
      final path = '${dir.path}/$filename';
      await File(path).writeAsBytes(bytes);

      final entry = PhotoEntry(id: _uuid.v4(), file: path, type: apiType);
      if (!mounted) return;
      setState(() {
        if (slotType == 'pod') {
          _podPhoto = entry;
          _errors.remove('pod_photo');
        } else if (slotType == 'mailpack') {
          _mailpackPhoto = entry;
          _errors.remove('mailpack_photo');
        } else {
          _selfiePhoto = entry;
          _errors.remove('selfie_photo');
        }
        _isPickerActive = false;
      });
    } on PlatformException catch (e) {
      setState(() => _isPickerActive = false);
      if (e.code == 'already_active') return;

      if (mounted) {
        showAppSnackbar(
          context,
          'Camera Error (${e.code}): ${e.message}',
          type: SnackbarType.error,
        );
      }
    } catch (e) {
      setState(() => _isPickerActive = false);
      if (mounted) {
        showAppSnackbar(
          context,
          'Failed to capture photo: ${e.toString()}',
          type: SnackbarType.error,
        );
      }
    }
  }

  // ── Selfie picker for failed delivery/osa — forces Camera ────────────────
  Future<void> _pickSelfieForFailedDeliveryOsa() async {
    await _pickPhotoForSlot('selfie', source: ImageSource.camera);
  }

  // ── Open landscape signature capture screen ───────────────────────────────
  Future<void> _openSignatureCapture() async {
    final bytes = await Navigator.push<Uint8List?>(
      context,
      MaterialPageRoute(builder: (_) => const SignatureCaptureScreen()),
    );
    if (bytes != null && mounted) {
      final dir = await getApplicationDocumentsDirectory();
      final filename = '${widget.barcode}_${_uuid.v4()}_signature.png';
      final path = '${dir.path}/$filename';
      await File(path).writeAsBytes(bytes);

      setState(() {
        _signaturePath = path;
        _errors.remove('recipient_signature');
      });
    }
  }

  // ── Philippine Standard Time helpers ─────────────────────────────────────
  static DateTime _pstNow() =>
      DateTime.now().toUtc().add(const Duration(hours: 8));

  static String _getCurrentDateTimePST() {
    final now = _pstNow();
    return DateFormat("MMMM d, yyyy 'at' h:mm a").format(now);
  }

  // ── Validation ────────────────────────────────────────────────────────────
  bool _validate() {
    _errors.clear();

    if (!kUpdateStatuses.contains(_status.toUpperCase())) {
      _errors['delivery_status'] = 'Invalid status.';
    }

    if (_note.text.length > kMaxNoteLength) {
      _errors['note'] = 'Note must not exceed $kMaxNoteLength characters.';
    }

    if (_isDelivered) {
      if (_recipient.text.trim().isEmpty) {
        _errors['recipient'] = 'This field is required.';
      }
      if (_relationship == null || _relationship!.isEmpty) {
        _errors['relationship'] = 'Relationship is required.';
      } else if (_relationship == 'OTHERS' &&
          _relationshipSpecify.text.trim().isEmpty) {
        _errors['relationship_specify'] = 'Please specify the relationship.';
      }
      if (_placement.isEmpty) {
        _errors['placement'] = 'Placement type is required.';
      }
      if (_podPhoto == null) {
        _errors['pod_photo'] = 'POD photo is required.';
      }
      if (_selfiePhoto == null) {
        _errors['selfie_photo'] = 'Selfie photo is required.';
      }
      if (_confirmationCode.text.trim().isEmpty) {
        _errors['confirmation_code'] =
            'Delivery confirmation code is required.';
      }
    }

    if (_isOsa) {
      if (_mailpackPhoto == null) {
        _errors['mailpack_photo'] = 'Mailpack photo is required.';
      }
    }

    if (_isFailedDelivery) {
      if (_reason == null || _reason!.isEmpty) {
        _errors['reason'] = 'Reason is required.';
      } else if (_reason == 'Others' && _reasonSpecify.text.trim().isEmpty) {
        _errors['reason_specify'] = 'Please specify the reason.';
      }
      if (_selfiePhoto == null) {
        _errors['selfie_photo'] = 'Selfie photo is required.';
      }
      final config = kReasonConfigs[_reason] ?? const ReasonConfig();
      if (config.requiresAccordingTo && _accordingTo.text.trim().isEmpty) {
        _errors['according_to'] = 'Informant name is required.';
      }
    }

    setState(() {});
    return _errors.isEmpty;
  }

  // ── Submit ────────────────────────────────────────────────────────────────
  Future<void> _submit() async {
    if (!_validate()) return;

    setState(() => _loading = true);

    // Prevent submission if the delivery is already locked (including attempts >= 3)
    if (checkIsLockedFromMap(_delivery)) {
      setState(() => _loading = false);
      showInfoNotification(
        context,
        'This delivery is locked and cannot be updated.',
      );
      return;
    }

    // Reject if device clock is behind the last sync anchor — a backdated
    // submission would create a delivery timeline that goes backwards.
    final timeCheck = await TimeValidationService.instance
        .checkSubmissionTime();
    if (!mounted) return;
    if (!timeCheck.valid) {
      setState(() => _loading = false);
      showErrorNotification(context, timeCheck.reason!);
      return;
    }

    final courierId = ref.read(authProvider).courier?['id']?.toString() ?? '';
    final isOnline = ref.read(isOnlineProvider);

    // Resolve final reason string: if 'Others', use the specify field value.
    final String? resolvedReason = _reason == 'Others'
        ? _reasonSpecify.text.trim().toUpperCase()
        : _reason?.toUpperCase();

    // Resolve final relationship string: if 'OTHERS', use the specify field value.
    final String? resolvedRelationship = _relationship == 'OTHERS'
        ? _relationshipSpecify.text.trim().toUpperCase()
        : _relationship;

    final now = DateTime.now();

    // Format delivered_date as Philippine Standard Time with explicit +08:00
    // offset to avoid server-side timezone misinterpretation.
    final pst = now.toUtc().add(const Duration(hours: 8));
    String two(int n) => n.toString().padLeft(2, '0');
    String three(int n) => n.toString().padLeft(3, '0');
    final deliveredDatePst =
        '${pst.year.toString().padLeft(4, '0')}-${two(pst.month)}-${two(pst.day)}T${two(pst.hour)}:${two(pst.minute)}:${two(pst.second)}.${three(pst.millisecond)}+08:00';

    final payload = <String, dynamic>{
      'delivery_status': _status.toUpperCase(),
      'delivered_date': deliveredDatePst,
      if (_note.text.trim().isNotEmpty) 'note': _note.text.trim(),
    };

    if (_latitude != null && _longitude != null) {
      payload['latitude'] = _latitude;
      payload['longitude'] = _longitude;
      if (_geoAccuracy != null) {
        payload['geo_accuracy'] = _geoAccuracy;
      }
    }

    final pendingMediaPaths = <String, String>{};

    if (_isDelivered) {
      if (_podPhoto != null) {
        pendingMediaPaths['pod'] = _podPhoto!.file;
      }
      if (_selfiePhoto != null) {
        pendingMediaPaths['selfie'] = _selfiePhoto!.file;
      }
      if (_signaturePath != null) {
        pendingMediaPaths['recipient_signature'] = _signaturePath!;
      }
      payload['recipient'] = _recipient.text.trim();
      payload['relationship'] = resolvedRelationship;
      payload['placement_type'] = _placement;
      payload['delivery_confirmation_code'] = _confirmationCode.text.trim();
    } else if (_isOsa) {
      if (_mailpackPhoto != null) {
        pendingMediaPaths['mailpack'] = _mailpackPhoto!.file;
      }
    } else if (_isFailedDelivery) {
      payload['reason'] = resolvedReason;
      if (_selfiePhoto != null) {
        pendingMediaPaths['selfie'] = _selfiePhoto!.file;
      }
      final config = kReasonConfigs[_reason] ?? const ReasonConfig();
      if (config.requiresAccordingTo && _accordingTo.text.trim().isNotEmpty) {
        payload['according_to'] = _accordingTo.text.trim();
      }
    }

    // Include any additional photos captured in the generic _photos list.
    for (var i = 0; i < _photos.length; i++) {
      final photo = _photos[i];
      // Use a suffix for duplicate types to keep keys unique in the map.
      final key = photo.type + (i > 0 ? '_$i' : '');
      pendingMediaPaths[key] = photo.file;
    }

    final opId = const Uuid().v4();
    final nowMs = now.millisecondsSinceEpoch;
    await SyncOperationsDao.instance.insert(
      SyncOperation(
        id: opId,
        courierId: courierId,
        barcode: widget.barcode,
        operationType: 'UPDATE_STATUS',
        payloadJson: jsonEncode(payload),
        mediaPathsJson: pendingMediaPaths.isNotEmpty
            ? jsonEncode(pendingMediaPaths)
            : null,
        status: 'pending',
        createdAt: nowMs,
      ),
    );

    await LocalDeliveryDao.instance.updateStatus(widget.barcode, _status);

    if (isOnline) {
      // ignore: unawaited_futures
      ref.read(syncManagerProvider.notifier).processQueue();
    }

    if (!mounted) return;
    ref.read(deliveryRefreshProvider.notifier).increment();
    setState(() => _loading = false);
    showSuccessNotification(context, 'Delivery status updated successfully.');
    // Fire-and-forget: may trigger the native in-app review sheet.
    ReviewPromptService.instance.onDeliveryCompleted();
    context.go('/dashboard');
  }

  void _clearDeliveredFields() {
    _recipient.clear();
    _relationshipSpecify.clear();
    _relationship = null;
    _recipientIsOwner = false;
    _placement = 'RECEIVED';
    _podPhoto = null;
    _selfiePhoto = null;
    _signaturePath = null;
    _showSignatureSlot = false;
    _confirmationCode.clear();
    _confirmationCodeFocus.unfocus();
    _photos.clear();
    _errors.clear();
  }

  void _clearNonDeliveredFields() {
    _reason = null;
    _reasonSpecify.clear();
    _accordingTo.clear();
    _selfiePhoto = null;
    _mailpackPhoto = null;
    _photos.clear();
    _errors.clear();
  }

  Future<void> _onStatusTap(String newStatus) async {
    if (newStatus == _status) return;

    final bool hasDeliveredData =
        _recipient.text.isNotEmpty ||
        _relationship != null ||
        _podPhoto != null ||
        _selfiePhoto != null ||
        _signaturePath != null;

    final bool hasNonDeliveredData =
        _reason != null || _selfiePhoto != null || _photos.isNotEmpty;

    if (_isDelivered && hasDeliveredData) {
      final confirmed = await _showSwitchConfirmDialog(
        context,
        from: 'DELIVERED',
        to: newStatus,
        detail: 'recipient info, photos, and signature',
      );
      if (confirmed != true || !mounted) return;
      _clearDeliveredFields();
    } else if ((_isNonDelivered) && hasNonDeliveredData) {
      final confirmed = await _showSwitchConfirmDialog(
        context,
        from: _status,
        to: newStatus,
        detail: 'reason and selfie photo',
      );
      if (confirmed != true || !mounted) return;
      _clearNonDeliveredFields();
    }

    setState(() => _status = newStatus);
  }

  Future<bool?> _showSwitchConfirmDialog(
    BuildContext context, {
    required String from,
    required String to,
    required String detail,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(
          'SWITCH STATUS?',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
        ),
        content: Text(
          'You have already filled in $detail for $from. '
          'Switching to $to will clear all of that data.\n\n'
          'Are you sure you want to continue?',
          style: const TextStyle(fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('CANCEL'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('YES, SWITCH'),
          ),
        ],
      ),
    );
  }

  // ── Searchable Pickers ─────────────────────────────────────────────────────

  Future<void> _openRelationshipPicker() async {
    if (_recipientIsOwner) return;

    final options = kRelationshipOptions
        .where((e) => _recipientIsOwner || e['value'] != 'OWNER')
        .toList();

    final result = await SearchableSelectionSheet.show<String>(
      context: context,
      title: 'SELECT RELATIONSHIP',
      options: options,
      initialValue: _relationship,
    );

    if (result != null && mounted) {
      setState(() {
        _relationship = result;
        _relationshipSpecify.clear();
        _errors.remove('relationship');
        _errors.remove('relationship_specify');
      });
    }
  }

  Future<void> _openReasonPicker() async {
    final result = await SearchableSelectionSheet.show<String>(
      context: context,
      title: 'SELECT REASON',
      options: kReasons,
      initialValue: _reason,
    );

    if (result != null && mounted) {
      setState(() {
        _reason = result;
        _reasonSpecify.clear();
        _errors.remove('reason');
        _errors.remove('reason_specify');
      });
    }
  }

  // ─── Build helpers ────────────────────────────────────────────────────────

  /// Horizontal scrollable row of preset chips shown above the Remarks field.
  /// Tapping a chip pre-fills the note with the preset text (and positions the
  /// cursor at the end so the courier can immediately extend it).
  /// Tapping the active chip again clears both the selection and the field.
  Widget _buildNotePresets(bool isDark) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Builder(
            builder: (context) {
              final List<String> presets;
              if (_isDelivered) {
                presets = kDeliveredNotePresets;
              } else if (_isOsa) {
                presets = kOsaConfig.remarksPresets;
              } else {
                presets = (_reason != null
                        ? kReasonConfigs[_reason]?.remarksPresets
                        : null) ??
                    [];
              }
              return Row(
                children: [
                  for (final preset in presets) ...[
                    _NotePresetChip(
                      label: preset,
                      selected: _activeNotePreset == preset,
                      isDark: isDark,
                      onTap: () {
                        setState(() {
                          if (_activeNotePreset == preset) {
                            // Second tap → deselect and clear only if the note still
                            // matches the preset (user may have extended it).
                            _activeNotePreset = null;
                            if (_note.text == preset) _note.clear();
                          } else {
                            _activeNotePreset = preset;
                            // Replace current text with the preset, cursor at end.
                            _note.value = TextEditingValue(
                              text: preset,
                              selection: TextSelection.collapsed(
                                offset: preset.length,
                              ),
                            );
                          }
                        });
                      },
                    ),
                    const SizedBox(width: 8),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  /// Clickable box for POD / SELFIE photo slots.
  Widget _buildPhotoSlot({
    required String slotType,
    required String label,
    required PhotoEntry? photo,
    required IconData icon,
    required Color color,
    required bool isDark,
    VoidCallback? onTapOverride,
  }) {
    final hasPhoto = photo != null;
    final errorKey = slotType == 'pod'
        ? 'pod_photo'
        : slotType == 'mailpack'
        ? 'mailpack_photo'
        : 'selfie_photo';
    final hasError = _errors[errorKey] != null;

    return Expanded(
      child: GestureDetector(
        onTap: onTapOverride ?? () => _pickPhotoForSlot(slotType),
        child: Container(
          height: _kPhotoHeight,
          decoration: BoxDecoration(
            color: hasPhoto
                ? Colors.transparent
                : (isDark ? DSColors.elevatedCardDark : Colors.white),
            borderRadius: DSStyles.cardRadius,
            border: Border.all(
              color: hasError
                  ? Colors.red
                  : hasPhoto
                  ? (isDark ? Colors.white10 : Colors.grey.shade200)
                  : color.withValues(alpha: DSStyles.alphaBorder),
              width: hasError ? 1.5 : 1.2,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            switchInCurve: Curves.easeOutBack,
            switchOutCurve: Curves.easeInBack,
            child: hasPhoto
                ? Stack(
                    key: const ValueKey('has_photo'),
                    fit: StackFit.expand,
                    children: [
                      Image.file(
                        File(photo.file),
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => Container(
                          color: isDark ? Colors.white10 : Colors.grey.shade100,
                          child: Icon(
                            Icons.broken_image_rounded,
                            size: 32,
                            color: Colors.grey.shade400,
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        child: Container(
                          color: Colors.black54,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                label,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: () => setState(() {
                                  if (slotType == 'pod') {
                                    _podPhoto = null;
                                  } else if (slotType == 'mailpack') {
                                    _mailpackPhoto = null;
                                  } else {
                                    _selfiePhoto = null;
                                  }
                                }),
                                child: const Padding(
                                  padding: EdgeInsets.all(4),
                                  child: Icon(
                                    Icons.delete_outline_rounded,
                                    size: 16,
                                    color: Colors.redAccent,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  )
                : Column(
                    key: const ValueKey('no_photo'),
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(icon, size: 34, color: color),
                      const SizedBox(height: 10),
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: color,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'TAP TO CAPTURE',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.grey.shade500,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  /// Clickable box for the recipient signature.
  Widget _buildSignatureSlot(bool isDark) {
    final hasSignature = _signaturePath != null;
    final hasError = _errors['recipient_signature'] != null;

    return GestureDetector(
      onTap: _openSignatureCapture,
      child: Container(
        height: _kSignatureHeight,
        decoration: BoxDecoration(
          borderRadius: DSStyles.cardRadius,
          border: Border.all(
            color: hasError
                ? Colors.red
                : hasSignature
                ? (isDark ? Colors.white10 : Colors.grey.shade200)
                : DSColors.primary.withValues(alpha: DSStyles.alphaBorder),
            width: hasError ? 1.5 : 1.2,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          switchInCurve: Curves.easeOutBack,
          switchOutCurve: Curves.easeInBack,
          child: hasSignature
              ? Stack(
                  key: const ValueKey('has_signature'),
                  fit: StackFit.expand,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Image.file(
                        File(_signaturePath!),
                        fit: BoxFit.contain,
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: Container(
                        color: Colors.black54,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'SIGNATURE',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.5,
                              ),
                            ),
                            Row(
                              children: [
                                GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onTap: _openSignatureCapture,
                                  child: const Padding(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    child: Text(
                                      'RE-SIGN',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white70,
                                      ),
                                    ),
                                  ),
                                ),
                                GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onTap: () =>
                                      setState(() => _signaturePath = null),
                                  child: const Padding(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    child: Text(
                                      'CLEAR',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.redAccent,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                )
              : Column(
                  key: const ValueKey('no_signature'),
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.draw_rounded,
                      size: 34,
                      color: DSColors.primary.withValues(
                        alpha: DSStyles.alphaGlass,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'SIGNATURE',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: DSColors.primary.withValues(
                          alpha: DSStyles.alphaGlass,
                        ),
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'TAP TO SIGN (OPTIONAL)',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey.shade500,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  bool get _isDirty {
    // Compare against the loaded delivery's initial status so the form isn't
    // considered dirty just because the delivery wasn't DELIVERED to begin
    // with (e.g. FAILED or MISROUTED).
    final initialStatus =
        _delivery['delivery_status']?.toString().toUpperCase() ?? 'DELIVERED';
    return _status != initialStatus ||
        _recipient.text.isNotEmpty ||
        _note.text.isNotEmpty ||
        _relationship != null ||
        _relationshipSpecify.text.isNotEmpty ||
        _reason != null ||
        _reasonSpecify.text.isNotEmpty ||
        _accordingTo.text.isNotEmpty ||
        _podPhoto != null ||
        _selfiePhoto != null ||
        _mailpackPhoto != null ||
        _photos.isNotEmpty ||
        _signaturePath != null ||
        _confirmationCode.text.isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isOnline = ref.read(isOnlineProvider);

    return PopScope(
      canPop: _forcePop || !_isDirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final leave = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Discard changes?'),
            content: const Text(
              'You have unsaved changes. Leave without submitting?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('STAY'),
              ),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text(
                  'DISCARD',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ],
          ),
        );
        if (leave == true && context.mounted) {
          setState(() => _forcePop = true);
          context.pop();
        }
      },
      child: Scaffold(
        // Inherits scaffoldBackgroundColor from global theme.
        // We only override if it needs to be different from the page default.
        floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
        floatingActionButton: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: FilledButton.icon(
            icon: _loading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.check_circle_outline_rounded),
            label: const Text(
              'SUBMIT UPDATE',
              style: TextStyle(fontWeight: FontWeight.w700, letterSpacing: 0.8),
            ),
            style: FilledButton.styleFrom(
              backgroundColor: DSColors.primary,
              minimumSize: const Size(double.infinity, 56),
              shape: RoundedRectangleBorder(borderRadius: DSStyles.cardRadius),
              elevation: 6,
              shadowColor: DSColors.primary.withValues(
                alpha: DSStyles.alphaBorder,
              ),
            ),
            onPressed: _loading ? null : _submit,
          ),
        ),
        appBar: AppHeaderBar(
          titleWidget: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'UPDATE STATUS',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.0,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
              Text(
                widget.barcode,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  color: isDark ? Colors.white54 : Colors.grey.shade500,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          backgroundColor: isDark ? DSColors.appBarDark : DSColors.appBarLight,
        ),
        body: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onHorizontalDragStart: (d) => _dragStart = d.localPosition.dx,
          onHorizontalDragEnd: (d) {
            final delta = d.localPosition.dx - _dragStart;
            if (delta.abs() > 30) {
              _cycleStatus(delta < 0 ? 1 : -1);
            }
          },
          child: Column(
            children: [
              Expanded(
                child: LoadingOverlay(
                  isLoading: _loading,
                  child: Stack(
                    children: [
                      _loadingDelivery
                          ? const Column(
                              children: [
                                SyncProgressBar(),
                                Expanded(
                                  child: Center(
                                    child: CircularProgressIndicator(),
                                  ),
                                ),
                              ],
                            )
                          : ListView(
                              padding: const EdgeInsets.fromLTRB(
                                16,
                                16,
                                16,
                                100,
                              ),
                              children: [
                                // ── Offline Banner ──────────────────────────────
                                if (!isOnline)
                                  const OfflineBanner(
                                    isMinimal: true,
                                    customMessage:
                                        'Update queued—will submit when online',
                                    margin: EdgeInsets.only(bottom: 20),
                                  ),

                                // ── STATUS SELECTION ────────────────────────────
                                const DeliverySectionHeader(
                                  label: 'SELECT STATUS',
                                ),
                                _kInnerGap,
                                _StatusSelector(
                                  key: _statusSelectorKey,
                                  currentStatus: _status,
                                  onStatusChanged: _onStatusTap,
                                ),
                                if (_errors['delivery_status'] != null)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 6),
                                    child: Text(
                                      _errors['delivery_status']!,
                                      style: const TextStyle(
                                        color: Colors.red,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),

                                // ── RECIPIENT INFO (delivered only) ─────────────
                                if (_isDelivered) ...[
                                  _kSectionGap,
                                  const DeliverySectionHeader(
                                    label: 'RECIPIENT INFO',
                                  ),
                                  _kInnerGap,
                                  DeliveryRecipientCards(
                                    recipientName:
                                        _delivery['name']?.toString() ?? '',
                                    authorizedRep:
                                        _delivery['authorized_rep']
                                            ?.toString() ??
                                        '',
                                    onSelectRecipient: (name, relationship) {
                                      _recipient.text = name;
                                      setState(() {
                                        _relationship = relationship;
                                        _recipientIsOwner =
                                            relationship == 'OWNER';
                                        _errors.remove('recipient');
                                        _errors.remove('relationship');
                                      });
                                    },
                                  ),
                                  _kFieldGap,

                                  ValueListenableBuilder<TextEditingValue>(
                                    valueListenable: _recipient,
                                    builder: (context, value, _) => TextFormField(
                                      controller: _recipient,
                                      readOnly: _recipientIsOwner,
                                      maxLength: kMaxRecipientLength,
                                      maxLengthEnforcement:
                                          MaxLengthEnforcement.enforced,
                                      buildCounter:
                                          (
                                            _, {
                                            required currentLength,
                                            required isFocused,
                                            maxLength,
                                          }) => null,
                                      textCapitalization:
                                          TextCapitalization.characters,
                                      inputFormatters: [
                                        TextInputFormatter.withFunction(
                                          (oldValue, newValue) =>
                                              newValue.copyWith(
                                                text: newValue.text
                                                    .toUpperCase(),
                                              ),
                                        ),
                                      ],
                                      onChanged: (_) {
                                        if (_recipientIsOwner) {
                                          setState(() {
                                            _recipientIsOwner = false;
                                            _relationship = null;
                                          });
                                        }
                                      },
                                      decoration:
                                          deliveryFieldDecoration(
                                            context,
                                            labelText: _recipientIsOwner
                                                ? 'RECIPIENT NAME (LOCKED — OWNER)'
                                                : 'RECIPIENT NAME',
                                            errorText: _errors['recipient'],
                                          ).copyWith(
                                            suffixIcon: value.text.isNotEmpty
                                                ? IconButton(
                                                    icon: const Icon(
                                                      Icons.clear_rounded,
                                                      size: 18,
                                                    ),
                                                    color: Colors.grey.shade500,
                                                    onPressed: () {
                                                      _recipient.clear();
                                                      setState(() {
                                                        _recipientIsOwner =
                                                            false;
                                                        _relationship = null;
                                                      });
                                                    },
                                                  )
                                                : null,
                                          ),
                                    ),
                                  ),
                                  _kFieldGap,

                                  GestureDetector(
                                    onTap: _recipientIsOwner
                                        ? null
                                        : _openRelationshipPicker,
                                    child: AbsorbPointer(
                                      child: TextFormField(
                                        key: ValueKey(_relationship),
                                        initialValue: kRelationshipOptions
                                            .firstWhere(
                                              (e) =>
                                                  e['value'] == _relationship,
                                              orElse: () => {'label': ''},
                                            )['label'],
                                        decoration:
                                            deliveryFieldDecoration(
                                              context,
                                              labelText: _recipientIsOwner
                                                  ? 'RELATIONSHIP (LOCKED — OWNER)'
                                                  : 'RELATIONSHIP',
                                              errorText:
                                                  _errors['relationship'],
                                            ).copyWith(
                                              suffixIcon: Icon(
                                                Icons.search_rounded,
                                                size: 20,
                                                color: Colors.grey.shade500,
                                              ),
                                            ),
                                      ),
                                    ),
                                  ),

                                  // ── OTHERS → specify relationship ─────────────
                                  if (_relationship == 'OTHERS') ...[
                                    _kFieldGap,
                                    TextFormField(
                                      controller: _relationshipSpecify,
                                      decoration:
                                          deliveryFieldDecoration(
                                            context,
                                            labelText: 'SPECIFY RELATIONSHIP',
                                            errorText:
                                                _errors['relationship_specify'],
                                          ).copyWith(
                                            prefixIcon: const Icon(
                                              Icons.edit_note_rounded,
                                              size: 20,
                                            ),
                                          ),
                                      textCapitalization:
                                          TextCapitalization.characters,
                                      maxLength: kMaxRelationshipLength,
                                      maxLengthEnforcement:
                                          MaxLengthEnforcement.enforced,
                                      buildCounter:
                                          (
                                            _, {
                                            required currentLength,
                                            required isFocused,
                                            maxLength,
                                          }) => null,
                                      onChanged: (v) => setState(
                                        () => _errors.remove(
                                          'relationship_specify',
                                        ),
                                      ),
                                    ),
                                  ],

                                  // ── Delivery confirmation code (required) ──────
                                  _kFieldGap,
                                  ValueListenableBuilder<TextEditingValue>(
                                    valueListenable: _confirmationCode,
                                    builder: (context, value, _) => TextFormField(
                                      controller: _confirmationCode,
                                      focusNode: _confirmationCodeFocus,
                                      maxLength: 6,
                                      maxLengthEnforcement:
                                          MaxLengthEnforcement.enforced,
                                      buildCounter:
                                          (
                                            _, {
                                            required currentLength,
                                            required isFocused,
                                            maxLength,
                                          }) => null,
                                      textCapitalization:
                                          TextCapitalization.characters,
                                      inputFormatters: [
                                        TextInputFormatter.withFunction(
                                          (old, newVal) => newVal.copyWith(
                                            text: newVal.text.toUpperCase(),
                                          ),
                                        ),
                                        FilteringTextInputFormatter.allow(
                                          RegExp(r'[A-Z0-9]'),
                                        ),
                                      ],
                                      keyboardType: TextInputType.text,
                                      decoration:
                                          deliveryFieldDecoration(
                                            context,
                                            labelText:
                                                'DELIVERY CONFIRMATION CODE',
                                            hintText: 'e.g. AB1C2D',
                                            errorText:
                                                _errors['confirmation_code'],
                                          ).copyWith(
                                            suffixIcon: value.text.isNotEmpty
                                                ? IconButton(
                                                    icon: const Icon(
                                                      Icons.clear_rounded,
                                                      size: 18,
                                                    ),
                                                    color: Colors.grey.shade500,
                                                    onPressed: () => setState(
                                                      () => _confirmationCode
                                                          .clear(),
                                                    ),
                                                  )
                                                : null,
                                          ),
                                      onChanged: (_) => setState(
                                        () =>
                                            _errors.remove('confirmation_code'),
                                      ),
                                    ),
                                  ),

                                  _kFieldGap,
                                  DropdownButtonFormField<String>(
                                    initialValue: _placement,
                                    decoration: deliveryFieldDecoration(
                                      context,
                                      labelText: 'PLACEMENT TYPE',
                                      errorText: _errors['placement'],
                                    ),
                                    items: kPlacementOptions
                                        .map(
                                          (e) => DropdownMenuItem(
                                            value: e['value'],
                                            child: Text(e['label']!),
                                          ),
                                        )
                                        .toList(),
                                    onChanged: (v) => setState(
                                      () => _placement = v ?? _placement,
                                    ),
                                  ),
                                ],

                                // ── REASON FOR NON-DELIVERY (failed delivery only) ──────
                                if (_isFailedDelivery) ...[
                                  _kSectionGap,
                                  const DeliverySectionHeader(
                                    label: 'REASON FOR NON-DELIVERY',
                                  ),
                                  _kInnerGap,
                                  GestureDetector(
                                    onTap: _openReasonPicker,
                                    child: AbsorbPointer(
                                      child: TextFormField(
                                        key: ValueKey(_reason),
                                        initialValue: _reason,
                                        decoration:
                                            deliveryFieldDecoration(
                                              context,
                                              labelText: 'SELECT REASON',
                                              errorText: _errors['reason'],
                                            ).copyWith(
                                              suffixIcon: Icon(
                                                Icons.search_rounded,
                                                size: 20,
                                                color: Colors.grey.shade500,
                                              ),
                                            ),
                                      ),
                                    ),
                                  ),

                                  // ── Others → specify reason ───────────────────
                                  if (_reason == 'Others') ...[
                                    _kFieldGap,
                                    TextFormField(
                                      controller: _reasonSpecify,
                                      decoration:
                                          deliveryFieldDecoration(
                                            context,
                                            labelText: 'SPECIFY REASON',
                                            hintText:
                                                'e.g. GATE IS LOCKED, NO CONTACT NUMBER',
                                            errorText:
                                                _errors['reason_specify'],
                                          ).copyWith(
                                            prefixIcon: const Icon(
                                              Icons.edit_note_rounded,
                                              size: 20,
                                            ),
                                          ),
                                      textCapitalization:
                                          TextCapitalization.characters,
                                      maxLength: kMaxReasonLength,
                                      maxLengthEnforcement:
                                          MaxLengthEnforcement.enforced,
                                      buildCounter:
                                          (
                                            _, {
                                            required currentLength,
                                            required isFocused,
                                            maxLength,
                                          }) => null,
                                      onChanged: (v) => setState(
                                        () => _errors.remove('reason_specify'),
                                      ),
                                    ),
                                  ],

                                  // ── According to (informant name) ─────────────
                                  if (_reason != null &&
                                      (kReasonConfigs[_reason]
                                              ?.requiresAccordingTo ??
                                          false)) ...[
                                    _kFieldGap,
                                    TextFormField(
                                      controller: _accordingTo,
                                      decoration:
                                          deliveryFieldDecoration(
                                            context,
                                            labelText:
                                                'ACCORDING TO (NAME OF INFORMANT)',
                                            hintText: 'e.g. GUARD, NEIGHBOR',
                                            errorText:
                                                _errors['according_to'],
                                          ).copyWith(
                                            prefixIcon: const Icon(
                                              Icons.person_outline_rounded,
                                              size: 20,
                                            ),
                                          ),
                                      textCapitalization:
                                          TextCapitalization.characters,
                                      inputFormatters: [
                                        TextInputFormatter.withFunction(
                                          (old, newVal) => newVal.copyWith(
                                            text: newVal.text.toUpperCase(),
                                          ),
                                        ),
                                      ],
                                      maxLength: 255,
                                      maxLengthEnforcement:
                                          MaxLengthEnforcement.enforced,
                                      buildCounter:
                                          (
                                            _, {
                                            required currentLength,
                                            required isFocused,
                                            maxLength,
                                          }) => null,
                                      onChanged: (_) => setState(
                                        () => _errors.remove('according_to'),
                                      ),
                                    ),
                                  ],
                                ],

                                // ── PROOF OF DELIVERY (delivered) ────────────────
                                if (_isDelivered) ...[
                                  _kSectionGap,
                                  const DeliverySectionHeader(
                                    label: 'PROOF OF DELIVERY PHOTOS',
                                  ),
                                  _kInnerGap,
                                  Row(
                                    children: [
                                      _buildPhotoSlot(
                                        slotType: 'pod',
                                        label: 'POD',
                                        photo: _podPhoto,
                                        icon: Icons.inventory_2_rounded,
                                        color: DSColors.primary,
                                        isDark: isDark,
                                      ),
                                      const SizedBox(width: 12),
                                      _buildPhotoSlot(
                                        slotType: 'selfie',
                                        label: 'SELFIE',
                                        photo: _selfiePhoto,
                                        icon: Icons.face_rounded,
                                        color: Colors.blueGrey,
                                        isDark: isDark,
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  // ── Signature checkbox ─────────────────────
                                  Row(
                                    children: [
                                      Checkbox(
                                        value: _showSignatureSlot,
                                        activeColor: DSColors.primary,
                                        onChanged: (checked) async {
                                          if (checked == true) {
                                            final confirmed = await showDialog<bool>(
                                              context: context,
                                              builder: (ctx) => AlertDialog(
                                                title: const Text(
                                                  'ADD SIGNATURE?',
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.w800,
                                                    fontSize: 15,
                                                  ),
                                                ),
                                                content: const Text(
                                                  'Do you want to capture the recipient\'s signature?',
                                                  style: TextStyle(
                                                    fontSize: 13,
                                                  ),
                                                ),
                                                actions: [
                                                  TextButton(
                                                    onPressed: () =>
                                                        Navigator.of(
                                                          ctx,
                                                        ).pop(false),
                                                    child: const Text('CANCEL'),
                                                  ),
                                                  FilledButton(
                                                    style:
                                                        FilledButton.styleFrom(
                                                          backgroundColor:
                                                              DSColors.primary,
                                                        ),
                                                    onPressed: () =>
                                                        Navigator.of(
                                                          ctx,
                                                        ).pop(true),
                                                    child: const Text('YES'),
                                                  ),
                                                ],
                                              ),
                                            );
                                            if (confirmed == true && mounted) {
                                              setState(
                                                () => _showSignatureSlot = true,
                                              );
                                            }
                                          } else {
                                            setState(() {
                                              _showSignatureSlot = false;
                                              _signaturePath = null;
                                            });
                                          }
                                        },
                                      ),
                                      const Text(
                                        'Include recipient signature',
                                        style: TextStyle(fontSize: 13),
                                      ),
                                    ],
                                  ),
                                  if (_showSignatureSlot) ...[
                                    const SizedBox(height: 8),
                                    _buildSignatureSlot(isDark),
                                  ],
                                ],

                                // ── MAILPACK PHOTO (misrouted / osa) ─────────────────
                                if (_isOsa) ...[
                                  _kSectionGap,
                                  const DeliverySectionHeader(
                                    label: 'MAILPACK PHOTO',
                                  ),
                                  _kInnerGap,
                                  Row(
                                    children: [
                                      _buildPhotoSlot(
                                        slotType: 'mailpack',
                                        label: 'MAILPACK',
                                        photo: _mailpackPhoto,
                                        icon: Icons.inventory_2_rounded,
                                        color: Colors.amber,
                                        isDark: isDark,
                                        onTapOverride: () =>
                                            _pickPhotoForSlot('mailpack'),
                                      ),
                                    ],
                                  ),
                                ],

                                // ── SELFIE PHOTO (failed delivery only) ──────────────
                                if (_isFailedDelivery) ...[
                                  _kSectionGap,
                                  const DeliverySectionHeader(
                                    label: 'SELFIE PHOTO',
                                  ),
                                  _kInnerGap,
                                  Row(
                                    children: [
                                      _buildPhotoSlot(
                                        slotType: 'selfie',
                                        label: 'SELFIE',
                                        photo: _selfiePhoto,
                                        icon: Icons.face_rounded,
                                        color: Colors.blueGrey,
                                        isDark: isDark,
                                        onTapOverride:
                                            _pickSelfieForFailedDeliveryOsa,
                                      ),
                                    ],
                                  ),
                                ],

                                // ── REMARKS ──────────────────────────────────────
                                _kSectionGap,
                                const DeliverySectionHeader(
                                  label: 'REMARKS (OPTIONAL)',
                                ),
                                _kInnerGap,

                                // Quick-select preset chips
                                _buildNotePresets(isDark),
                                const SizedBox(height: 8),

                                // Hint text below chips
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: Text(
                                    'TAP A PRESET TO FILL — YOU CAN STILL ADD MORE DETAILS BELOW',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: isDark
                                          ? Colors.white38
                                          : Colors.grey.shade500,
                                      letterSpacing: 0.3,
                                    ),
                                  ),
                                ),

                                ValueListenableBuilder<TextEditingValue>(
                                  valueListenable: _note,
                                  builder: (context, value, _) => TextFormField(
                                    controller: _note,
                                    maxLength: kMaxNoteLength,
                                    minLines: 3,
                                    maxLines: 6,
                                    textCapitalization:
                                        TextCapitalization.sentences,
                                    decoration:
                                        deliveryFieldDecoration(
                                          context,
                                          hintText: 'REMARKS',
                                          errorText: _errors['note'],
                                        ).copyWith(
                                          suffixIconConstraints:
                                              const BoxConstraints(
                                                minWidth: 40,
                                                minHeight: 40,
                                              ),
                                          suffixIcon: value.text.isNotEmpty
                                              ? IconButton(
                                                  icon: const Icon(
                                                    Icons.clear_rounded,
                                                    size: 18,
                                                  ),
                                                  color: Colors.grey.shade500,
                                                  onPressed: () {
                                                    _note.clear();
                                                    setState(
                                                      () => _activeNotePreset =
                                                          null,
                                                    );
                                                  },
                                                )
                                              : null,
                                        ),
                                  ),
                                ),

                                // ── TRANSACTION DATE ─────────────────────────────
                                _kSectionGap,
                                const DeliverySectionHeader(
                                  label:
                                      'TRANSACTION DATE (PHILIPPINE STANDARD TIME)',
                                ),
                                _kInnerGap,
                                TextFormField(
                                  initialValue: _getCurrentDateTimePST(),
                                  enabled: false,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                    color: isDark
                                        ? Colors.white70
                                        : Colors.black87,
                                  ),
                                  decoration: deliveryFieldDecoration(context)
                                      .copyWith(
                                        prefixIcon: Icon(
                                          Icons.calendar_today_rounded,
                                          size: 18,
                                          color: Colors.grey.shade500,
                                        ),
                                        suffixIcon: Icon(
                                          Icons.lock_outline_rounded,
                                          size: 16,
                                          color: Colors.grey.shade400,
                                        ),
                                      ),
                                ),

                                // ── GEO LOCATION ─────────────────────────────────
                                _kSectionGap,
                                const DeliverySectionHeader(
                                  label: 'GEO LOCATION',
                                ),
                                _kInnerGap,
                                DeliveryGeoLocationField(
                                  latitude: _latitude,
                                  longitude: _longitude,
                                  geoAccuracy: _geoAccuracy,
                                  isLoading: _gettingLocation,
                                  onCapture: _captureLocation,
                                ),

                                const SizedBox(height: 80),
                              ],
                            ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Note preset chip ─────────────────────────────────────────────────────────
/// A compact, tappable chip used in the quick-select remarks row.
class _NotePresetChip extends StatelessWidget {
  const _NotePresetChip({
    required this.label,
    required this.selected,
    required this.isDark,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final bool isDark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final selectedColor = DSColors.primary;
    final unselectedBg = isDark
        ? Colors.white.withValues(alpha: DSStyles.alphaSoft)
        : Colors.grey.shade100;
    final unselectedBorder = isDark
        ? Colors.white.withValues(alpha: DSStyles.alphaActiveAccent)
        : Colors.grey.shade300;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: selected
              ? selectedColor.withValues(alpha: DSStyles.alphaActiveAccent)
              : unselectedBg,
          borderRadius: DSStyles.cardRadius,
          border: Border.all(
            color: selected
                ? selectedColor.withValues(alpha: DSStyles.alphaGlass)
                : unselectedBorder,
            width: selected ? 1.4 : 1.0,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (selected) ...[
              Icon(Icons.check_rounded, size: 13, color: selectedColor),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected
                    ? selectedColor
                    : (isDark ? Colors.white70 : Colors.grey.shade700),
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Swipeable status selector ────────────────────────────────────────────────

class _StatusSelector extends StatefulWidget {
  const _StatusSelector({
    super.key,
    required this.currentStatus,
    required this.onStatusChanged,
  });

  final String currentStatus;
  final Future<void> Function(String) onStatusChanged;

  @override
  State<_StatusSelector> createState() => _StatusSelectorState();
}

class _StatusSelectorState extends State<_StatusSelector> {
  bool _hasInteracted = false;

  void markInteracted() {
    if (mounted) setState(() => _hasInteracted = true);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final selectedIndex = kUpdateStatuses.indexOf(widget.currentStatus);
    final activeStatus = selectedIndex >= 0
        ? widget.currentStatus
        : kUpdateStatuses[0];
    final activeMeta = _kStatusMeta[activeStatus]!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: 80,
          decoration: BoxDecoration(
            color: isDark ? Colors.white10 : Colors.grey.shade200,
            borderRadius: DSStyles.cardRadius,
            border: Border.all(
              color: isDark ? Colors.white12 : Colors.grey.shade300,
              width: 1,
            ),
          ),
          child: Stack(
            children: [
              AnimatedAlign(
                alignment: selectedIndex == 0
                    ? Alignment.centerLeft
                    : selectedIndex == 1
                    ? Alignment.center
                    : Alignment.centerRight,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutCubic,
                child: FractionallySizedBox(
                  widthFactor: 1 / 3,
                  heightFactor: 1.0,
                  child: Padding(
                    padding: const EdgeInsets.all(4.0),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      decoration: BoxDecoration(
                        color: activeMeta.color,
                        borderRadius: DSStyles.cardRadius,
                        boxShadow: [
                          BoxShadow(
                            color: activeMeta.color.withValues(
                              alpha: DSStyles.alphaDarkShadow,
                            ),
                            blurRadius: 6,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Row(
                children: kUpdateStatuses.map((rawStatus) {
                  final meta = _kStatusMeta[rawStatus]!;
                  final selected = widget.currentStatus == rawStatus;

                  return Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () async {
                        markInteracted();
                        await widget.onStatusChanged(rawStatus);
                      },
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            AnimatedScale(
                              scale: selected ? 1.15 : 1.0,
                              duration: const Duration(milliseconds: 250),
                              curve: Curves.easeOutBack,
                              child: Icon(
                                meta.icon,
                                color: selected
                                    ? Colors.white
                                    : (isDark
                                          ? Colors.white54
                                          : Colors.grey.shade600),
                                size: selected ? 24 : 22,
                              ),
                            ),
                            const SizedBox(height: 4),
                            AnimatedDefaultTextStyle(
                              duration: const Duration(milliseconds: 250),
                              style: TextStyle(
                                fontWeight: selected
                                    ? FontWeight.w800
                                    : FontWeight.w600,
                                fontSize: selected ? 11 : 10,
                                color: selected
                                    ? Colors.white
                                    : (isDark
                                          ? Colors.white54
                                          : Colors.grey.shade600),
                                letterSpacing: 0.5,
                              ),
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  meta.label,
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
        if (!_hasInteracted)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.touch_app_rounded,
                  size: 12,
                  color: isDark ? Colors.white30 : Colors.grey.shade500,
                ),
                const SizedBox(width: 4),
                Text(
                  'Tap or Swipe below to change status',
                  style: TextStyle(
                    fontSize: 10,
                    color: isDark ? Colors.white30 : Colors.grey.shade500,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
