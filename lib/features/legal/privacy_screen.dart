// DOCS: docs/development-standards.md
// DOCS: docs/features/legal.md — update that file when you edit this one.

// =============================================================================
// privacy_screen.dart
// =============================================================================
//
// Purpose:
//   Read-only viewer for the ITMS Privacy Policy.
//   Accessible from Profile → Legal section.
//
//   Content is fetched from GET /privacy-policy (backend-managed, so the
//   policy can be edited without an app release) and cached in
//   SharedPreferences so it still renders offline after the first load.
//
// Route: /privacy
// =============================================================================

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fsi_courier_app/core/api/api_client.dart';
import 'package:fsi_courier_app/shared/helpers/api_payload_helper.dart';
import 'package:fsi_courier_app/features/legal/terms_screen.dart'
    show LegalMarkdownText;
import 'package:fsi_courier_app/design_system/design_system.dart';
import 'package:fsi_courier_app/shared/widgets/app_header_bar.dart';

const _kPrivacyPolicyCacheKey = 'privacy_policy_cache_v1';

class _PrivacyPolicyData {
  const _PrivacyPolicyData({
    required this.title,
    required this.lastUpdated,
    required this.content,
  });

  final String title;
  final String lastUpdated;
  final String content;

  factory _PrivacyPolicyData.fromJson(Map<String, dynamic> json) {
    return _PrivacyPolicyData(
      title: (json['title'] as String?)?.trim().isNotEmpty == true
          ? json['title'] as String
          : 'Privacy Policy',
      lastUpdated: (json['last_updated'] as String?) ?? '',
      content: (json['content'] as String?) ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'title': title,
    'last_updated': lastUpdated,
    'content': content,
  };
}

class PrivacyScreen extends ConsumerStatefulWidget {
  const PrivacyScreen({super.key});

  @override
  ConsumerState<PrivacyScreen> createState() => _PrivacyScreenState();
}

class _PrivacyScreenState extends ConsumerState<PrivacyScreen> {
  _PrivacyPolicyData? _data;
  bool _loading = true;
  bool _showOfflineBanner = false;
  bool _isFetching = false;

  @override
  void initState() {
    super.initState();
    _loadContent();
  }

  Future<void> _loadContent() async {
    if (_isFetching) return;
    _isFetching = true;

    try {
      setState(() => _loading = _data == null);

      final prefs = await SharedPreferences.getInstance();
      if (_data == null) {
        final cachedRaw = prefs.getString(_kPrivacyPolicyCacheKey);
        if (cachedRaw != null) {
          try {
            final cached = _PrivacyPolicyData.fromJson(
              jsonDecode(cachedRaw) as Map<String, dynamic>,
            );
            // Paint the cached copy immediately; the network call below
            // refreshes it in the background.
            if (mounted) {
              setState(() {
                _data = cached;
                _loading = false;
              });
            }
          } catch (_) {
            // Corrupt cache entry — ignore and fall through to network fetch.
          }
        }
      }

      final result = await ref
          .read(apiClientProvider)
          .get<Map<String, dynamic>>('/privacy-policy', parser: parseApiMap);

      if (!mounted) return;

      if (result is ApiSuccess<Map<String, dynamic>>) {
        try {
          final body = mapFromKey(result.data, 'data');
          final fresh = _PrivacyPolicyData.fromJson(body);
          await prefs.setString(
            _kPrivacyPolicyCacheKey,
            jsonEncode(fresh.toJson()),
          );
          if (!mounted) return;
          setState(() {
            _data = fresh;
            _loading = false;
            _showOfflineBanner = false;
          });
        } catch (_) {
          // Unexpected response shape — keep whatever was already showing
          // (cache or nothing) instead of leaving the screen stuck loading.
          if (!mounted) return;
          setState(() {
            _loading = false;
            _showOfflineBanner = _data != null;
          });
        }
      } else {
        setState(() {
          _loading = false;
          _showOfflineBanner = _data != null;
        });
      }
    } finally {
      _isFetching = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? DSColors.scaffoldDark : DSColors.scaffoldLight;
    final cardColor = isDark ? DSColors.cardDark : DSColors.white;
    final muted = isDark ? DSColors.labelSecondaryDark : DSColors.labelTertiary;

    return Scaffold(
      backgroundColor: bg,
      appBar: const AppHeaderBar(title: 'Privacy Policy'),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _data == null
          ? _buildError()
          : RefreshIndicator(
              onRefresh: _loadContent,
              child: Column(
                children: [
                  if (_showOfflineBanner)
                    Padding(
                      padding: EdgeInsets.fromLTRB(
                        DSSpacing.md,
                        DSSpacing.md,
                        DSSpacing.md,
                        0,
                      ),
                      child: _buildStaleBanner(),
                    ),
                  Expanded(
                    child: Container(
                      margin: EdgeInsets.all(DSSpacing.md),
                      decoration: BoxDecoration(
                        color: cardColor,
                        borderRadius: DSStyles.cardRadius,
                      ),
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: EdgeInsets.all(DSSpacing.lg),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (_data!.lastUpdated.isNotEmpty) ...[
                              Text(
                                'Last updated: ${_data!.lastUpdated}',
                                style: DSTypography.caption(
                                  color: muted,
                                ).copyWith(fontSize: DSTypography.sizeSm),
                              ),
                              DSSpacing.hMd,
                            ],
                            LegalMarkdownText(
                              content: _data!.content,
                              isDark: isDark,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  /// Shown when a cached copy is on screen but the latest refresh failed
  /// (network or server error). Intentionally not gated by
  /// [ConnectionStatusBanner]'s own connectivity check — that check only
  /// probes the base API URL and would hide this message if, say,
  /// `/privacy-policy` itself 500s while the rest of the API is healthy.
  Widget _buildStaleBanner() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 14, vertical: DSSpacing.md),
      decoration: BoxDecoration(
        color: DSColors.warning.withValues(alpha: DSStyles.alphaSubtle),
        borderRadius: DSStyles.cardRadius,
        border: Border.all(
          color: DSColors.warning.withValues(alpha: DSStyles.alphaMuted),
          width: 1.2,
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.info_outline_rounded,
            size: DSIconSize.sm,
            color: DSColors.warning,
          ),
          DSSpacing.wSm,
          Expanded(
            child: Text(
              'Showing a saved copy — pull to refresh',
              style: DSTypography.label(color: DSColors.warning).copyWith(
                fontSize: DSTypography.sizeSm,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(DSSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.cloud_off_rounded,
              size: DSIconSize.xl,
              color: DSColors.labelTertiary,
            ),
            DSSpacing.hMd,
            Text(
              'Unable to load Privacy Policy. Connect to the internet and try again.',
              textAlign: TextAlign.center,
              style: DSTypography.body(color: DSColors.labelSecondary),
            ),
            DSSpacing.hMd,
            FilledButton(onPressed: _loadContent, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}
