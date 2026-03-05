import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import 'package:fsi_courier_app/core/api/api_client.dart';
import 'package:fsi_courier_app/core/api/api_result.dart';
import 'package:fsi_courier_app/core/device/device_info.dart';
import 'package:fsi_courier_app/shared/helpers/api_payload_helper.dart';
import 'package:fsi_courier_app/shared/helpers/snackbar_helper.dart';
import 'package:fsi_courier_app/shared/widgets/loading_overlay.dart';
import 'package:fsi_courier_app/shared/widgets/success_overlay.dart';
import 'package:fsi_courier_app/styles/color_styles.dart';

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

  // Reject form state
  final _rejectReasonController = TextEditingController();
  bool _showRejectForm = false;
  String? _rejectError;
  bool _rejecting = false;

  @override
  void dispose() {
    _rejectReasonController.dispose();
    super.dispose();
  }

  String _getActualLast4(String code) {
    if (code.length < 4) return code;
    return code.substring(code.length - 4);
  }

  Future<bool> _showPinDialog() async {
    final actual = _getActualLast4(widget.dispatchCode);
    return await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => _PinConfirmDialog(expectedPin: actual),
        ) ??
        false;
  }

  Future<void> _acceptDispatch() async {
    final confirmed = await _showPinDialog();
    if (!confirmed) return;

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
      setState(() => _loading = false);
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

  Future<void> _submitReject() async {
    final reason = _rejectReasonController.text.trim();
    if (reason.isEmpty) {
      setState(() => _rejectError = 'Rejection reason is required.');
      return;
    }

    setState(() {
      _rejecting = true;
      _rejectError = null;
    });

    final result = await ref
        .read(apiClientProvider)
        .post<Map<String, dynamic>>(
          '/reject-dispatch',
          data: {
            'dispatch_code': widget.dispatchCode,
            'reason': reason,
          },
          parser: parseApiMap,
        );

    if (!mounted) return;
    setState(() => _rejecting = false);

    if (result is ApiSuccess<Map<String, dynamic>>) {
      showAppSnackbar(
        context,
        'Dispatch rejected.',
        type: SnackbarType.success,
      );
      context.go('/dispatches');
    } else {
      showAppSnackbar(
        context,
        'Failed to reject dispatch. Please try again.',
        type: SnackbarType.error,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final eligible = widget.eligibilityResponse['eligible'] == true;
    final info = mapFromKey(widget.eligibilityResponse, 'data');
    final reason =
        widget.eligibilityResponse['message']?.toString() ??
        'You are not eligible for this dispatch.';
    final maskedCode = widget.dispatchCode.length > 4
        ? '${widget.dispatchCode.substring(0, widget.dispatchCode.length - 4)}****'
        : '****';
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'DISPATCH',
          style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: 1),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_scanner_rounded),
            tooltip: 'Scan Dispatch',
            onPressed: () =>
                context.push('/scan', extra: {'mode': 'dispatch'}),
          ),
        ],
      ),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (!eligible) ...[
                const SizedBox(height: 40),
                Icon(Icons.cancel_rounded, color: Colors.red.shade400, size: 64),
                const SizedBox(height: 12),
                const Text(
                  'NOT ELIGIBLE',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 8),
                Text(reason, textAlign: TextAlign.center),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: () => context.go('/dispatches'),
                  child: const Text('BACK TO DISPATCHES'),
                ),
              ] else if (_showRejectForm) ...[
                // ── Reject Form ─────────────────────────────────────────
                _SectionHeader(label: 'REJECT DISPATCH'),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF1E1E2E)
                        : Colors.red.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        maskedCode,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Provide a reason for rejecting this dispatch.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _rejectReasonController,
                  maxLength: 100,
                  maxLines: 4,
                  textCapitalization: TextCapitalization.characters,
                  decoration: InputDecoration(
                    labelText: 'REJECTION REASON',
                    hintText: 'STATE YOUR REASON HERE...',
                    errorText: _rejectError,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    alignLabelWithHint: true,
                  ),
                  onChanged: (_) {
                    if (_rejectError != null) {
                      setState(() => _rejectError = null);
                    }
                  },
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _rejecting
                            ? null
                            : () => setState(() => _showRejectForm = false),
                        child: const Text('BACK'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.red.shade600,
                        ),
                        onPressed: _rejecting ? null : _submitReject,
                        child: _rejecting
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text('SUBMIT REJECTION'),
                      ),
                    ),
                  ],
                ),
              ] else ...[
                // ── Dispatch Info Card ───────────────────────────────────
                _SectionHeader(label: 'DISPATCH DETAILS'),
                const SizedBox(height: 10),
                _DispatchInfoCard(maskedCode: maskedCode, info: info),

                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: Colors.red.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.error_outline,
                          color: Colors.red,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _error!,
                            style: const TextStyle(
                              color: Colors.red,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 20),

                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: Colors.amber.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.lock_outline,
                        color: Colors.amber,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'To confirm acceptance, you will need to enter the last 4 digits of the dispatch code.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.amber.shade700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                FilledButton.icon(
                  icon: const Icon(Icons.check_circle_outline_rounded),
                  label: const Text('ACCEPT DISPATCH'),
                  style: FilledButton.styleFrom(
                    backgroundColor: ColorStyles.grabGreen,
                    minimumSize: const Size.fromHeight(52),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: _loading ? null : _acceptDispatch,
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  icon: const Icon(Icons.cancel_outlined),
                  label: const Text('REJECT DISPATCH'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red),
                    minimumSize: const Size.fromHeight(52),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: () => setState(() => _showRejectForm = true),
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

// ─── PIN Confirmation Dialog ──────────────────────────────────────────────────

class _PinConfirmDialog extends StatefulWidget {
  const _PinConfirmDialog({required this.expectedPin});
  final String expectedPin;

  @override
  State<_PinConfirmDialog> createState() => _PinConfirmDialogState();
}

class _PinConfirmDialogState extends State<_PinConfirmDialog> {
  final List<TextEditingController> _controllers =
      List.generate(4, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(4, (_) => FocusNode());
  String? _error;


  @override
  void initState() {
    super.initState();
    // Auto-focus the first digit when dialog is shown
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNodes[0].requestFocus();
    });
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  void _onDigitChanged(int index, String value) {
    if (value.length == 1 && index < 3) {
      _focusNodes[index + 1].requestFocus();
    }
    if (value.isEmpty && index > 0) {
      _focusNodes[index - 1].requestFocus();
    }
    setState(() => _error = null);
  }

  void _confirm() {
    final entered = _controllers.map((c) => c.text).join();
    if (entered.length < 4) {
      setState(() => _error = 'Please enter all 4 characters.');
      return;
    }
    if (entered != widget.expectedPin) {
      setState(() {
        _error = 'Incorrect PIN. Please check the dispatch code.';
        for (final c in _controllers) {
          c.clear();
        }
      });
      _focusNodes[0].requestFocus();
      return;
    }
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.lock_outline_rounded,
              size: 36,
              color: ColorStyles.grabGreen,
            ),
            const SizedBox(height: 12),
            const Text(
              'CONFIRM ACCEPTANCE',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 16,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'ENTER LAST 4 DIGITS OF DISPATCH CODE TO CONFIRM',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey.shade600,
                letterSpacing: 0.3,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                4,
                (i) => Container(
                  width: 54,
                  height: 58,
                  margin: const EdgeInsets.symmetric(horizontal: 5),
                  child: TextFormField(
                    controller: _controllers[i],
                    focusNode: _focusNodes[i],
                    textAlign: TextAlign.center,
                    keyboardType: TextInputType.text,
                    maxLength: 1,
                    textCapitalization: TextCapitalization.characters,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                        RegExp(r'[a-zA-Z0-9]'),
                      ),
                      _UpperCaseFormatter(),
                    ],
                    decoration: InputDecoration(
                      counterText: '',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(
                          color: ColorStyles.grabGreen,
                          width: 2,
                        ),
                      ),
                    ),
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                    onChanged: (v) => _onDigitChanged(i, v),
                  ),
                ),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(
                _error!,
                style: const TextStyle(color: Colors.red, fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: const Text('CANCEL'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: ColorStyles.grabGreen,
                    ),
                    onPressed: _confirm,
                    child: const Text('CONFIRM'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Forces all alphanumeric text to uppercase.
class _UpperCaseFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return newValue.copyWith(text: newValue.text.toUpperCase());
  }
}

// ─── Dispatch Info Card ───────────────────────────────────────────────────────

class _DispatchInfoCard extends StatelessWidget {
  const _DispatchInfoCard({required this.maskedCode, required this.info});
  final String maskedCode;
  final Map<String, dynamic> info;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF1E1E2E) : Colors.white;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        border: const Border(
          left: BorderSide(color: ColorStyles.grabGreen, width: 4),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.05),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            maskedCode,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 18,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 12),
          _InfoRow(
            icon: Icons.inventory_2_outlined,
            label: 'MAILPACKS',
            value: '${info['deliveries_count'] ?? '-'}',
          ),
          _InfoRow(
            icon: Icons.layers_outlined,
            label: 'BATCH VOLUME',
            value: '${info['batch_volume'] ?? '-'}',
          ),
          _InfoRow(
            icon: Icons.schedule_outlined,
            label: 'TAT',
            value: '${info['tat'] ?? '-'}',
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.label, required this.value});
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 14, color: Colors.grey.shade500),
          const SizedBox(width: 6),
          Text(
            '$label: ',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade500,
            ),
          ),
          Text(
            value,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: Colors.grey.shade500,
        letterSpacing: 1.5,
      ),
    );
  }
}
