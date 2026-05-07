// DOCS: docs/development-standards.md
// DOCS: docs/features/bagsakan.md — update that file when you edit this one.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:go_router/go_router.dart';
import 'package:fsi_courier_app/design_system/design_system.dart';
import 'package:fsi_courier_app/shared/widgets/app_header_bar.dart';
import 'package:fsi_courier_app/shared/widgets/empty_state.dart';
import 'package:fsi_courier_app/shared/widgets/loading_overlay.dart';
import 'package:fsi_courier_app/features/delivery/widgets/delivery_form_helpers.dart';
import 'package:fsi_courier_app/features/delivery/widgets/delivery_submit_fab.dart';
import 'package:fsi_courier_app/core/database/database_providers.dart';
import 'package:fsi_courier_app/core/models/local_delivery.dart';
import 'package:fsi_courier_app/core/providers/delivery_refresh_provider.dart';
import 'package:fsi_courier_app/shared/helpers/snackbar_helper.dart';
import 'package:fsi_courier_app/features/bagsakan/bagsakan_components.dart';

enum BagsakanSearchMode { barcode, accountName }

// Matches delivery_update_screen.dart spacing constants.
const _kSectionGap = DSSpacing.hLg;
const _kInnerGap = DSSpacing.hSm;

class BagsakanListScreen extends ConsumerStatefulWidget {
  final int? groupId;

  const BagsakanListScreen({super.key, this.groupId});

  @override
  ConsumerState<BagsakanListScreen> createState() => _BagsakanListScreenState();
}

class _BagsakanListScreenState extends ConsumerState<BagsakanListScreen> {
  final _groupNameController = TextEditingController();
  final _groupDescriptionController = TextEditingController();
  final _searchController = TextEditingController();

  BagsakanSearchMode _searchMode = BagsakanSearchMode.barcode;
  bool _isSearching = false;
  bool _isSaving = false;
  bool _isLoadingGroup = false;
  List<LocalDelivery> _searchResults = [];
  final List<LocalDelivery> _groupItems = [];

  @override
  void initState() {
    super.initState();
    if (widget.groupId != null) {
      _loadGroupData();
    }
  }

  Future<void> _loadGroupData() async {
    setState(() => _isLoadingGroup = true);
    try {
      final dao = ref.read(bagsakanDaoProvider);
      final group = await dao.getBagsakanGroup(widget.groupId!);
      if (group != null) {
        _groupNameController.text = group['name'] as String;
        _groupDescriptionController.text =
            group['description'] as String? ?? '';

        final items = await dao.getBagsakanItems(widget.groupId!);
        if (mounted) {
          setState(() {
            _groupItems.clear();
            _groupItems.addAll(items);
          });
        }
      }
    } finally {
      if (mounted) setState(() => _isLoadingGroup = false);
    }
  }

