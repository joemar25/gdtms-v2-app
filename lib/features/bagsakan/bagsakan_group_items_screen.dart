// DOCS: docs/development-standards.md
// DOCS: docs/features/bagsakan.md — update that file when you edit this one.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:fsi_courier_app/design_system/design_system.dart';
import 'package:fsi_courier_app/shared/widgets/app_header_bar.dart';
import 'package:fsi_courier_app/shared/widgets/empty_state.dart';
import 'package:fsi_courier_app/shared/widgets/loading_overlay.dart';
import 'package:fsi_courier_app/core/database/database_providers.dart';
import 'package:fsi_courier_app/core/models/local_delivery.dart';
import 'package:fsi_courier_app/core/providers/delivery_refresh_provider.dart';
import 'package:fsi_courier_app/shared/widgets/delivery_card.dart';
import 'package:fsi_courier_app/shared/helpers/snackbar_helper.dart';
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
  bool _isLoading = true;
  Map<String, dynamic>? _group;
  List<LocalDelivery> _items = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final dao = ref.read(bagsakanDaoProvider);
      final group = await dao.getBagsakanGroup(widget.groupId);
      if (group != null) {
        final items = await dao.getBagsakanItems(widget.groupId);
        if (mounted) {
          setState(() {
            _group = group;
            _items = items;
          });
        }
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _onSubmitBagsakan() async {
    final deliveredItems = _items
        .where((e) => e.deliveryStatus == 'DELIVERED')
        .toList();
    if (deliveredItems.isEmpty) return;

    // Use the first delivered item as the source
    final sourceBarcode = deliveredItems.first.barcode;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('bagsakan.submit_confirm_title'.tr()),
        content: Text('bagsakan.submit_confirm_message'.tr()),
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
        await ref
            .read(bagsakanDaoProvider)
            .submitBagsakanGroup(widget.groupId, sourceBarcode);
        await _loadData();
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final groupName = _group?['name'] as String? ?? '';
    final isSubmitted = _group?['status'] == 'submitted';
    final hasDelivered = _items.any((e) => e.deliveryStatus == 'DELIVERED');
    final canSubmit = !isSubmitted && hasDelivered;

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
              icon: Icons.edit_rounded,
              onTap: () => context.push('/bagsakan/edit/${widget.groupId}'),
              isFlat: true,
            ),
        ],
      ),
      body: LoadingOverlay(
        isLoading: _isLoading,
        child: _items.isEmpty && !_isLoading
            ? Center(
                child: EmptyState(
                  message: 'bagsakan.no_items'.tr(),
                  icon: Icons.inventory_2_outlined,
                  iconColor: isDark
                      ? DSColors.labelSecondaryDark
                      : DSColors.labelSecondary,
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.all(DSSpacing.md),
                itemCount: _items.length,
                itemBuilder: (context, index) {
                  final delivery = _items[index];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: DSSpacing.md),
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
                    ),
                  );
                },
              ),
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
