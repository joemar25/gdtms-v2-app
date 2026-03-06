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
import 'package:fsi_courier_app/core/constants.dart';
import 'package:fsi_courier_app/core/models/photo_entry.dart';
import 'package:fsi_courier_app/core/providers/delivery_refresh_provider.dart';
import 'package:fsi_courier_app/features/delivery/signature_capture_screen.dart';
import 'package:fsi_courier_app/features/delivery/widgets/delivery_form_helpers.dart';
import 'package:fsi_courier_app/features/delivery/widgets/delivery_geo_location_field.dart';
import 'package:fsi_courier_app/features/delivery/widgets/delivery_recipient_cards.dart';
import 'package:fsi_courier_app/shared/helpers/api_payload_helper.dart';
import 'package:fsi_courier_app/shared/helpers/snackbar_helper.dart';
import 'package:fsi_courier_app/shared/widgets/loading_overlay.dart';
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
    final result = await ref
        .read(apiClientProvider)
        .get<Map<String, dynamic>>(
          '/deliveries/${widget.barcode}',
          parser: parseApiMap,
        );

    if (!mounted) return;

    if (result case ApiSuccess<Map<String, dynamic>>(:final data)) {
      _delivery = mapFromKey(data, 'data');
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

  // ── Pick photo for a pre-defined delivered slot (camera only) ─────────────
  Future<void> _pickPhotoForSlot(String slotType) async {
    final picked = await _picker.pickImage(source: ImageSource.camera);
    if (picked == null) return;

    final bytes = await FlutterImageCompress.compressWithFile(
      picked.path,
      minWidth: 800,
      quality: 80,
      format: CompressFormat.jpeg,
    );
    if (bytes == null) return;

    // Map display slot name to the API-accepted image type.
    // API accepts: package, recipient, location, damage, other.
    final apiType = slotType == 'pod' ? 'package' : 'recipient';
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

  // ── Pick photo for rts/osa (camera + gallery) ────────────────────────────
  Future<void> _pickImage(ImageSource source) async {
    if (_photos.length >= kMaxDeliveryImages) {
      showAppSnackbar(
        context,
        'Maximum of $kMaxDeliveryImages images allowed.',
        type: SnackbarType.info,
      );
      return;
    }
    final picked = await _picker.pickImage(source: source);
    if (picked == null) return;

    final bytes = await FlutterImageCompress.compressWithFile(
      picked.path,
      minWidth: 800,
      quality: 80,
      format: CompressFormat.jpeg,
    );
    if (bytes == null) return;

    setState(() {
      _photos.add(
        PhotoEntry(
          id: _uuid.v4(),
          file: base64Encode(bytes),
          type: kImageTypes.first,
        ),
      );
    });
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
      if (_signatureBytes == null) {
        _errors['recipient_signature'] = 'Recipient signature is required.';
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

    // NOTE: For production, save images/signature to cloud first to get URL link
    // and put the URL in the payload for the correct type and for signature.
    // For now, this is for development/testing and uses placeholder filenames.
    final List<Map<String, dynamic>> deliveryImages = _status == 'delivered'
        ? [
            if (_podPhoto != null) {'file': 'testing.png', 'type': 'pod'},
            if (_selfiePhoto != null) {'file': 'testing.png', 'type': 'selfie'},
          ]
        : _photos
              .map((image) => {...image.toApiJson(), 'file': 'testing.png'})
              .toList();

    // Build payload — only include fields relevant to the current status.
    // Omit null-only fields to avoid server-side "required" validation triggers.
    final payload = <String, dynamic>{
      'delivery_status': _status,
      if (_note.text.trim().isNotEmpty) 'note': _note.text.trim(),
    };

    if (_status == 'delivered') {
      payload['recipient'] = _recipient.text.trim();
      payload['relationship'] = _relationship;
      payload['placement_type'] = _placement;
      payload['delivery_images'] = deliveryImages;
      if (_signatureBytes != null) {
        payload['recipient_signature'] = 'signatureblob.png';
      }
    } else {
      // rts / osa
      payload['reason'] = _reason;
      if (deliveryImages.isNotEmpty) {
        payload['delivery_images'] = deliveryImages;
      }
    }

    if (_latitude != null && _longitude != null) {
      payload['latitude'] = _latitude;
      payload['longitude'] = _longitude;
      if (_geoAccuracy != null) payload['geo_accuracy'] = _geoAccuracy;
    }

    final result = await ref
        .read(apiClientProvider)
        .patch<Map<String, dynamic>>(
          '/deliveries/${widget.barcode}',
          data: payload,
          parser: parseApiMap,
        );

    if (!mounted) return;

    switch (result) {
      case ApiSuccess<Map<String, dynamic>>():
        // Signal all delivery-watching screens to refresh
        ref.read(deliveryRefreshProvider.notifier).state++;
        setState(() => _success = true);
        return; // success overlay takes over; skip _loading = false below
      case ApiValidationError<Map<String, dynamic>>(
        :final errors,
        :final message,
      ):
        errors.forEach((key, value) => _errors[key] = value.first);
        setState(() {});
        // Always show the server message so nothing is silently lost.
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
      default:
        showAppSnackbar(
          context,
          'Failed to update delivery.',
          type: SnackbarType.error,
        );
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
  }) {
    final hasPhoto = photo != null;
    final errorKey = slotType == 'pod' ? 'pod_photo' : 'selfie_photo';
    final hasError = _errors[errorKey] != null;

    return Expanded(
      child: GestureDetector(
        onTap: () => _pickPhotoForSlot(slotType),
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
                                color: Colors.white,
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
          color: Colors.white,
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
                              color: Colors.white,
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
                    'TAP TO SIGN',
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
  @override
  Widget build(BuildContext context) {
    final bool needsReason = _status == 'rts' || _status == 'osa';
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
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
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: FilledButton.icon(
            icon: const Icon(Icons.check_circle_outline_rounded),
            label: const Text(
              'SUBMIT UPDATE',
              style: TextStyle(fontWeight: FontWeight.w700, letterSpacing: 0.8),
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
                              (e) => DropdownMenuItem(value: e, child: Text(e)),
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

                    // ── PHOTOS: camera + gallery (rts / osa) ─────────────────
                    if (_status != 'delivered') ...[
                      const SizedBox(height: 20),
                      const DeliverySectionHeader(label: 'PHOTOS'),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: DeliveryPhotoSourceButton(
                              icon: Icons.photo_camera_rounded,
                              label: 'CAMERA',
                              color: ColorStyles.grabGreen,
                              enabled: _photos.length < kMaxDeliveryImages,
                              onTap: () => _pickImage(ImageSource.camera),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: DeliveryPhotoSourceButton(
                              icon: Icons.photo_library_rounded,
                              label: 'GALLERY',
                              color: Colors.blueGrey,
                              enabled: _photos.length < kMaxDeliveryImages,
                              onTap: () => _pickImage(ImageSource.gallery),
                            ),
                          ),
                        ],
                      ),
                      if (_photos.length >= kMaxDeliveryImages)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            'MAXIMUM $kMaxDeliveryImages IMAGES REACHED.',
                            style: TextStyle(
                              color: Colors.orange.shade700,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      if (_photos.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Column(
                          children: List.generate(_photos.length, (i) {
                            final photo = _photos[i];
                            final imageBytes = base64Decode(photo.file);
                            return Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? ColorStyles.grabCardElevatedDark
                                    : Colors.white,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: isDark
                                      ? Colors.white10
                                      : Colors.grey.shade200,
                                ),
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  SizedBox(
                                    width: 100,
                                    height: 100,
                                    child: Image.memory(
                                      imageBytes,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => Container(
                                        color: isDark
                                            ? Colors.white10
                                            : Colors.grey.shade100,
                                        child: Icon(
                                          Icons.broken_image_rounded,
                                          size: 28,
                                          color: Colors.grey.shade400,
                                        ),
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: Padding(
                                      padding: const EdgeInsets.fromLTRB(
                                        12,
                                        10,
                                        10,
                                        10,
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'PHOTO ${i + 1}',
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w700,
                                              letterSpacing: 0.5,
                                              color: Colors.grey.shade500,
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 10,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: isDark
                                                  ? ColorStyles.grabCardDark
                                                  : Colors.grey.shade50,
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              border: Border.all(
                                                color: isDark
                                                    ? Colors.white12
                                                    : Colors.grey.shade300,
                                              ),
                                            ),
                                            child: DropdownButton<String>(
                                              value: photo.type,
                                              isExpanded: true,
                                              underline:
                                                  const SizedBox.shrink(),
                                              isDense: true,
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w700,
                                                color: isDark
                                                    ? Colors.white
                                                    : Colors.black87,
                                              ),
                                              items: kImageTypes
                                                  .map(
                                                    (e) =>
                                                        DropdownMenuItem<
                                                          String
                                                        >(
                                                          value: e,
                                                          child: Text(
                                                            e.toUpperCase(),
                                                          ),
                                                        ),
                                                  )
                                                  .toList(),
                                              onChanged: (v) {
                                                if (v == null) return;
                                                setState(() {
                                                  _photos[i] = PhotoEntry(
                                                    id: photo.id,
                                                    file: photo.file,
                                                    type: v,
                                                  );
                                                });
                                              },
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          GestureDetector(
                                            onTap: () => setState(
                                              () => _photos.removeAt(i),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(
                                                  Icons.delete_outline_rounded,
                                                  size: 14,
                                                  color: Colors.red.shade400,
                                                ),
                                                const SizedBox(width: 4),
                                                Text(
                                                  'REMOVE',
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w700,
                                                    color: Colors.red.shade400,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                        ),
                      ],
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
    );
  }
}
