// DOCS: docs/features/profile.md — update that file when you edit this one.

// =============================================================================
// profile_screen.dart
// =============================================================================
//
// Purpose:
//   Displays the authenticated courier's profile information and provides
//   access to account settings, preferences, and administrative tools.
//
// Contents:
//   • Courier details — name, code, profile picture, email, phone.
//   • Available storage tile — shows free device storage (via platform channel)
//     and displays a warning banner when storage is critically low (< 2 GB).
//   • Settings — compact mode toggle, app version info.
//   • Account actions — Change Password, Edit Profile, Logout.
//   • Debug / admin tools (kDebugMode only) — error log viewer, config info.
//
// Storage monitoring:
//   Uses a custom MethodChannel ('fsi_courier/storage') to read free disk
//   space natively (StatFs on Android, FileManager on iOS). A red banner is
//   shown at the top of the screen when free space drops below 2 GB.
//
// Navigation:
//   Route: /profile
//   Accessed via: FloatingBottomNavBar (Profile tab)
//   Pushes to: ResetPasswordScreen, ProfileEditScreen
// =============================================================================

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:fsi_courier_app/core/api/api_client.dart';
import 'package:fsi_courier_app/core/database/error_log_dao.dart';
import 'package:fsi_courier_app/core/auth/auth_provider.dart';
import 'package:fsi_courier_app/core/auth/auth_storage.dart';
import 'package:fsi_courier_app/core/config.dart';
import 'package:fsi_courier_app/core/services/app_version_service.dart';
import 'package:fsi_courier_app/core/database/app_database.dart';
import 'package:fsi_courier_app/core/database/sync_operations_dao.dart';
import 'package:fsi_courier_app/core/device/device_info.dart';
import 'package:fsi_courier_app/core/providers/connectivity_provider.dart';
import 'package:fsi_courier_app/core/constants.dart';
import 'package:fsi_courier_app/core/settings/app_settings.dart';
import 'package:fsi_courier_app/core/settings/compact_mode_provider.dart';
import 'package:fsi_courier_app/core/services/push_notification_service.dart';
import 'package:fsi_courier_app/shared/helpers/api_payload_helper.dart';
import 'package:fsi_courier_app/shared/helpers/snackbar_helper.dart';
import 'package:fsi_courier_app/shared/widgets/app_header_bar.dart';
import 'package:fsi_courier_app/shared/widgets/confirmation_dialog.dart';
import 'package:fsi_courier_app/shared/widgets/offline_banner.dart';
import 'package:fsi_courier_app/design_system/design_system.dart';

// ── Design tokens ─────────────────────────────────────────────────────────────

class _Tokens {
  static const radius = 20.0;
  static const radiusSm = 14.0;
  static const radiusXs = 10.0;

  static const tileIconSize = 38.0;
  static const tileIconInner = 18.0;

  static Color cardLight = const Color(0xFFFFFFFF);
  static Color cardDark = const Color(0xFF1C1C28);
  static Color surfaceDark = const Color(0xFF13131F);
  static Color borderLight = const Color(0xFFF0F0F5);
  static Color borderDark = const Color(0xFF2A2A3A);

