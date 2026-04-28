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
    final bg = isDark ? DSColors.scaffoldDark : DSColors.scaffoldLight;
    final cardColor = isDark ? DSColors.cardDark : DSColors.white;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: isDark ? DSColors.cardDark : DSColors.white,
        elevation: DSStyles.elevationNone,
        title: Text(
          widget.viewOnly ? 'Terms & Conditions' : 'Terms & Conditions',
          style:
              DSTypography.title(
                color: isDark ? DSColors.white : DSColors.labelPrimary,
              ).copyWith(
                fontSize: DSTypography.sizeMd,
                fontWeight: FontWeight.w700,
              ),
        ),
        iconTheme: IconThemeData(
          color: isDark ? DSColors.white : DSColors.labelPrimary,
        ),
        automaticallyImplyLeading: widget.viewOnly,
      ),
      body: Column(
        children: [
          Expanded(
            child: _content.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : Container(
                    margin: EdgeInsets.all(DSSpacing.md),
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: DSStyles.cardRadius,
                    ),
                    child: SingleChildScrollView(
                      controller: _scrollCtrl,
                      padding: EdgeInsets.all(DSSpacing.lg),
                      child: LegalMarkdownText(
                        content: _content,
                        isDark: isDark,
                      ),
                    ),
                  ),
          ),
          if (!widget.viewOnly) ...[
            Container(
              padding: EdgeInsets.fromLTRB(
                DSSpacing.md,
                DSSpacing.sm,
                DSSpacing.md,
                DSSpacing.xl,
              ),
              color: isDark ? DSColors.cardDark : DSColors.white,
              child: Column(
                children: [
                  if (!_scrolledToEnd)
                    Padding(
                      padding: EdgeInsets.only(bottom: DSSpacing.sm),
                      child: Text(
                        'Scroll to the bottom to accept',
                        style: DSTypography.caption(
                          color: isDark
                              ? DSColors.white.withValues(
                                  alpha: DSStyles.alphaMuted,
                                )
                              : DSColors.labelTertiary,
                        ).copyWith(fontSize: DSTypography.sizeSm),
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
                        foregroundColor: DSColors.white,
                        disabledBackgroundColor: isDark
                            ? DSColors.separatorDark
                            : DSColors.separatorLight,
                        disabledForegroundColor: isDark
                            ? DSColors.white.withValues(
                                alpha: DSStyles.alphaMuted,
                              )
                            : DSColors.labelTertiary.withValues(
                                alpha: DSStyles.alphaMuted,
                              ),
                        shape: RoundedRectangleBorder(
                          borderRadius: DSStyles.cardRadius,
                        ),
                        elevation: DSStyles.elevationNone,
                      ),
                      child: _accepting
                          ? const SizedBox(
                              width: DSIconSize.xl,
                              height: DSIconSize.xl,
                              child: CircularProgressIndicator(
                                strokeWidth: DSStyles.strokeWidth,
                                color: DSColors.white,
                              ),
                            )
                          : Text(
                              'I Accept the Terms & Conditions',
                              style: DSTypography.button(color: DSColors.white),
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
    final baseColor = isDark
        ? DSColors.labelPrimaryDark
        : DSColors.labelPrimary;
    final mutedColor = isDark
        ? DSColors.labelSecondaryDark
        : DSColors.labelSecondary;

    final lines = content.split('\n');
    final widgets = <Widget>[];

    for (final line in lines) {
      if (line.startsWith('# ')) {
        widgets.add(
          Text(
            line.substring(2),
            style: DSTypography.heading(color: baseColor).copyWith(
              fontSize: DSTypography.sizeLg,
              fontWeight: FontWeight.w800,
            ),
          ),
        );
        widgets.add(DSSpacing.hSm);
      } else if (line.startsWith('## ')) {
        widgets.add(DSSpacing.hMd);
        widgets.add(
          Text(
            line.substring(3),
            style: DSTypography.title(color: baseColor).copyWith(
              fontSize: DSTypography.sizeMd,
              fontWeight: FontWeight.w700,
            ),
          ),
        );
        widgets.add(DSSpacing.hSm);
      } else if (line.startsWith('### ')) {
        widgets.add(DSSpacing.hSm);
        widgets.add(
          Text(
            line.substring(4),
            style: DSTypography.subTitle(color: baseColor).copyWith(
              fontSize: DSTypography.sizeMd,
              fontWeight: FontWeight.w600,
            ),
          ),
        );
        widgets.add(DSSpacing.hXs);
      } else if (line.startsWith('---')) {
        widgets.add(DSSpacing.hSm);
        widgets.add(
          Divider(
            color: isDark
                ? DSColors.white.withValues(alpha: DSStyles.alphaSubtle)
                : DSColors.separatorLight,
          ),
        );
        widgets.add(DSSpacing.hSm);
      } else if (line.startsWith('- ')) {
        widgets.add(
          Padding(
            padding: EdgeInsets.only(left: DSSpacing.sm, bottom: DSSpacing.xs),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('• ', style: DSTypography.body(color: DSColors.primary)),
                Expanded(child: _buildInlineText(line.substring(2), baseColor)),
              ],
            ),
          ),
        );
      } else if (line.trim().isEmpty) {
        widgets.add(DSSpacing.hSm);
      } else if (line.startsWith('*')) {
        widgets.add(
          Padding(
            padding: EdgeInsets.only(bottom: DSSpacing.xs),
            child: Text(
              line.replaceAll('*', '').trim(),
              style: DSTypography.caption(color: mutedColor).copyWith(
                fontSize: DSTypography.sizeSm,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        );
      } else {
        widgets.add(
          Padding(
            padding: EdgeInsets.only(bottom: DSSpacing.xs),
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
        style: DSTypography.body(color: baseColor).copyWith(
          fontSize: DSTypography.sizeMd,
          height: DSStyles.heightRelaxed,
        ),
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
          style: DSTypography.body().copyWith(fontWeight: FontWeight.w700),
        ),
      );
      lastEnd = match.end;
    }
    if (lastEnd < line.length) {
      spans.add(TextSpan(text: line.substring(lastEnd)));
    }

    return RichText(
      text: TextSpan(
        style: DSTypography.body(
          color: baseColor,
        ).copyWith(fontSize: 13.5, height: DSStyles.heightRelaxed),
        children: spans,
      ),
    );
  }
}
