// DOCS: docs/development-standards.md
// DOCS: docs/features/bagsakan.md — update that file when you edit this one.

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:fsi_courier_app/core/api/api_client.dart';
import 'package:fsi_courier_app/design_system/design_system.dart';
import 'package:fsi_courier_app/shared/widgets/app_header_bar.dart';
import 'package:fsi_courier_app/shared/widgets/empty_state.dart';
import 'package:fsi_courier_app/shared/widgets/loading_overlay.dart';
import 'package:fsi_courier_app/core/database/database_providers.dart';
import 'package:fsi_courier_app/core/models/local_delivery.dart';
import 'package:fsi_courier_app/core/models/delivery_status.dart';
import 'package:fsi_courier_app/core/providers/connectivity_provider.dart';
import 'package:fsi_courier_app/core/providers/delivery_refresh_provider.dart';
import 'package:fsi_courier_app/core/providers/sync_provider.dart';
import 'package:fsi_courier_app/core/sync/delivery_bootstrap_service.dart';
import 'package:fsi_courier_app/shared/widgets/delivery_card.dart';
import 'package:fsi_courier_app/shared/helpers/delivery_helper.dart';
import 'package:fsi_courier_app/shared/helpers/snackbar_helper.dart';
import 'package:fsi_courier_app/shared/helpers/api_payload_helper.dart';
import 'package:fsi_courier_app/core/auth/auth_provider.dart';
import 'package:fsi_courier_app/features/bagsakan/bagsakan_providers.dart';
import 'package:fsi_courier_app/features/bagsakan/bagsakan_components.dart';
import 'package:fsi_courier_app/features/delivery/widgets/delivery_submit_fab.dart';
import 'package:fsi_courier_app/shared/widgets/offline_banner.dart';
import 'package:go_router/go_router.dart';

class BagsakanGroupItemsScreen extends ConsumerStatefulWidget {
  final int groupId;

  const BagsakanGroupItemsScreen({super.key, required this.groupId});

  @override
  ConsumerState<BagsakanGroupItemsScreen> createState() =>
      _BagsakanGroupItemsScreenState();
}

