import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AnnouncementsSection extends StatefulWidget {
  const AnnouncementsSection({super.key});

  @override
  State<AnnouncementsSection> createState() => _AnnouncementsSectionState();
}

class _AnnouncementsSectionState extends State<AnnouncementsSection> {
  bool _isStorageWarningVisible = false;
  bool _hasReportingReminder = false;

  @override
  void initState() {
    super.initState();
    _loadStorageWarningState();
  }

  Future<void> _loadStorageWarningState() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isStorageWarningVisible = prefs.getBool('showStorageWarning') ?? true;
    });
  }

  Future<void> _hideStorageWarning() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('showStorageWarning', false);
    setState(() {
      _isStorageWarningVisible = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    // determine if any announcements exist
    final bool hasAnnouncements =
        _isStorageWarningVisible || _hasReportingReminder;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Announcements",
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),

        if (hasAnnouncements) ...[
          // 🟧 Storage Warning
          if (_isStorageWarningVisible)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFE082),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.warning_amber_rounded,
                    color: Colors.black54,
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      "Storage Running Low!\nSome functions may not work, please delete unused files to free up your internal storage.",
                      style: TextStyle(fontSize: 13, color: Colors.black87),
                    ),
                  ),
                  GestureDetector(
                    onTap: _hideStorageWarning,
                    child: const Icon(
                      Icons.close,
                      size: 16,
                      color: Colors.black54,
                    ),
                  ),
                ],
              ),
            ),

          if (_isStorageWarningVisible) const SizedBox(height: 10),

          // 🟩 Reporting Reminder
          if (_hasReportingReminder)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF2E7D32),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text(
                "Upcoming Delivery Reporting Date\nPlease report by/before 09/27/2025, Thank You!",
                style: TextStyle(color: Colors.white, fontSize: 13),
              ),
            ),
        ] else
          // 🩶 Placeholder if no announcements
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: const Center(
              child: Text(
                "No announcements at this time.",
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.black54,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
