// DOCS: docs/features/legal.md — update that file when you edit this one.

// =============================================================================
// terms_screen.dart
// =============================================================================
//
// Purpose:
//   Displays the Terms & Conditions that couriers must accept before using
//   the app for the first time (or after a Terms version bump).
//
//   When [viewOnly] is false (default), an "Accept" button is shown pinned
//   to the bottom. It becomes active only after the user has scrolled to the
//   end. Acceptance is persisted via SharedPreferences key 'terms_accepted_version'.
//
//   When [viewOnly] is true (accessed via /terms?mode=view from the profile),
//   no accept button is shown.
//
// Routes:
//   /terms            — first-time acceptance gate
//   /terms?mode=view  — read-only (from Profile → Legal section)
// =============================================================================

import 'package:flutter/material.dart';
import 'package:fsi_courier_app/core/constants.dart';

import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fsi_courier_app/design_system/design_system.dart';

/// The version string stored in prefs when terms are accepted.
/// Bump this to force re-acceptance on the next Terms update.
const kTermsVersion = 'v1';

class TermsScreen extends StatefulWidget {
  const TermsScreen({super.key, this.viewOnly = false});

  final bool viewOnly;

  @override
  State<TermsScreen> createState() => _TermsScreenState();
}

class _TermsScreenState extends State<TermsScreen> {
  final ScrollController _scrollCtrl = ScrollController();
  bool _scrolledToEnd = false;
  bool _accepting = false;
  String _content = '';

  @override
  void initState() {
    super.initState();
    _loadContent();
    _scrollCtrl.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollCtrl.removeListener(_onScroll);
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadContent() async {
    final raw = await rootBundle.loadString(AppAssets.legalTerms);
    if (mounted) setState(() => _content = raw);
  }

  void _onScroll() {
    if (_scrolledToEnd) return;
    final pos = _scrollCtrl.position;
    if (pos.pixels >= pos.maxScrollExtent - 50) {
      setState(() => _scrolledToEnd = true);
    }
  }

  Future<void> _accept() async {
    setState(() => _accepting = true);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('terms_accepted_version', kTermsVersion);
    if (!mounted) return;
    setState(() => _accepting = false);
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/dashboard');
    }
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
          widget.viewOnly ? 'Terms & Conditions' : 'Terms & Conditions',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        iconTheme: IconThemeData(color: isDark ? Colors.white : Colors.black87),
        automaticallyImplyLeading: widget.viewOnly,
      ),
      body: Column(
        children: [
          Expanded(
            child: _content.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : Container(
                    margin: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: DSStyles.cardRadius,
                    ),
                    child: SingleChildScrollView(
                      controller: _scrollCtrl,
                      padding: const EdgeInsets.all(20),
                      child: LegalMarkdownText(
                        content: _content,
                        isDark: isDark,
                      ),
                    ),
                  ),
          ),
          if (!widget.viewOnly) ...[
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
              color: isDark ? const Color(0xFF1C1C28) : Colors.white,
              child: Column(
                children: [
                  if (!_scrolledToEnd)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Text(
                        'Scroll to the bottom to accept',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.white38 : Colors.black38,
                        ),
                      ),
                    ),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: (_scrolledToEnd && !_accepting)
                          ? _accept
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: DSColors.primary,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: isDark
                            ? Colors.grey.shade800
                            : Colors.grey.shade300,
                        disabledForegroundColor: isDark
                            ? Colors.white24
                            : Colors.black26,
                        shape: RoundedRectangleBorder(
                          borderRadius: DSStyles.cardRadius,
                        ),
                        elevation: 0,
                      ),
                      child: _accepting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              'I Accept the Terms & Conditions',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Simple markdown-like renderer ─────────────────────────────────────────────
// Renders h1/h2/h3 headings, bold, and paragraphs without external packages.
// Public so privacy_screen.dart can reuse it.

class LegalMarkdownText extends StatelessWidget {
  const LegalMarkdownText({
    super.key,
    required this.content,
    required this.isDark,
  });

  final String content;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final baseColor = isDark ? const Color(0xDEFFFFFF) : Colors.black87;
    final mutedColor = isDark ? const Color(0x8AFFFFFF) : Colors.black54;

    final lines = content.split('\n');
    final widgets = <Widget>[];

    for (final line in lines) {
      if (line.startsWith('# ')) {
        widgets.add(
          Text(
            line.substring(2),
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: baseColor,
            ),
          ),
        );
        widgets.add(const SizedBox(height: 6));
      } else if (line.startsWith('## ')) {
        widgets.add(const SizedBox(height: 12));
        widgets.add(
          Text(
            line.substring(3),
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: baseColor,
            ),
          ),
        );
        widgets.add(const SizedBox(height: 6));
      } else if (line.startsWith('### ')) {
        widgets.add(const SizedBox(height: 8));
        widgets.add(
          Text(
            line.substring(4),
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: baseColor,
            ),
          ),
        );
        widgets.add(const SizedBox(height: 4));
      } else if (line.startsWith('---')) {
        widgets.add(const SizedBox(height: 8));
        widgets.add(Divider(color: isDark ? Colors.white12 : Colors.black12));
        widgets.add(const SizedBox(height: 8));
      } else if (line.startsWith('- ')) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(left: 12, bottom: 3),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('• ', style: TextStyle(color: DSColors.primary)),
                Expanded(child: _buildInlineText(line.substring(2), baseColor)),
              ],
            ),
          ),
        );
      } else if (line.trim().isEmpty) {
        widgets.add(const SizedBox(height: 6));
      } else if (line.startsWith('*')) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 3),
            child: Text(
              line.replaceAll('*', '').trim(),
              style: TextStyle(
                fontSize: 12,
                color: mutedColor,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        );
      } else {
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: _buildInlineText(line, baseColor),
          ),
        );
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: widgets,
    );
  }

  Widget _buildInlineText(String line, Color baseColor) {
    // Handle **bold** inline formatting.
    final boldPattern = RegExp(r'\*\*(.+?)\*\*');
    if (!boldPattern.hasMatch(line)) {
      return Text(
        line,
        style: TextStyle(fontSize: 13.5, color: baseColor, height: 1.5),
      );
    }

    final spans = <TextSpan>[];
    int lastEnd = 0;
    for (final match in boldPattern.allMatches(line)) {
      if (match.start > lastEnd) {
        spans.add(TextSpan(text: line.substring(lastEnd, match.start)));
      }
      spans.add(
        TextSpan(
          text: match.group(1),
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      );
      lastEnd = match.end;
    }
    if (lastEnd < line.length) {
      spans.add(TextSpan(text: line.substring(lastEnd)));
    }

    return RichText(
      text: TextSpan(
        style: TextStyle(fontSize: 13.5, color: baseColor, height: 1.5),
        children: spans,
      ),
    );
  }
}
