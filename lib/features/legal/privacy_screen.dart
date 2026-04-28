// DOCS: docs/features/legal.md — update that file when you edit this one.

// =============================================================================
// privacy_screen.dart
// =============================================================================
//
// Purpose:
//   Read-only viewer for the FSI Courier Privacy Policy.
//   Accessible from Profile → Legal section.
//
// Route: /privacy
// =============================================================================

import 'package:flutter/material.dart';
import 'package:fsi_courier_app/core/constants.dart';

import 'package:flutter/services.dart';

import 'package:fsi_courier_app/features/legal/terms_screen.dart'
    show LegalMarkdownText;
import 'package:fsi_courier_app/design_system/design_system.dart';

class PrivacyScreen extends StatefulWidget {
  const PrivacyScreen({super.key});

  @override
  State<PrivacyScreen> createState() => _PrivacyScreenState();
}

class _PrivacyScreenState extends State<PrivacyScreen> {
  String _content = '';

  @override
  void initState() {
    super.initState();
    _loadContent();
  }

  Future<void> _loadContent() async {
    final raw = await rootBundle.loadString(AppAssets.legalPrivacy);
    if (mounted) setState(() => _content = raw);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? DSColors.scaffoldDark : DSColors.scaffoldLight;
    final cardColor = isDark ? DSColors.cardDark : DSColors.white;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: isDark ? DSColors.cardDark : DSColors.white,
        elevation: DSStyles.elevationNone,
        title: Text(
          'Privacy Policy',
          style: TextStyle(
            fontSize: DSTypography.sizeMd,
            fontWeight: FontWeight.w700,
            color: isDark ? DSColors.white : DSColors.labelPrimary,
          ),
        ),
        iconTheme: IconThemeData(
          color: isDark ? DSColors.white : DSColors.labelPrimary,
        ),
      ),
      body: _content.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : Container(
              margin: EdgeInsets.all(DSSpacing.md),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: DSStyles.cardRadius,
              ),
              child: SingleChildScrollView(
                padding: EdgeInsets.all(DSSpacing.lg),
                child: LegalMarkdownText(content: _content, isDark: isDark),
              ),
            ),
    );
  }
}
