import 'dart:convert';
import 'dart:io';

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
import 'package:fsi_courier_app/core/api/api_result.dart';
import 'package:fsi_courier_app/core/auth/auth_provider.dart';
import 'package:fsi_courier_app/core/constants.dart';
import 'package:fsi_courier_app/core/database/local_delivery_dao.dart';
import 'package:fsi_courier_app/core/database/sync_operations_dao.dart';
import 'package:fsi_courier_app/core/models/sync_operation.dart';
import 'package:fsi_courier_app/core/models/photo_entry.dart';
import 'package:fsi_courier_app/core/providers/connectivity_provider.dart';
import 'package:fsi_courier_app/core/providers/delivery_refresh_provider.dart';
import 'package:fsi_courier_app/core/providers/sync_provider.dart';
import 'package:fsi_courier_app/features/delivery/signature_capture_screen.dart';
import 'package:fsi_courier_app/features/delivery/widgets/delivery_form_helpers.dart';
import 'package:fsi_courier_app/features/delivery/widgets/delivery_geo_location_field.dart';
import 'package:fsi_courier_app/features/delivery/widgets/delivery_recipient_cards.dart';
import 'package:fsi_courier_app/shared/helpers/api_payload_helper.dart';
import 'package:fsi_courier_app/shared/helpers/snackbar_helper.dart';
import 'package:fsi_courier_app/shared/widgets/loading_overlay.dart';
import 'package:fsi_courier_app/shared/widgets/offline_banner.dart';
import 'package:fsi_courier_app/shared/widgets/sync_progress_bar.dart';
import 'package:fsi_courier_app/styles/color_styles.dart';

// ─── Consistent spacing constants ───────────────────────────────────────────
const _kSectionGap = SizedBox(height: 24); // between major sections
const _kFieldGap = SizedBox(height: 12); // between fields within a section
const _kInnerGap = SizedBox(height: 8); // header → first field
const _kPhotoHeight = 160.0; // photo slot height
const _kSignatureHeight = 144.0; // signature slot height

