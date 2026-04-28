// DOCS: docs/features/report.md — update that file when you edit this one.

// =============================================================================
// report_issue_screen.dart
// =============================================================================
//
// Purpose:
//   Allows couriers to submit a bug report or feedback to the FSI admin.
//   Attaches recent local error logs by default so the admin has full context.
//
// Route: /report (authenticated only)
// Accessed from: ProfileScreen → "Report an Issue"
// =============================================================================

import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:fsi_courier_app/core/api/api_client.dart';
import 'package:fsi_courier_app/core/services/report_service.dart';
import 'package:fsi_courier_app/shared/helpers/snackbar_helper.dart';
import 'package:fsi_courier_app/shared/widgets/app_header_bar.dart';
import 'package:fsi_courier_app/design_system/design_system.dart';

class ReportIssueScreen extends ConsumerStatefulWidget {
  const ReportIssueScreen({super.key});

  @override
  ConsumerState<ReportIssueScreen> createState() => _ReportIssueScreenState();
}

class _ReportIssueScreenState extends ConsumerState<ReportIssueScreen> {
  final _formKey = GlobalKey<FormState>();
  final _summaryController = TextEditingController();
  final _messageController = TextEditingController();

  String _selectedType = 'bug';
  String _selectedSeverity = 'high';
  bool _includeLogs = true;
  bool _submitting = false;

  static const _types = [
    ('bug', 'Bug / App Error', Icons.bug_report_outlined),
    ('feedback', 'General Report', Icons.feedback_outlined),
  ];

  static const _severities = [
    ('low', 'Low', DSColors.accent),
    ('medium', 'Medium', DSColors.warning),
    ('high', 'High', DSColors.error),
    ('critical', 'Critical', DSColors.errorText),
  ];

  @override
  void dispose() {
    _summaryController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting) return;
    setState(() => _submitting = true);

    final result = await ref
        .read(reportServiceProvider)
        .submit(
          type: _selectedType,
          severity: _selectedSeverity,
          summary: _summaryController.text.trim(),
          userMessage: _messageController.text.trim().isEmpty
              ? null
              : _messageController.text.trim(),
          includeLogs: _includeLogs,
        );

    if (!mounted) return;
    setState(() => _submitting = false);

