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
  String _groupName = '';
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
        _groupName = group['name'] as String;
        final items = await dao.getBagsakanItems(widget.groupId);
        if (mounted) {
          setState(() {
            _items = items;
          });
        }
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Listen for refreshes (e.g. after saving an edit)
    ref.listen(deliveryRefreshProvider, (prev, next) {
      if (prev != next) {
        _loadData();
      }
    });

    return Scaffold(
      backgroundColor: isDark ? DSColors.scaffoldDark : DSColors.scaffoldLight,
      appBar: AppHeaderBar(
        title: _groupName.isEmpty
            ? 'bagsakan.group_items_header'.tr()
            : _groupName,
        actions: [
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
                      onTap: () {
                        context.push('/deliveries/${delivery.barcode}/update');
                      },
                    ),
                  );
                },
              ),
      ),
    );
  }
}
