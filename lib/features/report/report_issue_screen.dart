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
    ('low', 'Low', Colors.blue),
    ('medium', 'Medium', Colors.orange),
    ('high', 'High', Colors.red),
    ('critical', 'Critical', Colors.purple),
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
    final cardColor = isDark ? const Color(0xFF1C1C28) : Colors.white;
    final borderColor = isDark
        ? const Color(0xFF2A2A3A)
        : const Color(0xFFF0F0F5);

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF13131F)
          : const Color(0xFFF5F6FA),
      appBar: AppHeaderBar(title: 'Report an Issue'),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            // ── Info banner ────────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(14),
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
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? Colors.white70 : Colors.black87,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ── Summary / Subject ──────────────────────────────────────────
            _SectionLabel('Summary *', isDark: isDark),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: DSStyles.cardRadius,
                border: Border.all(color: borderColor),
              ),
              child: TextFormField(
                controller: _summaryController,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: isDark ? Colors.white : Colors.black87,
                ),
                decoration: InputDecoration(
                  hintText: 'Briefly describe the issue',
                  hintStyle: TextStyle(
                    color: isDark ? Colors.white38 : Colors.black38,
                    fontSize: 13,
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                ),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Required' : null,
              ),
            ),
            const SizedBox(height: 20),

            // ── Category ───────────────────────────────────────────────────
            _SectionLabel('Type', isDark: isDark),
            const SizedBox(height: 8),
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
                            horizontal: 12,
                            vertical: 10,
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
                                        : Colors.grey,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Icon(icon, size: 18, color: DSColors.primary),
                              const SizedBox(width: 8),
                              Text(
                                label,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: isDark ? Colors.white : Colors.black87,
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
            const SizedBox(height: 8),
            Row(
              children: _severities.map((s) {
                final (value, label, color) = s;
                final isSelected = _selectedSeverity == value;
                return Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedSeverity = value),
                    child: Container(
                      margin: EdgeInsets.only(
                        right: value != _severities.last.$1 ? 8 : 0,
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 10),
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
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: isSelected
                                ? Colors.white
                                : (isDark ? Colors.white54 : Colors.black54),
                          ),
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
            const SizedBox(height: 8),
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
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? Colors.white : Colors.black87,
                ),
                decoration: InputDecoration(
                  hintText:
                      'Describe what happened, what you expected, and any steps to reproduce…',
                  hintStyle: TextStyle(
                    color: isDark ? Colors.white38 : Colors.black38,
                    fontSize: 13,
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.all(14),
                  counterStyle: TextStyle(
                    color: isDark ? Colors.white38 : Colors.black38,
                    fontSize: 11,
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
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                subtitle: Text(
                  'Attaches recent error logs from this device to help the admin diagnose the issue.',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white54 : Colors.black54,
                    height: 1.4,
                  ),
                ),
                activeColor: DSColors.primary,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
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
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.grey.shade400,
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
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Submit Report',
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
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.8,
        color: isDark ? Colors.white54 : Colors.black45,
      ),
    );
  }
}