    switch (result) {
      case ApiSuccess<String>(:final data):
        final id = data.isNotEmpty ? ' (Ref: $data)' : '';
        showSuccessNotification(context, 'Report submitted successfully.$id');
        context.pop();
      case ApiNetworkError<String>():
        showErrorNotification(
          context,
          'No internet connection. Please try again when online.',
        );
      case ApiServerError<String>(:final message):
        showErrorNotification(context, message);
      case ApiValidationError<String>(:final errors):
        final first = errors.values.firstOrNull?.firstOrNull;
        showErrorNotification(
          context,
          first ?? 'Validation failed. Please check your input.',
        );
      case ApiBadRequest<String>(:final message):
        showErrorNotification(context, message);
      default:
        showErrorNotification(
          context,
          'Failed to submit report. Please try again.',
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? DSColors.cardDark : DSColors.cardLight;
    final borderColor = isDark
        ? DSColors.separatorDark
        : DSColors.separatorLight;

    return Scaffold(
      backgroundColor: isDark ? DSColors.scaffoldDark : DSColors.scaffoldLight,
      appBar: AppHeaderBar(title: 'Report an Issue'),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            DSSpacing.base,
            DSSpacing.base,
            DSSpacing.base,
            DSSpacing.xxl,
          ),
          children: [
            // ── Info banner ────────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(DSSpacing.md),
              decoration: BoxDecoration(
                color: DSColors.primary.withValues(alpha: DSStyles.alphaSoft),
                borderRadius: DSStyles.cardRadius,
                border: Border.all(
                  color: DSColors.primary.withValues(
                    alpha: DSStyles.alphaDarkShadow,
                  ),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    color: DSColors.primary,
                    size: 18,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Reports are sent directly to the FSI admin team. '
                      'Include as much detail as possible to help us resolve the issue faster.',
                      style: DSTypography.body(
                        fontSize: DSTypography.sizeMd,
                        color: isDark
                            ? DSColors.labelSecondaryDark
                            : DSColors.labelPrimary,
                      ).copyWith(height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
            DSSpacing.hLg,

            // ── Summary / Subject ──────────────────────────────────────────
            _SectionLabel('Summary *', isDark: isDark),
            DSSpacing.hSm,
            Container(
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: DSStyles.cardRadius,
                border: Border.all(color: borderColor),
              ),
              child: TextFormField(
                controller: _summaryController,
                style: DSTypography.body(
                  fontSize: DSTypography.sizeMd,
                  fontWeight: FontWeight.w600,
                  color: isDark
                      ? DSColors.labelPrimaryDark
                      : DSColors.labelPrimary,
                ),
                decoration: InputDecoration(
                  hintText: 'Briefly describe the issue',
                  hintStyle: DSTypography.body(
                    color: isDark
                        ? DSColors.labelTertiaryDark
                        : DSColors.labelTertiary,
                    fontSize: DSTypography.sizeMd,
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: DSSpacing.md,
                  ),
                ),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Required' : null,
              ),
            ),
            const SizedBox(height: 20),

            // ── Category ───────────────────────────────────────────────────
            _SectionLabel('Type', isDark: isDark),
            DSSpacing.hSm,
            Container(
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: DSStyles.cardRadius,
                border: Border.all(color: borderColor),
              ),
              child: Column(
                children: _types.asMap().entries.map((entry) {
                  final idx = entry.key;
                  final (value, label, icon) = entry.value;
                  return Column(
                    children: [
                      InkWell(
                        onTap: () => setState(() => _selectedType = value),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: DSSpacing.md,
                            vertical: DSSpacing.md,
                          ),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 24,
                                height: 24,
                                child: Checkbox(
                                  value: _selectedType == value,
                                  onChanged: (_) =>
                                      setState(() => _selectedType = value),
                                  activeColor: DSColors.primary,
                                  shape: const CircleBorder(),
                                  materialTapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                  side: BorderSide(
                                    color: _selectedType == value
                                        ? DSColors.primary
                                        : (isDark
                                              ? DSColors.labelTertiaryDark
                                              : DSColors.labelTertiary),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Icon(icon, size: 18, color: DSColors.primary),
                              const SizedBox(width: 8),
                              Text(
                                label,
                                style: DSTypography.body(
                                  fontSize: DSTypography.sizeMd,
                                  fontWeight: FontWeight.w600,
                                  color: isDark
                                      ? DSColors.labelPrimaryDark
                                      : DSColors.labelPrimary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (idx < _types.length - 1)
                        Divider(height: 1, color: borderColor),
                    ],
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 20),

            // ── Severity ───────────────────────────────────────────────────
            _SectionLabel('Severity', isDark: isDark),
            DSSpacing.hSm,
            Row(
              children: _severities.map((s) {
                final (value, label, color) = s;
                final isSelected = _selectedSeverity == value;
                return Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedSeverity = value),
                    child: Container(
                      margin: EdgeInsets.only(
                        right: value != _severities.last.$1 ? DSSpacing.sm : 0,
                      ),
                      padding: const EdgeInsets.symmetric(
                        vertical: DSSpacing.md,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected ? color : cardColor,
                        borderRadius: DSStyles.cardRadius,
                        border: Border.all(
                          color: isSelected ? color : borderColor,
                        ),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: color.withValues(
                                    alpha: DSStyles.alphaDarkShadow,
                                  ),
                                  blurRadius: 8,
                                  offset: const Offset(0, 4),
                                ),
                              ]
                            : null,
                      ),
                      child: Center(
                        child: Text(
                          label,
                          style: DSTypography.label(
                            color: isSelected
                                ? DSColors.white
                                : (isDark
                                      ? DSColors.labelSecondaryDark
                                      : DSColors.labelSecondary),
                          ).copyWith(fontSize: DSTypography.sizeSm),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),

            // ── Description ────────────────────────────────────────────────
            _SectionLabel('Description (optional)', isDark: isDark),
            DSSpacing.hSm,
            Container(
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: DSStyles.cardRadius,
                border: Border.all(color: borderColor),
              ),
              child: TextFormField(
                controller: _messageController,
                maxLines: 4,
                maxLength: 500,
                style: DSTypography.body(
                  fontSize: DSTypography.sizeMd,
                  color: isDark
                      ? DSColors.labelPrimaryDark
                      : DSColors.labelPrimary,
                ),
                decoration: InputDecoration(
                  hintText:
                      'Describe what happened, what you expected, and any steps to reproduce…',
                  hintStyle: DSTypography.body(
                    color: isDark
                        ? DSColors.labelTertiaryDark
                        : DSColors.labelTertiary,
                    fontSize: DSTypography.sizeMd,
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.all(DSSpacing.md),
                  counterStyle: DSTypography.caption(
                    color: isDark
                        ? DSColors.labelTertiaryDark
                        : DSColors.labelTertiary,
                    fontSize: DSTypography.sizeSm,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // ── Include logs ───────────────────────────────────────────────
            Container(
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: DSStyles.cardRadius,
                border: Border.all(color: borderColor),
              ),
              child: CheckboxListTile(
                value: _includeLogs,
                onChanged: (v) => setState(() => _includeLogs = v ?? true),
                title: Text(
                  'Include diagnostic logs',
                  style: DSTypography.body(
                    fontSize: DSTypography.sizeMd,
                    fontWeight: FontWeight.w600,
                    color: isDark
                        ? DSColors.labelPrimaryDark
                        : DSColors.labelPrimary,
                  ),
                ),
                subtitle: Text(
                  'Attaches recent error logs from this device to help the admin diagnose the issue.',
                  style: DSTypography.caption(
                    fontSize: DSTypography.sizeSm,
                    color: isDark
                        ? DSColors.labelSecondaryDark
                        : DSColors.labelSecondary,
                  ).copyWith(height: 1.4),
                ),
                activeColor: DSColors.primary,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: DSSpacing.md,
                  vertical: DSSpacing.xs,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: DSStyles.cardRadius,
                ),
              ),
            ),
            const SizedBox(height: 28),

            // ── Submit ─────────────────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _submitting ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: DSColors.primary,
                  foregroundColor: DSColors.white,
                  disabledBackgroundColor: isDark
                      ? DSColors.separatorDark
                      : DSColors.separatorLight,
                  shape: RoundedRectangleBorder(
                    borderRadius: DSStyles.cardRadius,
                  ),
                  elevation: 0,
                ),
                child: _submitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: DSColors.white,
                        ),
                      )
                    : Text(
                        'Submit Report',
                        style: DSTypography.button().copyWith(
                          fontSize: DSTypography.sizeMd,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text, {required this.isDark});
  final String text;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: DSTypography.label(
        color: isDark ? DSColors.labelSecondaryDark : DSColors.labelSecondary,
      ),
    );
  }
}
