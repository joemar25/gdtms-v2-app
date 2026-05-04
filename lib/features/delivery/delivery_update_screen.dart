// DOCS: docs/development-standards.md
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
// Permissions:
//   Standardized handling via [locationProvider] and [extraPermissionsProvider].
//
// Media:
//   Images are compressed to 600 px / quality 70 before queuing.
//   Signatures are captured via [SignatureCaptureScreen] and saved as PNG.
//   Media is uploaded to S3 (or API fallback) during sync.
//
// Navigation:
//   Route: /deliveries/:barcode/update
//   Pushed from: DeliveryCard (hold → View/Update option) or scan result
// =============================================================================

import 'dart:convert';
import 'dart:io';
// 'dart:typed_data' is available through flutter/services when needed

import 'package:flutter/material.dart';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/services.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:uuid/uuid.dart';
import 'package:path_provider/path_provider.dart';

import 'package:fsi_courier_app/core/api/api_client.dart';
import 'package:fsi_courier_app/core/services/review_prompt_service.dart';
import 'package:fsi_courier_app/core/services/time_validation_service.dart';
import 'package:fsi_courier_app/core/auth/auth_provider.dart';
import 'package:fsi_courier_app/core/constants.dart';
import 'package:fsi_courier_app/core/models/local_delivery.dart';
import 'package:fsi_courier_app/core/models/delivery_status.dart';
import 'package:fsi_courier_app/core/database/local_delivery_dao.dart';
import 'package:fsi_courier_app/core/database/sync_operations_dao.dart';
import 'package:fsi_courier_app/core/models/sync_operation.dart';
import 'package:fsi_courier_app/core/models/photo_entry.dart';
import 'package:fsi_courier_app/core/providers/connectivity_provider.dart';
import 'package:fsi_courier_app/core/providers/delivery_refresh_provider.dart';
import 'package:fsi_courier_app/features/permissions/providers/location_provider.dart';
import 'package:fsi_courier_app/features/permissions/providers/permissions_provider.dart';
import 'package:fsi_courier_app/core/providers/sync_provider.dart';
import 'package:fsi_courier_app/features/delivery/signature_capture_screen.dart';
import 'package:fsi_courier_app/shared/widgets/app_header_bar.dart';
import 'package:fsi_courier_app/features/delivery/widgets/delivery_form_helpers.dart';
import 'package:fsi_courier_app/features/delivery/widgets/delivery_status_section.dart';
import 'package:fsi_courier_app/features/delivery/widgets/delivery_metadata_section.dart';
import 'package:fsi_courier_app/features/delivery/widgets/delivery_submit_fab.dart';
import 'package:fsi_courier_app/features/delivery/widgets/delivery_update_screen_widgets.dart';
import 'package:fsi_courier_app/features/delivery/widgets/searchable_selection_sheet.dart';
import 'package:fsi_courier_app/shared/helpers/api_payload_helper.dart';
import 'package:fsi_courier_app/shared/helpers/delivery_helper.dart';
import 'package:fsi_courier_app/shared/helpers/snackbar_helper.dart';
import 'package:fsi_courier_app/shared/helpers/string_helper.dart';
import 'package:fsi_courier_app/shared/widgets/loading_overlay.dart';
import 'package:fsi_courier_app/shared/widgets/offline_banner.dart';
import 'package:fsi_courier_app/shared/widgets/sync_progress_bar.dart';
import 'package:fsi_courier_app/design_system/design_system.dart';
import 'package:fsi_courier_app/features/delivery/delivery_update_components.dart';
import 'package:fsi_courier_app/features/delivery/widgets/delivery_proof_section.dart';
import 'package:fsi_courier_app/features/delivery/widgets/delivery_reason_section.dart';
import 'package:fsi_courier_app/features/delivery/widgets/delivery_recipient_section.dart';
import 'package:fsi_courier_app/features/delivery/widgets/delivery_remarks_section.dart';
import 'package:fsi_courier_app/features/delivery/widgets/delivery_single_photo_section.dart';
import 'package:fsi_courier_app/features/delivery/helpers/delivery_update_helper.dart';

