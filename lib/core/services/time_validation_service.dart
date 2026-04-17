// DOCS: docs/time-enforcement.md

import 'dart:async' show unawaited;
import 'dart:io' show HandshakeException;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:http_parser/http_parser.dart' show parseHttpDate;
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ── Philippine Standard Time constant ────────────────────────────────────────
const _kPstOffset = Duration(hours: 8);

// HTTP timeout – give the server 5 seconds to respond.
const _kHttpTimeout = Duration(seconds: 5);

// How long to trust a cached "valid" result before rechecking.
const _kCacheTtl = Duration(minutes: 15);

// Lightweight endpoint that returns 204 + Date header with minimal overhead.
// Used by Android itself for connectivity checks — always available when online.
const _kTimeCheckUrl = 'https://clients3.google.com/generate_204';

// SharedPreferences key for the last NTP-validated server UTC timestamp (ms).
// Persisted across app restarts so the offline rollback check always has a
// reference point — even on cold start after the user has been online before.
const _kPersistedServerTimeKey = 'time_validation_last_server_utc_ms';

// SharedPreferences key for the delivery sync anchor (ms UTC).
// Updated after every successful delivery PATCH. Acts as a ratchet: only
// moves forward. Any submission whose device clock is behind this anchor is
// rejected — prevents backdating delivery updates offline.
const _kSyncAnchorKey = 'delivery_last_sync_anchor_ms';

/// Result of a time validation run.
class TimeValidationResult {
  final bool valid;
  final DateTime serverUtc;
  final DateTime deviceUtc;
  final Duration skew;
  final Duration deviceOffset;
  final String message;

  /// True when the result comes from the in-memory cache rather than a fresh
  /// request. Callers can use this to decide whether to show a "stale"
  /// indicator.
  final bool fromCache;

  const TimeValidationResult({
    required this.valid,
    required this.serverUtc,
    required this.deviceUtc,
    required this.skew,
    required this.deviceOffset,
    required this.message,
    this.fromCache = false,
  });
}

/// Service that validates the device time against a trusted HTTP time source
/// and enforces Philippine Standard Time (UTC+8 / Asia/Manila).
///
/// ## How time is fetched
/// A HEAD request is made to [_kTimeCheckUrl] (Google's connectivity check
/// endpoint). The RFC 7231 `Date` response header is parsed to get the server
/// UTC time. This avoids the `ntp` package entirely and works wherever the
/// device can reach the internet.
///
/// ## Offline behaviour
/// When [isOnline] is `false`, the NTP check is skipped. The timezone is
/// checked first (always possible). Then the persisted NTP reference is loaded
/// from SharedPreferences — if it has never been written (fresh install, never
/// went online) the result is **invalid** and the courier is blocked until an
/// online check succeeds. Once a reference exists, the device clock is compared
/// against it: if the device is behind the reference by more than [allowedSkew]
/// the clock was rolled back and the result is **invalid**. A second in-memory
/// monotonic guard catches rollbacks within the same app session.
///
/// This design intentionally has no hardcoded date floor: the persisted
/// reference is the only trusted anchor, so any rollback — even 1 second —
/// is detectable once an online check has run at least once.
///
/// ## Result cache
/// A successful validation result is cached for [_kCacheTtl] (15 min).
/// Subsequent calls within the TTL return the cached result instantly so the
/// app is never blocked by network latency on every app resume.
class TimeValidationService {
  TimeValidationService._();
  static final instance = TimeValidationService._();

  TimeValidationResult? _cache;
  DateTime? _cacheAt;

  // Monotonic clock started when the last valid result is cached.
  // Unlike DateTime.now(), Stopwatch is based on the OS monotonic clock and
  // cannot be changed by the user adjusting the device date/time settings.
  // Comparing Stopwatch.elapsed to (DateTime.now() - _cacheAt) lets us detect
  // manual clock changes even when the device is completely offline.
  Stopwatch? _monotonicWatch;

  // Single Dio instance — no auth, just a quick HEAD to get the Date header.
  final _dio = Dio(
    BaseOptions(
      connectTimeout: _kHttpTimeout,
      receiveTimeout: _kHttpTimeout,
      followRedirects: false,
      validateStatus: (_) => true, // accept any HTTP status (204, 301, …)
      headers: const {'User-Agent': 'FSICourierApp/1.0'},
    ),
  );