  @override
  void dispose() {
    _groupNameController.dispose();
    _groupDescriptionController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _performSearch() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) {
      setState(() => _searchResults = []);
      return;
    }
    setState(() => _isSearching = true);
    try {
      final results = _searchMode == BagsakanSearchMode.barcode
          ? await ref.read(bagsakanDaoProvider).searchByBarcodeLike(query)
          : await ref.read(bagsakanDaoProvider).searchByAccountName(query);
      if (mounted) setState(() => _searchResults = results);
    } finally {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  Future<void> _onSaveGroup() async {
    final name = _groupNameController.text.trim();
    if (name.isEmpty) {
      showErrorNotification(context, 'bagsakan.error_empty_name'.tr());
      return;
    }
    if (_groupItems.isEmpty) {
      showErrorNotification(context, 'bagsakan.error_empty_items'.tr());
      return;
    }

    final description = _groupDescriptionController.text.trim();
    setState(() => _isSaving = true);
    try {
      final dao = ref.read(bagsakanDaoProvider);
      final int groupId;

      if (widget.groupId != null) {
        groupId = widget.groupId!;
        await dao.updateBagsakanGroup(
          groupId: groupId,
          name: name,
          description: description,
        );
        // Clear current items to handle removals properly
        await dao.clearBagsakanGroup(groupId);
      } else {
        groupId = await dao.createBagsakanGroup(
          name: name,
          description: description,
        );
      }

      await dao.assignToBagsakan(
        groupId: groupId,
        barcodes: _groupItems.map((e) => e.barcode).toList(),
      );

      if (mounted) {
        showSuccessNotification(
          context,
          widget.groupId != null
              ? 'bagsakan.success_updated'.tr(args: [name])
              : 'bagsakan.success_created'.tr(args: [name]),
        );
        ref.read(deliveryRefreshProvider.notifier).increment();
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        showErrorNotification(context, 'bagsakan.error_failed'.tr());
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // ─── MARK: Handlers ────────────────────────────────────────────────────────

  void _onAddToBagsakan(LocalDelivery delivery) {
    if (_groupItems.any((e) => e.barcode == delivery.barcode)) {
      showInfoNotification(context, 'bagsakan.already_added'.tr());
      return;
    }

    setState(() {
      _groupItems.add(delivery);
      _searchResults.removeWhere((e) => e.barcode == delivery.barcode);
    });
  }

  Future<void> _onRemoveFromBagsakan(LocalDelivery delivery) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'bagsakan.remove_confirm_title'.tr(),
          style: DSTypography.heading(
            color: Theme.of(context).brightness == Brightness.dark
                ? DSColors.labelPrimaryDark
                : DSColors.labelPrimary,
          ),
        ),
        content: Text(
          'bagsakan.remove_confirm_message'.tr(
            args: [delivery.recipientName ?? delivery.barcode],
          ),
          style: DSTypography.body(
            color: Theme.of(context).brightness == Brightness.dark
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
                color: DSColors.error,
              ).copyWith(fontWeight: FontWeight.bold),
            ),
          ),
        ],
        backgroundColor: Theme.of(context).brightness == Brightness.dark
            ? DSColors.cardDark
            : DSColors.cardLight,
        shape: RoundedRectangleBorder(borderRadius: DSStyles.cardRadius),
      ),
    );

    if (confirmed == true) {
      setState(() {
        _groupItems.removeWhere((e) => e.barcode == delivery.barcode);
      });
      if (mounted) {
        showAppSnackbar(
          context,
          'bagsakan.success_removed'.tr(
            args: [delivery.recipientName ?? delivery.barcode],
          ),
          type: SnackbarType.success,
        );
      }
    }
  }

  Widget _radioOption({
    required String label,
    required BagsakanSearchMode value,
    required bool isDark,
  }) {
    final selected = _searchMode == value;
    return InkWell(
      onTap: () => setState(() {
        _searchMode = value;
        _searchResults.clear();
      }),
      borderRadius: DSStyles.pillRadius,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            selected
                ? Icons.radio_button_checked_rounded
                : Icons.radio_button_unchecked_rounded,
            color: selected
                ? DSColors.primary
                : (isDark
                      ? DSColors.labelSecondaryDark
                      : DSColors.labelSecondary),
            size: DSIconSize.md,
          ),
          DSSpacing.wXs,
          Text(
            label,
            style: DSTypography.body(
              color: isDark ? DSColors.labelPrimaryDark : DSColors.labelPrimary,
            ).copyWith(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  // ─── MARK: UI Building ─────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: _groupItems.isEmpty
          ? null
          : DeliverySubmitFab(
              isLoading: _isSaving,
              onPressed: _onSaveGroup,
              label: widget.groupId != null
                  ? 'bagsakan.update_group'.tr()
                  : 'bagsakan.create_group'.tr(),
              icon: widget.groupId != null
                  ? Icons.save_rounded
                  : Icons.inventory_2_rounded,
            ),
      appBar: AppHeaderBar(
        title: widget.groupId != null
            ? 'bagsakan.edit'.tr()
            : 'bagsakan.create'.tr(),
      ),
      body: LoadingOverlay(
        isLoading: _isSearching || _isSaving || _isLoadingGroup,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            DSSpacing.md,
            DSSpacing.md,
            DSSpacing.md,
            100,
          ),
          children: [
            // ── GROUP INFO ─────────────────────────────────────────────────
            DeliverySectionHeader(label: 'bagsakan.group_info'.tr()),
            _kInnerGap,
            DSInput(
              label: 'bagsakan.group_name'.tr(),
              hintText: 'bagsakan.group_name_hint'.tr(),
              controller: _groupNameController,
            ),
            DSInput(
              label: 'bagsakan.group_description'.tr(),
              hintText: 'bagsakan.group_description_hint'.tr(),
              controller: _groupDescriptionController,
            ),

            // ── FIND DELIVERY ──────────────────────────────────────────────
            _kSectionGap,
            DeliverySectionHeader(label: 'bagsakan.delivery_details'.tr()),
            _kInnerGap,
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: DSInput(
                    label: 'bagsakan.search_hint'.tr(),
                    controller: _searchController,
                    prefixIcon: Icons.search_rounded,
                    onChanged: (v) {
                      if (v.isEmpty && _searchResults.isNotEmpty) {
                        setState(() => _searchResults.clear());
                      }
                    },
                  ),
                ),
                if (_searchMode == BagsakanSearchMode.barcode) ...[
                  DSSpacing.wMd,
                  Container(
                    height: DSSpacing.lg + DSSpacing.xl,
                    width: DSSpacing.lg + DSSpacing.xl,
                    decoration: BoxDecoration(
                      color: isDark
                          ? DSColors.secondarySurfaceDark
                          : DSColors.secondarySurfaceLight,
                      borderRadius: DSStyles.cardRadius,
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.qr_code_scanner_rounded),
                      color: DSColors.primary,
                      onPressed: () =>
                          context.push('/scan', extra: {'mode': 'bagsakan'}),
                    ),
                  ),
                ],
              ],
            ),
            _kInnerGap,
            Wrap(
              spacing: DSSpacing.md,
              runSpacing: DSSpacing.xs,
              children: [
                _radioOption(
                  label: 'bagsakan.barcode'.tr(),
                  value: BagsakanSearchMode.barcode,
                  isDark: isDark,
                ),
                _radioOption(
                  label: 'bagsakan.account_name'.tr(),
                  value: BagsakanSearchMode.accountName,
                  isDark: isDark,
                ),
              ],
            ),
            DSSpacing.hMd,
            FilledButton.icon(
              icon: _isSearching
                  ? const SizedBox(
                      width: DSIconSize.md,
                      height: DSIconSize.md,
                      child: CircularProgressIndicator(
                        strokeWidth: DSStyles.strokeWidth,
                        color: DSColors.white,
                      ),
                    )
                  : const Icon(Icons.search_rounded),
              label: Text(
                'bagsakan.search'.tr(),
                style: DSTypography.button().copyWith(
                  letterSpacing: DSTypography.lsExtraLoose,
                  fontSize: DSTypography.sizeMd,
                ),
              ),
              style: FilledButton.styleFrom(
                minimumSize: const Size(
                  double.infinity,
                  DSSpacing.lg + DSSpacing.xl,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: DSStyles.cardRadius,
                ),
              ),
              onPressed: _isSearching ? null : _performSearch,
            ),

            // Search results / no-results feedback
            if (_searchResults.isNotEmpty) ...[
              _kSectionGap,
              ..._searchResults.map((delivery) {
                final isAdded = _groupItems.any(
                  (e) => e.barcode == delivery.barcode,
                );
                return BagsakanItemCard(
                  delivery: delivery.toDeliveryMap(),
                  isDark: isDark,
                  isAdded: isAdded,
                  onAdd: () => _onAddToBagsakan(delivery),
                  onRemove: () => _onRemoveFromBagsakan(delivery),
                );
              }),
            ] else if (_searchController.text.isNotEmpty && !_isSearching) ...[
              _kSectionGap,
              SizedBox(
                height: MediaQuery.of(context).size.height * 0.25,
                child: EmptyState(
                  message: 'bagsakan.no_results'.tr(),
                  icon: Icons.search_off_rounded,
                  iconColor: isDark
                      ? DSColors.labelSecondaryDark
                      : DSColors.labelSecondary,
                ),
              ),
            ],

            // ── GROUP ITEMS ────────────────────────────────────────────────
            _kSectionGap,
            DeliverySectionHeader(label: 'bagsakan.group_items'.tr()),
            _kInnerGap,
            if (_groupItems.isEmpty)
              SizedBox(
                height: MediaQuery.of(context).size.height * 0.3,
                child: EmptyState(
                  message: 'bagsakan.no_items'.tr(),
                  subMessage: 'bagsakan.no_items_hint'.tr(),
                  icon: Icons.inventory_2_outlined,
                  iconColor: DSColors.primary,
                ),
              )
            else
              ..._groupItems.map(
                (delivery) => BagsakanItemCard(
                  key: Key('group_item_${delivery.barcode}'),
                  delivery: delivery.toDeliveryMap(),
                  isDark: isDark,
                  isAdded: true,
                  onRemove: () => _onRemoveFromBagsakan(delivery),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
