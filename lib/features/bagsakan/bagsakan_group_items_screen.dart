// DOCS: docs/development-standards.md
// DOCS: docs/features/bagsakan.md — update that file when you edit this one.

import 'dart:async';
import 'package:flutter/material.dart';
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
import 'package:fsi_courier_app/core/database/sync_operations_dao.dart';
import 'package:fsi_courier_app/core/providers/sync_provider.dart';
import 'package:fsi_courier_app/core/sync/delivery_bootstrap_service.dart';
import 'package:fsi_courier_app/shared/widgets/delivery_card.dart';
import 'package:fsi_courier_app/shared/helpers/snackbar_helper.dart';
import 'package:fsi_courier_app/shared/helpers/api_payload_helper.dart';
import 'package:fsi_courier_app/core/auth/auth_provider.dart';
import 'package:fsi_courier_app/features/bagsakan/bagsakan_providers.dart';
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

  Future<void> _onAssignAccount() async {
    final accountController = TextEditingController();
    final accountName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Assign account to this Bagsakan'),
        content: TextField(
          controller: accountController,
          autofocus: true,
          textInputAction: TextInputAction.done,
          decoration: const InputDecoration(
            labelText: 'Account name',
            hintText: 'e.g. SBC',
          ),
          onSubmitted: (_) => Navigator.pop(context, accountController.text),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('common.cancel'.tr()),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, accountController.text),
            child: const Text('Assign'),
          ),
        ],
      ),
    );

    final account = (accountName ?? '').trim();
    if (account.isEmpty || !mounted) return;

    final isOnline =
        ref.read(connectionStatusProvider) == ConnectionStatus.online;
    if (!isOnline) {
      showErrorNotification(
        context,
        'Account assignment requires an online connection.',
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final result = await ref
          .read(apiClientProvider)
          .post<Map<String, dynamic>>(
            '/bagsakan/groups/$_activeGroupId/assign-account',
            data: {'account_name': account},
            parser: parseApiMap,
          );

      if (result is ApiSuccess<Map<String, dynamic>>) {
        final root = result.data;
        final data = mapFromKey(root, 'data');
        final assignedCount =
            (data['assigned_count'] as num?)?.toInt() ??
            (root['assigned_count'] as num?)?.toInt() ??
            0;

        await DeliveryBootstrapService.instance.syncFromApi(
          ref.read(apiClientProvider),
        );
        await ref.read(syncManagerProvider.notifier).loadEntries();
        await _loadData();
        ref.read(deliveryRefreshProvider.notifier).increment();

        if (mounted) {
          showSuccessNotification(
            context,
            assignedCount > 0
                ? 'Assigned $assignedCount delivery item${assignedCount == 1 ? '' : 's'} from account $account.'
                : 'Account $account assignment completed.',
          );
        }
      } else {
        final errorMessage = switch (result) {
          ApiBadRequest(:final message) => message,
          ApiValidationError(:final message) => message ?? 'Validation error',
          ApiConflict(:final message) => message,
          ApiServerError(:final message) => message,
          ApiNetworkError(:final message) => message,
          ApiRateLimited(:final message) => message,
          _ => 'Failed to assign account to bagsakan.',
        };
        if (mounted) showErrorNotification(context, errorMessage);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
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
        content: Text(
          'bagsakan.submit_confirm_message_status_reminder'.tr(
            args: [sourceStatusLabel],
          ),
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
          if (!isSubmitted)
            HeaderIconButton(
              icon: Icons.group_add_rounded,
              onTap: _onAssignAccount,
              isFlat: true,
            ),
          if (!isSubmitted)
            HeaderIconButton(
              icon: Icons.edit_rounded,
              onTap: () => context.push('/bagsakan/edit/$_activeGroupId'),
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
                            ),
                          ),
                        ],
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(DSSpacing.md),
                        physics: const AlwaysScrollableScrollPhysics(),
                        itemCount:
                            _items.length +
                            (_propagationSourceBarcode != null ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (_propagationSourceBarcode != null && index == 0) {
                            return Padding(
                              padding: const EdgeInsets.only(
                                bottom: DSSpacing.md,
                              ),
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(DSSpacing.md),
                                decoration: BoxDecoration(
                                  color: DSColors.primary.withValues(
                                    alpha: 0.08,
                                  ),
                                  borderRadius: DSStyles.cardRadius,
                                ),
                                child: Text(
                                  'Propagation source: $_propagationSourceBarcode',
                                  style: DSTypography.caption(
                                    color: DSColors.primary,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            );
                          }

                          final itemIndex = _propagationSourceBarcode != null
                              ? index - 1
                              : index;
                          final delivery = _items[itemIndex];
                          return Padding(
                            padding: const EdgeInsets.only(
                              bottom: DSSpacing.md,
                            ),
                            child: DeliveryCard(
                              delivery: delivery.toDeliveryMap(),
                              compact: false,
                              onTap: isSubmitted
                                  ? null
                                  : () {
                                      context.push(
                                        '/deliveries/${delivery.barcode}/update',
                                      );
                                    },
                              onRemoveFromBagsakanTap: isSubmitted
                                  ? null
                                  : () => _onRemoveFromBagsakan(delivery),
                            ),
                          );
                        },
                      ),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: canSubmit
          ? Container(
              padding: const EdgeInsets.all(DSSpacing.md),
              decoration: BoxDecoration(
                color: isDark ? DSColors.cardDark : DSColors.cardLight,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 10,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: SafeArea(
                child: FilledButton.icon(
                  onPressed: _isLoading ? null : _onSubmitBagsakan,
                  icon: const Icon(Icons.check_circle_outline_rounded),
                  label: Text('bagsakan.submit_button'.tr().toUpperCase()),
                  style: FilledButton.styleFrom(
                    backgroundColor: DSColors.primary,
                    minimumSize: const Size(double.infinity, 56),
                    shape: RoundedRectangleBorder(
                      borderRadius: DSStyles.cardRadius,
                    ),
                  ),
                ),
              ),
            )
          : null,
    );
  }
}
