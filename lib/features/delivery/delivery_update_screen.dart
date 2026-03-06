import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:signature/signature.dart';
import 'package:uuid/uuid.dart';

import 'package:fsi_courier_app/core/api/api_client.dart';
import 'package:fsi_courier_app/core/api/api_result.dart';
import 'package:fsi_courier_app/core/constants.dart';
import 'package:fsi_courier_app/core/models/photo_entry.dart';
import 'package:fsi_courier_app/features/delivery/widgets/delivery_form_helpers.dart';
import 'package:fsi_courier_app/features/delivery/widgets/delivery_geo_location_field.dart';
import 'package:fsi_courier_app/features/delivery/widgets/delivery_recipient_cards.dart';
import 'package:fsi_courier_app/features/delivery/widgets/delivery_signature_field.dart';
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
  final _photos = <PhotoEntry>[];
  final _uuid = const Uuid();

  final _picker = ImagePicker();

  String _status = 'delivered';
  String? _relationship;
  String _placement = 'received'; // Default to 'received'
  String? _reason;
  bool _loading = false;
  bool _success = false;

  // Geo location
  double? _latitude;
  double? _longitude;
  double? _geoAccuracy;
  bool _gettingLocation = false;

  // Recipient signature
  late final SignatureController _signatureController;

  @override
  void initState() {
    super.initState();
    _signatureController = SignatureController(
      penStrokeWidth: 2.5,
      penColor: Colors.black87,
      exportBackgroundColor: Colors.white,
    );
    _loadDelivery();
    _captureLocation(); // auto-start on screen open; button is only fallback
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
    _recipient.dispose();
    _signatureController.dispose();
    super.dispose();
  }

  Future<void> _captureLocation() async {
    setState(() => _gettingLocation = true);
    try {
      // Check if GPS is turned on
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

      // Use permission_handler to request (same pattern as camera)
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
      if (_photos.isEmpty) {
        _errors['delivery_images'] = 'At least one delivery image is required.';
      }
      if (!_signatureController.isNotEmpty) {
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

  Future<void> _submit() async {
    if (!_validate()) return;

    setState(() => _loading = true);

    Uint8List? sigBytes;
    if (_status == 'delivered' && _signatureController.isNotEmpty) {
      sigBytes = await _signatureController.toPngBytes();
    }

    final result = await ref
        .read(apiClientProvider)
        .patch<Map<String, dynamic>>(
          '/deliveries/${widget.barcode}',
          data: {
            'delivery_status': _status,
            'note': _note.text,
            'recipient': _status == 'delivered' ? _recipient.text.trim() : null,
            'relationship': _status == 'delivered' ? _relationship : null,
            'placement_type': _status == 'delivered' ? _placement : null,
            'reason': (_status == 'rts' || _status == 'osa') ? _reason : null,
            'delivery_images': _photos.map((e) => e.toApiJson()).toList(),
            if (_status == 'delivered' && sigBytes != null)
              'recipient_signature': base64Encode(sigBytes),
            if (_latitude != null && _longitude != null) ...{
              'latitude': _latitude,
              'longitude': _longitude,
              if (_geoAccuracy != null) 'geo_accuracy': _geoAccuracy,
            },
          },
          parser: parseApiMap,
        );

    if (!mounted) return;

    switch (result) {
      case ApiSuccess<Map<String, dynamic>>():
        setState(() => _success = true);
      case ApiValidationError<Map<String, dynamic>>(:final errors):
        errors.forEach((key, value) => _errors[key] = value.first);
        setState(() {});
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
    _placement = 'received';
    _photos.clear();
    _signatureController.clear();
    _errors.clear();
  }

  Future<void> _onStatusTap(String newStatus) async {
    if (newStatus == _status) return;

    // Confirm before discarding delivered details
    if (_status == 'delivered' &&
        (_recipient.text.isNotEmpty ||
            _relationship != null ||
            _photos.isNotEmpty ||
            _signatureController.isNotEmpty)) {
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

  @override
  Widget build(BuildContext context) {
    final bool allowGallery = _status != 'delivered';
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
                    // ── STATUS SELECTION ────────────────────────────────────────
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

                    // ── RECIPIENT INFO (delivered only) ────────────────────────
                    if (_status == 'delivered') ...[
                      const SizedBox(height: 20),
                      const DeliverySectionHeader(label: 'RECIPIENT INFO'),
                      const SizedBox(height: 8),
                      // Clickable recipient + authorized rep cards
                      DeliveryRecipientCards(
                        recipientName: _delivery['name']?.toString() ?? '',
                        authorizedRep: _delivery['authorized_rep']?.toString() ?? '',
                        onSelectRecipient: (name, relationship) => setState(() {
                          _recipient.text = name;
                          if (relationship != null) _relationship = relationship;
                        }),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _recipient,
                        maxLength: kMaxRecipientLength,
                        textCapitalization: TextCapitalization.characters,
                        decoration: deliveryFieldDecoration(
                          context,
                          labelText: 'RECIPIENT NAME',
                          errorText: _errors['recipient'],
                        ),
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        initialValue: _relationship,
                        decoration: deliveryFieldDecoration(
                          context,
                          labelText: 'RELATIONSHIP',
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
                        onChanged: (v) => setState(() => _relationship = v),
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

                    // ── REASON (rts / osa / failed_attempt) ───────────────────
                    if (needsReason) ...[
                      const SizedBox(height: 20),
                      const DeliverySectionHeader(label: 'REASON FOR NON-DELIVERY'),
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

                    // ── PHOTOS ─────────────────────────────────────────────────
                    const SizedBox(height: 20),
                    const DeliverySectionHeader(label: 'PROOF OF DELIVERY PHOTOS'),
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
                        // Gallery available for non-delivered statuses (rts/osa)
                        if (allowGallery) ...[
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
                    if (_errors['delivery_images'] != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          _errors['delivery_images']!,
                          style: const TextStyle(
                            color: Colors.red,
                            fontSize: 12,
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
                                // Actual image thumbnail
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
                                // Right: label + type dropdown + remove
                                Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                        12, 10, 10, 10),
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
                                                      DropdownMenuItem<String>(
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
                                              () => _photos.removeAt(i)),
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

                    // ── REMARKS ────────────────────────────────────────────────
                    const SizedBox(height: 20),
                    const DeliverySectionHeader(label: 'REMARKS'),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _note,
                      maxLength: kMaxNoteLength,
                      maxLines: 3,
                      textCapitalization: TextCapitalization.characters,
                      decoration: deliveryFieldDecoration(
                        context,
                        hintText: 'REMARKS (OPTIONAL)',
                        errorText: _errors['note'],
                      ),
                    ),

                    // ── GEO LOCATION ────────────────────────────────────────────
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

                    // ── SIGNATURE (delivered only) ───────────────────────────
                    if (_status == 'delivered') ...[
                      const SizedBox(height: 20),
                      const DeliverySectionHeader(label: 'RECIPIENT SIGNATURE'),
                      const SizedBox(height: 8),
                      DeliverySignatureField(
                        controller: _signatureController,
                        errorText: _errors['recipient_signature'],
                        onClear: () => setState(() {
                          _signatureController.clear();
                          _errors.remove('recipient_signature');
                        }),
                      ),
                    ],

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