// ─── Consistent spacing constants ───────────────────────────────────────────
const _kSectionGap = DSSpacing.hLg; // between major sections
const _kInnerGap = DSSpacing.hSm; // header → first field

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
  final _statusSelectorKey = GlobalKey<DeliveryStatusSelectorState>();
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

  /// Returns true if this is an EXPRESS delivery.
  /// EXPRESS deliveries have restricted placement types (e.g. no mailbox).
  bool get _isExpress {
    final type = (_delivery['mail_type'] ?? '').toString().toUpperCase();
    return type == 'EXPRESS';
  }

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
        final item = mapFromKey(data, 'data');
        // Standardise via model to ensure v3.6 canonical keys
        _delivery = LocalDelivery.fromApiItem(item).toDeliveryMap();
        final currentStatus =
            _delivery['delivery_status']?.toString().toUpperCase() ??
            'DELIVERED';
        setState(() {
          _status = kUpdateStatuses.contains(currentStatus)
              ? currentStatus
              : kUpdateStatuses.first;
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
      _status = kUpdateStatuses.contains(currentStatus)
          ? currentStatus
          : kUpdateStatuses.first;
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

  // ── Geo location ─────────────────────────────────────────────────────────
  Future<void> _captureLocation() async {
    setState(() => _gettingLocation = true);
    try {
      final locState = ref.read(locationProvider);
      if (locState.status == LocationStatus.serviceDisabled) {
        if (mounted) {
          showErrorNotification(
            context,
            'delivery_update.location.gps_required'.tr(),
          );
        }
        return;
      }

      if (!locState.isReady) {
        await ref.read(locationProvider.notifier).requestPermission();
        final updated = ref.read(locationProvider);
        if (updated.status == LocationStatus.permissionPermanentlyDenied) {
          if (mounted) {
            showErrorNotification(
              context,
              'delivery_update.location.permission_permanently_denied'.tr(),
            );
            await ref.read(locationProvider.notifier).openSettings();
          }
          return;
        }
        if (!updated.isReady) {
          if (mounted) {
            showErrorNotification(
              context,
              'delivery_update.location.permission_required'.tr(),
            );
          }
          return;
        }
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
        showErrorNotification(
          context,
          'delivery_update.location.gps_disabled'.tr(),
        );
      }
    } catch (_) {
      if (mounted) {
        showErrorNotification(
          context,
          'delivery_update.location.could_not_get_location'.tr(),
        );
      }
    } finally {
      if (mounted) setState(() => _gettingLocation = false);
    }
  }

  // ── Camera permission ─────────────────────────────────────────────────────
  Future<bool> _handleCameraPermission() async {
    final perms = ref.read(extraPermissionsProvider);
    if (perms.cameraStatus.isGranted) {
      return true;
    }

    if (perms.cameraStatus.isPermanentlyDenied) {
      if (mounted) {
        showErrorNotification(
          context,
          'delivery_update.camera.permission_settings'.tr(),
        );
        await ref.read(extraPermissionsProvider.notifier).openSettings();
      }
      return false;
    }

    await ref.read(extraPermissionsProvider.notifier).requestCamera();
    final updated = ref.read(extraPermissionsProvider);

    if (updated.cameraStatus.isGranted) {
      return true;
    }

    if (mounted) {
      showErrorNotification(
        context,
        'delivery_update.camera.permission_photo'.tr(),
      );
    }
    return false;
  }

  // ── Recover lost data (Android activity killed during camera) ────────────
  Future<void> _handleLostData() async {
    if (!Platform.isAndroid) return;
    try {
      final response = await _picker.retrieveLostData();
      if (response.isEmpty || response.file == null || !mounted) return;
      final rawBytes = await response.file!.readAsBytes();
      await FlutterImageCompress.compressWithList(
        rawBytes,
        minWidth: DSIconSize.heroLg.toInt(),
        quality: 70,
        format: CompressFormat.jpeg,
      );
      final entry = PhotoEntry(
        id: _uuid.v4(),
        file: response.file!.path,
        type: 'recovered',
      );
      setState(() {
        _podPhoto ??= PhotoEntry(id: entry.id, file: entry.file, type: 'pod');
      });
      if (!mounted) return;
      showSuccessNotification(
        context,
        'delivery_update.photo.recovered_success'.tr(),
      );
    } catch (e) {
      debugPrint('Error recovering lost data: $e');
    }
  }

  // ── Pick photo for a pre-defined slot ─────────────────────────────────────
  Future<void> _pickPhotoForSlot(
    String slotType, {
    ImageSource source = ImageSource.camera,
  }) async {
    if (_isPickerActive) return;
    if (source == ImageSource.camera) {
      final ok = await _handleCameraPermission();
      if (!ok) return;
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
      Uint8List bytes;
      try {
        bytes = await FlutterImageCompress.compressWithList(
          rawBytes,
          minWidth: DSIconSize.heroLg.toInt(),
          quality: 70,
          format: CompressFormat.jpeg,
        );
      } catch (e) {
        debugPrint('Image compression failed: $e');
        bytes = rawBytes;
      }
      if (bytes.isEmpty || !mounted) {
        setState(() => _isPickerActive = false);
        return;
      }
      final apiType = slotType; // 'pod' | 'selfie' | 'mailpack'
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
      if (e.code == 'already_active') {
        return;
      }
      if (mounted) {
        showErrorNotification(
          context,
          'delivery_update.camera.error'.tr(
            namedArgs: {'code': e.code, 'message': e.message ?? ''},
          ),
        );
      }
    } catch (e) {
      setState(() => _isPickerActive = false);
      if (mounted) {
        showErrorNotification(
          context,
          'delivery_update.camera.capture_failed'.tr(
            namedArgs: {'error': e.toString()},
          ),
        );
      }
    }
  }

  Future<void> _pickSelfieForFailedDeliveryOsa() async =>
      _pickPhotoForSlot('selfie', source: ImageSource.camera);

  // ── Signature capture ─────────────────────────────────────────────────────
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

  // ── Validation ────────────────────────────────────────────────────────────
  bool _validate() {
    _errors.clear();
    if (!kUpdateStatuses.contains(_status.toUpperCase())) {
      _errors['delivery_status'] = 'delivery_update.validation.invalid_status'
          .tr();
    }
    if (_note.text.length > kMaxNoteLength) {
      _errors['note'] = 'delivery_update.validation.note_too_long'.tr(
        namedArgs: {'max': kMaxNoteLength.toString()},
      );
    }
    if (_isDelivered) {
      if (_recipient.text.trim().isEmpty) {
        _errors['recipient'] = 'delivery_update.validation.field_required'.tr();
      }
      if (_relationship == null || _relationship!.isEmpty) {
        _errors['relationship'] =
            'delivery_update.validation.relationship_required'.tr();
      } else if (_relationship == 'OTHERS' &&
          _relationshipSpecify.text.trim().isEmpty) {
        _errors['relationship_specify'] =
            'delivery_update.validation.relationship_specify'.tr();
      }
      if (_placement.isEmpty) {
        _errors['placement'] = 'delivery_update.validation.placement_required'
            .tr();
      }
      if (_podPhoto == null) {
        _errors['pod_photo'] = 'delivery_update.validation.pod_photo_required'
            .tr();
      }
      if (_selfiePhoto == null) {
        _errors['selfie_photo'] =
            'delivery_update.validation.selfie_photo_required'.tr();
      }
      if (_confirmationCode.text.trim().isEmpty) {
        _errors['confirmation_code'] =
            'delivery_update.validation.confirmation_code_required'.tr();
      }
    }
    if (_isOsa && _mailpackPhoto == null) {
      _errors['mailpack_photo'] =
          'delivery_update.validation.mailpack_photo_required'.tr();
    }
    if (_isFailedDelivery) {
      if (_reason == null || _reason!.isEmpty) {
        _errors['reason'] = 'delivery_update.validation.reason_required'.tr();
      } else if (_reason == 'Others' && _reasonSpecify.text.trim().isEmpty) {
        _errors['reason_specify'] = 'delivery_update.validation.reason_specify'
            .tr();
      }
      if (_selfiePhoto == null) {
        _errors['selfie_photo'] =
            'delivery_update.validation.selfie_photo_required'.tr();
      }
      final config = kReasonConfigs[_reason] ?? const ReasonConfig();
      if (config.requiresAccordingTo && _accordingTo.text.trim().isEmpty) {
        _errors['according_to'] =
            'delivery_update.validation.informant_name_required'.tr();
      }
    }
    setState(() {});
    return _errors.isEmpty;
  }

  // ── Submit ────────────────────────────────────────────────────────────────
  Future<void> _submit() async {
    if (!_validate()) return;
    setState(() => _loading = true);
    if (checkIsLockedFromMap(_delivery)) {
      setState(() => _loading = false);
      showInfoNotification(context, 'delivery_update.status.locked'.tr());
      return;
    }
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
    final String? resolvedReason = _reason == 'Others'
        ? _reasonSpecify.text.trim().toUpperCase()
        : _reason?.toUpperCase();
    final String? resolvedRelationship = _relationship == 'OTHERS'
        ? _relationshipSpecify.text.trim().toUpperCase()
        : _relationship;
    final now = DateTime.now();
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
      if (_geoAccuracy != null) payload['geo_accuracy'] = _geoAccuracy;
    }
    final pendingMediaPaths = <String, String>{};
    if (_isDelivered) {
      if (_podPhoto != null) pendingMediaPaths['pod'] = _podPhoto!.file;
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
    for (var i = 0; i < _photos.length; i++) {
      final p = _photos[i];
      pendingMediaPaths[p.type + (i > 0 ? '_$i' : '')] = p.file;
    }
    await SyncOperationsDao.instance.insert(
      SyncOperation(
        id: const Uuid().v4(),
        courierId: courierId,
        barcode: widget.barcode,
        operationType: 'UPDATE_STATUS',
        payloadJson: jsonEncode(payload),
        mediaPathsJson: pendingMediaPaths.isNotEmpty
            ? jsonEncode(pendingMediaPaths)
            : null,
        status: 'pending',
        createdAt: now.millisecondsSinceEpoch,
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
    showSuccessNotification(
      context,
      'delivery_update.status.updated_success'.tr(),
    );
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

  void _showAccountDetailsDialog(BuildContext context) {
    showDeliveryAccountDetails(context, _delivery, widget.barcode);
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
        detail: 'delivery_update.detail.recipient_info_photos_signature'.tr(),
      );
      if (confirmed != true || !mounted) return;
      _clearDeliveredFields();
    } else if ((_isNonDelivered) && hasNonDeliveredData) {
      final confirmed = await _showSwitchConfirmDialog(
        context,
        from: _status,
        to: newStatus,
        detail: 'delivery_update.detail.reason_and_selfie_photo'.tr(),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fullText = 'delivery_update.switch_status.content'.tr(
      namedArgs: {
        'detail': '<b>$detail</b>',
        'from': '<b>${from.toDisplayStatus()}</b>',
        'to': '<b>${to.toDisplayStatus()}</b>',
      },
    );

    final spans = <InlineSpan>[];
    final regex = RegExp(r'<b>(.*?)</b>');
    int lastMatchEnd = 0;

    for (final match in regex.allMatches(fullText)) {
      if (match.start > lastMatchEnd) {
        spans.add(
          TextSpan(text: fullText.substring(lastMatchEnd, match.start)),
        );
      }
      spans.add(
        TextSpan(
          text: match.group(1),
          style: DSTypography.body(fontWeight: FontWeight.bold),
        ),
      );
      lastMatchEnd = match.end;
    }
    if (lastMatchEnd < fullText.length) {
      spans.add(TextSpan(text: fullText.substring(lastMatchEnd)));
    }

    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'delivery_update.switch_status.title'.tr(),
          style: DSTypography.heading().copyWith(fontSize: DSTypography.sizeMd),
        ),
        content: Text.rich(
          TextSpan(
            style: DSTypography.body().copyWith(
              fontSize: DSTypography.sizeMd,
              color: isDark ? DSColors.labelPrimaryDark : DSColors.labelPrimary,
            ),
            children: spans,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('delivery_update.switch_status.cancel'.tr()),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: DSColors.error),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('delivery_update.switch_status.confirm'.tr()),
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
      title: 'delivery_update.header.select_relationship'.tr(),
      options: options,
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
      title: 'delivery_update.header.select_reason'.tr(),
      options: kReasons,
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

  bool get _isDirty {
    return DeliveryUpdateHelper.isDirty(
      recipient: _recipient.text,
      note: _note.text,
      relationship: _relationship,
      relationshipSpecify: _relationshipSpecify.text,
      reason: _reason,
      reasonSpecify: _reasonSpecify.text,
      accordingTo: _accordingTo.text,
      hasPodPhoto: _podPhoto != null,
      hasSelfiePhoto: _selfiePhoto != null,
      hasMailpackPhoto: _mailpackPhoto != null,
      hasAdditionalPhotos: _photos.isNotEmpty,
      hasSignature: _signaturePath != null,
      confirmationCode: _confirmationCode.text,
      placement: _placement,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final List<String> notePresets;
    if (_isDelivered) {
      notePresets = kDeliveredNotePresets;
    } else if (_isOsa) {
      notePresets = kOsaConfig.remarksPresets;
    } else {
      notePresets =
          (_reason != null ? kReasonConfigs[_reason]?.remarksPresets : null) ??
          [];
    }

    return PopScope(
      canPop: _forcePop || !_isDirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final leave = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text('delivery_update.discard_changes.title'.tr()),
            content: Text('delivery_update.discard_changes.message'.tr()),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: Text('delivery_update.discard_changes.stay'.tr()),
              ),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: Text(
                  'delivery_update.discard_changes.discard'.tr(),
                  style: DSTypography.button(color: DSColors.error),
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
        floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
        floatingActionButton: DeliverySubmitFab(
          isLoading: _loading,
          onPressed: _submit,
        ),
        appBar: AppHeaderBar(
          titleWidget: DeliveryUpdateAppBarTitle(barcode: widget.barcode),
          actions: [
            const Center(child: SecureBadge()),
            DSSpacing.wXs,
            IconButton(
              icon: const Icon(Icons.info_outline_rounded),
              tooltip: 'delivery_update.header.account_details'.tr(),
              onPressed: () => _showAccountDetailsDialog(context),
            ),
          ],
          showNotificationBell: false,
          backgroundColor: isDark ? DSColors.cardDark : DSColors.cardLight,
        ),
        body: SecureView(
          child: GestureDetector(
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
                                padding: EdgeInsets.fromLTRB(
                                  DSSpacing.md,
                                  DSSpacing.md,
                                  DSSpacing.md,
                                  100,
                                ),
                                children: [
                                  // ── Connection status banner ─────────────────
                                  // Self-hides when online; shows 'no internet' or
                                  // 'server unavailable' as appropriate.
                                  ConnectionStatusBanner(
                                    isMinimal: true,
                                    customOfflineMessage:
                                        'delivery_update.offline_banner.queued_online'
                                            .tr(),
                                    margin: EdgeInsets.only(
                                      bottom: DSSpacing.lg,
                                    ),
                                  ),

                                  // ── STATUS SELECTION ────────────────────────────
                                  DeliveryStatusSection(
                                    statusSelectorKey: _statusSelectorKey,
                                    currentStatus: _status,
                                    onStatusChanged: _onStatusTap,
                                    error: _errors['delivery_status'],
                                  ),

                                  // ── RECIPIENT INFO (delivered only) ──────────
                                  if (_isDelivered) ...[
                                    _kSectionGap,
                                    DeliverySectionHeader(
                                      label:
                                          'delivery_update.header.recipient_info'
                                              .tr(),
                                    ),
                                    _kInnerGap,
                                    DeliveryRecipientSection(
                                      delivery: _delivery,
                                      recipientController: _recipient,
                                      relationshipSpecifyController:
                                          _relationshipSpecify,
                                      confirmationCodeController:
                                          _confirmationCode,
                                      confirmationCodeFocusNode:
                                          _confirmationCodeFocus,
                                      relationship: _relationship,
                                      recipientIsOwner: _recipientIsOwner,
                                      placement: _placement,
                                      isExpress: _isExpress,
                                      errors: _errors,
                                      isDark: isDark,
                                      onSelectRecipient: (name, rel) {
                                        _recipient.text = name;
                                        setState(() {
                                          _relationship = rel;
                                          _recipientIsOwner = rel == 'OWNER';
                                          _errors.remove('recipient');
                                          _errors.remove('relationship');
                                        });
                                      },
                                      onRecipientManuallyChanged: () =>
                                          setState(() {
                                            _recipientIsOwner = false;
                                            _relationship = null;
                                          }),
                                      onRecipientCleared: () {
                                        _recipient.clear();
                                        setState(() {
                                          _recipientIsOwner = false;
                                          _relationship = null;
                                        });
                                      },
                                      onRelationshipPickerTap:
                                          _openRelationshipPicker,
                                      onRelationshipSpecifyChanged: () =>
                                          setState(
                                            () => _errors.remove(
                                              'relationship_specify',
                                            ),
                                          ),
                                      onConfirmationCodeChanged: () => setState(
                                        () =>
                                            _errors.remove('confirmation_code'),
                                      ),
                                      onConfirmationCodeCleared: () => setState(
                                        () => _confirmationCode.clear(),
                                      ),
                                      onPlacementChanged: (v) => setState(
                                        () => _placement = v ?? _placement,
                                      ),
                                    ),
                                  ],

                                  // ── REASON FOR NON-DELIVERY (failed delivery only) ──────
                                  if (_isFailedDelivery) ...[
                                    _kSectionGap,
                                    DeliverySectionHeader(
                                      label:
                                          'delivery_update.header.reason_for_non_delivery'
                                              .tr(),
                                    ),
                                    _kInnerGap,
                                    DeliveryReasonSection(
                                      reason: _reason,
                                      reasonSpecifyController: _reasonSpecify,
                                      accordingToController: _accordingTo,
                                      errors: _errors,
                                      isDark: isDark,
                                      onReasonPickerTap: _openReasonPicker,
                                      onReasonSpecifyChanged: () => setState(
                                        () => _errors.remove('reason_specify'),
                                      ),
                                      onAccordingToChanged: () => setState(
                                        () => _errors.remove('according_to'),
                                      ),
                                    ),
                                  ],

                                  // ── PROOF OF DELIVERY (delivered) ────────────────
                                  if (_isDelivered) ...[
                                    _kSectionGap,
                                    DeliverySectionHeader(
                                      label:
                                          'delivery_update.header.proof_of_delivery_photos'
                                              .tr(),
                                    ),
                                    _kInnerGap,
                                    DeliveryProofSection(
                                      podPhoto: _podPhoto,
                                      selfiePhoto: _selfiePhoto,
                                      signaturePath: _signaturePath,
                                      showSignatureSlot: _showSignatureSlot,
                                      errors: _errors,
                                      isDark: isDark,
                                      onPodTap: () => _pickPhotoForSlot('pod'),
                                      onPodClear: () => setState(() {
                                        _podPhoto = null;
                                        _errors.remove('pod_photo');
                                      }),
                                      onSelfieTap: () =>
                                          _pickPhotoForSlot('selfie'),
                                      onSelfieClear: () => setState(() {
                                        _selfiePhoto = null;
                                        _errors.remove('selfie_photo');
                                      }),
                                      onSignatureSlotToggled:
                                          (show, clearPath) => setState(() {
                                            _showSignatureSlot = show;
                                            if (clearPath) {
                                              _signaturePath = null;
                                            }
                                          }),
                                      onSignatureCapture: _openSignatureCapture,
                                      onSignatureClear: () =>
                                          setState(() => _signaturePath = null),
                                    ),
                                  ],

                                  // ── MAILPACK PHOTO (misrouted / osa) ─────────────────
                                  if (_isOsa) ...[
                                    _kSectionGap,
                                    DeliverySectionHeader(
                                      label:
                                          'delivery_update.header.mailpack_photo'
                                              .tr(),
                                    ),
                                    _kInnerGap,
                                    DeliverySinglePhotoSection(
                                      label: 'delivery_update.photo.mailpack'
                                          .tr(),
                                      photo: _mailpackPhoto,
                                      icon: Icons.inventory_2_rounded,
                                      color: DSColors.warning,
                                      isDark: isDark,
                                      hasError:
                                          _errors['mailpack_photo'] != null,
                                      onTap: () =>
                                          _pickPhotoForSlot('mailpack'),
                                      onClear: () => setState(() {
                                        _mailpackPhoto = null;
                                        _errors.remove('mailpack_photo');
                                      }),
                                    ),
                                  ],

                                  // ── SELFIE PHOTO (failed delivery only) ──────────────
                                  if (_isFailedDelivery) ...[
                                    _kSectionGap,
                                    DeliverySectionHeader(
                                      label:
                                          'delivery_update.header.selfie_photo'
                                              .tr(),
                                    ),
                                    _kInnerGap,
                                    DeliverySinglePhotoSection(
                                      label: 'delivery_update.photo.selfie'
                                          .tr(),
                                      photo: _selfiePhoto,
                                      icon: Icons.face_rounded,
                                      color: DSColors.labelSecondary,
                                      isDark: isDark,
                                      hasError: _errors['selfie_photo'] != null,
                                      onTap: _pickSelfieForFailedDeliveryOsa,
                                      onClear: () => setState(() {
                                        _selfiePhoto = null;
                                        _errors.remove('selfie_photo');
                                      }),
                                    ),
                                  ],

                                  // ── REMARKS ──────────────────────────────────────
                                  _kSectionGap,
                                  DeliverySectionHeader(
                                    label:
                                        'delivery_update.header.remarks_optional'
                                            .tr(),
                                  ),
                                  _kInnerGap,
                                  DeliveryRemarksSection(
                                    noteController: _note,
                                    notePresets: notePresets,
                                    activeNotePreset: _activeNotePreset,
                                    errors: _errors,
                                    isDark: isDark,
                                    onPresetTapped: (preset) => setState(() {
                                      if (_activeNotePreset == preset) {
                                        _activeNotePreset = null;
                                        if (_note.text == preset) _note.clear();
                                      } else {
                                        _activeNotePreset = preset;
                                        _note.value = TextEditingValue(
                                          text: preset,
                                          selection: TextSelection.collapsed(
                                            offset: preset.length,
                                          ),
                                        );
                                      }
                                    }),
                                    onNoteCleared: () {
                                      _note.clear();
                                      setState(() => _activeNotePreset = null);
                                    },
                                  ),

                                  // ── METADATA (DATE & GEO) ────────────────────────
                                  _kSectionGap,
                                  DeliveryUpdateMetadataSection(
                                    latitude: _latitude,
                                    longitude: _longitude,
                                    geoAccuracy: _geoAccuracy,
                                    isGettingLocation: _gettingLocation,
                                    onCaptureLocation: _captureLocation,
                                  ),

                                  DSSpacing.hLg,
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
      ),
    );
  }
}
