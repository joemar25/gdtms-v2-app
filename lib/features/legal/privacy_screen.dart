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
import 'package:flutter/services.dart';

import 'package:fsi_courier_app/features/legal/terms_screen.dart'
    show LegalMarkdownText;

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
    final raw = await rootBundle.loadString('assets/legal/privacy.md');
    if (mounted) setState(() => _content = raw);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF13131F) : const Color(0xFFF5F6FA);
    final cardColor = isDark ? const Color(0xFF1C1C28) : Colors.white;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF1C1C28) : Colors.white,
        elevation: 0,
        title: Text(
          'Privacy Policy',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        iconTheme: IconThemeData(color: isDark ? Colors.white : Colors.black87),
      ),
      body: _content.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : Container(
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(14),
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: LegalMarkdownText(content: _content, isDark: isDark),
              ),
            ),
    );
  }
}
