import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_result.dart';
import '../../shared/helpers/api_payload_helper.dart';
import '../../shared/widgets/bottom_nav_bar.dart';

class WalletScreen extends ConsumerStatefulWidget {
  const WalletScreen({super.key});

  @override
  ConsumerState<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends ConsumerState<WalletScreen> {
  bool _loading = true;
  Map<String, dynamic> _data = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final result = await ref
        .read(apiClientProvider)
        .get<Map<String, dynamic>>('/wallet-summary', parser: parseApiMap);

    if (!mounted) return;
    if (result case ApiSuccess<Map<String, dynamic>>(:final data)) {
      _data = mapFromKey(data, 'data');
    }
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final latest = asStringDynamicMap(_data['latest_request']);

    return Scaffold(
      appBar: AppBar(title: const Text('Wallet')),
      bottomNavigationBar: const AppBottomNavBar(currentPath: '/wallet'),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  child: ListTile(
                    title: const Text('Total Earnings'),
                    trailing: Text('${_data['total_earnings'] ?? '0.00'}'),
                  ),
                ),
                Card(
                  child: ListTile(
                    title: const Text('Tentative Pending Payout'),
                    trailing: Text(
                      '${_data['tentative_pending_payout'] ?? '0.00'}',
                    ),
                  ),
                ),
                if (latest.isNotEmpty)
                  Card(
                    child: ListTile(
                      title: Text('Latest Request #${latest['id']}'),
                      subtitle: Text(
                        '${latest['status']} • ${latest['from_date']} to ${latest['to_date']}',
                      ),
                      trailing: Text('${latest['amount']}'),
                      onTap: () => context.push('/wallet/${latest['id']}'),
                    ),
                  ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: () => context.push('/wallet/request'),
                  child: const Text('Request Payout'),
                ),
              ],
            ),
    );
  }
}
