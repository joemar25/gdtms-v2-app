import 'package:flutter/material.dart';

enum StatusNoticeType {
  osa,
  rts,
  deliveredToday,
}

class StatusNoticeBanner extends StatelessWidget {
  const StatusNoticeBanner({
    super.key,
    required this.type,
  });

  final StatusNoticeType type;

  @override
  Widget build(BuildContext context) {
    final (bgColor, borderColor, iconColor, textColor, icon, label) =
        _getStyles();

    return Container(
      margin: const EdgeInsets.only(top: 12, bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor, width: 1.2),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: iconColor),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: textColor,
                letterSpacing: 0.3,
              ),
            ),
          ),
        ],
      ),
    );
  }

  (Color, Color, Color, Color, IconData, String) _getStyles() {
    return switch (type) {
      StatusNoticeType.osa => (
          Colors.amber.shade50,
          Colors.amber.shade300,
          Colors.amber.shade800,
          Colors.amber.shade900,
          Icons.info_outline_rounded,
          'PENDING ADMIN REVIEW — NO ACTION REQUIRED'
        ),
      StatusNoticeType.rts => (
          Colors.red.shade50,
          Colors.red.shade300,
          Colors.red.shade800,
          Colors.red.shade900,
          Icons.assignment_return_outlined,
          "SHOWING RTS ITEMS"
        ),
      StatusNoticeType.deliveredToday => (
          Colors.green.shade50,
          Colors.green.shade300,
          Colors.green.shade800,
          Colors.green.shade900,
          Icons.check_circle_outline_rounded,
          "SHOWING YOU'RE DELIVERED ITEMS"
        ),
    };
  }
}