class _BagsakanGroupItemsScreenState
    extends ConsumerState<BagsakanGroupItemsScreen> {
  bool _isLoading = false;
  Map<String, dynamic>? _group;
  List<LocalDelivery> _items = [];
  String? _propagationSourceBarcode;
  late int _activeGroupId;

  @override
  void initState() {
    super.initState();
    _activeGroupId = widget.groupId;
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final dao = ref.read(bagsakanDaoProvider);
      final group = await dao.getBagsakanGroup(_activeGroupId);
      if (group != null) {
        final items = await dao.getBagsakanItems(_activeGroupId);
        if (mounted) {
          setState(() {
            _group = group;
            _items = items;
          });
        }

        final isOnline =
            ref.read(connectionStatusProvider) == ConnectionStatus.online;
        if (isOnline) {
          await _loadGroupDetailsFromApi();
        }
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadGroupDetailsFromApi() async {
    final createPending = await ref
        .read(syncOperationsDaoProvider)
        .hasPendingSync('BAGSAKAN_$_activeGroupId');
    if (createPending) return;

    final result = await ref
        .read(apiClientProvider)
        .get<Map<String, dynamic>>(
          '/bagsakan/groups/$_activeGroupId',
          parser: parseApiMap,
        );
    if (result is! ApiSuccess<Map<String, dynamic>> || !mounted) return;

    final groupData = mapFromKey(result.data, 'data');
    final deliveries = listOfMapsFromKey(groupData, 'deliveries');
    String? sourceBarcode;
    for (final item in deliveries) {
      if (item['propagation_source'] == true) {
        final barcode = (item['barcode']?.toString() ?? '').trim();
        if (barcode.isNotEmpty) {
          sourceBarcode = barcode;
          break;
        }
      }
    }

    setState(() {
      _propagationSourceBarcode = sourceBarcode;
    });
  }

  Future<void> _onSubmitBagsakan() async {
    final sourceDelivery = _resolveSubmitSourceDelivery();
    if (sourceDelivery == null) return;

    final sourceStatus = DeliveryStatus.fromString(
      sourceDelivery.deliveryStatus,
    );
    final sourceStatusApi = sourceStatus.toApiString();
    final sourceStatusLabel = sourceStatus.displayName.toUpperCase();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('bagsakan.submit_confirm_title'.tr()),
        content: Builder(
          builder: (ctx) {
            final isDark = Theme.of(ctx).brightness == Brightness.dark;
            final fullText = 'bagsakan.submit_confirm_message_status_reminder'
                .tr(args: [sourceStatusLabel]);

            final spans = <InlineSpan>[];
            final regex = RegExp(r'<b>(.*?)</b>|<warn>(.*?)</warn>');
            int lastMatchEnd = 0;

            for (final match in regex.allMatches(fullText)) {
              if (match.start > lastMatchEnd) {
                spans.add(
                  TextSpan(text: fullText.substring(lastMatchEnd, match.start)),
                );
              }

              final boldText = match.group(1);
              final warnText = match.group(2);

              if (boldText != null) {
                spans.add(
                  TextSpan(
                    text: boldText,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                );
              } else if (warnText != null) {
                spans.add(
                  TextSpan(
                    text: warnText,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: DSColors.error,
                    ),
                  ),
                );
              }

              lastMatchEnd = match.end;
            }

            if (lastMatchEnd < fullText.length) {
              spans.add(TextSpan(text: fullText.substring(lastMatchEnd)));
            }

            return RichText(
              text: TextSpan(
                style: DSTypography.body(
                  color: isDark
                      ? DSColors.labelPrimaryDark
                      : DSColors.labelPrimary,
                ),
                children: spans,
              ),
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'common.cancel'.tr(),
              style: const TextStyle(color: DSColors.labelSecondary),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              'bagsakan.submit_confirm_confirm'.tr(),
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: DSColors.primary,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      setState(() => _isLoading = true);
      try {
        final courierId =
            ref.read(authProvider).courier?['id']?.toString() ?? '';
        await ref
            .read(bagsakanDaoProvider)
            .submitBagsakanGroup(
              _activeGroupId,
              sourceDelivery.barcode,
              courierId,
              propagationStatus: sourceStatusApi,
            );
        await ref.read(syncManagerProvider.notifier).loadEntries();
        await _loadData();
        ref.read(deliveryRefreshProvider.notifier).increment();
        if (mounted) {
          showSuccessNotification(context, 'bagsakan.success_submitted'.tr());
        }
      } catch (e) {
        if (mounted) {
          showErrorNotification(context, 'common.error'.tr());
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  LocalDelivery? _resolveSubmitSourceDelivery() {
    final finalItems = _items
        .where((item) => DeliveryStatus.fromString(item.deliveryStatus).isFinal)
        .toList();

    if (_propagationSourceBarcode != null &&
        _propagationSourceBarcode!.trim().isNotEmpty) {
      final wanted = _propagationSourceBarcode!.trim().toUpperCase();
      for (final item in finalItems) {
        if (item.barcode.toUpperCase() == wanted) {
          return item;
        }
      }
    }

    final candidateItems = finalItems
        .where((item) => item.syncStatus == 'dirty')
        .toList();

    if (candidateItems.isEmpty) return null;

    candidateItems.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return candidateItems.first;
  }

  Future<void> _onRemoveFromBagsakan(LocalDelivery delivery) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('bagsakan.remove_confirm_title'.tr()),
        content: Text(
          'bagsakan.remove_confirm_message'.tr(args: [delivery.barcode]),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'common.cancel'.tr(),
              style: const TextStyle(color: DSColors.labelSecondary),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              'common.delete'.tr(), // Using 'Delete' or 'Remove' label
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: DSColors.error,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      setState(() => _isLoading = true);
      try {
        final courierId =
            ref.read(authProvider).courier?['id']?.toString() ?? '';
        await ref
            .read(bagsakanDaoProvider)
            .unassignFromBagsakan(delivery.barcode, courierId);

        await ref.read(syncManagerProvider.notifier).loadEntries();
        // Trigger auto-sync for background reconciliation
        unawaited(ref.read(syncManagerProvider.notifier).processQueue());

        await _loadData();
        ref.read(deliveryRefreshProvider.notifier).increment();

        if (mounted) {
          showSuccessNotification(
            context,
            'bagsakan.success_removed'.tr(args: [delivery.barcode]),
          );
        }
      } catch (e) {
        if (mounted) {
          showErrorNotification(context, 'common.error'.tr());
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  void _showPropagationHelpBottomSheet() {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      backgroundColor: DSColors.transparent,
      isScrollControlled: true,
      builder: (_) =>
          const SafeArea(top: false, child: BagsakanPropagationHelpSheet()),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Listen for remaps
    ref.listen<Map<int, int>>(bagsakanIdRemapProvider, (prev, next) {
      if (next.containsKey(_activeGroupId)) {
        setState(() => _activeGroupId = next[_activeGroupId]!);
        _loadData();
      }
    });

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final groupName = _group?['name'] as String? ?? '';
    final isSubmitted = _group?['status'] == 'submitted';
    final submitSource = _resolveSubmitSourceDelivery();
    final canSubmit = !isSubmitted && submitSource != null;

    // Listen for refreshes
    ref.listen(deliveryRefreshProvider, (prev, next) {
      if (prev != next) {
        _loadData();
      }
    });

    return Scaffold(
      backgroundColor: isDark ? DSColors.scaffoldDark : DSColors.scaffoldLight,
      appBar: AppHeaderBar(
        title: groupName.isEmpty
            ? 'bagsakan.group_items_header'.tr()
            : groupName,
        actions: [
          BagsakanHeaderInfoButton(onTap: _showPropagationHelpBottomSheet),

          if (!isSubmitted)
            HeaderIconButton(
              icon: Icons.edit_rounded,
              onTap: () async {
                if (_propagationSourceBarcode != null) {
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: Text(
                        'bagsakan.edit_confirm_title'.tr(),
                        style: DSTypography.heading(
                          color: isDark
                              ? DSColors.labelPrimaryDark
                              : DSColors.labelPrimary,
                        ),
                      ),
                      content: Text(
                        'bagsakan.edit_confirm_message'.tr(),
                        style: DSTypography.body(
                          color: isDark
                              ? DSColors.labelSecondaryDark
                              : DSColors.labelSecondary,
                        ),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: Text(
                            'common.cancel'.tr(),
                            style: DSTypography.body(
                              color: DSColors.primary,
                            ).copyWith(fontWeight: FontWeight.bold),
                          ),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: Text(
                            'common.confirm'.tr(),
                            style: DSTypography.body(
                              color: DSColors.primary,
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
                  if (confirmed != true) return;
                }
                if (!context.mounted) return;
                context.push('/bagsakan/edit/$_activeGroupId');
              },
              isFlat: true,
            ),
        ],
      ),
      // Rule: Connectivity awareness is required for all Bagsakan management screens.
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
            child: LoadingOverlay(
              isLoading: _isLoading,
              child: RefreshIndicator(
                onRefresh: () async {
                  final isOnline = ref.read(isOnlineProvider);
                  if (isOnline) {
                    await DeliveryBootstrapService.instance.syncFromApi(
                      ref.read(apiClientProvider),
                    );
                  }
                  ref.read(deliveryRefreshProvider.notifier).increment();
                },
                child: _items.isEmpty && !_isLoading
                    ? ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: [
                          SizedBox(
                            height: MediaQuery.of(context).size.height * 0.7,
                            child: EmptyState(
                              message: 'bagsakan.no_items'.tr(),
                              icon: Icons.inventory_2_outlined,
                              iconColor: isDark
                                  ? DSColors.labelSecondaryDark
                                  : DSColors.labelSecondary,
                            ).dsFadeEntry(),
                          ),
                        ],
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(
                          DSSpacing.md,
                          DSSpacing.sm,
                          DSSpacing.md,
                          100, // Bottom padding for FAB
                        ),
                        physics: const AlwaysScrollableScrollPhysics(),
                        itemCount: _items.length,
                        itemBuilder: (context, index) {
                          final delivery = _items[index];
                          final isPropagationSource =
                              _propagationSourceBarcode != null &&
                              delivery.barcode.toUpperCase() ==
                                  _propagationSourceBarcode!
                                      .trim()
                                      .toUpperCase();

                          return DeliveryCard(
                            delivery: delivery.toDeliveryMap(),
                            compact: false,
                            isPropagationSource: isPropagationSource,
                            onTap: isSubmitted
                                ? null
                                : () {
                                    // RULE: If an individual item is already delivered/sealed,
                                    // prevent re-updating it to avoid data corruption.
                                    final dMap = delivery.toDeliveryMap();

                                    // We temporarily ignore the bagsakan_id for the lock check because we are
                                    // explicitly managing the group here; we only care about the delivery status lock.
                                    final testMap = Map<String, dynamic>.from(
                                      dMap,
                                    )..remove('bagsakan_id');
                                    final isItemLocked = checkIsLockedFromMap(
                                      testMap,
                                    );

                                    if (isItemLocked) {
                                      final status = delivery.deliveryStatus
                                          .toUpperCase();
                                      final ds = DeliveryStatus.fromString(
                                        status,
                                      );
                                      String msg =
                                          'This delivery is ${ds.displayName.toLowerCase()} and cannot be opened.';
                                      if (ds == DeliveryStatus.delivered) {
                                        msg =
                                            'This item has already been delivered and is locked.';
                                      } else if (ds == DeliveryStatus.osa) {
                                        msg =
                                            'This item is marked OSA and cannot be opened.';
                                      } else if (ds ==
                                          DeliveryStatus.failedDelivery) {
                                        msg =
                                            'This failed delivery is no longer actionable.';
                                      }
                                      showInfoNotification(context, msg);
                                      return;
                                    }

                                    context.push(
                                      '/deliveries/${delivery.barcode}/update',
                                    );
                                  },
                            onRemoveFromBagsakanTap: isSubmitted
                                ? null
                                : () => _onRemoveFromBagsakan(delivery),
                          ).dsCardEntry(delay: DSAnimations.stagger(index));
                        },
                      ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: canSubmit
          ? DeliverySubmitFab(
              isLoading: _isLoading,
              onPressed: _onSubmitBagsakan,
              label: 'bagsakan.submit_button'.tr().toUpperCase(),
            )
          : null,
    );
  }
}