  static Color accentGreen = DSColors.primary;
  static Color accentBlue = const Color(0xFF3B7FE8);
  static Color accentPurple = const Color(0xFF7C5CFC);
  static Color accentTeal = const Color(0xFF00BFA6);
  static Color accentAmber = const Color(0xFFFFA726);
}

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool _autoAccept = false;
  int _syncRetentionDays = kDefaultSyncRetentionDays;

  String _deviceModel = '…';
  String _osVersion = '…';
  String _deviceId = '…';
  String _sdkVersion = '…';
  bool _specsLoaded = false;
  double _freeStorageGb = -1.0;

  int _errorLogCount = 0;
  double _horizontalDrag = 0.0;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _loadDeviceSpecs();
    _loadErrorLogCount();
    _loadProfile();
  }

  Future<void> _refresh() async {
    await Future.wait([
      _loadSettings(),
      _loadDeviceSpecs(),
      _loadErrorLogCount(),
      _loadProfile(),
    ]);
  }

  Future<void> _loadProfile() async {
    if (!mounted) return;
    final isOnline = ref.read(isOnlineProvider);
    if (!isOnline) return;

    final result = await ref
        .read(apiClientProvider)
        .get<Map<String, dynamic>>('/me', parser: parseApiMap);

    if (!mounted) return;

    if (result is ApiSuccess<Map<String, dynamic>>) {
      final data = result.data['data'];
      if (data is Map<String, dynamic>) {
        await ref.read(authProvider.notifier).setAuthenticated(courier: data);
        if (mounted && data['is_active'] == false) {
          showErrorNotification(
            context,
            'Your account is currently inactive. Please contact support.',
          );
        }
      }
    }
  }

  Future<void> _loadErrorLogCount() async {
    final count = await ErrorLogDao.instance.getCount();
    if (mounted) setState(() => _errorLogCount = count);
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
    final authStorage = ref.read(authStorageProvider);
    final results = await Future.wait([
      device.deviceModel,
      device.osVersion,
      authStorage.getDeviceId(),
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
    final courierId =
        await ref.read(authStorageProvider).getLastCourierId() ?? '';
    final pendingCount = await SyncOperationsDao.instance.getPendingCount(
      courierId,
    );
    if (!mounted) return;
    if (pendingCount > 0) {
      final forceLogout = await ConfirmationDialog.show(
        context,
        title: 'Pending Sync Operations',
        subtitle:
            'You have $pendingCount pending offline updates. If you sign out now, they may be lost. Are you sure you want to force sign out?',
        confirmLabel: 'Force Sign Out',
        cancelLabel: 'Wait',
        isDestructive: true,
      );
      if (forceLogout != true) return;
    }

    await PushNotificationService.instance.clearToken();
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

  // Sign out all devices — currently not used in UI but kept for reference.
  // To avoid an unused_element analyzer warning, the action is left commented
  // out in the UI where it was previously referenced. Re-enable if needed.

  String get _backendLabel {
    final host = Uri.tryParse(apiBaseUrl)?.host ?? apiBaseUrl;
    final env = apiBaseUrl.contains('staging') ? 'Staging' : 'Production';
    return '$env · $host';
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final courier = authState.courier ?? {};
    final branchName =
        (courier['branch'] is Map && courier['branch']['branch_name'] != null)
        ? courier['branch']['branch_name'].toString()
        : '-';
    final isActive = courier['is_active'] != false;
    final isCompact = ref.watch(compactModeProvider);
    final isOnline = ref.watch(isOnlineProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        // When on Profile, navigate back to Dashboard instead of exiting.
        context.go('/dashboard');
      },
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onHorizontalDragUpdate: (details) =>
            _horizontalDrag += details.delta.dx,
        onHorizontalDragEnd: (details) {
          final dx = _horizontalDrag;
          _horizontalDrag = 0.0;
          final velocity = details.primaryVelocity ?? 0.0;
          if (dx.abs() > 60 || velocity.abs() > 300) {
            if (dx < 0 || velocity < 0) {
              // swipe left → Dashboard (wrap-around)
              context.go('/dashboard', extra: {'_swipe': 'left'});
            } else {
              // swipe right → Wallet
              context.go('/wallet', extra: {'_swipe': 'right'});
            }
          }
        },
        child: Scaffold(
          extendBody: true,
          backgroundColor: isDark
              ? _Tokens.surfaceDark
              : const Color(0xFFF5F6FA),
          appBar: AppHeaderBar(
            title: 'Profile',
            pageIcon: Icons.person_rounded,
          ),
          // bottomNavigationBar: const FloatingBottomNavBar(
          //   currentPath: '/profile',
          // ),
          body: RefreshIndicator(
            onRefresh: _refresh,
            color: _Tokens.accentGreen,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
              children: [
                // ── Status banners ─────────────────────────────────────────
                if (!isOnline) const OfflineBanner(),
                if (!isOnline) const SizedBox(height: 12),
                if (!isActive) _AccountInactiveBanner(),
                if (!isActive) const SizedBox(height: 12),

                // ── Hero profile card ──────────────────────────────────────
                _ProfileHeroCard(
                  courier: courier,
                  branchName: branchName,
                  isDark: isDark,
                  isOnline: isOnline,
                ).animate().fadeIn(duration: 500.ms).slideY(begin: 0.2, end: 0),
                const SizedBox(height: 24),

                // ── Account actions ────────────────────────────────────────
                _SectionLabel('Account').animate().fadeIn(delay: 200.ms),
                _ModernCard(
                  isDark: isDark,
                  children: [
                    _ActionTile(
                      icon: Icons.lock_reset_rounded,
                      iconColor: _Tokens.accentBlue,
                      label: 'Change Password',
                      subtitle: 'Update your login credentials',
                      isDark: isDark,
                      onTap: () => context.push('/change-password'),
                    ),
                    _CardDivider(isDark: isDark),
                    _ActionTile(
                      icon: Icons.logout_rounded,
                      iconColor: Colors.red.shade400,
                      label: 'Sign Out',
                      subtitle: 'End your current session',
                      isDark: isDark,
                      isDestructive: true,
                      onTap: () async {
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
                    ),
                    // this is not needed
                    // _CardDivider(isDark: isDark),
                    // _ActionTile(
                    //   icon: Icons.devices_rounded,
                    //   iconColor: Colors.red.shade700,
                    //   label: 'Sign Out All Devices',
                    //   subtitle: 'Revoke all active sessions on every device',
                    //   isDark: isDark,
                    //   isDestructive: true,
                    //   onTap: () async {
                    //     final confirmed = await ConfirmationDialog.show(
                    //       context,
                    //       title: 'Sign out all devices',
                    //       subtitle:
                    //           'This will end all active sessions on every device, including this one. You will need to log in again.',
                    //       confirmLabel: 'Sign out all',
                    //       cancelLabel: 'Cancel',
                    //       isDestructive: true,
                    //     );
                    //     if (confirmed == true && mounted) await _logoutAll();
                    //   },
                    // ),
                  ],
                ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.1, end: 0),
                const SizedBox(height: 24),

                // ── Preferences ────────────────────────────────────────────
                _SectionLabel('Preferences').animate().fadeIn(delay: 400.ms),
                _ModernCard(
                  isDark: isDark,
                  children: [
                    _ModernSwitchTile(
                      icon: Icons.flash_on_rounded,
                      iconColor: _Tokens.accentAmber,
                      label: 'Auto-accept Dispatch',
                      subtitle:
                          'Automatically accept new dispatches after a successful barcode scan. Recommended for high-volume days.',
                      value: _autoAccept,
                      isDark: isDark,
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

                    // Debug-only: Sync Retention
                    if (kDebugMode) ...[
                      _CardDivider(isDark: isDark),
                      _SyncRetentionTile(
                        syncRetentionDays: _syncRetentionDays,
                        isDark: isDark,
                        onChanged: (val) async {
                          final confirmed = await ConfirmationDialog.show(
                            context,
                            title: 'Update Retention Period?',
                            subtitle:
                                'This changes how long offline sync history is kept on this device. Are you sure you want to change it?',
                            confirmLabel: 'Update',
                            cancelLabel: 'Cancel',
                          );
                          if (confirmed != true || !mounted) return;
                          await ref
                              .read(appSettingsProvider)
                              .setSyncRetentionDays(val.first);
                          setState(() => _syncRetentionDays = val.first);
                          _showSettingsUpdated();
                        },
                      ),
                    ],
                  ],
                ).animate().fadeIn(delay: 500.ms).slideY(begin: 0.1, end: 0),
                const SizedBox(height: 24),

                // ── Appearance ─────────────────────────────────────────────
                _SectionLabel('Appearance').animate().fadeIn(delay: 600.ms),
                _ModernCard(
                  isDark: isDark,
                  children: [
                    _ThemeSegmentedTile(
                      isDark: isDark,
                      themeMode: authState.themeMode,
                      onChanged: (val) async {
                        await ref
                            .read(authProvider.notifier)
                            .setThemeMode(val.first);
                        _showSettingsUpdated();
                      },
                    ),
                    _CardDivider(isDark: isDark),
                    _ModernSwitchTile(
                      icon: Icons.density_small_rounded,
                      iconColor: _Tokens.accentPurple,
                      label: 'Compact Mode',
                      subtitle:
                          'Shrinks delivery cards to show more items on screen at once.',
                      value: isCompact,
                      isDark: isDark,
                      onChanged: (v) async {
                        ref.read(compactModeProvider.notifier).setValue(v);
                        await ref.read(appSettingsProvider).setCompactMode(v);
                        _showSettingsUpdated();
                      },
                    ),
                  ],
                ).animate().fadeIn(delay: 700.ms).slideY(begin: 0.1, end: 0),
                const SizedBox(height: 24),

                // ── Device Specifications ──────────────────────────────────
                _SectionLabel('Device').animate().fadeIn(delay: 800.ms),
                if (_specsLoaded &&
                    _freeStorageGb >= 0 &&
                    _freeStorageGb < 2.0) ...[
                  _StorageBanner(freeStorageGb: _freeStorageGb),
                  const SizedBox(height: 10),
                ],
                _ModernCard(
                  isDark: isDark,
                  children: [
                    if (kAppDebugMode) ...[
                      _DetailTile(
                        icon: Icons.cloud_outlined,
                        iconColor: _Tokens.accentTeal,
                        label: 'Backend',
                        value: _backendLabel,
                        isDark: isDark,
                      ),
                      _CardDivider(isDark: isDark),
                      _DetailTile(
                        icon: Icons.smartphone_outlined,
                        iconColor: _Tokens.accentBlue,
                        label: 'Device Model',
                        value: _specsLoaded ? _deviceModel : '…',
                        isDark: isDark,
                      ),
                      _CardDivider(isDark: isDark),
                      _DetailTile(
                        icon: Platform.isAndroid
                            ? Icons.android_outlined
                            : Icons.phone_iphone_outlined,
                        iconColor: _Tokens.accentGreen,
                        label: 'Operating System',
                        value: _specsLoaded ? _osVersion : '…',
                        isDark: isDark,
                      ),
                      _CardDivider(isDark: isDark),
                      _DetailTile(
                        icon: Icons.fingerprint_outlined,
                        iconColor: _Tokens.accentPurple,
                        label: 'Device ID',
                        value: _specsLoaded ? _deviceId : '…',
                        isDark: isDark,
                      ),
                      _CardDivider(isDark: isDark),
                    ],
                    _DetailTile(
                      icon: Icons.info_outline_rounded,
                      iconColor: _Tokens.accentBlue,
                      label: 'App Version',
                      value: AppVersionService.displayVersion,
                      isDark: isDark,
                    ),
                    if (kAppDebugMode) ...[
                      _CardDivider(isDark: isDark),
                      _DetailTile(
                        icon: Icons.code_rounded,
                        iconColor: _Tokens.accentAmber,
                        label: 'SDK Version',
                        value: _specsLoaded ? _sdkVersion : '…',
                        isDark: isDark,
                      ),
                    ],
                    _CardDivider(isDark: isDark),
                    _DetailTile(
                      icon: Icons.sd_storage_outlined,
                      iconColor: _storageIconColor,
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
                      isDark: isDark,
                    ),
                  ],
                ).animate().fadeIn(delay: 900.ms).slideY(begin: 0.1, end: 0),
                const SizedBox(height: 24),

                // ── Legal ──────────────────────────────────────────────────
                _SectionLabel('Legal').animate().fadeIn(delay: 1000.ms),
                _ModernCard(
                  isDark: isDark,
                  children: [
                    _ActionTile(
                      icon: Icons.description_outlined,
                      iconColor: _Tokens.accentBlue,
                      label: 'Terms & Conditions',
                      subtitle: 'Read the app terms of service',
                      isDark: isDark,
                      onTap: () => context.push('/terms?mode=view'),
                    ),
                    _CardDivider(isDark: isDark),
                    _ActionTile(
                      icon: Icons.shield_outlined,
                      iconColor: _Tokens.accentTeal,
                      label: 'Privacy Policy',
                      subtitle: 'How we collect and use your data',
                      isDark: isDark,
                      onTap: () => context.push('/privacy'),
                    ),
                  ],
                ).animate().fadeIn(delay: 1100.ms).slideY(begin: 0.1, end: 0),
                const SizedBox(height: 24),

                // ── Diagnostics ────────────────────────────────────────────
                _SectionLabel('Diagnostics').animate().fadeIn(delay: 1200.ms),
                _ModernCard(
                  isDark: isDark,
                  children: [
                    _ActionTile(
                      icon: Icons.bug_report_outlined,
                      iconColor: _Tokens.accentAmber,
                      label: 'Report an Issue',
                      subtitle: isOnline
                          ? 'Send a bug report or feedback to the admin'
                          : 'Requires internet connection',
                      isDark: isDark,
                      onTap: isOnline ? () => context.push('/report') : null,
                    ),
                    _CardDivider(isDark: isDark),
                    _ErrorLogsTile(
                      isDark: isDark,
                      errorLogCount: _errorLogCount,
                      onTap: () async {
                        await context.push('/error-logs');
                        _loadErrorLogCount();
                      },
                    ),
                  ],
                ).animate().fadeIn(delay: 1300.ms).slideY(begin: 0.1, end: 0),
                const SizedBox(height: 36),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color get _storageIconColor {
    if (!_specsLoaded || _freeStorageGb < 0) return _Tokens.accentTeal;
    if (_freeStorageGb < 0.5) return Colors.red;
    if (_freeStorageGb < 2.0) return Colors.orange;
    return _Tokens.accentTeal;
  }
}

// ─── Profile Hero Card ────────────────────────────────────────────────────────

class _ProfileHeroCard extends StatelessWidget {
  const _ProfileHeroCard({
    required this.courier,
    required this.branchName,
    required this.isDark,
    required this.isOnline,
  });

  final Map<String, dynamic> courier;
  final String branchName;
  final bool isDark;
  final bool isOnline;

  @override
  Widget build(BuildContext context) {
    final name = '${courier['first_name'] ?? '-'} ${courier['last_name'] ?? ''}'
        .trim();
    final email = courier['email']?.toString() ?? 'No email';
    final courierCode = courier['courier_code']?.toString() ?? '-';

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF1E2D40), const Color(0xFF1C2535)]
              : [const Color(0xFF0D6EFD), const Color(0xFF00A86B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(_Tokens.radius),
        boxShadow: [
          BoxShadow(
            color: (isDark ? Colors.black : DSColors.primary).withValues(
              alpha: isDark ? 0.3 : 0.25,
            ),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Row(
            children: [
              // Avatar
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: DSStyles.alphaBorder),
                    width: 2,
                  ),
                  color: Colors.white.withValues(
                    alpha: DSStyles.alphaActiveAccent,
                  ),
                ),
                child: Hero(
                  tag: 'profile_avatar',
                  child: ClipOval(
                    child: courier['profile_picture_url'] != null
                        ? Image.network(
                            courier['profile_picture_url'].toString(),
                            width: 64,
                            height: 64,
                            fit: BoxFit.cover,
                            errorBuilder: (_, e, s) => const Center(
                              child: Icon(
                                Icons.person_rounded,
                                size: 32,
                                color: Colors.white,
                              ),
                            ),
                          )
                        : const Center(
                            child: Icon(
                              Icons.person_rounded,
                              size: 32,
                              color: Colors.white,
                            ),
                          ),
                  ),
                ),
              ),
              const SizedBox(width: 16),

              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name.isEmpty ? '-' : name,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        letterSpacing: -0.3,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      email,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withValues(
                          alpha: DSStyles.alphaGlass,
                        ),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    if (kDebugMode)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(
                            alpha: DSStyles.alphaActiveAccent,
                          ),
                          borderRadius: DSStyles.pillRadius,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.badge_outlined,
                              size: 10,
                              color: Colors.white70,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '$courierCode (Debug)',
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),

              // Edit Button — ONLY visible when ONLINE
              if (isOnline)
                IconButton(
                  onPressed: () => context.push('/profile/edit'),
                  icon: const Icon(
                    Icons.edit_note_rounded,
                    color: Colors.white,
                    size: 24,
                  ),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.white.withValues(
                      alpha: DSStyles.alphaActiveAccent,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: DSStyles.cardRadius,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Divider(
            color: Colors.white.withValues(alpha: DSStyles.alphaActiveAccent),
            height: 1,
          ),
          const SizedBox(height: 16),
          // Compact Info Row
          Row(
            children: [
              _CompactInfoItem(
                icon: Icons.phone_android_rounded,
                label: 'Phone',
                value: courier['phone_number']?.toString() ?? '-',
              ),
              const SizedBox(width: 20),
              _CompactInfoItem(
                icon: Icons.store_rounded,
                label: 'Branch',
                value: branchName,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CompactInfoItem extends StatelessWidget {
  const _CompactInfoItem({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 12, color: Colors.white.withValues(alpha: 0.6)),
              const SizedBox(width: 4),
              Text(
                label.toUpperCase(),
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  color: Colors.white.withValues(alpha: 0.6),
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

// ─── Account Inactive Banner ──────────────────────────────────────────────────

class _AccountInactiveBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: DSStyles.alphaSoft),
        border: Border.all(
          color: Colors.red.withValues(alpha: DSStyles.alphaDarkShadow),
        ),
        borderRadius: BorderRadius.circular(_Tokens.radiusSm),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: Colors.red.withValues(alpha: DSStyles.alphaActiveAccent),
              borderRadius: BorderRadius.circular(_Tokens.radiusXs),
            ),
            child: const Icon(
              Icons.warning_amber_rounded,
              color: Colors.red,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Your account is currently inactive. Please contact support.',
              style: TextStyle(
                color: Colors.red,
                fontSize: 13,
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

// ─── Section Label ────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, left: 4),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: Colors.grey.shade500,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

class _ModernCard extends StatelessWidget {
  const _ModernCard({required this.children, required this.isDark});

  final List<Widget> children;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? _Tokens.cardDark : _Tokens.cardLight,
        borderRadius: BorderRadius.circular(_Tokens.radius),
        border: Border.all(
          color: isDark ? _Tokens.borderDark : _Tokens.borderLight,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.22 : 0.05),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(_Tokens.radius),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: children,
        ),
      ),
    );
  }
}

// ─── Card Divider ─────────────────────────────────────────────────────────────

class _CardDivider extends StatelessWidget {
  const _CardDivider({required this.isDark});

  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      thickness: 1,
      indent: 58,
      color: isDark ? _Tokens.borderDark : _Tokens.borderLight,
    );
  }
}

// ─── Action Tile ──────────────────────────────────────────────────────────────

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.subtitle,
    required this.isDark,
    required this.onTap,
    this.isDestructive = false,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final String subtitle;
  final bool isDark;
  final VoidCallback? onTap;
  final bool isDestructive;

  @override
  Widget build(BuildContext context) {
    final textColor = isDestructive
        ? Colors.red.shade400
        : (isDark ? Colors.white : const Color(0xFF1A1A2E));

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: _Tokens.tileIconSize,
              height: _Tokens.tileIconSize,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: DSStyles.alphaActiveAccent),
                borderRadius: BorderRadius.circular(_Tokens.radiusXs),
              ),
              child: Icon(icon, size: _Tokens.tileIconInner, color: iconColor),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade500,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: Colors.grey.shade400,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Modern Switch Tile ───────────────────────────────────────────────────────

class _ModernSwitchTile extends StatelessWidget {
  const _ModernSwitchTile({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.subtitle,
    required this.value,
    required this.isDark,
    required this.onChanged,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final String subtitle;
  final bool value;
  final bool isDark;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: _Tokens.tileIconSize,
            height: _Tokens.tileIconSize,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: DSStyles.alphaActiveAccent),
              borderRadius: BorderRadius.circular(_Tokens.radiusXs),
            ),
            child: Icon(icon, size: _Tokens.tileIconInner, color: iconColor),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : const Color(0xFF1A1A2E),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade500,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: DSColors.primary,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ],
      ),
    );
  }
}

// ─── Sync Retention Tile (Debug only) ────────────────────────────────────────

class _SyncRetentionTile extends StatelessWidget {
  const _SyncRetentionTile({
    required this.syncRetentionDays,
    required this.isDark,
    required this.onChanged,
  });

  final int syncRetentionDays;
  final bool isDark;
  final ValueChanged<Set<int>> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: _Tokens.tileIconSize,
                height: _Tokens.tileIconSize,
                decoration: BoxDecoration(
                  color: _Tokens.accentTeal.withValues(
                    alpha: DSStyles.alphaActiveAccent,
                  ),
                  borderRadius: BorderRadius.circular(_Tokens.radiusXs),
                ),
                child: Icon(
                  Icons.history_rounded,
                  color: _Tokens.accentTeal,
                  size: _Tokens.tileIconInner,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Sync History',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : const Color(0xFF1A1A2E),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'How long synced updates are kept before auto-removal.',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade500,
                        height: 1.35,
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
                ButtonSegment(value: 0, label: Text('1 min')),
                ButtonSegment(value: 1, label: Text('1 day')),
                ButtonSegment(value: 3, label: Text('3 days')),
                ButtonSegment(value: 5, label: Text('5 days')),
              ],
              selected: {syncRetentionDays},
              style: ButtonStyle(
                textStyle: WidgetStateProperty.all(
                  const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
              ),
              onSelectionChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Theme Segmented Tile ─────────────────────────────────────────────────────

class _ThemeSegmentedTile extends StatelessWidget {
  const _ThemeSegmentedTile({
    required this.isDark,
    required this.themeMode,
    required this.onChanged,
  });

  final bool isDark;
  final ThemeMode themeMode;
  final ValueChanged<Set<ThemeMode>> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: _Tokens.tileIconSize,
                height: _Tokens.tileIconSize,
                decoration: BoxDecoration(
                  color: _Tokens.accentPurple.withValues(
                    alpha: DSStyles.alphaActiveAccent,
                  ),
                  borderRadius: BorderRadius.circular(_Tokens.radiusXs),
                ),
                child: Icon(
                  Icons.palette_outlined,
                  color: _Tokens.accentPurple,
                  size: _Tokens.tileIconInner,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Theme',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : const Color(0xFF1A1A2E),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Choose light, dark, or system default.',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade500,
                        height: 1.35,
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
                ButtonSegment(value: ThemeMode.light, label: Text('Light')),
                ButtonSegment(value: ThemeMode.system, label: Text('System')),
                ButtonSegment(value: ThemeMode.dark, label: Text('Dark')),
              ],
              selected: {themeMode},
              style: ButtonStyle(
                textStyle: WidgetStateProperty.all(
                  const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
              ),
              onSelectionChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Detail Tile ──────────────────────────────────────────────────────────────

class _DetailTile extends StatelessWidget {
  const _DetailTile({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    required this.isDark,
    this.valueColor,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
  final bool isDark;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      child: Row(
        children: [
          Container(
            width: _Tokens.tileIconSize,
            height: _Tokens.tileIconSize,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: DSStyles.alphaActiveAccent),
              borderRadius: BorderRadius.circular(_Tokens.radiusXs),
            ),
            child: Icon(icon, size: _Tokens.tileIconInner, color: iconColor),
          ),
          const SizedBox(width: 14),
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
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color:
                        valueColor ??
                        (isDark ? Colors.white : const Color(0xFF1A1A2E)),
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

// ─── Error Logs Tile ──────────────────────────────────────────────────────────

class _ErrorLogsTile extends StatelessWidget {
  const _ErrorLogsTile({
    required this.isDark,
    required this.errorLogCount,
    required this.onTap,
  });

  final bool isDark;
  final int errorLogCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: _Tokens.tileIconSize,
              height: _Tokens.tileIconSize,
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: DSStyles.alphaSoft),
                borderRadius: BorderRadius.circular(_Tokens.radiusXs),
              ),
              child: const Icon(
                Icons.bug_report_outlined,
                color: Colors.red,
                size: _Tokens.tileIconInner,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Error Logs',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : const Color(0xFF1A1A2E),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'View errors and warnings recorded on this device.',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade500,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
            if (errorLogCount > 0) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.red.shade600,
                  borderRadius: DSStyles.cardRadius,
                ),
                child: Text(
                  '$errorLogCount',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 6),
            ],
            Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: Colors.grey.shade400,
            ),
          ],
        ),
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      decoration: BoxDecoration(
        color: color.withValues(alpha: DSStyles.alphaSoft),
        borderRadius: BorderRadius.circular(_Tokens.radiusSm),
        border: Border.all(
          color: color.withValues(alpha: DSStyles.alphaDarkShadow),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: color.withValues(alpha: DSStyles.alphaActiveAccent),
              borderRadius: BorderRadius.circular(_Tokens.radiusXs),
            ),
            child: Icon(Icons.warning_amber_rounded, color: color, size: 16),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: 12,
                color: color,
                fontWeight: FontWeight.w500,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
