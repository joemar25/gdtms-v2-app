import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_client.dart';
import '../../core/auth/auth_provider.dart';
import '../../core/auth/auth_storage.dart';
import '../../core/settings/app_settings.dart';
import '../../shared/helpers/api_payload_helper.dart';
import '../../shared/widgets/bottom_nav_bar.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool _autoAccept = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    _autoAccept = await ref.read(appSettingsProvider).getAutoAcceptDispatch();
    if (mounted) setState(() {});
  }

  Future<void> _logout() async {
    await ref
        .read(apiClientProvider)
        .post<Map<String, dynamic>>('/logout', parser: parseApiMap);
    await ref.read(authStorageProvider).clearAll();
    await ref.read(authProvider.notifier).initialize();
    if (mounted) context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final courier = authState.courier ?? {};

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      bottomNavigationBar: const AppBottomNavBar(currentPath: '/profile'),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ListTile(
            title: const Text('Name'),
            subtitle: Text('${courier['name'] ?? '-'}'),
          ),
          ListTile(
            title: const Text('Courier Code'),
            subtitle: Text('${courier['courier_code'] ?? '-'}'),
          ),
          ListTile(
            title: const Text('Phone Number'),
            subtitle: Text('${courier['phone_number'] ?? '-'}'),
          ),
          const Divider(),
          SwitchListTile(
            title: const Text('Auto-accept dispatch'),
            value: _autoAccept,
            onChanged: (v) async {
              await ref.read(appSettingsProvider).setAutoAcceptDispatch(v);
              setState(() => _autoAccept = v);
            },
          ),
          SwitchListTile(
            title: const Text('Dark mode'),
            value: authState.themeMode == ThemeMode.dark,
            onChanged: (v) => ref.read(authProvider.notifier).setDarkMode(v),
          ),
          const SizedBox(height: 12),
          FilledButton.tonal(
            onPressed: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Confirm logout'),
                  content: const Text('Are you sure you want to logout?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Cancel'),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('Logout'),
                    ),
                  ],
                ),
              );
              if (confirmed == true) {
                await _logout();
              }
            },
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }
}
