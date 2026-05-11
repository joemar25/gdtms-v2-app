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
import 'package:fsi_courier_app/core/api/api_client.dart';
import 'package:fsi_courier_app/core/auth/auth_provider.dart';
import 'package:fsi_courier_app/core/database/database_providers.dart';
import 'package:fsi_courier_app/core/models/local_delivery.dart';
import 'package:fsi_courier_app/core/providers/connectivity_provider.dart';
import 'package:fsi_courier_app/core/providers/delivery_refresh_provider.dart';
import 'package:fsi_courier_app/core/providers/sync_provider.dart';
import 'package:fsi_courier_app/shared/helpers/api_payload_helper.dart';
import 'package:fsi_courier_app/shared/helpers/snackbar_helper.dart';
import 'package:fsi_courier_app/shared/widgets/ds_segmented_selector.dart';
import 'package:fsi_courier_app/shared/widgets/delivery_card.dart';
import 'package:fsi_courier_app/shared/widgets/offline_banner.dart';

enum BagsakanSearchMode { barcode, accountName }

// Matches delivery_update_screen.dart spacing constants.
const _kSectionGap = DSSpacing.hLg;
const _kInnerGap = DSSpacing.hSm;

class BagsakanFormScreen extends ConsumerStatefulWidget {
  final int? groupId;

  const BagsakanFormScreen({super.key, this.groupId});

  @override
  ConsumerState<BagsakanFormScreen> createState() => _BagsakanFormScreenState();
}

class _BagsakanFormScreenState extends ConsumerState<BagsakanFormScreen> {
  final _pageController = PageController(initialPage: 0);
  final _groupNameController = TextEditingController();
  final _groupDescriptionController = TextEditingController();
  final _searchController = TextEditingController();

  int _currentPage = 0;
  BagsakanSearchMode _searchMode = BagsakanSearchMode.barcode;
  bool _isSearching = false;
  bool _isSaving = false;
  bool _isLoadingGroup = false;
  List<LocalDelivery> _searchResults = [];
  final List<LocalDelivery> _groupItems = [];
  final Set<String> _initialBarcodes = {};
  String _initialName = '';
  String _initialDescription = '';

