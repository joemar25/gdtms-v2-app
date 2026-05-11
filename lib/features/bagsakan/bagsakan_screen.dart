// DOCS: docs/development-standards.md
// DOCS: docs/features/bagsakan.md — update that file when you edit this one.

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:fsi_courier_app/design_system/design_system.dart';
import 'package:fsi_courier_app/shared/widgets/app_header_bar.dart';
import 'package:go_router/go_router.dart';

import 'package:fsi_courier_app/shared/widgets/empty_state.dart';
import 'package:fsi_courier_app/features/bagsakan/bagsakan_providers.dart';
import 'package:fsi_courier_app/core/providers/delivery_refresh_provider.dart';
import 'package:fsi_courier_app/core/api/api_client.dart';
import 'package:fsi_courier_app/core/providers/connectivity_provider.dart';
import 'package:fsi_courier_app/core/sync/delivery_bootstrap_service.dart';
import 'package:fsi_courier_app/core/providers/sync_provider.dart';
import 'package:fsi_courier_app/core/database/database_providers.dart';
import 'package:fsi_courier_app/core/auth/auth_provider.dart';
import 'package:fsi_courier_app/shared/helpers/snackbar_helper.dart';
import 'package:fsi_courier_app/shared/widgets/offline_banner.dart';
import 'package:fsi_courier_app/features/bagsakan/bagsakan_components.dart';

class BagsakanScreen extends ConsumerStatefulWidget {
  const BagsakanScreen({super.key});

  @override
  ConsumerState<BagsakanScreen> createState() => _BagsakanScreenState();
}

