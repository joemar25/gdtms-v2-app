import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:uuid/uuid.dart';

import 'package:fsi_courier_app/core/api/api_client.dart';
import 'package:fsi_courier_app/core/api/api_result.dart';
import 'package:fsi_courier_app/core/auth/auth_provider.dart';
import 'package:fsi_courier_app/core/constants.dart';
import 'package:fsi_courier_app/core/database/delivery_update_dao.dart';
import 'package:fsi_courier_app/core/database/local_delivery_dao.dart';
import 'package:fsi_courier_app/core/models/delivery_update_entry.dart';
import 'package:fsi_courier_app/core/models/photo_entry.dart';
import 'package:fsi_courier_app/core/providers/connectivity_provider.dart';
import 'package:fsi_courier_app/core/providers/delivery_refresh_provider.dart';
import 'package:fsi_courier_app/features/delivery/signature_capture_screen.dart';
import 'package:fsi_courier_app/features/delivery/widgets/delivery_form_helpers.dart';
import 'package:fsi_courier_app/features/delivery/widgets/delivery_geo_location_field.dart';
import 'package:fsi_courier_app/features/delivery/widgets/delivery_recipient_cards.dart';
import 'package:fsi_courier_app/shared/helpers/api_payload_helper.dart';
import 'package:fsi_courier_app/shared/helpers/snackbar_helper.dart';
import 'package:fsi_courier_app/shared/widgets/loading_overlay.dart';
import 'package:fsi_courier_app/shared/widgets/offline_banner.dart';
import 'package:fsi_courier_app/shared/widgets/success_overlay.dart';
import 'package:fsi_courier_app/styles/color_styles.dart';

