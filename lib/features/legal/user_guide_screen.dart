// DOCS: docs/development-standards.md
// DOCS: docs/features/legal.md — update that file when you edit this one.

// =============================================================================
// user_guide_screen.dart
// =============================================================================
//
// Purpose:
//   Read-only viewer for the ITMS User Guide manual.
//   Accessible from Profile → Legal section.
//
// Route: /user-guide
// =============================================================================

import 'package:flutter/material.dart';
import 'package:fsi_courier_app/core/constants.dart';

import 'package:flutter/services.dart';
import 'package:easy_localization/easy_localization.dart';

import 'package:fsi_courier_app/features/legal/terms_screen.dart'
    show LegalMarkdownText;
import 'package:fsi_courier_app/design_system/design_system.dart';
import 'package:fsi_courier_app/shared/widgets/app_header_bar.dart';

class UserGuideScreen extends StatefulWidget {
  const UserGuideScreen({super.key});

  @override
  State<UserGuideScreen> createState() => _UserGuideScreenState();
}

class _UserGuideScreenState extends State<UserGuideScreen> {
  String _content = '';

  @override
  void initState() {
    super.initState();
    _loadContent();
  }

  Future<void> _loadContent() async {
    final raw = await rootBundle.loadString(AppAssets.userGuide);
    if (mounted) setState(() => _content = raw);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? DSColors.scaffoldDark : DSColors.scaffoldLight;
    final cardColor = isDark ? DSColors.cardDark : DSColors.white;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppHeaderBar(title: 'profile.legal.user_guide'.tr()),
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
