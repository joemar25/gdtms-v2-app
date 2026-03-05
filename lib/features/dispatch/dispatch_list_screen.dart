import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_result.dart';
import '../../core/constants.dart';
import '../../shared/helpers/api_payload_helper.dart';
import '../../shared/widgets/empty_state.dart';

class DispatchListScreen extends ConsumerStatefulWidget {
  const DispatchListScreen({super.key});

  @override
  ConsumerState<DispatchListScreen> createState() => _DispatchListScreenState();
}

class _DispatchListScreenState extends ConsumerState<DispatchListScreen> {
  bool _loading = true;
  List<Map<String, dynamic>> _dispatches = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final result = await ref
        .read(apiClientProvider)
        .get<Map<String, dynamic>>(
          '/pending-dispatches',
          queryParameters: {'page': 1, 'per_page': kDispatchesPerPage},
          parser: parseApiMap,
        );

    if (!mounted) return;
    if (result case ApiSuccess<Map<String, dynamic>>(:final data)) {
      _dispatches = listOfMapsFromKey(data, 'pending_dispatches');
    }
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Dispatches')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/dispatches/scan'),
        child: const Icon(Icons.qr_code_scanner),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: _dispatches.isEmpty
                  ? ListView(
                      children: [
                        SizedBox(
                          height: 400,
                          child: EmptyState(message: 'No pending dispatches.'),
                        ),
                      ],
                    )
                  : ListView.builder(
                      itemCount: _dispatches.length,
                      itemBuilder: (_, i) {
                        final item = _dispatches[i];
                        final code = item['dispatch_code']?.toString() ?? '';
                        return Card(
                          child: ListTile(
                            title: Text(code),
                            subtitle: Text(item['status']?.toString() ?? ''),
                            trailing: Text(
                              item['created_at']?.toString() ?? '',
                            ),
                            onTap: () => context.push(
                              '/dispatches/eligibility?dispatch_code=$code',
                            ),
                          ),
                        );
                      },
                    ),
            ),
    );
  }
}