class _BagsakanScreenState extends ConsumerState<BagsakanScreen> {
  double _horizontalDrag = 0.0;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final groupsAsync = ref.watch(bagsakanGroupsProvider);

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onHorizontalDragUpdate: (details) => _horizontalDrag += details.delta.dx,
      onHorizontalDragEnd: (details) {
        final dx = _horizontalDrag;
        _horizontalDrag = 0.0;
        final velocity = details.primaryVelocity ?? 0.0;
        if (dx.abs() > 60 || velocity.abs() > 300) {
          if (dx < 0 || velocity < 0) {
            // swipe left → Wallet
            context.go('/wallet', extra: {'_swipe': 'left'});
          } else {
            // swipe right → Home
            context.go('/dashboard', extra: {'_swipe': 'right'});
          }
        }
      },
      child: Scaffold(
        backgroundColor: isDark
            ? DSColors.scaffoldDark
            : DSColors.scaffoldLight,
        appBar: AppHeaderBar(
          title: 'bagsakan.title'.tr(),
          pageIcon: Icons.inventory_2_rounded,
          actions: [
            HeaderIconButton(
              icon: Icons.add_rounded,
              onTap: () => context.push('/bagsakan/create'),
              isFlat: true,
            ),
          ],
        ),
        // Rule: Always show the connectivity status banner at the top of the body.
        // This ensures couriers know if they can sync deletions or group updates.
        body: Column(
          children: [
            const ConnectionStatusBanner(
              isMinimal: true,
              margin: EdgeInsets.fromLTRB(
                DSSpacing.md,
                DSSpacing.md,
                DSSpacing.md,
                0,
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async {
                  final isOnline = ref.read(isOnlineProvider);
                  if (isOnline) {
                    final api = ref.read(apiClientProvider);
                    final sync = ref.read(syncManagerProvider.notifier);

                    // Rule: online data is priority. Pull the latest state first,
                    // then push any pending local changes to reconcile.
                    await DeliveryBootstrapService.instance.syncFromApi(api);
                    await sync.processQueue();
                  }
                  ref.read(deliveryRefreshProvider.notifier).increment();
                },
                color: DSColors.primary,
                child: groupsAsync.when(
                  loading: () => const Center(
                    child: CircularProgressIndicator(color: DSColors.primary),
                  ),
                  error: (err, stack) => Center(
                    child: EmptyState(
                      message: 'common.error'.tr(),
                      icon: Icons.error_outline_rounded,
                      iconColor: DSColors.error,
                    ),
                  ),
                  data: (groups) {
                    if (groups.isEmpty) {
                      return ListView(
                        children: [
                          SizedBox(
                            height: MediaQuery.of(context).size.height * 0.7,
                            child: EmptyState(
                              message: 'bagsakan.empty_list'.tr(),
                              icon: Icons.inventory_2_outlined,
                              iconColor: isDark
                                  ? DSColors.labelSecondaryDark
                                  : DSColors.labelSecondary,
                            ),
                          ),
                        ],
                      );
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.all(DSSpacing.md),
                      itemCount: groups.length,
                      itemBuilder: (context, index) {
                        final group = groups[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: DSSpacing.md),
                          child: BagsakanGroupCard(
                            group: group,
                            isDark: isDark,
                            onTap: () {
                              final id = group['id'] as int;
                              context.push('/bagsakan/group/$id');
                            },
                            onDelete: () async {
                              final id = group['id'] as int;
                              final liveGroup = await ref
                                  .read(bagsakanDaoProvider)
                                  .getBagsakanGroup(id);
                              if (!context.mounted) return;
                              final liveStatus =
                                  (liveGroup?['status']?.toString() ?? '')
                                      .toLowerCase();
                              if (liveStatus == 'submitted') {
                                showInfoNotification(
                                  context,
                                  'bagsakan.error_delete_submitted'.tr(),
                                );
                                return;
                              }

                              final confirmed = await showDialog<bool>(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: Text(
                                    'bagsakan.delete_confirm_title'.tr(),
                                    style: DSTypography.heading(
                                      color: isDark
                                          ? DSColors.labelPrimaryDark
                                          : DSColors.labelPrimary,
                                    ),
                                  ),
                                  content: Text(
                                    'bagsakan.delete_confirm_message'.tr(),
                                    style: DSTypography.body(
                                      color: isDark
                                          ? DSColors.labelSecondaryDark
                                          : DSColors.labelSecondary,
                                    ),
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(context, false),
                                      child: Text(
                                        'common.cancel'.tr(),
                                        style: DSTypography.body(
                                          color: DSColors.primary,
                                        ).copyWith(fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(context, true),
                                      child: Text(
                                        'bagsakan.delete_confirm_confirm'.tr(),
                                        style: DSTypography.body(
                                          color: DSColors.error,
                                        ).copyWith(fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ],
                                  backgroundColor: isDark
                                      ? DSColors.cardDark
                                      : DSColors.cardLight,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: DSStyles.cardRadius,
                                  ),
                                ),
                              );

                              if (confirmed == true && context.mounted) {
                                try {
                                  final courierId =
                                      ref
                                          .read(authProvider)
                                          .courier?['id']
                                          ?.toString() ??
                                      '';
                                  await ref
                                      .read(bagsakanDaoProvider)
                                      .deleteBagsakanGroup(id, courierId);
                                  await ref
                                      .read(syncManagerProvider.notifier)
                                      .loadEntries();

                                  // Auto-sync after deletion
                                  unawaited(
                                    ref
                                        .read(syncManagerProvider.notifier)
                                        .processQueue(),
                                  );

                                  ref
                                      .read(deliveryRefreshProvider.notifier)
                                      .increment();

                                  if (context.mounted) {
                                    showSuccessNotification(
                                      context,
                                      'bagsakan.success_deleted'.tr(
                                        args: [group['name']],
                                      ),
                                    );
                                  }
                                } catch (e) {
                                  if (!context.mounted) return;
                                  final msg =
                                      e.toString().toLowerCase().contains(
                                        'submitted',
                                      )
                                      ? 'bagsakan.error_delete_submitted'.tr()
                                      : 'bagsakan.error_delete_failed'.tr();
                                  showErrorNotification(context, msg);
                                }
                              }
                            },
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
