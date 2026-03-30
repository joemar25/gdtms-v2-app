import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import 'package:fsi_courier_app/core/config.dart';

/// Uploads files directly to AWS S3 using AWS Signature Version 4.
///
/// Used when [kUseS3Upload] is true as an alternative to the API upload
/// endpoint. The returned URL can be used directly in the delivery PATCH
/// payload as a delivery_image or recipient_signature value.
class S3UploadService {
  S3UploadService._();

  static final _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 60),
    ),
  );

  /// Upload [bytes] directly to S3 at [s3Key].
  ///
  /// Returns `(url: objectUrl, error: null)` on success, or
  /// `(url: null, error: description)` on any failure.
  ///
  /// Retries up to 3 attempts on network/5xx errors (delays: 2 s, 5 s).
  /// Does NOT retry on 4xx — credential or permission errors won't self-heal.
  ///
  /// Example [s3Key]: `'deliveries/FSI8938A223/images/pod_1741523867.jpg'`
  static Future<({String? url, String? error})> upload({
    required Uint8List bytes,
    required String mimeType,
    required String s3Key,
  }) async {
    const maxAttempts = 3;
    const retryDelays = [Duration(seconds: 2), Duration(seconds: 5)];

    String? lastError;

    for (var attempt = 0; attempt < maxAttempts; attempt++) {
      if (attempt > 0) {
        final delay = retryDelays[attempt - 1];
        debugPrint('[S3] Retry $attempt/${ maxAttempts - 1} for $s3Key after ${delay.inSeconds}s…');
        await Future.delayed(delay);
      }

      try {
        final now = DateTime.now().toUtc();
        final dateStamp = _fmt8(now);  // YYYYMMDD
        final amzDate = _fmt15(now);   // YYYYMMDDTHHMMSSZ

        final host = '$awsBucket.s3.$awsRegion.amazonaws.com';
        final payloadHash = _sha256Hex(bytes);

        // Canonical URI: percent-encode each path segment; preserve '/' separator.
        final canonicalUri =
            '/${s3Key.split('/').map(Uri.encodeComponent).join('/')}';

        // Canonical headers must be sorted alphabetically by header name.
        final canonicalHeaders =
            'content-type:$mimeType\n'
            'host:$host\n'
            'x-amz-content-sha256:$payloadHash\n'
            'x-amz-date:$amzDate\n';
        const signedHeaders =
            'content-type;host;x-amz-content-sha256;x-amz-date';

        final canonicalRequest = [
          'PUT',
          canonicalUri,
          '', // no query string
          canonicalHeaders,
          signedHeaders,
          payloadHash,
        ].join('\n');

        // ── String to sign ──────────────────────────────────────────────────
        const algorithm = 'AWS4-HMAC-SHA256';
        final credScope = '$dateStamp/$awsRegion/s3/aws4_request';
        final stringToSign = [
          algorithm,
          amzDate,
          credScope,
          _sha256Hex(utf8.encode(canonicalRequest)),
        ].join('\n');

        // ── Derived signing key ─────────────────────────────────────────────
        final signingKey = _signingKey(
          awsSecretAccessKey,
          dateStamp,
          awsRegion,
          's3',
        );
        final signature = _hmacHex(signingKey, stringToSign);

        final authorization =
            '$algorithm Credential=$awsAccessKeyId/$credScope, '
            'SignedHeaders=$signedHeaders, Signature=$signature';

        // ── PUT to S3 ───────────────────────────────────────────────────────
        final objectUrl = 'https://$host/$s3Key';
        final response = await _dio.put<dynamic>(
          objectUrl,
          data: bytes,
          options: Options(
            contentType: mimeType,
            headers: {
              'x-amz-content-sha256': payloadHash,
              'x-amz-date': amzDate,
              'Authorization': authorization,
            },
            responseType: ResponseType.plain,
            validateStatus: (s) => s != null,  // let us handle all statuses
          ),
        );

        final status = response.statusCode ?? 0;
        if (status >= 200 && status < 300) {
          return (url: objectUrl, error: null);
        }

        // Non-2xx: log status + first 500 chars of body for diagnosis.
        final body = response.data?.toString() ?? '';
        final snippet = body.length > 500 ? body.substring(0, 500) : body;
        lastError = 'HTTP $status — $snippet';
        debugPrint('[S3] HTTP $status for $s3Key\n$snippet');

        // 4xx means wrong credentials / bucket config — retrying won't help.
        if (status >= 400 && status < 500) {
          return (url: null, error: lastError);
        }
        // 5xx — fall through to retry loop.
      } on DioException catch (e) {
        lastError = 'DioException(${e.type.name}): ${e.message}';
        debugPrint('[S3] Network error on attempt ${attempt + 1} for $s3Key — $lastError');
        // Fall through to retry loop.
      } catch (e) {
        lastError = e.toString();
        debugPrint('[S3] Unexpected error on attempt ${attempt + 1} for $s3Key — $lastError');
        // Unexpected errors are unlikely to self-heal — bail immediately.
        return (url: null, error: lastError);
      }
    }

    return (url: null, error: lastError ?? 'Upload failed after $maxAttempts attempts');
  }

  // ── AWS Signature V4 helpers ──────────────────────────────────────────────

  static String _fmt8(DateTime dt) =>
      dt.year.toString().padLeft(4, '0') +
      dt.month.toString().padLeft(2, '0') +
      dt.day.toString().padLeft(2, '0');

  static String _fmt15(DateTime dt) =>
      '${_fmt8(dt)}T'
      '${dt.hour.toString().padLeft(2, '0')}'
      '${dt.minute.toString().padLeft(2, '0')}'
      '${dt.second.toString().padLeft(2, '0')}Z';

  static String _sha256Hex(List<int> data) => sha256.convert(data).toString();

  static String _hmacHex(List<int> key, String data) =>
      Hmac(sha256, key).convert(utf8.encode(data)).toString();

  static List<int> _hmacBytes(List<int> key, String data) =>
      Hmac(sha256, key).convert(utf8.encode(data)).bytes;

  static List<int> _signingKey(
    String secret,
    String dateStamp,
    String region,
    String service,
  ) {
    final kDate = _hmacBytes(utf8.encode('AWS4$secret'), dateStamp);
    final kRegion = _hmacBytes(kDate, region);
    final kService = _hmacBytes(kRegion, service);
    return _hmacBytes(kService, 'aws4_request');
  }
}
