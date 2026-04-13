<!--
  MAINTENANCE NOTICE
  ══════════════════════════════════════════════════════════════════════════════
  API SOURCE OF TRUTH: docs/gdtms-v2-api/Courier-Mobile-API.postman_collection.json
  See docs/gdtms-v2-api/README.md for the full endpoint reference and changelog.

  When an endpoint changes: update the Postman collection FIRST, then
  docs/gdtms-v2-api/README.md, then this file, then the app code.

  This file documents the Dart client layer:
    lib/core/api/api_client.dart
    lib/core/api/api_result.dart
    lib/core/api/s3_upload_service.dart

  Update this document whenever you change any of those files.
  Each of those files carries a header comment: "DOCS: docs/core/api.md"
  ══════════════════════════════════════════════════════════════════════════════
-->

# Core — API

## Files

| File | Role |
|------|------|
| `lib/core/api/api_client.dart` | Dio HTTP client wrapper with auth injection |
| `lib/core/api/api_result.dart` | Typed result/error model for all API calls |
| `lib/core/api/s3_upload_service.dart` | Direct S3 upload via AWS Signature V4 |

---

## `api_client.dart`

Wraps Dio with:

- **Auth injection**: adds `Authorization: Bearer <token>` to every request via interceptor.
- **Error mapping**: maps HTTP status codes to typed `ApiResult` errors (e.g. `ApiConflict`, `ApiServerError`, `ApiUnauthorized`).
- **Base URL**: read from `lib/core/config.dart` (`apiBaseUrl`), injected at build via `--dart-define=API_BASE_URL`.

### Error types (from `api_result.dart`)

| Type | HTTP status | Meaning |
|------|-------------|---------|
| `ApiSuccess` | 2xx | Payload is in `.data` |
| `ApiUnauthorized` | 401 | Token expired or invalid — triggers logout |
| `ApiConflict` | 409 | Business rule conflict (e.g. duplicate payout) |
| `ApiServerError` | 5xx | Server-side failure |
| `ApiNetworkError` | — | No connectivity or timeout |
| `ApiValidationError` | 422 | Field-level validation from server |

### Usage pattern

```dart
final result = await apiClient.get('/some-endpoint');
result.when(
  success: (data) { ... },
  error: (err) { ... },
);
```

---

## `s3_upload_service.dart`

Used only when `USE_S3_UPLOAD=true` dart-define is set.

- Signs the PUT request with AWS Signature V4 using `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY`.
- S3 key pattern: `deliveries/{barcode}/images/{type}_{timestamp}.{ext}`
- Returns the S3 object URL on success; caller includes it in the delivery PATCH payload.
- **Offline**: images are stored as base64 in `delivery_update_queue` under `_pending_media`. `SyncManager` handles upload on reconnect.

---

## Media upload modes

| Mode | `USE_S3_UPLOAD` | Flow |
|------|----------------|------|
| API (default) | `false` | POST `{ file_data, mime_type, type }` to `/deliveries/{barcode}/media` |
| S3 direct | `true` | PUT signed request directly to S3; URL included in PATCH |