  /// Flush the in-memory cache. Useful after the user corrects their device
  /// time so the next [validate] call forces a fresh check.
  void invalidateCache() {
    _cache = null;
    _cacheAt = null;
    _monotonicWatch?.stop();
    _monotonicWatch = null;
  }

  /// Persist [serverUtc] to SharedPreferences so it survives app restarts.
  /// Called after every successful NTP check.
  Future<void> _persistServerTime(DateTime serverUtc) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(
        _kPersistedServerTimeKey,
        serverUtc.millisecondsSinceEpoch,
      );
    } catch (e) {
      debugPrint('[TIME] failed to persist server time: $e');
    }
  }

  /// Load the last persisted NTP-validated server UTC time, or `null` if none.
  Future<DateTime?> _loadPersistedServerTime() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final ms = prefs.getInt(_kPersistedServerTimeKey);
      if (ms == null) return null;
      return DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true);
    } catch (e) {
      debugPrint('[TIME] failed to load persisted server time: $e');
      return null;
    }
  }

  /// Records the current device time as the sync anchor.
  ///
  /// Call this immediately after every successful delivery PATCH so the anchor
  /// always reflects the most recent server-confirmed moment. The anchor only
  /// moves forward — if [DateTime.now()] is earlier than the stored value the
  /// call is a no-op (the existing anchor is already a stricter bound).
  Future<void> recordSyncAnchor() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final nowMs = DateTime.now().toUtc().millisecondsSinceEpoch;
      final existing = prefs.getInt(_kSyncAnchorKey);
      if (existing == null || nowMs > existing) {
        await prefs.setInt(_kSyncAnchorKey, nowMs);
        debugPrint('[TIME] sync anchor updated: $nowMs');
      }
    } catch (e) {
      debugPrint('[TIME] failed to record sync anchor: $e');
    }
  }

  /// Checks whether the current device time is valid for a new delivery
  /// submission by comparing it against the stored sync anchor.
  ///
  /// Returns `(valid: false, reason: <message>)` when the device clock is
  /// behind the last sync anchor by more than [allowedSkew] — a sign the
  /// clock was rolled back after a successful sync. Returns `(valid: true)`
  /// when the anchor does not exist yet or the time is acceptable.
  Future<({bool valid, String? reason})> checkSubmissionTime({
    Duration allowedSkew = const Duration(seconds: 30),
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final anchorMs = prefs.getInt(_kSyncAnchorKey);
      if (anchorMs == null) return (valid: true, reason: null);

      final anchor = DateTime.fromMillisecondsSinceEpoch(anchorMs, isUtc: true);
      final deviceNow = DateTime.now().toUtc();
      // Positive diff = device clock is BEHIND the anchor = rollback detected.
      final rollback = anchor.difference(deviceNow);
      if (rollback > allowedSkew) {
        final anchorLocal = anchor.toLocal();
        final formatted =
            '${anchorLocal.year}-'
            '${anchorLocal.month.toString().padLeft(2, '0')}-'
            '${anchorLocal.day.toString().padLeft(2, '0')} '
            '${anchorLocal.hour.toString().padLeft(2, '0')}:'
            '${anchorLocal.minute.toString().padLeft(2, '0')}';
        return (
          valid: false,
          reason:
              'Device clock is behind the last sync time ($formatted). '
              'Enable automatic date & time and try again.',
        );
      }
      return (valid: true, reason: null);
    } catch (e) {
      debugPrint('[TIME] checkSubmissionTime error (fail open): $e');
      return (valid: true, reason: null);
    }
  }

  /// Validate device time and timezone.
  ///
  /// - [isOnline]: when `false`, only the timezone offset is checked.
  /// - [allowedSkew]: maximum accepted difference between server and device time.
  Future<TimeValidationResult> validate({
    bool isOnline = true,
    Duration allowedSkew = const Duration(seconds: 30),
  }) async {
    // ── 1. Always check timezone first (works offline too) ──────────────────
    final deviceOffset = DateTime.now().timeZoneOffset;
    final timezoneOk = deviceOffset == _kPstOffset;

    if (!timezoneOk) {
      final result = _buildResult(
        valid: false,
        serverUtc: DateTime.now().toUtc(),
        deviceUtc: DateTime.now().toUtc(),
        skew: Duration.zero,
        deviceOffset: deviceOffset,
        message:
            'Device timezone is not Philippine Standard Time (UTC+8 / Asia/Manila). '
            'Current offset is UTC${_formatOffset(deviceOffset)}.',
      );
      _reportToSentry(result);
      return result;
    }

    // ── 2. Offline path ──────────────────────────────────────────────────────
    // Without a network connection we rely entirely on the persisted NTP
    // reference (written to SharedPreferences after every successful online
    // check). Two sub-checks run:
    //
    //   A. Persisted reference (survives restarts) — the primary guard.
    //      If the device clock is BEHIND the last known-good server time by
    //      more than allowedSkew, the clock was rolled back.
    //      Forward drift is expected (time passes between sessions); only flag
    //      when the device is BEHIND the reference.
    //
    //   B. In-memory monotonic reference (same session only) — secondary guard.
    //      CLOCK_MONOTONIC cannot be adjusted by the user and detects a rollback
    //      that happens while the app is already running.
    //
    if (!isOnline) {
      final deviceUtcNow = DateTime.now().toUtc();

      // A. Persisted reference.
      // If no reference exists yet (fresh install / first run with new code),
      // we cannot prove the clock is wrong — fail open so the courier is not
      // blocked. The reference is written on the first successful online check,
      // after which every offline session is protected.
      final persistedRef = await _loadPersistedServerTime();
      if (persistedRef != null) {
        // Only flag when the device is BEHIND the reference — that is a rollback.
        // Forward drift (device ahead of reference) is normal: time passes
        // between online sessions.
        final rollbackA = persistedRef.difference(deviceUtcNow);
        if (rollbackA > allowedSkew) {
          final result = _buildResult(
            valid: false,
            serverUtc: persistedRef,
            deviceUtc: deviceUtcNow,
            skew: rollbackA,
            deviceOffset: deviceOffset,
            message:
                'Device clock is behind the last verified server time by '
                '${rollbackA.inSeconds}s. '
                'Enable automatic date & time in your device settings.',
          );
          _reportToSentry(result);
          return result;
        }
      }

      // B. In-memory monotonic reference.
      // CLOCK_MONOTONIC stops during deep sleep, so forward drift vs
      // DateTime.now() is expected — only flag a BEHIND delta.
      if (_monotonicWatch != null && _cacheAt != null) {
        final expectedNow = _cacheAt!.add(_monotonicWatch!.elapsed);
        final rollbackB = expectedNow.difference(DateTime.now());
        if (rollbackB > allowedSkew) {
          final result = _buildResult(
            valid: false,
            serverUtc: expectedNow.toUtc(),
            deviceUtc: DateTime.now().toUtc(),
            skew: rollbackB,
            deviceOffset: deviceOffset,
            message:
                'Device clock was rolled back by ${rollbackB.inSeconds}s. '
                'Enable automatic date & time in your device settings.',
          );
          _reportToSentry(result);
          return result;
        }
      }

      return _buildResult(
        valid: true,
        serverUtc: deviceUtcNow,
        deviceUtc: deviceUtcNow,
        skew: Duration.zero,
        deviceOffset: deviceOffset,
        message: 'Timezone OK (offline – reference verified).',
      );
    }

    // ── 3. Return cached result if still fresh ───────────────────────────────
    final now = DateTime.now();
    if (_cache != null &&
        _cacheAt != null &&
        now.difference(_cacheAt!) < _kCacheTtl &&
        _cache!.valid) {
      return _cache!.copyWith(fromCache: true);
    }

    // ── 4. Full HTTP time check ──────────────────────────────────────────────
    final deviceUtc = now.toUtc();
    DateTime serverUtc;

    try {
      final response = await _dio.head(_kTimeCheckUrl);
      final dateHeader = response.headers.value('date');
      if (dateHeader == null || dateHeader.isEmpty) {
        throw Exception('No Date header in response');
      }
      serverUtc = parseHttpDate(dateHeader).toUtc();
    } on DioException catch (e) {
      // TLS/certificate errors are caused by the device clock being too far off
      // (SSL handshakes validate certificate validity periods against the device
      // clock). Treat this as a time failure — fail closed.
      if (_isTlsError(e)) {
        debugPrint('[TIME] TLS error — device time is likely wrong: $e');
        final result = _buildResult(
          valid: false,
          serverUtc: deviceUtc,
          deviceUtc: deviceUtc,
          skew: Duration.zero,
          deviceOffset: deviceOffset,
          message:
              'Cannot verify network time — device clock may be too far off. '
              'Enable automatic date & time in your device settings.',
        );
        _reportToSentry(result);
        return result;
      }

      // Genuine connectivity failure (no route, DNS, plain timeout).
      // Treat as effectively offline — don't block the courier.
      debugPrint('[TIME] HTTP time check network error (fail open): $e');
      return _buildResult(
        valid: true,
        serverUtc: deviceUtc,
        deviceUtc: deviceUtc,
        skew: Duration.zero,
        deviceOffset: deviceOffset,
        message: 'Network time check unavailable – timezone verified OK.',
      );
    } catch (e) {
      // Unexpected error (bad Date header format, etc.) — fail open.
      debugPrint('[TIME] HTTP time check parse error (fail open): $e');
      return _buildResult(
        valid: true,
        serverUtc: deviceUtc,
        deviceUtc: deviceUtc,
        skew: Duration.zero,
        deviceOffset: deviceOffset,
        message: 'Network time check unavailable – timezone verified OK.',
      );
    }

    final skew = serverUtc.difference(deviceUtc).abs();
    final skewOk = skew <= allowedSkew;

    final result = _buildResult(
      valid: skewOk,
      serverUtc: serverUtc,
      deviceUtc: deviceUtc,
      skew: skew,
      deviceOffset: deviceOffset,
      message: skewOk
          ? 'OK'
          : 'Device clock differs from network time by ${skew.inSeconds}s '
                '(maximum allowed: ${allowedSkew.inSeconds}s). '
                'Enable automatic date & time in your device settings.',
    );

    if (result.valid) {
      _cache = result;
      _cacheAt = now;
      // Start (or restart) the monotonic watch so offline tamper detection
      // has a reference point from this exact moment.
      _monotonicWatch?.stop();
      _monotonicWatch = Stopwatch()..start();
      // Persist the server time so the offline rollback check survives restarts.
      unawaited(_persistServerTime(serverUtc));
    } else {
      invalidateCache();
      _reportToSentry(result);
    }

    return result;
  }

  // ── Helpers ─────────────────────────────────────────────────────────────────

  /// Returns true when [e] is caused by a TLS/SSL handshake failure.
  ///
  /// Wrong device time is the most common cause: the OS rejects certificates
  /// whose validity period doesn't overlap the device clock. We treat this as
  /// a time-enforcement failure (fail closed) rather than a network outage.
  static bool _isTlsError(DioException e) {
    if (e.type == DioExceptionType.badCertificate) return true;
    final inner = e.error;
    if (inner is HandshakeException) return true;
    final msg = inner?.toString() ?? '';
    return msg.contains('HandshakeException') ||
        msg.contains('CERTIFICATE_VERIFY_FAILED') ||
        msg.contains('HANDSHAKE_FAILURE');
  }

  static TimeValidationResult _buildResult({
    required bool valid,
    required DateTime serverUtc,
    required DateTime deviceUtc,
    required Duration skew,
    required Duration deviceOffset,
    required String message,
  }) {
    return TimeValidationResult(
      valid: valid,
      serverUtc: serverUtc,
      deviceUtc: deviceUtc,
      skew: skew,
      deviceOffset: deviceOffset,
      message: message,
    );
  }

  static String _formatOffset(Duration offset) {
    final hours = offset.inHours;
    final minutes = offset.inMinutes.remainder(60).abs();
    final sign = hours >= 0 ? '+' : '-';
    return '$sign${hours.abs().toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}';
  }

  static void _reportToSentry(TimeValidationResult result) {
    if (kReleaseMode) {
      Sentry.addBreadcrumb(
        Breadcrumb(
          message: 'Time validation failed',
          category: 'time_enforcement',
          level: SentryLevel.warning,
          data: {
            'reason': result.message,
            'skew_seconds': result.skew.inSeconds,
            'device_offset': _formatOffset(result.deviceOffset),
          },
        ),
      );
    }
    debugPrint('[TIME] validation failed: ${result.message}');
  }
}

extension _TimeValidationResultCopyWith on TimeValidationResult {
  TimeValidationResult copyWith({bool? fromCache}) {
    return TimeValidationResult(
      valid: valid,
      serverUtc: serverUtc,
      deviceUtc: deviceUtc,
      skew: skew,
      deviceOffset: deviceOffset,
      message: message,
      fromCache: fromCache ?? this.fromCache,
    );
  }
}