  @override
  void initState() {
    super.initState();
    if (widget.groupId != null) {
      _loadGroupData();
      _currentPage = 1; // Default to Deliveries in edit mode
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_pageController.hasClients) {
          _pageController.jumpToPage(1);
        }
      });
    }
  }

  Future<void> _loadGroupData() async {
    setState(() => _isLoadingGroup = true);
    try {
      final dao = ref.read(bagsakanDaoProvider);

      // 1. Initial local load for responsiveness
      final localGroup = await dao.getBagsakanGroup(widget.groupId!);
      if (localGroup != null && mounted) {
        setState(() {
          _groupNameController.text = localGroup['name'] as String? ?? '';
          _groupDescriptionController.text =
              localGroup['description'] as String? ?? '';
          _initialName = _groupNameController.text;
          _initialDescription = _groupDescriptionController.text;
        });
        final localItems = await dao.getBagsakanItems(widget.groupId!);
        if (mounted) {
          setState(() {
            _groupItems.clear();
            _groupItems.addAll(localItems);
            _initialBarcodes.clear();
            _initialBarcodes.addAll(localItems.map((e) => e.barcode));
          });
        }
      }

      // 2. Online Refresh (Priority)
      final isOnline =
          ref.read(connectionStatusProvider) == ConnectionStatus.online;
      if (isOnline) {
        try {
          final api = ref.read(apiClientProvider);
          final res = await api.get<Map<String, dynamic>>(
            'bagsakan/groups/${widget.groupId}',
            parser: parseApiMap,
          );
          if (res is ApiSuccess<Map<String, dynamic>>) {
            final groupData = res.data['data'];
            if (groupData is Map<String, dynamic>) {
              await dao.upsertGroupsFromSync([groupData]);

              // Reload from local DB after API sync
              final syncedGroup = await dao.getBagsakanGroup(widget.groupId!);
              final syncedItems = await dao.getBagsakanItems(widget.groupId!);

              if (mounted && syncedGroup != null) {
                setState(() {
                  _groupNameController.text =
                      syncedGroup['name'] as String? ?? '';
                  _groupDescriptionController.text =
                      syncedGroup['description'] as String? ?? '';
                  _initialName = _groupNameController.text;
                  _initialDescription = _groupDescriptionController.text;
                  _groupItems.clear();
                  _groupItems.addAll(syncedItems);
                  _initialBarcodes.clear();
                  _initialBarcodes.addAll(syncedItems.map((e) => e.barcode));
                });
              }
            }
          }
        } catch (e) {
          debugPrint('[BAGSAKAN] Online refresh failed: $e');
        }
      }
    } finally {
      if (mounted) setState(() => _isLoadingGroup = false);
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
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
      List<LocalDelivery> results = [];

      // Prefer server-qualified results when online so eligibility logic stays
      // aligned with backend rules (v3.8: eligible_for_bagsakan flag).
      final isOnline =
          ref.read(connectionStatusProvider) == ConnectionStatus.online;
      if (isOnline) {
        final apiResult = await ref
            .read(apiClientProvider)
            .get<Map<String, dynamic>>(
              '/deliveries/search',
              queryParameters: {
                'q': query,
                'eligible_for_bagsakan': 1,
                'per_page': 50,
              },
              parser: parseApiMap,
            );

        if (apiResult case ApiSuccess<Map<String, dynamic>>(:final data)) {
          final serverItems = listOfMapsFromKey(data, 'data');
          results = serverItems
              .map((e) => LocalDelivery.fromApiItem(e))
              .toList();
        }
      }

      // Offline or API fallback: local search remains available.
      if (results.isEmpty) {
        results = _searchMode == BagsakanSearchMode.barcode
            ? await ref.read(bagsakanDaoProvider).searchByBarcodeLike(query)
            : await ref.read(bagsakanDaoProvider).searchByAccountName(query);
      }

      final existingBarcodes = _groupItems.map((e) => e.barcode).toSet();
      final filtered = results
          .where((e) => !existingBarcodes.contains(e.barcode))
          .toList();

      if (mounted) {
        setState(() {
          _searchResults = filtered;
          _isSearching = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isSearching = false);
      rethrow;
    }
  }

  Future<void> _onSaveGroup() async {
    final name = _groupNameController.text.trim();
    if (name.isEmpty) {
      showErrorNotification(context, 'bagsakan.error_empty_name'.tr());
      _pageController.animateToPage(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      return;
    }
    if (_groupItems.isEmpty) {
      showErrorNotification(context, 'bagsakan.error_empty_items'.tr());
      _pageController.animateToPage(
        1,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      return;
    }

    final description = _groupDescriptionController.text.trim();
    setState(() => _isSaving = true);
    try {
      final dao = ref.read(bagsakanDaoProvider);
      final courierId = ref.read(authProvider).courier?['id']?.toString() ?? '';
      final int groupId;

      if (widget.groupId != null) {
        groupId = widget.groupId!;
        final currentBarcodes = _groupItems.map((e) => e.barcode).toSet();
        final hasMetadataChange =
            name != _initialName || description != _initialDescription;
        final hasItemChange =
            currentBarcodes.length != _initialBarcodes.length ||
            currentBarcodes.any((b) => !_initialBarcodes.contains(b));

        if (hasMetadataChange) {
          await dao.updateBagsakanGroup(
            groupId: groupId,
            name: name,
            description: description,
            courierId: courierId,
          );
        }

        if (hasItemChange) {
          // Clear current items to handle removals properly
          await dao.clearBagsakanGroup(groupId, courierId);
          await dao.assignToBagsakan(
            groupId: groupId,
            barcodes: currentBarcodes.toList(),
            courierId: courierId,
          );
        }

        if (!hasMetadataChange && !hasItemChange) {
          debugPrint('[BAGSAKAN] No changes detected, skipping save.');
          if (mounted) context.pop();
          return;
        }
      } else {
        groupId = await dao.createBagsakanGroup(
          name: name,
          description: description,
          courierId: courierId,
        );
        await dao.assignToBagsakan(
          groupId: groupId,
          barcodes: _groupItems.map((e) => e.barcode).toList(),
          courierId: courierId,
        );
      }
      await ref.read(syncManagerProvider.notifier).loadEntries();

      // When online, immediately flush queued Bagsakan operations.
      // We AWAIT this when online to ensure the authoritative server ID is
      // obtained and remapped locally before we return to the list screen,
      // satisfying the "Online Priority" and "Respect Sync Always" requirements.
      final isOnline =
          ref.read(connectionStatusProvider) == ConnectionStatus.online;
      if (isOnline) {
        try {
          await ref.read(syncManagerProvider.notifier).processQueue();
        } catch (e) {
          debugPrint('[BAGSAKAN] immediate sync failed: $e');
          // Non-blocking for the UI pop, the queue will retry automatically.
        }
      }

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
        setState(() => _isSaving = false);
        showErrorNotification(
          context,
          'bagsakan.error_saving'.tr(args: [e.toString()]),
        );
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

  Future<void> _handleScannedBarcode(String barcode) async {
    final dao = ref.read(bagsakanDaoProvider);
    final results = await dao.searchByBarcodeLike(barcode);
    if (results.isNotEmpty) {
      // Find exact match if possible
      final exactMatch = results.firstWhere(
        (e) => e.barcode.toUpperCase() == barcode.toUpperCase(),
        orElse: () => results.first,
      );
      _onAddToBagsakan(exactMatch);
    } else {
      if (mounted) {
        showErrorNotification(context, 'bagsakan.not_found'.tr());
      }
    }
  }

  Future<void> _onRemoveFromBagsakan(LocalDelivery delivery) async {
    final isExisting = _initialBarcodes.contains(delivery.barcode);

    bool confirmed = true;
    if (isExisting) {
      confirmed =
          await showDialog<bool>(
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
            ),
          ) ??
          false;
    }

    if (confirmed) {
      setState(() {
        _groupItems.removeWhere((e) => e.barcode == delivery.barcode);
      });
      if (mounted) {
        showSuccessNotification(
          context,
          'bagsakan.success_removed'.tr(
            args: [delivery.recipientName ?? delivery.barcode],
          ),
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
      floatingActionButton: _currentPage == 0
          ? DeliverySubmitFab(
              isLoading: false,
              onPressed: () {
                if (_groupNameController.text.trim().isEmpty) {
                  showErrorNotification(
                    context,
                    'bagsakan.error_empty_name'.tr(),
                  );
                  return;
                }
                _pageController.animateToPage(
                  1,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                );
              },
              label: 'common.next'.tr(),
              icon: Icons.arrow_forward_rounded,
            )
          : (_groupItems.isEmpty
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
                  )),
      appBar: AppHeaderBar(
        showBottomBorder: false,
        title: widget.groupId != null
            ? 'bagsakan.edit'.tr()
            : 'bagsakan.create'.tr(),
      ),
      body: LoadingOverlay(
        isLoading: _isSearching || _isSaving || _isLoadingGroup,
        child: Column(
          children: [
            // ── CONNECTION STATUS BANNER ────────────────────────────────────
            const ConnectionStatusBanner(isMinimal: true),
            // ── PREMIUM SUB-HEADER ──────────────────────────────────────────
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(DSSpacing.xl),
                  bottomRight: Radius.circular(DSSpacing.xl),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Theme.of(
                      context,
                    ).primaryColor.withValues(alpha: 0.3),
                    blurRadius: 15,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              padding: const EdgeInsets.fromLTRB(
                DSSpacing.md,
                0,
                DSSpacing.md,
                DSSpacing.lg,
              ),
              child: DSSegmentedSelector<int>(
                height: 64,
                selectedTextColor: Theme.of(context).primaryColor,
                unselectedTextColor: DSColors.white.withValues(alpha: 0.75),
                backgroundColor: DSColors.white.withValues(alpha: 0.15),
                showBorder: false,
                options: [
                  DSSegmentOption(
                    value: 0,
                    label: 'bagsakan.tab_info'.tr(),
                    icon: Icons.info_outline_rounded,
                    color: DSColors.white,
                  ),
                  DSSegmentOption(
                    value: 1,
                    label: 'bagsakan.tab_deliveries'.tr(),
                    icon: Icons.inventory_2_outlined,
                    color: DSColors.white,
                    badge: _groupItems.length,
                  ),
                ],
                selected: _currentPage,
                onChanged: (page) {
                  _pageController.animateToPage(
                    page,
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                  );
                },
              ),
            ),
            // ── CONTENT ─────────────────────────────────────────────────────
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (page) => setState(() => _currentPage = page),
                children: [_buildInfoPage(isDark), _buildItemsPage(isDark)],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoPage(bool isDark) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        DSSpacing.md,
        DSSpacing.md,
        DSSpacing.md,
        100,
      ),
      children: [
        DeliverySectionHeader(label: 'bagsakan.group_info_header'.tr()),
        _kInnerGap,
        DSInput(
          label: 'bagsakan.group_name'.tr(),
          hintText: 'bagsakan.group_name_hint'.tr(),
          controller: _groupNameController,
          autofocus: widget.groupId == null,
        ),
        DSInput(
          label: 'bagsakan.group_description'.tr(),
          hintText: 'bagsakan.group_description_hint'.tr(),
          controller: _groupDescriptionController,
        ),
      ],
    );
  }

  Widget _buildItemsPage(bool isDark) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        DSSpacing.md,
        DSSpacing.md,
        DSSpacing.md,
        100,
      ),
      children: [
        // ── FIND DELIVERY ──────────────────────────────────────────────
        DeliverySectionHeader(label: 'bagsakan.search_deliveries'.tr()),
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
                  onPressed: () async {
                    final barcode = await context.push<String>(
                      '/scan',
                      extra: {'mode': 'bagsakan'},
                    );
                    if (barcode != null && mounted) {
                      _handleScannedBarcode(barcode);
                    }
                  },
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
            shape: RoundedRectangleBorder(borderRadius: DSStyles.cardRadius),
          ),
          onPressed: _isSearching ? null : _performSearch,
        ),

        // Search results
        if (_searchResults.isNotEmpty) ...[
          _kSectionGap,
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: DeliverySectionHeader(
                  label: 'bagsakan.search_results_header'.tr(
                    args: [_searchResults.length.toString()],
                  ),
                ),
              ),
              TextButton.icon(
                icon: const Icon(Icons.add_task_rounded, size: DSIconSize.sm),
                label: Text(
                  'bagsakan.add_all'.tr(),
                  style: DSTypography.body(
                    color: DSColors.primary,
                  ).copyWith(fontWeight: FontWeight.bold),
                ),
                onPressed: () {
                  int added = 0;
                  for (final item in _searchResults) {
                    if (!_groupItems.any((e) => e.barcode == item.barcode)) {
                      _groupItems.add(item);
                      added++;
                    }
                  }
                  if (added > 0) {
                    setState(() {
                      _searchResults.clear();
                      _searchController.clear();
                    });
                    showSuccessNotification(
                      context,
                      'bagsakan.success_added_bulk'.tr(
                        args: [added.toString()],
                      ),
                    );
                  }
                },
              ),
            ],
          ),
          _kInnerGap,
          ..._searchResults.asMap().entries.map((entry) {
            final index = entry.key;
            final delivery = entry.value;
            final isAdded = _groupItems.any(
              (e) => e.barcode == delivery.barcode,
            );
            return DeliveryCard(
              delivery: delivery.toDeliveryMap(),
              onTap: null,
              isForAssigning: true,
              isInBagsakan: isAdded,
              onAddToBagsakanTap: () => _onAddToBagsakan(delivery),
              onRemoveFromBagsakanTap: () => _onRemoveFromBagsakan(delivery),
              compact: false,
            ).dsCardEntry(delay: DSAnimations.stagger(index));
          }),
        ] else if (_searchController.text.isNotEmpty && !_isSearching) ...[
          _kSectionGap,
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.2,
            child: EmptyState(
              message: 'bagsakan.no_results'.tr(),
              icon: Icons.search_off_rounded,
              iconColor: isDark ? DSColors.primaryDark : DSColors.primary,
            ),
          ),
        ],

        // ── PENDING ADDITIONS (Filtered summary) ──────────────────────────
        _buildPendingAdditions(isDark),
      ],
    );
  }

  Widget _buildPendingAdditions(bool isDark) {
    // Show all items if creating new group
    // Show only NEWLY added items if editing existing group
    final itemsToShow = widget.groupId == null
        ? _groupItems
        : _groupItems
              .where((e) => !_initialBarcodes.contains(e.barcode))
              .toList();

    if (itemsToShow.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _kSectionGap,
        DeliverySectionHeader(
          label: widget.groupId == null
              ? 'bagsakan.group_items_header'.tr()
              : 'bagsakan.new_items_header'.tr(),
        ),
        _kInnerGap,
        ...itemsToShow.asMap().entries.map((entry) {
          final index = entry.key;
          final delivery = entry.value;
          return Padding(
            padding: const EdgeInsets.only(bottom: DSSpacing.md),
            child: DeliveryCard(
              delivery: delivery.toDeliveryMap(),
              onTap: null,
              isForAssigning: true,
              isInBagsakan: true,
              onRemoveFromBagsakanTap: () => _onRemoveFromBagsakan(delivery),
              compact: false,
            ),
          ).dsCardEntry(delay: DSAnimations.stagger(index));
        }),
      ],
    );
  }
}
