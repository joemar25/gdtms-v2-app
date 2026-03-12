import 'package:flutter/material.dart';
import 'package:fsi_courier_app/styles/color_styles.dart';

class DispatchCard extends StatelessWidget {
  const DispatchCard({
    super.key,
    required this.maskedCode,
    required this.branchName,
    required this.volume,
    required this.reportingDate,
    required this.status,
    required this.isChecking,
    this.onTap,
  });

  final String maskedCode;
  final String branchName;
  final String volume;
  final String reportingDate;
  final String status;
  final bool isChecking;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E1E2E) : Colors.white;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedOpacity(
        opacity: isChecking ? 0.6 : 1.0,
        duration: const Duration(milliseconds: 200),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border(
              left: BorderSide(color: ColorStyles.grabOrange, width: 4),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      maskedCode,
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: ColorStyles.grabOrange.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      status,
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: ColorStyles.grabOrange,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 10,
                runSpacing: 6,
                children: [
                  InfoChip(icon: Icons.store_outlined, label: branchName),
                  InfoChip(
                    icon: Icons.inventory_2_outlined,
                    label: '$volume item${volume == '1' ? '' : 's'}',
                  ),
                  InfoChip(icon: Icons.event_outlined, label: reportingDate),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  if (isChecking) ...[
                    const SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation(
                          ColorStyles.grabOrange,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Checking eligibility\u2026',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ] else ...[
                    const Icon(
                      Icons.info_outline,
                      size: 13,
                      color: Colors.grey,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Tap to view and accept or reject',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                  const Spacer(),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: Colors.grey.shade400,
                    size: 20,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class InfoChip extends StatelessWidget {
  const InfoChip({super.key, required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: Colors.grey.shade500),
        const SizedBox(width: 3),
        Text(
          label,
          style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
        ),
      ],
    );
  }
}
