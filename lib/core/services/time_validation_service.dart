// DOCS: docs/time-enforcement.md

import 'dart:io' show HandshakeException;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:http_parser/http_parser.dart' show parseHttpDate;
import 'package:sentry_flutter/sentry_flutter.dart';

// ── Philippine Standard Time constant ────────────────────────────────────────
const _kPstOffset = Duration(hours: 8);

// HTTP timeout – give the server 5 seconds to respond.
const _kHttpTimeout = Duration(seconds: 5);

// How long to trust a cached "valid" result before rechecking.
const _kCacheTtl = Duration(minutes: 15);

// Lightweight endpoint that returns 204 + Date header with minimal overhead.
// Used by Android itself for connectivity checks — always available when online.
const _kTimeCheckUrl = 'https://clients3.google.com/generate_204';

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
/// ## Offline-safe behaviour
/// When [isOnline] is `false`, the NTP check is skipped and only the device
/// timezone is validated. If the HTTP request itself fails due to a network
/// error (e.g. corporate VPN, firewall), the same offline-safe path is taken —
/// the user is not blocked just because Google's endpoint is unreachable.
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

    // ── 2. If offline, trust the timezone check and return valid ─────────────
    // Couriers often work in areas with spotty signal. During a connectivity
    // gap we cannot reach the time server but the timezone is already confirmed
    // correct. We accept this and re-run the full check the moment they come
    // back online.
    if (!isOnline) {
      return _buildResult(
        valid: true,
        serverUtc: DateTime.now().toUtc(),
        deviceUtc: DateTime.now().toUtc(),
        skew: Duration.zero,
        deviceOffset: deviceOffset,
        message: 'Timezone OK (offline – skew check deferred until online).',
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
