import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:fsi_courier_app/core/api/api_client.dart';
import 'package:fsi_courier_app/core/auth/auth_provider.dart';
import 'package:fsi_courier_app/core/auth/auth_storage.dart';
import 'package:fsi_courier_app/core/config.dart';
import 'package:fsi_courier_app/core/database/app_database.dart';
import 'package:fsi_courier_app/core/device/device_info.dart';
import 'package:fsi_courier_app/core/providers/connectivity_provider.dart';
import 'package:fsi_courier_app/core/constants.dart';
import 'package:fsi_courier_app/core/settings/app_settings.dart';
import 'package:fsi_courier_app/core/settings/compact_mode_provider.dart';
import 'package:fsi_courier_app/shared/helpers/api_payload_helper.dart';
import 'package:fsi_courier_app/shared/helpers/snackbar_helper.dart';
import 'package:fsi_courier_app/shared/widgets/app_header_bar.dart';
import 'package:fsi_courier_app/shared/widgets/confirmation_dialog.dart';
import 'package:fsi_courier_app/shared/widgets/floating_bottom_nav_bar.dart';
import 'package:fsi_courier_app/shared/widgets/offline_banner.dart';
import 'package:fsi_courier_app/styles/color_styles.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool _autoAccept = false;
  int _syncRetentionDays = kDefaultSyncRetentionDays;

  // Device specs (loaded async)
  String _deviceModel = '…';
  String _osVersion = '…';
  String _deviceId = '…';
  String _sdkVersion = '…';
  bool _specsLoaded = false;
  double _freeStorageGb = -1.0;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _loadDeviceSpecs();
  }

  Future<void> _refresh() async {
    await Future.wait([_loadSettings(), _loadDeviceSpecs()]);
  }

  Future<void> _loadSettings() async {
    final autoAccept = await ref
        .read(appSettingsProvider)
        .getAutoAcceptDispatch();
    final retentionDays = await ref
        .read(appSettingsProvider)
        .getSyncRetentionDays();
    if (mounted) {
      setState(() {
        _autoAccept = autoAccept;
        _syncRetentionDays = retentionDays;
      });
    }
  }

  void _showSettingsUpdated() {
    if (!mounted) return;
    showSuccessNotification(context, 'Settings updated');
  }

  Future<void> _loadDeviceSpecs() async {
    final device = ref.read(deviceInfoProvider);
    final results = await Future.wait([
      device.deviceModel,
      device.osVersion,
      device.deviceId,
      device.sdkVersion,
      device.getFreeStorageGb(),
    ]);
    if (mounted) {
      setState(() {
        _deviceModel = results[0] as String;
        _osVersion = results[1] as String;
        _deviceId = results[2] as String;
        _sdkVersion = results[3] as String;
        _freeStorageGb = results[4] as double;
        _specsLoaded = true;
      });
    }
  }

  Future<void> _logout() async {
    await ref
        .read(apiClientProvider)
        .post<Map<String, dynamic>>('/logout', parser: parseApiMap);
    await AppDatabase.clearAllDeliveryData();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('_session_fingerprint');
    await ref.read(authStorageProvider).clearAll();
    await ref.read(authProvider.notifier).initialize();
    if (mounted) context.go('/splash');
  }

  String get _backendLabel {
    final host = Uri.tryParse(apiBaseUrl)?.host ?? apiBaseUrl;
    final env = apiBaseUrl.contains('staging') ? 'Staging' : 'Production';
    return '$env · $host';
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final courier = authState.courier ?? {};
    final isCompact = ref.watch(compactModeProvider);
    final isOnline = ref.watch(isOnlineProvider);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final shouldExit = await ConfirmationDialog.show(
          context,
          title: 'Exit App',
          subtitle: 'Are you sure you want to exit?',
          confirmLabel: 'Exit',
          cancelLabel: 'Stay',
          isDestructive: true,
        );
        if (shouldExit == true && mounted) SystemNavigator.pop();
      },
      child: Scaffold(
        extendBody: true,
        appBar: const AppHeaderBar(title: 'Profile'),
      bottomNavigationBar: const FloatingBottomNavBar(currentPath: '/profile'),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        children: [
          if (!isOnline) const OfflineBanner(),
          if (!isOnline) const SizedBox(height: 16),
          // ── Courier Info ──────────────────────────────────────────────────
          _SectionHeader('Account'),
          _InfoCard(
            children: [
              _InfoTile(
                icon: Icons.person_outline,
                label: 'Name',
                value: '${courier['name'] ?? '-'}',
              ),
              const Divider(height: 1, indent: 56),
              _InfoTile(
                icon: Icons.badge_outlined,
                label: 'Courier Code',
                value: '${courier['courier_code'] ?? '-'}',
              ),
              const Divider(height: 1, indent: 56),
              _InfoTile(
                icon: Icons.phone_outlined,
                label: 'Phone Number',
                value: '${courier['phone_number'] ?? '-'}',
              ),
            ],
          ),
          const SizedBox(height: 16),

          // ── Logout ────────────────────────────────────────────────────────────────
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 52),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            onPressed: () async {
              final confirmed = await ConfirmationDialog.show(
                context,
                title: 'Sign out',
                subtitle:
                    'Are you sure you want to sign out? You will need to log in again to access the app.',
                confirmLabel: 'Sign out',
                cancelLabel: 'Cancel',
                isDestructive: true,
              );
              if (confirmed == true && mounted) await _logout();
            },
            child: const Text(
              'Sign Out',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(height: 24),

          // ── Preferences ──────────────────────────────────────────────────────
          _SectionHeader('Preferences'),
          _InfoCard(
            children: [
              SwitchListTile(
                secondary: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: ColorStyles.grabGreen.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.flash_on_rounded,
                    color: ColorStyles.grabGreen,
                    size: 18,
                  ),
                ),
                title: const Text(
                  'Auto-accept dispatch',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: const Text(
                  'Automatically accept new dispatches after a successful barcode scan. Recommended for high-volume days.',
                  style: TextStyle(fontSize: 12, height: 1.4),
                ),
                value: _autoAccept,
                activeThumbColor: ColorStyles.grabGreen,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),
                onChanged: isOnline
                    ? (v) async {
                        if (v) {
                          final ok = await ConfirmationDialog.show(
                            context,
                            title: 'Enable Auto-Accept?',
                            subtitle:
                                'Dispatches will be automatically accepted after scanning without manual confirmation. Only enable this if you are ready to receive all incoming dispatches.',
                            confirmLabel: 'Enable',
                            cancelLabel: 'Cancel',
                            isDestructive: false,
                          );
                          if (ok != true || !mounted) return;
                        }
                        await ref
                            .read(appSettingsProvider)
                            .setAutoAcceptDispatch(v);
                        setState(() => _autoAccept = v);
                        _showSettingsUpdated();
                      }
                    : null,
              ),
              const Divider(height: 1, indent: 16),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: Colors.teal.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.history_rounded,
                            color: Colors.teal,
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Sync history',
                                style: TextStyle(fontWeight: FontWeight.w600),
                              ),
                              Text(
                                'How long synced updates are kept before auto-removal.',
                                style: TextStyle(
                                  fontSize: 12,
                                  height: 1.4,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: SegmentedButton<int>(
                        showSelectedIcon: false,
                        segments: const [
                          ButtonSegment(value: 1, label: Text('1 day')),
                          ButtonSegment(value: 3, label: Text('3 days')),
                          ButtonSegment(value: 5, label: Text('5 days')),
                        ],
                        selected: {_syncRetentionDays},
                        style: ButtonStyle(
                          textStyle: WidgetStateProperty.all(
                            const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        onSelectionChanged: (val) async {
                          await ref
                              .read(appSettingsProvider)
                              .setSyncRetentionDays(val.first);
                          setState(() => _syncRetentionDays = val.first);
                          _showSettingsUpdated();
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // ── Appearance ───────────────────────────────────────────────────
          _SectionHeader('Appearance'),
          _InfoCard(
            children: [
              // ─ Theme segmented button ──────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: Colors.indigo.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.palette_outlined,
                            color: Colors.indigo,
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Theme',
                                style: TextStyle(fontWeight: FontWeight.w600),
                              ),
                              Text(
                                'Choose light, dark, or system default',
                                style: TextStyle(
                                  fontSize: 12,
                                  height: 1.4,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: SegmentedButton<ThemeMode>(
                        showSelectedIcon: false,
                        segments: const [
                          ButtonSegment(
                            value: ThemeMode.light,
                            label: Text('Light'),
                          ),
                          ButtonSegment(
                            value: ThemeMode.system,
                            label: Text('System'),
                          ),
                          ButtonSegment(
                            value: ThemeMode.dark,
                            label: Text('Dark'),
                          ),
                        ],
                        selected: {authState.themeMode},
                        style: ButtonStyle(
                          textStyle: WidgetStateProperty.all(
                            const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        onSelectionChanged: (val) async {
                          await ref
                              .read(authProvider.notifier)
                              .setThemeMode(val.first);
                          _showSettingsUpdated();
                        },
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, indent: 16),
              // ─ Compact mode ────────────────────────────────────────────
              SwitchListTile(
                secondary: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.purple.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.density_small_rounded,
                    color: Colors.purple,
                    size: 18,
                  ),
                ),
                title: const Text(
                  'Compact mode',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: const Text(
                  'Shrinks delivery cards to show more items on screen at once.',
                  style: TextStyle(fontSize: 12, height: 1.4),
                ),
                value: isCompact,
                activeThumbColor: ColorStyles.grabGreen,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),
                onChanged: (v) async {
                  ref.read(compactModeProvider.notifier).state = v;
                  await ref.read(appSettingsProvider).setCompactMode(v);
                  _showSettingsUpdated();
                },
              ),
            ],
          ),
          const SizedBox(height: 24),

          // ── Device Specifications ────────────────────────────────────────
          _SectionHeader('Device Specifications'),
          if (_specsLoaded && _freeStorageGb >= 0 && _freeStorageGb < 2.0)
            _StorageBanner(freeStorageGb: _freeStorageGb),
          if (_specsLoaded && _freeStorageGb >= 0 && _freeStorageGb < 2.0)
            const SizedBox(height: 8),
          _InfoCard(
            children: [
              _InfoTile(
                icon: Icons.cloud_outlined,
                label: 'Backend',
                value: _backendLabel,
              ),
              const Divider(height: 1, indent: 56),
              _InfoTile(
                icon: Icons.smartphone_outlined,
                label: 'Device Model',
                value: _specsLoaded ? _deviceModel : '…',
              ),
              const Divider(height: 1, indent: 56),
              _InfoTile(
                icon: Platform.isAndroid
                    ? Icons.android_outlined
                    : Icons.phone_iphone_outlined,
                label: 'Operating System',
                value: _specsLoaded ? _osVersion : '…',
              ),
              const Divider(height: 1, indent: 56),
              _InfoTile(
                icon: Icons.fingerprint_outlined,
                label: 'Device ID',
                value: _specsLoaded ? _deviceId : '…',
              ),
              const Divider(height: 1, indent: 56),
              _InfoTile(
                icon: Icons.info_outline_rounded,
                label: 'App Version',
                value: 'v$appVersion',
              ),
              const Divider(height: 1, indent: 56),
              _InfoTile(
                icon: Icons.code_rounded,
                label: 'SDK Version',
                value: _specsLoaded ? _sdkVersion : '…',
              ),
              const Divider(height: 1, indent: 56),
              _InfoTile(
                icon: Icons.sd_storage_outlined,
                label: 'Available Storage',
                value: _specsLoaded
                    ? (_freeStorageGb >= 0
                          ? '${_freeStorageGb.toStringAsFixed(1)} GB free'
                          : 'Unavailable')
                    : '…',
                valueColor: _specsLoaded && _freeStorageGb >= 0
                    ? (_freeStorageGb < 0.5
                          ? Colors.red
                          : _freeStorageGb < 2.0
                          ? Colors.orange
                          : null)
                    : null,
              ),
            ],
          ),
          const SizedBox(height: 32),
        ],
      ),
      ),
      ),
    );
  }
}

// ─── Section Header ───────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 4),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: Colors.grey.shade500,
          letterSpacing: 1.1,
        ),
      ),
    );
  }
}

// ─── Info Card ────────────────────────────────────────────────────────────────

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }
}

// ─── Info Tile ────────────────────────────────────────────────────────────────

class _InfoTile extends StatelessWidget {
  const _InfoTile({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Colors.grey.shade500),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade500,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: valueColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Storage Warning Banner ───────────────────────────────────────────────────

class _StorageBanner extends StatelessWidget {
  const _StorageBanner({required this.freeStorageGb});

  final double freeStorageGb;

  @override
  Widget build(BuildContext context) {
    final isCritical = freeStorageGb < 0.5;
    final color = isCritical ? Colors.red : Colors.orange;
    final freeMb = (freeStorageGb * 1024).round();
    final valueLabel = isCritical
        ? '$freeMb MB'
        : '${freeStorageGb.toStringAsFixed(1)} GB';
    final message = isCritical
        ? 'Critical storage: $valueLabel remaining. Free up space to avoid sync failures.'
        : 'Low storage: $valueLabel remaining. Consider freeing up space.';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.warning_amber_rounded, color: color, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: 12,
                color: color,
                fontWeight: FontWeight.w500,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
