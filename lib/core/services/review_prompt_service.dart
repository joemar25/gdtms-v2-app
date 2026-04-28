// DOCS: docs/development-standards.md
// DOCS: docs/core/services.md — update that file when you edit this one.

import 'package:flutter/foundation.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Triggers the native in-app review prompt at appropriate milestones.
///
/// Rules:
///  - Fires after the 10th completed delivery, then every 50 deliveries.
///  - Never fires within 30 days of the last prompt.
///  - Only fires in release builds.
class ReviewPromptService {
  ReviewPromptService._();
  static final ReviewPromptService instance = ReviewPromptService._();

  static const _keyDeliveryCount = '_review_delivery_count';
  static const _keyLastPromptMs = '_review_last_prompt_ms';
  static const _thirtyDaysMs = 30 * 24 * 60 * 60 * 1000;

  /// Call this after each successful delivery submission.
  Future<void> onDeliveryCompleted() async {
    if (kDebugMode) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final count = (prefs.getInt(_keyDeliveryCount) ?? 0) + 1;
      await prefs.setInt(_keyDeliveryCount, count);

      final shouldPrompt =
          count == 10 || (count > 10 && (count - 10) % 50 == 0);
      if (!shouldPrompt) return;

      final lastPromptMs = prefs.getInt(_keyLastPromptMs) ?? 0;
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      if (nowMs - lastPromptMs < _thirtyDaysMs) return;

      final inAppReview = InAppReview.instance;
      if (await inAppReview.isAvailable()) {
        await inAppReview.requestReview();
        await prefs.setInt(_keyLastPromptMs, nowMs);
      }
    } catch (_) {
      // Never surface review errors to the courier.
    }
  }
}