// ─── Status metadata ────────────────────────────────────────────────────────
const _kStatusMeta = {
  'delivered': (
    label: 'DELIVERED',
    icon: Icons.check_circle_rounded,
    color: Color(0xFF00B14F),
  ),
  'rts': (
    label: 'RTS',
    icon: Icons.keyboard_return_rounded,
    color: Colors.purple,
  ),
  'osa': (label: 'OSA', icon: Icons.inbox_rounded, color: Colors.amber),
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
  final _errors = <String, String>{};
  final _uuid = const Uuid();

  final _picker = ImagePicker();

  String _status = 'delivered';
  String? _relationship;
  bool _recipientIsOwner = false;
  String _placement = 'received';
  String? _reason;
  bool _loading = false;
  bool _success = false;

  // Delivered-specific: two fixed photo slots (POD + SELFIE)
  PhotoEntry? _podPhoto;
  PhotoEntry? _selfiePhoto;

  // Non-delivered photos (rts / osa) — camera + gallery, free type
  final _photos = <PhotoEntry>[];

  // Signature bytes (PNG) for delivered status
  Uint8List? _signatureBytes;

  // Geo location
  double? _latitude;
  double? _longitude;
  double? _geoAccuracy;
  bool _gettingLocation = false;

  @override
  void initState() {
    super.initState();
    _recipient.addListener(_onRecipientTextChanged);
    _loadDelivery();
    _captureLocation();
  }

  /// When the courier manually edits the recipient field, un-lock the
  /// owner-selection and reset the relationship to blank.
  void _onRecipientTextChanged() {
    if (_recipientIsOwner) {
      setState(() {
        _recipientIsOwner = false;
        _relationship = null;
      });
    }
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
        setState(() => _loadingDelivery = false);
        return;
      }
    }

    // Offline fallback.
    final local = await LocalDeliveryDao.instance.getByBarcode(widget.barcode);
    if (!mounted) return;
    if (local != null) {
      _delivery = local.toDeliveryMap();
    }
    setState(() => _loadingDelivery = false);
  }

  @override
  void dispose() {
    _note.dispose();
    _recipient.removeListener(_onRecipientTextChanged);
    _recipient.dispose();
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

  // ── Pick photo for a pre-defined slot ──────────────────────────────────────
  Future<void> _pickPhotoForSlot(
    String slotType, {
    ImageSource source = ImageSource.camera,
  }) async {
    final picked = await _picker.pickImage(source: source);
    if (picked == null) return;

    final bytes = await FlutterImageCompress.compressWithFile(
      picked.path,
      minWidth: 600,
      quality: 70,
      format: CompressFormat.jpeg,
    );
    if (bytes == null) return;

    // Map display slot name to the API-accepted delivery_images type.
    // API accepts: pod, selfie, recipient_signature, other.
    final apiType = slotType == 'pod' ? 'pod' : 'selfie';
    final entry = PhotoEntry(
      id: _uuid.v4(),
      file: base64Encode(bytes),
      type: apiType,
    );
    setState(() {
      if (slotType == 'pod') {
        _podPhoto = entry;
        _errors.remove('pod_photo');
      } else {
        _selfiePhoto = entry;
        _errors.remove('selfie_photo');
      }
    });
  }

  // ── Selfie picker for rts/osa — shows Camera / Gallery sheet ───────────────
  Future<void> _pickSelfieForRtsOsa() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade400,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 12),
            ListTile(
              leading: const Icon(Icons.photo_camera_rounded),
              title: const Text('Camera'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded),
              title: const Text('Gallery'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (source == null) return;
    await _pickPhotoForSlot('selfie', source: source);
  }

  // ── Open landscape signature capture screen ───────────────────────────────
  Future<void> _openSignatureCapture() async {
    final bytes = await Navigator.push<Uint8List?>(
      context,
      MaterialPageRoute(builder: (_) => const SignatureCaptureScreen()),
    );
    if (bytes != null && mounted) {
      setState(() {
        _signatureBytes = bytes;
        _errors.remove('recipient_signature');
      });
    }
  }

  // ── Philippine Standard Time helpers ─────────────────────────────────────
  static DateTime _pstNow() =>
      DateTime.now().toUtc().add(const Duration(hours: 8));

  static String _todayPST() => DateFormat('MMMM d, yyyy').format(_pstNow());

  // ── Validation ────────────────────────────────────────────────────────────
  bool _validate() {
    _errors.clear();

    if (!kUpdateStatuses.contains(_status)) {
      _errors['delivery_status'] = 'Invalid status.';
    }

    if (_note.text.length > kMaxNoteLength) {
      _errors['note'] = 'Note must not exceed $kMaxNoteLength characters.';
    }

    if (_status == 'delivered') {
      if (_recipient.text.trim().isEmpty) {
        _errors['recipient'] = 'This field is required.';
      }
      if (_relationship == null || _relationship!.isEmpty) {
        _errors['relationship'] = 'Relationship is required.';
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
    }

    if (_status == 'rts' || _status == 'osa') {
      if (_reason == null || _reason!.isEmpty) {
        _errors['reason'] = 'Reason is required.';
      }
    }

    setState(() {});
    return _errors.isEmpty;
  }

  // ── Submit ────────────────────────────────────────────────────────────────
  Future<void> _submit() async {
    if (!_validate()) return;

    setState(() => _loading = true);

    final courierId =
        ref.read(authProvider).courier?['id']?.toString() ?? '';
    final isOnline = ref.read(isOnlineProvider);

    // Build payload — only include fields relevant to the current status.
    final payload = <String, dynamic>{
      'delivery_status': _status,
      if (_note.text.trim().isNotEmpty) 'note': _note.text.trim(),
    };

    if (_latitude != null && _longitude != null) {
      payload['latitude'] = _latitude;
      payload['longitude'] = _longitude;
      if (_geoAccuracy != null) payload['geo_accuracy'] = _geoAccuracy;
    }

    if (isOnline) {
      // ── Online path: upload media first, then patch ─────────────────────
      final uploadedImages = <Map<String, dynamic>>[];
      final api = ref.read(apiClientProvider);
      final uploadPath = '/deliveries/${widget.barcode}/media';

      Future<String?> uploadBytes(
        Uint8List bytes,
        String type,
        String filename,
      ) async {
        final r = await api.uploadMedia<Map<String, dynamic>>(
          uploadPath,
          bytes: bytes,
          filename: filename,
          type: type,
          parser: (d) {
            if (d is Map<String, dynamic>) return d;
            if (d is Map) return d.map((k, v) => MapEntry(k.toString(), v));
            return <String, dynamic>{};
          },
        );
        if (!mounted) return null;
        if (r case ApiSuccess<Map<String, dynamic>>(:final data)) {
          final inner = data['data'];
          // The upload endpoint may return the URL in several field names.
          // Try the nested data object first, then fall back to top-level keys.
          final url =
              (inner is Map
                      ? inner['url'] ??
                            inner['signed_url'] ??
                            inner['file'] ??
                            inner['path']
                      : data['url'] ?? data['signed_url'])
                  ?.toString();
          debugPrint('[UPLOAD] uploadBytes success: url=$url raw_data=$data');
          return url;
        }
        // Log the failure so we can see the actual API error
        switch (r) {
          case ApiValidationError<Map<String, dynamic>>(:final message, :final errors):
            debugPrint('[UPLOAD] uploadBytes validation error: $message | errors: $errors');
          case ApiServerError<Map<String, dynamic>>(:final message):
            debugPrint('[UPLOAD] uploadBytes server error: $message');
          case ApiNetworkError<Map<String, dynamic>>(:final message):
            debugPrint('[UPLOAD] uploadBytes network error: $message');
          case ApiConflict<Map<String, dynamic>>(:final message):
            debugPrint('[UPLOAD] uploadBytes conflict: $message');
          case ApiUnauthorized<Map<String, dynamic>>():
            debugPrint('[UPLOAD] uploadBytes unauthorized (401)');
          default:
            debugPrint('[UPLOAD] uploadBytes failed (unknown): $r');
        }
        return null;
      }

      if (_status == 'delivered') {
        if (_podPhoto != null) {
          final url = await uploadBytes(
            base64Decode(_podPhoto!.file),
            'pod', // upload endpoint type
            'pod.jpg',
          );
          if (url != null) uploadedImages.add({'file': url, 'type': 'pod'});
        }
        if (_selfiePhoto != null) {
          final url = await uploadBytes(
            base64Decode(_selfiePhoto!.file),
            'selfie', // upload endpoint type
            'selfie.jpg',
          );
          if (url != null) uploadedImages.add({'file': url, 'type': 'selfie'});
        }
        payload['recipient'] = _recipient.text.trim();
        payload['relationship'] = _relationship;
        payload['placement_type'] = _placement;
        payload['delivery_images'] = uploadedImages;
        if (_signatureBytes != null) {
          final url = await uploadBytes(
            _signatureBytes!,
            'recipient_signature',
            'signature.png',
          );
          if (url != null) payload['recipient_signature'] = url;
        }
      } else {
        // rts / osa — single selfie photo tagged as 'selfie'
        payload['reason'] = _reason;
        debugPrint(
          '[SUBMIT] rts/osa selfie: ${_selfiePhoto != null ? "present" : "not taken"}',
        );
        if (_selfiePhoto != null) {
          final url = await uploadBytes(
            base64Decode(_selfiePhoto!.file),
            'selfie',
            'selfie.jpg',
          );
          debugPrint('[SUBMIT] rts/osa selfie upload result: $url');
          if (url == null) {
            // Upload failed — surface the error instead of silently proceeding
            // without images attached to the delivery.
            if (mounted) {
              setState(() => _loading = false);
              showAppSnackbar(
                context,
                'Photo upload failed. Please check your connection and try again.',
                type: SnackbarType.error,
              );
            }
            return;
          }
          uploadedImages.add({'file': url, 'type': 'selfie', 'captured_at': DateTime.now().toUtc().toIso8601String()});
        }
        if (uploadedImages.isNotEmpty) {
          payload['delivery_images'] = uploadedImages;
        }
      }

      debugPrint('[PATCH] payload keys: ${payload.keys.toList()}');
      debugPrint('[PATCH] delivery_images: ${payload['delivery_images']}');

      if (!mounted) return;

      final result = await api.patch<Map<String, dynamic>>(
        '/deliveries/${widget.barcode}',
        data: payload,
        parser: parseApiMap,
      );

      if (!mounted) return;

      switch (result) {
        case ApiSuccess<Map<String, dynamic>>(:final data):
          debugPrint('[PATCH] response keys: ${data.keys.toList()}');
          // Backend now returns { data: { delivery_status, rts_count, rts_attempts, media, ... } }
          // Unwrap the 'data' key; fall back to the flat response for backwards compat.
          final rawData = data['data'] is Map<String, dynamic>
              ? data['data'] as Map<String, dynamic>
              : data;
          debugPrint('[PATCH] response data keys: ${rawData.keys.toList()}');
          debugPrint('[PATCH] response media: ${rawData['media']}');
          debugPrint('[PATCH] rts_count: ${rawData['rts_count']}  rts_attempts: ${rawData['rts_attempts']}');
          await LocalDeliveryDao.instance.updateFromJson(
            widget.barcode,
            rawData,
          );
          final now = DateTime.now().millisecondsSinceEpoch;
          await DeliveryUpdateDao.instance.insert(
            DeliveryUpdateEntry(
              courierId: courierId,
              barcode: widget.barcode,
              payloadJson: jsonEncode(payload),
              syncStatus: SyncStatus.synced,
              attemptCount: 1,
              createdAt: now,
              updatedAt: now,
              syncedAt: now,
            ),
          );
          ref.read(deliveryRefreshProvider.notifier).state++;
          setState(() => _success = true);
          return;
        case ApiValidationError<Map<String, dynamic>>(
          :final errors,
          :final message,
        ):
          errors.forEach((key, value) => _errors[key] = value.first);
          setState(() {});
          final validationMsg = message?.isNotEmpty == true
              ? message!
              : 'Please correct the errors and try again.';
          showAppSnackbar(context, validationMsg, type: SnackbarType.error);
        case ApiConflict<Map<String, dynamic>>(:final message):
          showAppSnackbar(context, message, type: SnackbarType.error);
        case ApiNetworkError<Map<String, dynamic>>(:final message):
          showAppSnackbar(context, message, type: SnackbarType.error);
        case ApiRateLimited<Map<String, dynamic>>(:final message):
          showAppSnackbar(context, message, type: SnackbarType.error);
        case ApiServerError<Map<String, dynamic>>(:final message):
          showAppSnackbar(context, message, type: SnackbarType.error);
        case ApiUnauthorized<Map<String, dynamic>>():
          showAppSnackbar(
            context,
            'Session expired. Please log in again.',
            type: SnackbarType.error,
          );
      }
    } else {
      // ── Offline path: queue for later sync ──────────────────────────────
      // Store image bytes as base64 in _pending_media so the sync manager
      // can upload them when connectivity is restored.
      final pendingMedia = <Map<String, dynamic>>[];

      if (_status == 'delivered') {
        if (_podPhoto != null) {
          pendingMedia.add({
            'upload_type': 'pod',
            'delivery_images_type': 'pod', // API delivery_images type
            'b64': _podPhoto!.file,
            'filename': 'pod.jpg',
          });
        }
        if (_selfiePhoto != null) {
          pendingMedia.add({
            'upload_type': 'selfie',
            'delivery_images_type': 'selfie',
            'b64': _selfiePhoto!.file,
            'filename': 'selfie.jpg',
          });
        }
        if (_signatureBytes != null) {
          pendingMedia.add({
            'upload_type':
                'recipient_signature', // no delivery_images_type — goes to recipient_signature field
            'b64': base64Encode(_signatureBytes!),
            'filename': 'signature.png',
          });
        }
        payload['recipient'] = _recipient.text.trim();
        payload['relationship'] = _relationship;
        payload['placement_type'] = _placement;
      } else {
        // rts / osa — single selfie, same type for upload and delivery_images
        payload['reason'] = _reason;
        if (_selfiePhoto != null) {
          pendingMedia.add({
            'upload_type': 'selfie',
            'delivery_images_type': 'selfie',
            'b64': _selfiePhoto!.file,
            'filename': 'selfie.jpg',
          });
        }
      }

      if (pendingMedia.isNotEmpty) {
        payload['_pending_media'] = pendingMedia;
      }

      final now = DateTime.now().millisecondsSinceEpoch;
      await DeliveryUpdateDao.instance.insert(
        DeliveryUpdateEntry(
          courierId: courierId,
          barcode: widget.barcode,
          payloadJson: jsonEncode(payload),
          syncStatus: SyncStatus.pending,
          attemptCount: 0,
          createdAt: now,
          updatedAt: now,
        ),
      );
      await LocalDeliveryDao.instance.updateStatus(widget.barcode, _status);

      if (!mounted) return;
      ref.read(deliveryRefreshProvider.notifier).state++;
      setState(() {
        _loading = false;
        _success = true;
      });
      return;
    }

    if (mounted) setState(() => _loading = false);
  }

  void _clearDeliveredFields() {
    _recipient.clear();
    _relationship = null;
    _recipientIsOwner = false;
    _placement = 'received';
    _podPhoto = null;
    _selfiePhoto = null;
    _signatureBytes = null;
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
        _signatureBytes != null;

    if (_status == 'delivered' && hasDeliveredData) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text(
            'SWITCH STATUS?',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
          ),
          content: Text(
            'You have filled in delivery details (recipient, photos, signature). '
            'Switching to ${newStatus.toUpperCase()} will clear all of that data.\n\n'
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
      if (confirmed != true) return;
      _clearDeliveredFields();
    }

    setState(() {
      _status = newStatus;
      _reason = null;
    });
  }

  // ─── Build helpers ────────────────────────────────────────────────────────

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
    final errorKey = slotType == 'pod' ? 'pod_photo' : 'selfie_photo';
    final hasError = _errors[errorKey] != null;

    return Expanded(
      child: GestureDetector(
        onTap: onTapOverride ?? () => _pickPhotoForSlot(slotType),
        child: Container(
          height: 148,
          decoration: BoxDecoration(
            color: hasPhoto
                ? Colors.transparent
                : (isDark ? ColorStyles.grabCardElevatedDark : Colors.white),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: hasError
                  ? Colors.red
                  : hasPhoto
                  ? (isDark ? Colors.white10 : Colors.grey.shade200)
                  : color.withValues(alpha: 0.45),
              width: hasError ? 1.5 : 1.2,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: hasPhoto
              ? Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.memory(
                      base64Decode(photo.file),
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        color: isDark ? Colors.white10 : Colors.grey.shade100,
                        child: Icon(
                          Icons.broken_image_rounded,
                          size: 28,
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
                          horizontal: 10,
                          vertical: 6,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              label,
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,

                                letterSpacing: 0.5,
                              ),
                            ),
                            GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () => setState(() {
                                if (slotType == 'pod') {
                                  _podPhoto = null;
                                } else {
                                  _selfiePhoto = null;
                                }
                              }),
                              child: const Icon(
                                Icons.delete_outline_rounded,
                                size: 14,
                                color: Colors.redAccent,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                )
              : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(icon, size: 30, color: color),
                    const SizedBox(height: 8),
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
                        fontSize: 9,
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

  /// Clickable box for the recipient signature — same visual style as photo slots.
  Widget _buildSignatureSlot(bool isDark) {
    final hasSignature = _signatureBytes != null;
    final hasError = _errors['recipient_signature'] != null;

    return GestureDetector(
      onTap: _openSignatureCapture,
      child: Container(
        height: 130,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: hasError
                ? Colors.red
                : hasSignature
                ? (isDark ? Colors.white10 : Colors.grey.shade200)
                : ColorStyles.grabGreen.withValues(alpha: 0.45),
            width: hasError ? 1.5 : 1.2,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: hasSignature
            ? Stack(
                fit: StackFit.expand,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(10),
                    child: Image.memory(_signatureBytes!, fit: BoxFit.contain),
                  ),
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      color: Colors.black54,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'SIGNATURE',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,

                              letterSpacing: 0.5,
                            ),
                          ),
                          Row(
                            children: [
                              GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: _openSignatureCapture,
                                child: const Text(
                                  'RE-SIGN',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white70,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: () =>
                                    setState(() => _signatureBytes = null),
                                child: const Text(
                                  'CLEAR',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.redAccent,
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
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.draw_rounded,
                    size: 30,
                    color: ColorStyles.grabGreen.withValues(alpha: 0.7),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'SIGNATURE',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: ColorStyles.grabGreen.withValues(alpha: 0.8),
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'TAP TO SIGN (OPTIONAL)',
                    style: TextStyle(
                      fontSize: 9,
                      color: Colors.grey.shade500,
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  /// Returns true if the user has modified any form field from its initial
  /// state. Used by the navigation guard to decide whether to show the
  /// "Discard changes?" prompt.
  bool get _isDirty =>
      // changed status tab
      _status != 'delivered' ||
      // text fields
      _recipient.text.isNotEmpty ||
      _note.text.isNotEmpty ||
      // dropdowns
      _relationship != null ||
      _reason != null ||
      // photos / signature
      _podPhoto != null ||
      _selfiePhoto != null ||
      _photos.isNotEmpty ||
      _signatureBytes != null;

  @override
  Widget build(BuildContext context) {
    final bool needsReason = _status == 'rts' || _status == 'osa';
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isOnline = ref.read(isOnlineProvider);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        // Allow immediate back-navigation when nothing has changed or after
        // a successful submit (SuccessOverlay is already showing).
        if (!_isDirty || _success) {
          if (mounted) context.pop();
          return;
        }
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
        // ignore: use_build_context_synchronously
        if (leave == true && mounted) context.pop();
      },
      child: Scaffold(
        backgroundColor: isDark
            ? ColorStyles.grabCardDark
            : ColorStyles.grabCardLight,
        appBar: AppBar(
          backgroundColor: isDark ? ColorStyles.grabCardDark : Colors.white,
          elevation: 0,
          titleSpacing: 0,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'UPDATE STATUS',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.0,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
              Text(
                widget.barcode,
                style: TextStyle(
                  fontSize: 11,
                  color: isDark ? Colors.white54 : Colors.grey.shade500,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ), // Column
        ), // AppBar
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: FilledButton.icon(
              icon: const Icon(Icons.check_circle_outline_rounded),
              label: const Text(
                'SUBMIT UPDATE',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                ),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: ColorStyles.grabGreen,
                minimumSize: const Size.fromHeight(52),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onPressed: _loading ? null : _submit,
            ),
          ),
        ),
        body: Stack(
          children: [
            _loadingDelivery
                ? const Center(child: CircularProgressIndicator())
                : ListView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                    children: [
                      // ── Offline Banner ────────────────────────────────────────
                      if (!isOnline)
                        const OfflineBanner(
                          isMinimal: true,
                          customMessage: 'Update queued—will submit when online',
                          margin: EdgeInsets.only(bottom: 16),
                        ),
                      // ── STATUS SELECTION ──────────────────────────────────────
                      const DeliverySectionHeader(label: 'SELECT STATUS'),
                      const SizedBox(height: 10),
                      Row(
                        children: kUpdateStatuses.map((s) {
                          final meta = _kStatusMeta[s]!;
                          final selected = _status == s;
                          return Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4.0,
                              ),
                              child: GestureDetector(
                                onTap: () => _onStatusTap(s),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 180),
                                  decoration: BoxDecoration(
                                    color: selected
                                        ? meta.color
                                        : meta.color.withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: selected
                                          ? meta.color
                                          : meta.color.withValues(alpha: 0.35),
                                      width: selected ? 2 : 1.2,
                                    ),
                                    boxShadow: selected
                                        ? [
                                            BoxShadow(
                                              color: meta.color.withValues(
                                                alpha: 0.18,
                                              ),
                                              blurRadius: 8,
                                              offset: const Offset(0, 2),
                                            ),
                                          ]
                                        : [],
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 0,
                                    vertical: 12,
                                  ),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        meta.icon,
                                        color: selected
                                            ? Colors.white
                                            : meta.color,
                                        size: 22,
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        meta.label,
                                        style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 11,
                                          color: selected
                                              ? Colors.white
                                              : meta.color,
                                          letterSpacing: 0.5,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      if (_errors['delivery_status'] != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            _errors['delivery_status']!,
                            style: const TextStyle(
                              color: Colors.red,
                              fontSize: 12,
                            ),
                          ),
                        ),

                      // ── RECIPIENT INFO (delivered only) ───────────────────────
                      if (_status == 'delivered') ...[
                        const SizedBox(height: 20),
                        const DeliverySectionHeader(label: 'RECIPIENT INFO'),
                        const SizedBox(height: 8),
                        DeliveryRecipientCards(
                          recipientName: _delivery['name']?.toString() ?? '',
                          authorizedRep:
                              _delivery['authorized_rep']?.toString() ?? '',
                          onSelectRecipient: (name, relationship) {
                            // Detach listener so programmatic setText does not
                            // falsely trigger the owner-clearing logic.
                            _recipient.removeListener(_onRecipientTextChanged);
                            _recipient.text = name;
                            _recipient.addListener(_onRecipientTextChanged);
                            setState(() {
                              // null relationship = auth rep → reset to blank
                              _relationship = relationship;
                              _recipientIsOwner = relationship == 'self';
                              _errors.remove('recipient');
                              _errors.remove('relationship');
                            });
                          },
                        ),
                        const SizedBox(height: 8),

                        // Recipient name field with clear (✕) suffix icon
                        ValueListenableBuilder<TextEditingValue>(
                          valueListenable: _recipient,
                          builder: (context, value, _) => TextFormField(
                            controller: _recipient,
                            maxLength: kMaxRecipientLength,
                            textCapitalization: TextCapitalization.characters,
                            decoration:
                                deliveryFieldDecoration(
                                  context,
                                  labelText: 'RECIPIENT NAME',
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
                                              _recipientIsOwner = false;
                                              _relationship = null;
                                            });
                                          },
                                        )
                                      : null,
                                ),
                          ),
                        ),
                        const SizedBox(height: 8),

                        // Relationship dropdown: disabled (locked) when owner
                        // is selected; key forces rebuild when value changes.
                        DropdownButtonFormField<String>(
                          key: ValueKey(_relationship),
                          initialValue: _relationship,
                          decoration: deliveryFieldDecoration(
                            context,
                            labelText: _recipientIsOwner
                                ? 'RELATIONSHIP (LOCKED — OWNER)'
                                : 'RELATIONSHIP',
                            errorText: _errors['relationship'],
                          ),
                          items: kRelationshipOptions
                              .map(
                                (e) => DropdownMenuItem(
                                  value: e['value'],
                                  child: Text(e['label']!),
                                ),
                              )
                              .toList(),
                          onChanged: _recipientIsOwner
                              ? null
                              : (v) => setState(() => _relationship = v),
                        ),
                        const SizedBox(height: 8),

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
                          onChanged: (v) =>
                              setState(() => _placement = v ?? _placement),
                        ),
                      ],

                      // ── REASON (rts / osa) ───────────────────────────────────
                      if (needsReason) ...[
                        const SizedBox(height: 20),
                        const DeliverySectionHeader(
                          label: 'REASON FOR NON-DELIVERY',
                        ),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<String>(
                          initialValue: _reason,
                          decoration: deliveryFieldDecoration(
                            context,
                            labelText: 'SELECT REASON',
                            errorText: _errors['reason'],
                          ),
                          items: kReasons
                              .map(
                                (e) =>
                                    DropdownMenuItem(value: e, child: Text(e)),
                              )
                              .toList(),
                          onChanged: (v) => setState(() => _reason = v),
                        ),
                      ],

                      // ── PROOF OF DELIVERY: two fixed slots + signature ────────
                      if (_status == 'delivered') ...[
                        const SizedBox(height: 20),
                        const DeliverySectionHeader(
                          label: 'PROOF OF DELIVERY PHOTOS',
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            _buildPhotoSlot(
                              slotType: 'pod',
                              label: 'POD',
                              photo: _podPhoto,
                              icon: Icons.inventory_2_rounded,
                              color: ColorStyles.grabGreen,
                              isDark: isDark,
                            ),
                            const SizedBox(width: 10),
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
                        if (_errors['pod_photo'] != null ||
                            _errors['selfie_photo'] != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (_errors['pod_photo'] != null)
                                  Text(
                                    _errors['pod_photo']!,
                                    style: const TextStyle(
                                      color: Colors.red,
                                      fontSize: 12,
                                    ),
                                  ),
                                if (_errors['selfie_photo'] != null)
                                  Text(
                                    _errors['selfie_photo']!,
                                    style: const TextStyle(
                                      color: Colors.red,
                                      fontSize: 12,
                                    ),
                                  ),
                              ],
                            ),
                          ),

                        // Signature — same click-box design as photo slots
                        const SizedBox(height: 10),
                        _buildSignatureSlot(isDark),
                        if (_errors['recipient_signature'] != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              _errors['recipient_signature']!,
                              style: const TextStyle(
                                color: Colors.red,
                                fontSize: 12,
                              ),
                            ),
                          ),
                      ],

                      // ── SELFIE PHOTO (rts / osa) ──────────────────────────────
                      if (_status != 'delivered') ...[
                        const SizedBox(height: 20),
                        const DeliverySectionHeader(label: 'SELFIE PHOTO'),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            _buildPhotoSlot(
                              slotType: 'selfie',
                              label: 'SELFIE',
                              photo: _selfiePhoto,
                              icon: Icons.face_rounded,
                              color: Colors.blueGrey,
                              isDark: isDark,
                              onTapOverride: _pickSelfieForRtsOsa,
                            ),
                          ],
                        ),
                      ],

                      // ── REMARKS ───────────────────────────────────────────────
                      const SizedBox(height: 20),
                      const DeliverySectionHeader(label: 'REMARKS'),
                      const SizedBox(height: 8),
                      ValueListenableBuilder<TextEditingValue>(
                        valueListenable: _note,
                        builder: (context, value, _) => TextFormField(
                          controller: _note,
                          maxLength: kMaxNoteLength,
                          maxLines: 3,
                          textCapitalization: TextCapitalization.characters,
                          decoration:
                              deliveryFieldDecoration(
                                context,
                                hintText: 'REMARKS (OPTIONAL)',
                                errorText: _errors['note'],
                              ).copyWith(
                                suffixIcon: value.text.isNotEmpty
                                    ? Align(
                                        alignment: Alignment.topRight,
                                        heightFactor: 1.0,
                                        child: IconButton(
                                          icon: const Icon(
                                            Icons.clear_rounded,
                                            size: 18,
                                          ),
                                          color: Colors.grey.shade500,
                                          onPressed: () => _note.clear(),
                                        ),
                                      )
                                    : null,
                              ),
                        ),
                      ),

                      // ── TRANSACTION DATE (today in PST, read-only) ───────────
                      const SizedBox(height: 20),
                      const DeliverySectionHeader(label: 'TRANSACTION DATE'),
                      const SizedBox(height: 8),
                      TextFormField(
                        initialValue: _todayPST(),
                        enabled: false,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: isDark ? Colors.white70 : Colors.black87,
                        ),
                        decoration:
                            deliveryFieldDecoration(
                              context,
                              labelText: 'DATE (PHILIPPINE STANDARD TIME)',
                            ).copyWith(
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

                      // ── GEO LOCATION ──────────────────────────────────────────
                      const SizedBox(height: 20),
                      const DeliverySectionHeader(label: 'GEO LOCATION'),
                      const SizedBox(height: 8),
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
            if (_loading) const LoadingOverlay(),
            if (_success)
              SuccessOverlay(
                onDone: () {
                  if (!mounted) return;
                  showAppSnackbar(
                    context,
                    'Delivery status updated successfully.',
                    type: SnackbarType.success,
                  );
                  context.go('/dashboard');
                },
              ),
          ],
        ),
      ), // Scaffold
    ); // PopScope
  }
}

// working
