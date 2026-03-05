import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_result.dart';
import '../../core/device/device_info.dart';
import '../../shared/helpers/api_payload_helper.dart';
import '../../shared/helpers/snackbar_helper.dart';
import '../../shared/widgets/loading_overlay.dart';
import '../../shared/widgets/success_overlay.dart';

class DispatchEligibilityScreen extends ConsumerStatefulWidget {
  const DispatchEligibilityScreen({
    super.key,
    required this.dispatchCode,
    required this.eligibilityResponse,
    required this.autoAccept,
  });

  final String dispatchCode;
  final Map<String, dynamic> eligibilityResponse;
  final bool autoAccept;

  @override
  ConsumerState<DispatchEligibilityScreen> createState() =>
      _DispatchEligibilityScreenState();
}

class _DispatchEligibilityScreenState
    extends ConsumerState<DispatchEligibilityScreen> {
  bool _loading = false;
  bool _showSuccess = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.eligibilityResponse['eligible'] == true && widget.autoAccept) {
      _acceptDispatch();
    }
  }

  Future<void> _acceptDispatch() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    const uuid = Uuid();
    final acceptId = uuid.v4();
    final device = ref.read(deviceInfoProvider);

    final result = await ref
        .read(apiClientProvider)
        .post<Map<String, dynamic>>(
          '/accept-dispatch',
          data: {
            'dispatch_code': widget.dispatchCode,
            'client_request_id': acceptId,
            'device_info': await device.toMap(),
          },
          parser: parseApiMap,
        );

    if (!mounted) return;

    final alreadyAccepted =
        result is ApiConflict<Map<String, dynamic>> ||
        (result is ApiServerError<Map<String, dynamic>> &&
            result.message.toLowerCase().contains('already accepted'));

    if (result is ApiSuccess<Map<String, dynamic>>) {
      setState(() {
        _showSuccess = true;
        _loading = false;
      });
      return;
    }

    if (alreadyAccepted) {
      setState(() {
        _loading = false;
      });
      showAppSnackbar(
        context,
        'Dispatch already accepted. Opening deliveries.',
        type: SnackbarType.info,
      );
      context.go('/deliveries');
      return;
    }

    setState(() {
      _loading = false;
      _error = result is ApiServerError<Map<String, dynamic>>
          ? result.message
          : 'Unable to accept dispatch.';
    });
  }

  @override
  Widget build(BuildContext context) {
    final eligible = widget.eligibilityResponse['eligible'] == true;
    final info = mapFromKey(widget.eligibilityResponse, 'data');
    final reason =
        widget.eligibilityResponse['message']?.toString() ??
        'You are not eligible for this dispatch.';

    return Scaffold(
      appBar: AppBar(title: const Text('Dispatch Eligibility')),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (!eligible) ...[
                const Icon(Icons.cancel, color: Colors.red, size: 60),
                const SizedBox(height: 8),
                Text(reason, textAlign: TextAlign.center),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => context.go('/dispatches/scan'),
                  child: const Text('Back'),
                ),
              ] else ...[
                Text('Dispatch Code: ${widget.dispatchCode}'),
                const SizedBox(height: 8),
                Text('Deliveries: ${info['deliveries_count'] ?? '-'}'),
                Text('Batch Volume: ${info['batch_volume'] ?? '-'}'),
                Text('TAT: ${info['tat'] ?? '-'}'),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(_error!, style: const TextStyle(color: Colors.red)),
                ],
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _loading ? null : _acceptDispatch,
                  child: const Text('Accept'),
                ),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: () {
                    showAppSnackbar(
                      context,
                      'Dispatch rejected.',
                      type: SnackbarType.info,
                    );
                    context.go('/dispatches/scan');
                  },
                  child: const Text('Reject'),
                ),
              ],
            ],
          ),
          if (_loading) const LoadingOverlay(),
          if (_showSuccess)
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
    );
  }
}
