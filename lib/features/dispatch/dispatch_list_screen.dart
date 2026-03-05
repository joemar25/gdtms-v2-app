import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:fsi_courier_app/core/api/api_client.dart';
import 'package:fsi_courier_app/core/api/api_result.dart';
import 'package:fsi_courier_app/core/constants.dart';
import 'package:fsi_courier_app/core/settings/app_settings.dart';
import 'package:fsi_courier_app/shared/helpers/api_payload_helper.dart';
import 'package:fsi_courier_app/shared/widgets/app_header_bar.dart';
import 'package:fsi_courier_app/shared/widgets/empty_state.dart';

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
      appBar: const AppHeaderBar(title: 'Dispatches'),
      floatingActionButton: FloatingActionButton(
        onPressed: () =>
            context.push('/scan', extra: {'mode': 'dispatch'}),
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
                            onTap: () async {
                              final autoAccept = await ref
                                  .read(appSettingsProvider)
                                  .getAutoAcceptDispatch();
                              if (!context.mounted) return;
                              context.push('/dispatches/eligibility', extra: {
                                'dispatch_code': code,
                                'eligibility_response': {
                                  ...item,
                                  'eligible': true,
                                },
                                'auto_accept': autoAccept,
                              });
                            },
                          ),
                        );
                      },
                    ),
            ),
    );
  }
}
