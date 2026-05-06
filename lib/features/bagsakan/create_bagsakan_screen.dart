// DOCS: docs/development-standards.md
// DOCS: docs/features/bagsakan.md — update that file when you edit this one.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:go_router/go_router.dart';
import 'package:fsi_courier_app/design_system/design_system.dart';
import 'package:fsi_courier_app/shared/widgets/app_header_bar.dart';
import 'package:fsi_courier_app/shared/widgets/delivery_card.dart';
import 'package:fsi_courier_app/shared/widgets/empty_state.dart';
import 'package:fsi_courier_app/shared/widgets/loading_overlay.dart';
import 'package:fsi_courier_app/features/delivery/widgets/delivery_form_helpers.dart';
import 'package:fsi_courier_app/features/delivery/widgets/delivery_submit_fab.dart';
import 'package:fsi_courier_app/core/database/local_delivery_dao.dart';
import 'package:fsi_courier_app/core/models/local_delivery.dart';

enum BagsakanSearchMode { barcode, accountName }

// Matches delivery_update_screen.dart spacing constants.
const _kSectionGap = DSSpacing.hLg;
const _kInnerGap = DSSpacing.hSm;

class CreateBagsakanScreen extends ConsumerStatefulWidget {
  const CreateBagsakanScreen({super.key});

  @override
  ConsumerState<CreateBagsakanScreen> createState() =>
      _CreateBagsakanScreenState();
}

class _CreateBagsakanScreenState extends ConsumerState<CreateBagsakanScreen> {
  final _groupNameController = TextEditingController();
  final _groupDescriptionController = TextEditingController();
  final _searchController = TextEditingController();

  BagsakanSearchMode _searchMode = BagsakanSearchMode.barcode;
  bool _isSearching = false;
  final bool _isCreating = false;
  List<LocalDelivery> _searchResults = [];
  final List<LocalDelivery> _groupItems = [];

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
          ? await LocalDeliveryDao.instance.searchByBarcodeLike(query)
          : await LocalDeliveryDao.instance.searchByAccountName(query);
      if (mounted) setState(() => _searchResults = results);
    } finally {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  void _onCreateGroup() {
    // TODO: implement create group
  }

  void _onAddToBagsakan(LocalDelivery delivery) {
    // TODO: implement add to group
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: DeliverySubmitFab(
        isLoading: _isCreating,
        onPressed: _onCreateGroup,
        label: 'bagsakan.create_group'.tr(),
        icon: Icons.inventory_2_rounded,
      ),
      appBar: AppHeaderBar(title: 'bagsakan.create'.tr()),
      body: LoadingOverlay(
        isLoading: _isSearching || _isCreating,
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
              ..._searchResults.map(
                (delivery) => DeliveryCard(
                  delivery: delivery.toDeliveryMap(),
                  onTap: () {},
                  compact: false,
                  isForAssigning: true,
                  onAddToBagsakanTap: () => _onAddToBagsakan(delivery),
                ),
              ),
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
                (delivery) => DeliveryCard(
                  delivery: delivery.toDeliveryMap(),
                  onTap: () {},
                  compact: true,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
