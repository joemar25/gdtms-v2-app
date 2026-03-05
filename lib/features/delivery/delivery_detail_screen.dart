import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_result.dart';
import '../../shared/helpers/api_payload_helper.dart';
import '../../shared/widgets/status_badge.dart';

class DeliveryDetailScreen extends ConsumerStatefulWidget {
  const DeliveryDetailScreen({super.key, required this.barcode});

  final String barcode;

  @override
  ConsumerState<DeliveryDetailScreen> createState() =>
      _DeliveryDetailScreenState();
}

class _DeliveryDetailScreenState extends ConsumerState<DeliveryDetailScreen> {
  bool _loading = true;
  Map<String, dynamic> _delivery = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
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

    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final status = _delivery['delivery_status']?.toString() ?? 'pending';

    return Scaffold(
      appBar: AppBar(title: Text(widget.barcode)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                StatusBadge(status: status),
                const SizedBox(height: 12),
                ..._delivery.entries.map(
                  (e) => ListTile(
                    title: Text(e.key),
                    subtitle: Text('${e.value}'),
                  ),
                ),
                if (status == 'pending' || status == 'rts' || status == 'osa')
                  FilledButton(
                    onPressed: () =>
                        context.push('/deliveries/${widget.barcode}/update'),
                    child: const Text('Update Status'),
                  ),
              ],
            ),
    );
  }
}