// ─── Status metadata ────────────────────────────────────────────────────────
const _kStatusMeta = {
  'DELIVERED': (
    label: 'DELIVERED',
    icon: Icons.check_circle_rounded,
    color: Color(0xFF00B14F),
  ),
  'RTS': (
    label: 'RTS',
    icon: Icons.keyboard_return_rounded,
    color: Colors.purple,
  ),
  'OSA': (label: 'OSA', icon: Icons.inbox_rounded, color: Colors.amber),
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
  double _dragStart = 0;

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

  // Non-delivered photos (rts / osa) — camera + gallery, free type
  final _photos = <PhotoEntry>[];

  // Signature file path for delivered status
  String? _signaturePath;

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
    // Detect when the courier edits the note manually so we can deselect the
    // active preset chip (it no longer exactly matches what's in the field).
    _note.addListener(_onNoteChanged);
  }

  void _onNoteChanged() {
    if (_activeNotePreset != null && _note.text != _activeNotePreset) {
      // Don't call setState here; just update the flag. The field will be
      // rebuilt on the next scheduled frame or next interaction anyway.
      // If an exact-match test is needed later it can be done lazily.
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
    _note.removeListener(_onNoteChanged);
    _note.dispose();
    _recipient.dispose();
    _relationshipSpecify.dispose();
    _reasonSpecify.dispose();
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
    final isSelfie = slotType == 'selfie';
    final picked = await _picker.pickImage(
      source: source,
      preferredCameraDevice:
          isSelfie ? CameraDevice.front : CameraDevice.rear,
    );
    if (picked == null || !mounted) return;

    final rawBytes = await picked.readAsBytes();
    final bytes = await FlutterImageCompress.compressWithList(
      rawBytes,
      minWidth: 600,
      quality: 70,
      format: CompressFormat.jpeg,
    );
    if (bytes.isEmpty || !mounted) return;

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
      } else {
        _selfiePhoto = entry;
        _errors.remove('selfie_photo');
      }
    });
  }

  // ── Selfie picker for rts/osa — forces Camera ─────────────────────────────
  Future<void> _pickSelfieForRtsOsa() async {
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

    if (_status == 'DELIVERED') {
      if (_recipient.text.trim().isEmpty) {
        _errors['recipient'] = 'This field is required.';
      }
      if (_relationship == null || _relationship!.isEmpty) {
        _errors['relationship'] = 'Relationship is required.';
      } else if (_relationship == 'OTHERS' &&
          _relationshipSpecify.text.trim().isEmpty) {
        _errors['relationship_specify'] =
            'Please specify the relationship.';
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

    if (_status == 'RTS' || _status == 'OSA') {
      if (_reason == null || _reason!.isEmpty) {
        _errors['reason'] = 'Reason is required.';
      } else if (_reason == 'Others' && _reasonSpecify.text.trim().isEmpty) {
        _errors['reason_specify'] = 'Please specify the reason.';
      }
      if (_selfiePhoto == null) {
        _errors['selfie_photo'] = 'Selfie photo is required.';
      }
    }

    setState(() {});
    return _errors.isEmpty;
  }

  // ── Submit ────────────────────────────────────────────────────────────────
  Future<void> _submit() async {
    if (!_validate()) return;

    setState(() => _loading = true);

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

    final payload = <String, dynamic>{
      'delivery_status': _status.toUpperCase(),
      if (_note.text.trim().isNotEmpty) 'note': _note.text.trim(),
    };

    if (_latitude != null && _longitude != null) {
      payload['latitude'] = _latitude;
      payload['longitude'] = _longitude;
      if (_geoAccuracy != null) payload['geo_accuracy'] = _geoAccuracy;
    }

    final pendingMediaPaths = <String, String>{};

    if (_status == 'DELIVERED') {
      if (_podPhoto != null) pendingMediaPaths['pod'] = _podPhoto!.file;
      if (_selfiePhoto != null) pendingMediaPaths['selfie'] = _selfiePhoto!.file;
      if (_signaturePath != null) {
        pendingMediaPaths['recipient_signature'] = _signaturePath!;
      }
      payload['recipient'] = _recipient.text.trim();
      payload['relationship'] = resolvedRelationship;
      payload['placement_type'] = _placement;
    } else {
      payload['reason'] = resolvedReason;
      if (_selfiePhoto != null) pendingMediaPaths['selfie'] = _selfiePhoto!.file;
    }

    final opId = const Uuid().v4();
    final now = DateTime.now().millisecondsSinceEpoch;
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
        createdAt: now,
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
    _photos.clear();
    _errors.clear();
  }

  void _clearNonDeliveredFields() {
    _reason = null;
    _reasonSpecify.clear();
    _selfiePhoto = null;
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

    if (_status == 'DELIVERED' && hasDeliveredData) {
      final confirmed = await _showSwitchConfirmDialog(
        context,
        from: 'DELIVERED',
        to: newStatus,
        detail: 'recipient info, photos, and signature',
      );
      if (confirmed != true || !mounted) return;
      _clearDeliveredFields();
    } else if ((_status == 'RTS' || _status == 'OSA') && hasNonDeliveredData) {
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
          Builder(builder: (context) {
            final presets = _status == 'DELIVERED'
                ? kDeliveredNotePresets
                : kNonDeliveredNotePresets;
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
    }),
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
    final errorKey = slotType == 'pod' ? 'pod_photo' : 'selfie_photo';
    final hasError = _errors[errorKey] != null;

    return Expanded(
      child: GestureDetector(
        onTap: onTapOverride ?? () => _pickPhotoForSlot(slotType),
        child: Container(
          height: _kPhotoHeight,
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
                    Image.file(
                      File(photo.file),
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        color: isDark
                            ? Colors.white10
                            : Colors.grey.shade100,
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
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.draw_rounded,
                    size: 34,
                    color: ColorStyles.grabGreen.withValues(alpha: 0.7),
                  ),
                  const SizedBox(height: 10),
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
                      fontSize: 10,
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
  bool get _isDirty =>
      _status != 'DELIVERED' ||
      _recipient.text.isNotEmpty ||
      _note.text.isNotEmpty ||
      _relationship != null ||
      _relationshipSpecify.text.isNotEmpty ||
      _reason != null ||
      _reasonSpecify.text.isNotEmpty ||
      _podPhoto != null ||
      _selfiePhoto != null ||
      _photos.isNotEmpty ||
      _signaturePath != null;

  @override
  Widget build(BuildContext context) {
    final bool needsReason = _status == 'RTS' || _status == 'OSA';
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isOnline = ref.read(isOnlineProvider);

    return PopScope(
      canPop: !_isDirty,
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
        // ignore: use_build_context_synchronously
        if (leave == true && mounted) context.pop();
      },
      child: Scaffold(
        backgroundColor: isDark
            ? ColorStyles.grabCardDark
            : ColorStyles.grabCardLight,
        floatingActionButtonLocation:
            FloatingActionButtonLocation.centerFloat,
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
              style: TextStyle(
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
              ),
            ),
            style: FilledButton.styleFrom(
              backgroundColor: ColorStyles.grabGreen,
              minimumSize: const Size(double.infinity, 56),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              elevation: 6,
              shadowColor: ColorStyles.grabGreen.withValues(alpha: 0.4),
            ),
            onPressed: _loading ? null : _submit,
          ),
        ),
        appBar: AppBar(
          backgroundColor:
              isDark ? ColorStyles.grabCardDark : Colors.white,
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
          ),
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
              child: Stack(
                children: [
                  _loadingDelivery
                      ? const Column(
                          children: [
                            SyncProgressBar(),
                            Expanded(
                              child:
                                  Center(child: CircularProgressIndicator()),
                            ),
                          ],
                        )
                      : ListView(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
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
                            if (_status == 'DELIVERED') ...[
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
                                  buildCounter: (
                                    _, {
                                    required currentLength,
                                    required isFocused,
                                    maxLength,
                                  }) =>
                                      null,
                                  textCapitalization:
                                      TextCapitalization.characters,
                                  inputFormatters: [
                                    TextInputFormatter.withFunction((oldValue, newValue) => newValue.copyWith(text: newValue.text.toUpperCase())),
                                  ],
                                  onChanged: (_) {
                                    if (_recipientIsOwner) {
                                      setState(() {
                                        _recipientIsOwner = false;
                                        _relationship = null;
                                      });
                                    }
                                  },
                                  decoration: deliveryFieldDecoration(
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
                                                _recipientIsOwner = false;
                                                _relationship = null;
                                              });
                                            },
                                          )
                                        : null,
                                  ),
                                ),
                              ),
                              _kFieldGap,

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
                                    .where(
                                      (e) =>
                                          _recipientIsOwner ||
                                          e['value'] != 'OWNER',
                                    )
                                    .map(
                                      (e) => DropdownMenuItem(
                                        value: e['value'],
                                        child: Text(e['label']!),
                                      ),
                                    )
                                    .toList(),
                                onChanged: _recipientIsOwner
                                    ? null
                                    : (v) => setState(() {
                                          _relationship = v;
                                          _relationshipSpecify.clear();
                                          _errors
                                              .remove('relationship_specify');
                                        }),
                              ),

                              // ── OTHERS → specify relationship ─────────────
                              if (_relationship == 'OTHERS') ...[
                                _kFieldGap,
                                TextFormField(
                                  controller: _relationshipSpecify,
                                  decoration: deliveryFieldDecoration(
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
                                  buildCounter: (
                                    _, {
                                    required currentLength,
                                    required isFocused,
                                    maxLength,
                                  }) =>
                                      null,
                                  onChanged: (v) => setState(
                                    () => _errors.remove(
                                      'relationship_specify',
                                    ),
                                  ),
                                ),
                              ],

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

                            // ── REASON FOR NON-DELIVERY (rts / osa) ─────────
                            if (needsReason) ...[
                              _kSectionGap,
                              const DeliverySectionHeader(
                                label: 'REASON FOR NON-DELIVERY',
                              ),
                              _kInnerGap,
                              DropdownButtonFormField<String>(
                                initialValue: _reason,
                                decoration: deliveryFieldDecoration(
                                  context,
                                  labelText: 'SELECT REASON',
                                  errorText: _errors['reason'],
                                ),
                                items: kReasons
                                    .map(
                                      (e) => DropdownMenuItem(
                                        value: e,
                                        child: Text(e),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (v) => setState(() {
                                  _reason = v;
                                  _reasonSpecify.clear();
                                  _errors.remove('reason_specify');
                                }),
                              ),

                              // ── Others → specify reason ───────────────────
                              if (_reason == 'Others') ...[
                                _kFieldGap,
                                TextFormField(
                                  controller: _reasonSpecify,
                                  decoration: deliveryFieldDecoration(
                                    context,
                                    labelText: 'SPECIFY REASON',
                                    hintText:
                                        'e.g. GATE IS LOCKED, NO CONTACT NUMBER',
                                    errorText: _errors['reason_specify'],
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
                                  buildCounter: (
                                    _, {
                                    required currentLength,
                                    required isFocused,
                                    maxLength,
                                  }) =>
                                      null,
                                  onChanged: (v) => setState(
                                    () => _errors.remove('reason_specify'),
                                  ),
                                ),
                              ],
                            ],

                            // ── PROOF OF DELIVERY (delivered) ────────────────
                            if (_status == 'DELIVERED') ...[
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
                                    color: ColorStyles.grabGreen,
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
                              _buildSignatureSlot(isDark),
                            ],

                            // ── SELFIE PHOTO (rts / osa) ─────────────────────
                            if (_status != 'DELIVERED') ...[
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
                                    onTapOverride: _pickSelfieForRtsOsa,
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
                              padding:
                                  const EdgeInsets.only(bottom: 8),
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
                                decoration: deliveryFieldDecoration(
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
                                              () =>
                                                  _activeNotePreset = null,
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
                              decoration:
                                  deliveryFieldDecoration(context).copyWith(
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
                  if (_loading) const LoadingOverlay(),
                ],
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
    final selectedColor = ColorStyles.grabGreen;
    final unselectedBg =
        isDark ? Colors.white.withValues(alpha: 0.06) : Colors.grey.shade100;
    final unselectedBorder = isDark
        ? Colors.white.withValues(alpha: 0.15)
        : Colors.grey.shade300;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: selected
              ? selectedColor.withValues(alpha: 0.12)
              : unselectedBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected
                ? selectedColor.withValues(alpha: 0.7)
                : unselectedBorder,
            width: selected ? 1.4 : 1.0,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (selected) ...[
              Icon(
                Icons.check_rounded,
                size: 13,
                color: selectedColor,
              ),
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
    final activeStatus =
        selectedIndex >= 0 ? widget.currentStatus : kUpdateStatuses[0];
    final activeMeta = _kStatusMeta[activeStatus]!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: 80,
          decoration: BoxDecoration(
            color: isDark ? Colors.white10 : Colors.grey.shade200,
            borderRadius: BorderRadius.circular(14),
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
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                            color: activeMeta.color.withValues(alpha: 0.3),
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