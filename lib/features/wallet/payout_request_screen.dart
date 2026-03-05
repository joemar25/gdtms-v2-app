import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_result.dart';
import '../../shared/helpers/api_payload_helper.dart';
import '../../shared/helpers/snackbar_helper.dart';

class PayoutRequestScreen extends ConsumerStatefulWidget {
  const PayoutRequestScreen({super.key});

  @override
  ConsumerState<PayoutRequestScreen> createState() =>
      _PayoutRequestScreenState();
}

class _PayoutRequestScreenState extends ConsumerState<PayoutRequestScreen> {
  DateTime? _fromDate;
  DateTime? _toDate;
  bool _loading = false;
  String? _error;

  String _fmt(DateTime d) => DateFormat('yyyy-MM-dd').format(d);

  Future<void> _submit() async {
    if (_toDate == null) {
      setState(() => _error = 'This field is required.');
      return;
    }
    if (_fromDate != null && _toDate!.isBefore(_fromDate!)) {
      setState(() => _error = 'End date must be after start date.');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    final result = await ref
        .read(apiClientProvider)
        .post<Map<String, dynamic>>(
          '/payment-request',
          data: {
            'from_date': _fromDate != null ? _fmt(_fromDate!) : null,
            'to_date': _fmt(_toDate!),
          },
          parser: parseApiMap,
        );

    if (!mounted) return;

    if (result is ApiSuccess<Map<String, dynamic>>) {
      showAppSnackbar(
        context,
        'Payout request submitted.',
        type: SnackbarType.success,
      );
      context.go('/wallet');
    } else if (result is ApiValidationError<Map<String, dynamic>>) {
      final firstError = result.errors.values.isNotEmpty
          ? result.errors.values.first.first
          : null;
      setState(() => _error = firstError ?? result.message ?? 'Invalid input.');
    } else {
      showAppSnackbar(
        context,
        'Failed to submit payout request.',
        type: SnackbarType.error,
      );
    }

    if (mounted) setState(() => _loading = false);
  }

  Future<void> _pickFromDate() async {
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      initialDate: _fromDate ?? DateTime.now(),
    );
    if (picked != null) setState(() => _fromDate = picked);
  }

  Future<void> _pickToDate() async {
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      initialDate: _toDate ?? DateTime.now(),
    );
    if (picked != null) setState(() => _toDate = picked);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Request Payout')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ListTile(
            title: const Text('From Date (optional)'),
            subtitle: Text(_fromDate != null ? _fmt(_fromDate!) : 'Not set'),
            trailing: const Icon(Icons.date_range),
            onTap: _pickFromDate,
          ),
          ListTile(
            title: const Text('To Date'),
            subtitle: Text(_toDate != null ? _fmt(_toDate!) : 'Required'),
            trailing: const Icon(Icons.date_range),
            onTap: _pickToDate,
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.all(8),
              child: Text(_error!, style: const TextStyle(color: Colors.red)),
            ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _loading ? null : _submit,
            child: const Text('Submit'),
          ),
        ],
      ),
    );
  }
}
