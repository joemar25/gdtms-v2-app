// DOCS: docs/development-standards.md
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
import 'package:easy_localization/easy_localization.dart';
import 'package:fsi_courier_app/shared/widgets/confirmation_dialog.dart';
import 'package:fsi_courier_app/shared/widgets/offline_banner.dart';
import 'package:fsi_courier_app/design_system/design_system.dart';

// Design tokens managed via DesignSystem
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
            'profile.account.inactive_account'.tr(),
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
    showSuccessNotification(
      context,
      'profile.preferences.settings_updated'.tr(),
    );
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
        title: 'profile.account.pending_sync_title'.tr(),
        subtitle: 'profile.account.pending_sync_message'.tr(
          args: [pendingCount.toString()],
        ),
        confirmLabel: 'profile.account.force_sign_out'.tr(),
        cancelLabel: 'profile.account.wait'.tr(),
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
              ? DSColors.scaffoldDark
              : DSColors.scaffoldLight,
          appBar: AppHeaderBar(
            title: 'profile.title'.tr(),
            pageIcon: Icons.person_rounded,
          ),
          // bottomNavigationBar: const FloatingBottomNavBar(
          //   currentPath: '/profile',
          // ),
          body: RefreshIndicator(
            onRefresh: _refresh,
            color: DSColors.primary,
            child: ListView(
              padding: EdgeInsets.fromLTRB(
                DSSpacing.md,
                DSSpacing.md,
                DSSpacing.md,
                120, // Extra bottom padding for floating nav
              ),
              children: [
                // ── Status banners ─────────────────────────────────────────
                if (!isOnline) const OfflineBanner(),
                if (!isOnline) DSSpacing.hMd,
                if (!isActive) _AccountInactiveBanner(),
                if (!isActive) DSSpacing.hMd,

                // ── Hero profile card ──────────────────────────────────────
                _ProfileHeroCard(
                  courier: courier,
                  branchName: branchName,
                  isDark: isDark,
                  isOnline: isOnline,
                ).dsCardEntry(duration: DSAnimations.dNormal),
                DSSpacing.hSm,

                // ── Account Section ────────────────────────────────────────
                const DSSectionHeader(
                  title: 'profile.sections.account',
                  useLocalization: true,
                ),
                _ModernCard(
                  isDark: isDark,
                  children: [
                    _ActionTile(
                      icon: Icons.lock_reset_rounded,
                      iconColor: DSColors.primary,
                      label: 'profile.account.change_password'.tr(),
                      subtitle: 'profile.account.change_password_sub'.tr(),
                      isDark: isDark,
                      onTap: () => context.push('/change-password'),
                    ),
                    _CardDivider(isDark: isDark),
                    _ActionTile(
                      icon: Icons.logout_rounded,
                      iconColor: DSColors.error,
                      label: 'profile.account.sign_out'.tr(),
                      subtitle: 'profile.account.sign_out_sub'.tr(),
                      isDark: isDark,
                      isDestructive: true,
                      onTap: () async {
                        final confirmed = await ConfirmationDialog.show(
                          context,
                          title: 'profile.account.logout_confirm_title'.tr(),
                          subtitle: 'profile.account.logout_confirm_message'
                              .tr(),
                          confirmLabel: 'profile.account.logout_confirm_confirm'
                              .tr(),
                          cancelLabel: 'profile.account.logout_confirm_cancel'
                              .tr(),
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
                ).dsCardEntry(delay: DSAnimations.stagger(1)),
                DSSpacing.hSm,

                // ── Preferences Section ────────────────────────────────────
                const DSSectionHeader(
                  title: 'profile.sections.preferences',
                  useLocalization: true,
                ),
                _ModernCard(
                  isDark: isDark,
                  children: [
                    _LanguageSegmentedTile(
                      isDark: isDark,
                      onChanged: _showSettingsUpdated,
                    ),
                    _CardDivider(isDark: isDark),
                    _ModernSwitchTile(
                      icon: Icons.flash_on_rounded,
                      iconColor: DSColors.warning,
                      label: 'profile.preferences.auto_accept'.tr(),
                      subtitle: 'profile.preferences.auto_accept_sub'.tr(),
                      value: _autoAccept,
                      isDark: isDark,
                      onChanged: isOnline
                          ? (v) async {
                              if (v) {
                                final ok = await ConfirmationDialog.show(
                                  context,
                                  title:
                                      'profile.preferences.auto_accept_confirm_title'
                                          .tr(),
                                  subtitle:
                                      'profile.preferences.auto_accept_confirm_message'
                                          .tr(),
                                  confirmLabel: 'dashboard.exit_confirm_confirm'
                                      .tr(), // reuse generic Enable/Confirm
                                  cancelLabel: 'dashboard.exit_confirm_cancel'
                                      .tr(),
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

                    _CardDivider(isDark: isDark),
                    _ModernSwitchTile(
                      icon: Icons.density_small_rounded,
                      iconColor: DSColors.primary,
                      label: 'profile.preferences.compact_mode'.tr(),
                      subtitle: 'profile.preferences.compact_mode_sub'.tr(),
                      value: isCompact,
                      isDark: isDark,
                      onChanged: (v) async {
                        ref.read(compactModeProvider.notifier).setValue(v);
                        await ref.read(appSettingsProvider).setCompactMode(v);
                        _showSettingsUpdated();
                      },
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
                            title: 'profile.preferences.retention_update_title'
                                .tr(),
                            subtitle:
                                'profile.preferences.retention_update_message'
                                    .tr(),
                            confirmLabel: 'dashboard.exit_confirm_confirm'.tr(),
                            cancelLabel: 'dashboard.exit_confirm_cancel'.tr(),
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
                ).dsCardEntry(delay: DSAnimations.stagger(2)),
                DSSpacing.hSm,

                // ── Appearance Section ─────────────────────────────────────
                const DSSectionHeader(
                  title: 'profile.sections.appearance',
                  useLocalization: true,
                ),
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
                  ],
                ).dsCardEntry(delay: DSAnimations.stagger(3)),
                DSSpacing.hSm,

                // ── Device Section ─────────────────────────────────────────
                const DSSectionHeader(
                  title: 'profile.sections.device',
                  useLocalization: true,
                ),
                if (_specsLoaded &&
                    _freeStorageGb >= 0 &&
                    _freeStorageGb < 2.0) ...[
                  _StorageBanner(freeStorageGb: _freeStorageGb),
                  DSSpacing.hMd,
                ],
                _ModernCard(
                  isDark: isDark,
                  children: [
                    if (kAppDebugMode) ...[
                      _DetailTile(
                        icon: Icons.cloud_outlined,
                        iconColor: DSColors.success,
                        label: 'profile.device.backend'.tr(),
                        value: _backendLabel,
                        isDark: isDark,
                      ),
                      _CardDivider(isDark: isDark),
                      _DetailTile(
                        icon: Icons.smartphone_outlined,
                        iconColor: DSColors.primary,
                        label: 'profile.device.model'.tr(),
                        value: _specsLoaded ? _deviceModel : '…',
                        isDark: isDark,
                      ),
                      _CardDivider(isDark: isDark),
                      _DetailTile(
                        icon: Platform.isAndroid
                            ? Icons.android_outlined
                            : Icons.phone_iphone_outlined,
                        iconColor: DSColors.success,
                        label: 'profile.device.os'.tr(),
                        value: _specsLoaded ? _osVersion : '…',
                        isDark: isDark,
                      ),
                      _CardDivider(isDark: isDark),
                      _DetailTile(
                        icon: Icons.fingerprint_outlined,
                        iconColor: DSColors.pending,
                        label: 'profile.device.id'.tr(),
                        value: _specsLoaded ? _deviceId : '…',
                        isDark: isDark,
                      ),
                      _CardDivider(isDark: isDark),
                    ],
                    _DetailTile(
                      icon: Icons.info_outline_rounded,
                      iconColor: DSColors.primary,
                      label: 'profile.device.app_version'.tr(),
                      value: AppVersionService.displayVersion,
                      isDark: isDark,
                    ),
                    if (kAppDebugMode) ...[
                      _CardDivider(isDark: isDark),
                      _DetailTile(
                        icon: Icons.code_rounded,
                        iconColor: DSColors.warning,
                        label: 'profile.device.sdk_version'.tr(),
                        value: _specsLoaded ? _sdkVersion : '…',
                        isDark: isDark,
                      ),
                    ],
                    _CardDivider(isDark: isDark),
                    _DetailTile(
                      icon: Icons.sd_storage_outlined,
                      iconColor: _storageIconColor,
                      label: 'profile.device.storage'.tr(),
                      value: _specsLoaded
                          ? (_freeStorageGb >= 0
                                ? 'profile.device.storage_free'.tr(
                                    args: [_freeStorageGb.toStringAsFixed(1)],
                                  )
                                : 'profile.device.storage_unavailable'.tr())
                          : '…',
                      valueColor: _specsLoaded && _freeStorageGb >= 0
                          ? (_freeStorageGb < 0.5
                                ? DSColors.error
                                : _freeStorageGb < 2.0
                                ? DSColors.warning
                                : null)
                          : null,
                      isDark: isDark,
                    ),
                  ],
                ).dsCardEntry(delay: DSAnimations.stagger(4)),
                DSSpacing.hSm,

                // ── Legal Section ──────────────────────────────────────────
                const DSSectionHeader(
                  title: 'profile.sections.legal',
                  useLocalization: true,
                ),
                _ModernCard(
                  isDark: isDark,
                  children: [
                    _ActionTile(
                      icon: Icons.description_outlined,
                      iconColor: DSColors.primary,
                      label: 'profile.legal.terms'.tr(),
                      subtitle: 'profile.legal.terms_sub'.tr(),
                      isDark: isDark,
                      onTap: () => context.push('/terms?mode=view'),
                    ),
                    _CardDivider(isDark: isDark),
                    _ActionTile(
                      icon: Icons.shield_outlined,
                      iconColor: DSColors.success,
                      label: 'profile.legal.privacy'.tr(),
                      subtitle: 'profile.legal.privacy_sub'.tr(),
                      isDark: isDark,
                      onTap: () => context.push('/privacy'),
                    ),
                  ],
                ).dsCardEntry(delay: DSAnimations.stagger(5)),
                DSSpacing.hSm,

                // ── Diagnostics Section ────────────────────────────────────
                const DSSectionHeader(
                  title: 'profile.sections.diagnostics',
                  useLocalization: true,
                ),
                _ModernCard(
                  isDark: isDark,
                  children: [
                    _ActionTile(
                      icon: Icons.bug_report_outlined,
                      iconColor: DSColors.warning,
                      label: 'profile.diagnostics.report_issue'.tr(),
                      subtitle: isOnline
                          ? 'profile.diagnostics.report_issue_sub'.tr()
                          : 'profile.diagnostics.offline_warning'.tr(),
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
                ).dsCardEntry(delay: DSAnimations.stagger(6)),
                DSSpacing.hXl,
                // ── App Info Footer ────────────────────────────────────────
                Center(
                  child: Column(
                    children: [
                      Text(
                        'v${AppVersionService.version}',
                        style: DSTypography.caption().copyWith(
                          color: isDark
                              ? DSColors.labelTertiaryDark
                              : DSColors.labelTertiary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      DSSpacing.hXs,
                      Text(
                        'profile.info.copyright'.tr(
                          args: [DateTime.now().year.toString()],
                        ),
                        style: DSTypography.caption().copyWith(
                          color: isDark
                              ? DSColors.labelTertiaryDark
                              : DSColors.labelTertiary,
                          fontSize: DSTypography.sizeXs,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color get _storageIconColor {
    if (!_specsLoaded || _freeStorageGb < 0) return DSColors.success;
    if (_freeStorageGb < 0.5) return DSColors.error;
    if (_freeStorageGb < 2.0) return DSColors.warning;
    return DSColors.success;
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
    final email = courier['email']?.toString() ?? 'profile.info.no_email'.tr();
    final courierCode = courier['courier_code']?.toString() ?? '-';

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [DSColors.cardElevatedDark, DSColors.cardDark]
              : [DSColors.primary, DSColors.primaryPressed],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: DSStyles.cardRadius,
        border: Border.all(
          color: DSColors.white.withValues(alpha: 0.1),
          width: 0.5,
        ),
        boxShadow: [
          BoxShadow(
            color: (isDark ? DSColors.black : DSColors.primary).withValues(
              alpha: isDark ? DSStyles.alphaMuted : DSStyles.alphaSubtle,
            ),
            blurRadius: DSSpacing.lg,
            offset: const Offset(0, DSSpacing.md),
          ),
        ],
      ),
      padding: EdgeInsets.all(DSSpacing.lg),
      child: Column(
        children: [
          Row(
            children: [
              // Avatar
              Container(
                width: DSSpacing.huge + DSSpacing.md,
                height: DSSpacing.huge + DSSpacing.md,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: DSColors.white.withValues(
                      alpha: DSStyles.alphaMuted,
                    ),
                    width: DSStyles.strokeWidth,
                  ),
                  color: DSColors.white.withValues(alpha: DSStyles.alphaSubtle),
                ),
                child: Hero(
                  tag: 'profile_avatar',
                  child: ClipOval(
                    child: courier['profile_picture_url'] != null
                        ? Image.network(
                            courier['profile_picture_url'].toString(),
                            width: DSSpacing.huge + DSSpacing.md,
                            height: DSSpacing.huge + DSSpacing.md,
                            fit: BoxFit.cover,
                            errorBuilder: (_, e, s) => const Center(
                              child: Icon(
                                Icons.person_rounded,
                                size: DSIconSize.xl,
                                color: DSColors.white,
                              ),
                            ),
                          )
                        : const Center(
                            child: Icon(
                              Icons.person_rounded,
                              size: DSIconSize.xl,
                              color: DSColors.white,
                            ),
                          ),
                  ),
                ),
              ),
              DSSpacing.wMd,

              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name.isEmpty ? '-' : name,
                      style: DSTypography.heading().copyWith(
                        fontSize: DSTypography.sizeMd,
                        fontWeight: FontWeight.w700,
                        color: DSColors.white,
                        letterSpacing: -0.3,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      email,
                      style: DSTypography.caption().copyWith(
                        fontSize: DSTypography.sizeSm,
                        color: DSColors.white.withValues(
                          alpha: DSStyles.alphaDisabled,
                        ),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    DSSpacing.hXs,
                    if (kDebugMode)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: DSSpacing.sm,
                          vertical: DSSpacing.xs,
                        ),
                        decoration: BoxDecoration(
                          color: DSColors.white.withValues(
                            alpha: DSStyles.alphaSubtle,
                          ),
                          borderRadius: DSStyles.pillRadius,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.badge_outlined,
                              size: DSIconSize.xs,
                              color: DSColors.primary,
                            ),
                            DSSpacing.wXs,
                            Text(
                              '$courierCode (Debug)',
                              style: DSTypography.label().copyWith(
                                fontSize: DSTypography.sizeXs,
                                fontWeight: FontWeight.w600,
                                color: DSColors.white,
                                letterSpacing: DSTypography.lsLoose,
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
                    color: DSColors.white,
                    size: DSIconSize.xl,
                  ),
                  style: IconButton.styleFrom(
                    backgroundColor: DSColors.white.withValues(
                      alpha: DSStyles.alphaSubtle,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: DSStyles.cardRadius,
                    ),
                  ),
                ),
            ],
          ),
          DSSpacing.hMd,
          Divider(
            color: DSColors.white.withValues(alpha: DSStyles.alphaSubtle),
            height: DSStyles.borderWidth,
          ),
          DSSpacing.hMd,
          // Compact Info Row
          Row(
            children: [
              _CompactInfoItem(
                icon: Icons.phone_android_rounded,
                label: 'Phone',
                value: courier['phone_number']?.toString() ?? '-',
              ),
              DSSpacing.wXl,
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
              Icon(
                icon,
                size: DSIconSize.xs,
                color: DSColors.white.withValues(alpha: DSStyles.alphaDisabled),
              ),
              DSSpacing.wXs,
              Text(
                label.toUpperCase(),
                style:
                    DSTypography.label(
                      color: DSColors.white.withValues(
                        alpha: DSStyles.alphaDisabled,
                      ),
                    ).copyWith(
                      fontSize: DSTypography.sizeXs,
                      fontWeight: FontWeight.w800,
                    ),
              ),
            ],
          ),
          DSSpacing.hXs,
          Text(
            value,
            style: DSTypography.body(color: DSColors.white).copyWith(
              fontSize: DSTypography.sizeMd,
              fontWeight: FontWeight.w600,
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
      padding: EdgeInsets.all(DSSpacing.md),
      decoration: BoxDecoration(
        color: DSColors.error.withValues(alpha: DSStyles.alphaSoft),
        border: Border.all(
          color: DSColors.error.withValues(alpha: DSStyles.alphaMuted),
        ),
        borderRadius: DSStyles.cardRadius,
      ),
      child: Row(
        children: [
          Container(
            width: DSSpacing.xs,
            height: 34,
            decoration: BoxDecoration(
              color: DSColors.error.withValues(alpha: DSStyles.alphaSubtle),
              borderRadius: DSStyles.pillRadius,
            ),
            child: const Icon(
              Icons.warning_amber_rounded,
              color: DSColors.error,
              size: DSIconSize.md,
            ),
          ),
          DSSpacing.wMd,
          Expanded(
            child: Text(
              'Your account is currently inactive. Please contact support.',
              style: DSTypography.body().copyWith(
                color: DSColors.error,
                fontSize: DSTypography.sizeMd,
                fontWeight: FontWeight.w500,
                height: DSStyles.heightNormal,
              ),
            ),
          ),
        ],
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
        color: isDark ? DSColors.cardDark : DSColors.cardLight,
        borderRadius: DSStyles.cardRadius,
        border: Border.all(
          color: isDark ? DSColors.separatorDark : DSColors.separatorLight,
          width: DSStyles.borderWidth,
        ),
        boxShadow: DSStyles.shadowXS(context),
      ),
      child: ClipRRect(
        borderRadius: DSStyles.cardRadius,
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
      height: DSStyles.borderWidth,
      thickness: 1,
      indent: 58,
      color: isDark ? DSColors.separatorDark : DSColors.separatorLight,
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
        ? DSColors.error
        : (isDark ? DSColors.white : DSColors.labelPrimary);

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: DSSpacing.md, vertical: 14),
        child: Row(
          children: [
            Container(
              width: DSIconSize.heroSm,
              height: DSIconSize.heroSm,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: DSStyles.alphaSubtle),
                borderRadius: DSStyles.pillRadius,
              ),
              child: Icon(icon, size: DSIconSize.md, color: iconColor),
            ),
            DSSpacing.wMd,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: DSTypography.body().copyWith(
                      fontSize: DSTypography.sizeMd,
                      fontWeight: FontWeight.w600,
                      color: textColor,
                    ),
                  ),
                  DSSpacing.hXs,
                  Text(
                    subtitle,
                    style: DSTypography.caption().copyWith(
                      fontSize: DSTypography.sizeSm,
                      color: isDark
                          ? DSColors.labelSecondaryDark
                          : DSColors.labelSecondary,
                      height: DSStyles.heightNormal,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              size: DSIconSize.md,
              color: isDark
                  ? DSColors.labelTertiaryDark
                  : DSColors.labelTertiary,
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
      padding: EdgeInsets.symmetric(
        horizontal: DSSpacing.md,
        vertical: DSSpacing.md,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: DSIconSize.heroSm,
            height: DSIconSize.heroSm,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: DSStyles.alphaSubtle),
              borderRadius: DSStyles.pillRadius,
            ),
            child: Icon(icon, size: DSIconSize.md, color: iconColor),
          ),
          DSSpacing.wMd,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: DSTypography.body().copyWith(
                    fontSize: DSTypography.sizeMd,
                    fontWeight: FontWeight.w600,
                    color: isDark ? DSColors.white : DSColors.labelPrimary,
                  ),
                ),
                DSSpacing.hXs,
                Text(
                  subtitle,
                  style: DSTypography.caption().copyWith(
                    fontSize: DSTypography.sizeSm,
                    color: isDark
                        ? DSColors.labelSecondaryDark
                        : DSColors.labelSecondary,
                    height: DSStyles.heightNormal,
                  ),
                ),
              ],
            ),
          ),
          DSSpacing.wMd,
          Switch(
            value: value,
            onChanged: onChanged,
            thumbColor: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.selected)) return DSColors.white;
              return isDark
                  ? DSColors.labelTertiaryDark
                  : DSColors.labelTertiary;
            }),
            trackColor: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.selected)) {
                return iconColor;
              }
              return isDark ? DSColors.separatorDark : DSColors.separatorLight;
            }),
            trackOutlineColor: WidgetStateProperty.all(DSColors.transparent),
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
      padding: EdgeInsets.symmetric(
        horizontal: DSSpacing.md,
        vertical: DSSpacing.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: DSIconSize.heroSm,
                height: DSIconSize.heroSm,
                decoration: BoxDecoration(
                  color: DSColors.success.withValues(
                    alpha: DSStyles.alphaSubtle,
                  ),
                  borderRadius: DSStyles.pillRadius,
                ),
                child: Icon(
                  Icons.history_rounded,
                  color: DSColors.success,
                  size: DSIconSize.md,
                ),
              ),
              DSSpacing.wMd,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Sync History',
                      style: DSTypography.body().copyWith(
                        fontSize: DSTypography.sizeMd,
                        fontWeight: FontWeight.w600,
                        color: isDark ? DSColors.white : DSColors.labelPrimary,
                      ),
                    ),
                    DSSpacing.hXs,
                    Text(
                      'How long synced updates are kept before auto-removal.',
                      style: DSTypography.caption().copyWith(
                        fontSize: DSTypography.sizeSm,
                        color: isDark
                            ? DSColors.labelSecondaryDark
                            : DSColors.labelSecondary,
                        height: DSStyles.heightNormal,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          DSSpacing.hMd,
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
                  DSTypography.body().copyWith(
                    fontWeight: FontWeight.w600,
                    fontSize: DSTypography.sizeMd,
                  ),
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
      padding: EdgeInsets.symmetric(
        horizontal: DSSpacing.md,
        vertical: DSSpacing.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: DSIconSize.heroSm,
                height: DSIconSize.heroSm,
                decoration: BoxDecoration(
                  color: DSColors.pending.withValues(
                    alpha: DSStyles.alphaSubtle,
                  ),
                  borderRadius: DSStyles.pillRadius,
                ),
                child: Icon(
                  Icons.palette_outlined,
                  color: DSColors.pending,
                  size: DSIconSize.md,
                ),
              ),
              DSSpacing.wMd,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Theme',
                      style: DSTypography.body().copyWith(
                        fontSize: DSTypography.sizeMd,
                        fontWeight: FontWeight.w600,
                        color: isDark ? DSColors.white : DSColors.labelPrimary,
                      ),
                    ),
                    DSSpacing.hXs,
                    Text(
                      'Choose light, dark, or system default.',
                      style: DSTypography.caption().copyWith(
                        fontSize: DSTypography.sizeSm,
                        color: isDark
                            ? DSColors.labelSecondaryDark
                            : DSColors.labelSecondary,
                        height: DSStyles.heightNormal,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          DSSpacing.hMd,
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
                  DSTypography.button().copyWith(
                    fontWeight: FontWeight.w600,
                    fontSize: DSTypography.sizeMd,
                  ),
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
      padding: EdgeInsets.symmetric(horizontal: DSSpacing.md, vertical: 13),
      child: Row(
        children: [
          Container(
            width: DSIconSize.heroSm,
            height: DSIconSize.heroSm,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: DSStyles.alphaSubtle),
              borderRadius: DSStyles.pillRadius,
            ),
            child: Icon(icon, size: DSIconSize.md, color: iconColor),
          ),
          DSSpacing.wMd,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style:
                      DSTypography.caption(
                        color: isDark
                            ? DSColors.labelSecondaryDark
                            : DSColors.labelSecondary,
                      ).copyWith(
                        fontSize: DSTypography.sizeSm,
                        fontWeight: FontWeight.w500,
                        letterSpacing: DSTypography.lsLoose,
                      ),
                ),
                DSSpacing.hXs,
                Text(
                  value,
                  style:
                      DSTypography.body(
                        color:
                            valueColor ??
                            (isDark
                                ? DSColors.labelPrimaryDark
                                : DSColors.labelPrimary),
                      ).copyWith(
                        fontSize: DSTypography.sizeMd,
                        fontWeight: FontWeight.w600,
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
        padding: EdgeInsets.symmetric(horizontal: DSSpacing.md, vertical: 14),
        child: Row(
          children: [
            Container(
              width: DSIconSize.heroSm,
              height: DSIconSize.heroSm,
              decoration: BoxDecoration(
                color: DSColors.error.withValues(alpha: DSStyles.alphaSoft),
                borderRadius: DSStyles.pillRadius,
              ),
              child: Icon(
                Icons.bug_report_outlined,
                color: DSColors.error,
                size: DSIconSize.md,
              ),
            ),
            DSSpacing.wMd,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Error Logs',
                    style: DSTypography.body().copyWith(
                      fontSize: DSTypography.sizeMd,
                      fontWeight: FontWeight.w600,
                      color: isDark ? DSColors.white : DSColors.labelPrimary,
                    ),
                  ),
                  DSSpacing.hXs,
                  Text(
                    'View errors and warnings recorded on this device.',
                    style: DSTypography.caption().copyWith(
                      fontSize: DSTypography.sizeSm,
                      color: isDark
                          ? DSColors.labelSecondaryDark
                          : DSColors.labelSecondary,
                      height: DSStyles.heightNormal,
                    ),
                  ),
                ],
              ),
            ),
            if (errorLogCount > 0) ...[
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: DSSpacing.sm,
                  vertical: DSSpacing.xs,
                ),
                decoration: BoxDecoration(
                  color: DSColors.error,
                  borderRadius: DSStyles.cardRadius,
                ),
                child: Text(
                  '$errorLogCount',
                  style: DSTypography.label(color: DSColors.white).copyWith(
                    fontSize: DSTypography.sizeSm,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              DSSpacing.wXs,
            ],
            Icon(
              Icons.chevron_right_rounded,
              size: DSIconSize.md,
              color: isDark
                  ? DSColors.labelTertiaryDark
                  : DSColors.labelTertiary,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Language Segmented Tile ──────────────────────────────────────────────────

class _LanguageSegmentedTile extends StatelessWidget {
  const _LanguageSegmentedTile({required this.isDark, required this.onChanged});

  final bool isDark;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final currentCode =
        EasyLocalization.of(context)?.currentLocale?.languageCode ?? 'en';

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: DSSpacing.md,
        vertical: DSSpacing.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: DSIconSize.heroSm,
                height: DSIconSize.heroSm,
                decoration: BoxDecoration(
                  color: DSColors.primary.withValues(
                    alpha: DSStyles.alphaSubtle,
                  ),
                  borderRadius: DSStyles.pillRadius,
                ),
                child: const Icon(
                  Icons.language_rounded,
                  color: DSColors.primary,
                  size: DSIconSize.md,
                ),
              ),
              DSSpacing.wMd,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Language',
                      style: DSTypography.body().copyWith(
                        fontSize: DSTypography.sizeMd,
                        fontWeight: FontWeight.w600,
                        color: isDark ? DSColors.white : DSColors.labelPrimary,
                      ),
                    ),
                    DSSpacing.hXs,
                    Text(
                      'Choose your preferred language',
                      style: DSTypography.caption().copyWith(
                        fontSize: DSTypography.sizeSm,
                        color: isDark
                            ? DSColors.labelSecondaryDark
                            : DSColors.labelSecondary,
                        height: DSStyles.heightNormal,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          DSSpacing.hMd,
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<String>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: 'en', label: Text('🇺🇸  English')),
                ButtonSegment(value: 'fil', label: Text('🇵🇭  Filipino')),
              ],
              selected: {currentCode},
              style: ButtonStyle(
                textStyle: WidgetStateProperty.all(
                  DSTypography.body().copyWith(
                    fontWeight: FontWeight.w600,
                    fontSize: DSTypography.sizeMd,
                  ),
                ),
              ),
              onSelectionChanged: (val) {
                context.setLocale(Locale(val.first));
                onChanged();
              },
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
    final color = isCritical ? DSColors.error : DSColors.warning;
    final freeMb = (freeStorageGb * 1024).round();
    final valueLabel = isCritical
        ? '$freeMb MB'
        : '${freeStorageGb.toStringAsFixed(1)} GB';
    final message = isCritical
        ? 'Critical storage: $valueLabel remaining. Free up space to avoid sync failures.'
        : 'Low storage: $valueLabel remaining. Consider freeing up space.';

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: DSSpacing.md, vertical: 13),
      decoration: BoxDecoration(
        color: color.withValues(alpha: DSStyles.alphaSoft),
        borderRadius: DSStyles.cardRadius,
        border: Border.all(color: color.withValues(alpha: DSStyles.alphaMuted)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: DSIconSize.heroSm,
            height: DSIconSize.heroSm,
            decoration: BoxDecoration(
              color: color.withValues(alpha: DSStyles.alphaSubtle),
              borderRadius: DSStyles.pillRadius,
            ),
            child: Icon(
              Icons.warning_amber_rounded,
              color: color,
              size: DSIconSize.md,
            ),
          ),
          DSSpacing.wMd,
          Expanded(
            child: Text(
              message,
              style: DSTypography.caption().copyWith(
                fontSize: DSTypography.sizeSm,
                color: color,
                fontWeight: FontWeight.w500,
                height: DSStyles.heightNormal,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
