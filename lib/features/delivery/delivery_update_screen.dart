import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_result.dart';
import '../../core/constants.dart';
import '../../core/models/photo_entry.dart';
import '../../shared/helpers/api_payload_helper.dart';
import '../../shared/helpers/snackbar_helper.dart';
import '../../shared/widgets/loading_overlay.dart';
import '../../shared/widgets/success_overlay.dart';

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
    return Scaffold(
      appBar: AppBar(title: Text('Update ${widget.barcode}')),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.all(16),
            children: [
              DropdownButtonFormField<String>(
                initialValue: _status,
                decoration: InputDecoration(
                  labelText: 'Status',
                  errorText: _errors['delivery_status'],
                ),
                items: kUpdateStatuses
                    .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                    .toList(),
                onChanged: (v) => setState(() => _status = v ?? _status),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _note,
                maxLength: kMaxNoteLength,
                decoration: InputDecoration(
                  labelText: 'Note',
                  errorText: _errors['note'],
                ),
              ),
              if (_status == 'delivered') ...[
                TextField(
                  controller: _recipient,
                  maxLength: kMaxRecipientLength,
                  decoration: InputDecoration(
                    labelText: 'Recipient',
                    errorText: _errors['recipient'],
                  ),
                ),
                DropdownButtonFormField<String>(
                  initialValue: _relationship,
                  decoration: const InputDecoration(
                    labelText: 'Relationship (optional)',
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
                DropdownButtonFormField<String>(
                  initialValue: _placement,
                  decoration: const InputDecoration(
                    labelText: 'Placement Type (optional)',
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
              if (_status == 'rts' || _status == 'osa')
                DropdownButtonFormField<String>(
                  initialValue: _reason,
                  decoration: InputDecoration(
                    labelText: 'Reason',
                    errorText: _errors['reason'],
                  ),
                  items: kReasons
                      .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                      .toList(),
                  onChanged: (v) => setState(() => _reason = v),
                ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: _photos.length >= kMaxDeliveryImages
                        ? null
                        : () => _pickImage(ImageSource.camera),
                    icon: const Icon(Icons.photo_camera),
                    label: const Text('Camera'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _photos.length >= kMaxDeliveryImages
                        ? null
                        : () => _pickImage(ImageSource.gallery),
                    icon: const Icon(Icons.photo_library),
                    label: const Text('Gallery'),
                  ),
                ],
              ),
              if (_photos.length >= kMaxDeliveryImages)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'You have reached the $kMaxDeliveryImages-image limit.',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
              if (_errors['delivery_images'] != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    _errors['delivery_images']!,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
              const SizedBox(height: 8),
              GridView.builder(
                itemCount: _photos.length,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  childAspectRatio: 1.3,
                ),
                itemBuilder: (_, i) {
                  final photo = _photos[i];
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Column(
                        children: [
                          const Icon(Icons.image),
                          DropdownButton<String>(
                            value: photo.type,
                            isExpanded: true,
                            items: kImageTypes
                                .map(
                                  (e) => DropdownMenuItem<String>(
                                    value: e,
                                    child: Text(e),
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
                            child: const Text('Remove'),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _loading ? null : _submit,
                child: const Text('Submit Update'),
              ),
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
