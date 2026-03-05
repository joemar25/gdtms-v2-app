import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';

import 'package:fsi_courier_app/core/api/api_client.dart';
import 'package:fsi_courier_app/core/api/api_result.dart';
import 'package:fsi_courier_app/core/constants.dart';
import 'package:fsi_courier_app/core/models/photo_entry.dart';
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
  final _note = TextEditingController();
  final _recipient = TextEditingController();
  final _errors = <String, String>{};
  final _photos = <PhotoEntry>[];
  final _uuid = const Uuid();

  final _picker = ImagePicker();

  String _status = 'delivered';
  String? _relationship;
  String? _placement;
  String? _reason;
  bool _loading = false;
  bool _success = false;

  @override
  void dispose() {
    _note.dispose();
    _recipient.dispose();
    super.dispose();
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
      if (_photos.isEmpty) {
        _errors['delivery_images'] = 'At least one delivery image is required.';
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

  @override
  Widget build(BuildContext context) {
    final bool allowGallery = _status == 'rts' || _status == 'osa';
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
          ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              // ── STATUS SELECTION ────────────────────────────────────────
              const _SectionHeader(label: 'SELECT STATUS'),
              const SizedBox(height: 10),
              Row(
                children: kUpdateStatuses.map((s) {
                  final meta = _kStatusMeta[s]!;
                  final selected = _status == s;
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4.0),
                      child: GestureDetector(
                        onTap: () => setState(() {
                          _status = s;
                          _reason = null;
                        }),
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
                                      color: meta.color.withValues(alpha: 0.18),
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
                                color: selected ? Colors.white : meta.color,
                                size: 22,
                              ),
                              const SizedBox(height: 6),
                              Text(
                                meta.label,
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 11,
                                  color: selected ? Colors.white : meta.color,
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
                    style: const TextStyle(color: Colors.red, fontSize: 12),
                  ),
                ),

              // ── RECIPIENT INFO (delivered only) ────────────────────────
              if (_status == 'delivered') ...[
                const SizedBox(height: 20),
                const _SectionHeader(label: 'RECIPIENT INFO'),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _recipient,
                  maxLength: kMaxRecipientLength,
                  textCapitalization: TextCapitalization.characters,
                  decoration: _fieldDecoration(
                    context,
                    labelText: 'RECIPIENT NAME',
                    errorText: _errors['recipient'],
                  ),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: _relationship,
                  decoration: _fieldDecoration(
                    context,
                    labelText: 'RELATIONSHIP (OPTIONAL)',
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
                  decoration: _fieldDecoration(
                    context,
                    labelText: 'PLACEMENT TYPE (OPTIONAL)',
                  ),
                  items: kPlacementOptions
                      .map(
                        (e) => DropdownMenuItem(
                          value: e['value'],
                          child: Text(e['label']!),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => setState(() => _placement = v),
                ),
              ],

              // ── REASON (rts / osa / failed_attempt) ───────────────────
              if (needsReason) ...[
                const SizedBox(height: 20),
                const _SectionHeader(label: 'REASON FOR NON-DELIVERY'),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: _reason,
                  decoration: _fieldDecoration(
                    context,
                    labelText: 'SELECT REASON',
                    errorText: _errors['reason'],
                  ),
                  items: kReasons
                      .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                      .toList(),
                  onChanged: (v) => setState(() => _reason = v),
                ),
              ],

              // ── PHOTOS ─────────────────────────────────────────────────
              const SizedBox(height: 20),
              const _SectionHeader(label: 'PROOF OF DELIVERY PHOTOS'),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _PhotoSourceButton(
                      icon: Icons.photo_camera_rounded,
                      label: 'CAMERA',
                      color: ColorStyles.grabGreen,
                      enabled: _photos.length < kMaxDeliveryImages,
                      onTap: () => _pickImage(ImageSource.camera),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _PhotoSourceButton(
                      icon: Icons.photo_library_rounded,
                      label: 'GALLERY',
                      color: Colors.blueGrey,
                      enabled:
                          allowGallery && _photos.length < kMaxDeliveryImages,
                      onTap: allowGallery
                          ? () => _pickImage(ImageSource.gallery)
                          : null,
                      disabledReason:
                          allowGallery ? null : 'GALLERY ONLY FOR RTS/OSA',
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
              if (_errors['delivery_images'] != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    _errors['delivery_images']!,
                    style: const TextStyle(color: Colors.red, fontSize: 12),
                  ),
                ),
              if (_photos.isNotEmpty) ...[
                const SizedBox(height: 12),
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  childAspectRatio: 1.3,
                  children: List.generate(_photos.length, (i) {
                    final photo = _photos[i];
                    return Container(
                      decoration: BoxDecoration(
                        color: isDark
                            ? ColorStyles.grabCardElevatedDark
                            : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isDark ? Colors.white10 : Colors.grey.shade200,
                        ),
                      ),
                      padding: const EdgeInsets.all(10),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.image_rounded,
                            size: 28,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(height: 4),
                          DropdownButton<String>(
                            value: photo.type,
                            isExpanded: true,
                            underline: const SizedBox.shrink(),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                            items: kImageTypes
                                .map(
                                  (e) => DropdownMenuItem<String>(
                                    value: e,
                                    child: Text(e.toUpperCase()),
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
                          TextButton(
                            onPressed: () =>
                                setState(() => _photos.removeAt(i)),
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.red,
                              padding: EdgeInsets.zero,
                              minimumSize: const Size(0, 24),
                            ),
                            child: const Text(
                              'REMOVE',
                              style: TextStyle(fontSize: 11),
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
              const _SectionHeader(label: 'REMARKS'),
              const SizedBox(height: 8),
              TextFormField(
                controller: _note,
                maxLength: kMaxNoteLength,
                maxLines: 3,
                textCapitalization: TextCapitalization.characters,
                decoration: _fieldDecoration(
                  context,
                  hintText: 'ADD A REMARK (OPTIONAL)',
                  errorText: _errors['note'],
                ),
              ),

              // ── SYSTEM FIELDS (PENDING API) ────────────────────────────
              const SizedBox(height: 20),
              const _SectionHeader(label: 'SYSTEM FIELDS'),
              const SizedBox(height: 8),
              const _PendingApiField(label: 'GEO LOCATION'),

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

// ─── Theme-aware field decoration ───────────────────────────────────────────
InputDecoration _fieldDecoration(
  BuildContext context, {
  String? labelText,
  String? hintText,
  String? errorText,
}) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final fill = isDark ? ColorStyles.grabCardElevatedDark : Colors.white;
  final borderColor = isDark ? Colors.white12 : Colors.grey.shade300;
  return InputDecoration(
    labelText: labelText,
    hintText: hintText,
    errorText: errorText,
    filled: true,
    fillColor: fill,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: borderColor),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: borderColor),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: ColorStyles.grabGreen, width: 1.5),
    ),
  );
}

// ─── Section header ──────────────────────────────────────────────────────────
class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.2,
        color: Colors.grey.shade600,
      ),
    );
  }
}

// ─── Pending API field placeholder ───────────────────────────────────────────
class _PendingApiField extends StatelessWidget {
  const _PendingApiField({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? ColorStyles.grabCardElevatedDark : Colors.white;
    final textColor = isDark ? Colors.white70 : Colors.grey.shade600;
    final borderColor = isDark ? Colors.white10 : Colors.grey.shade300;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          Icon(Icons.location_on_outlined, size: 18, color: textColor),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Read-only • Not saved',
                  style: TextStyle(
                    fontSize: 10,
                    color: isDark ? Colors.white54 : Colors.grey.shade500,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: ColorStyles.grabOrange.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Text(
              '⏳ API PENDING',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: ColorStyles.grabOrange,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Photo source button ──────────────────────────────────────────────────────
class _PhotoSourceButton extends StatelessWidget {
  const _PhotoSourceButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.enabled,
    required this.onTap,
    this.disabledReason,
  });
  final IconData icon;
  final String label;
  final Color color;
  final bool enabled;
  final VoidCallback? onTap;
  final String? disabledReason;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        decoration: BoxDecoration(
          color: enabled
              ? color.withValues(alpha: 0.08)
              : ColorStyles.grabCardElevatedDark, // Use consistent disabled bg
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: enabled
                ? color.withValues(alpha: 0.4)
                : ColorStyles.grabCardDark, // Use consistent disabled border
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: enabled ? color : Colors.grey.shade400, size: 22),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: enabled ? color : Colors.grey.shade400,
                letterSpacing: 0.5,
              ),
            ),
            if (disabledReason != null && !enabled)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  disabledReason!,
                  style: const TextStyle(
                    fontSize: 9,
                    color: Colors.deepOrange,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
