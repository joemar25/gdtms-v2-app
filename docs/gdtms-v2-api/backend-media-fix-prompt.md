# Backend Task: Resolve Media Upload Errors (v3.3 Compliance)

The mobile application is encountering **400 Bad Request** and **422 Unprocessable Entity** errors during media synchronization. Additionally, the backend appears to be returning non-JSON (HTML) error pages in some cases, which causes parsing failures in the mobile client.

### 1. Fix `GET /api/mbl/media/upload-params` (400 Error)
The mobile app is now sending the following request:
`GET /api/mbl/media/upload-params?type=POD&barcode=FSID123`

**Requirements**:
- **Validation**: Ensure both `type` and `barcode` are accepted. `type` should support uppercase `POD`, `SELFIE`, `SIGNATURE`, `MAILPACK`.
- **Logic**: Generate pre-signed S3 parameters or a temporary upload URL for the specific delivery.
- **Error Handling**: If `barcode` is missing or invalid, return a **JSON** response with status 400:
  ```json
  { "success": false, "message": "Delivery ID is required", "code": "MISSING_DELIVERY_ID" }
  ```

### 2. Debug `POST /api/mbl/deliveries/{barcode}/media` (422 Error)
The legacy fallback is hitting the `mobile.deliveries.upload-media` route and returning **422**.

**Requirements**:
- **Validation**: Check the validation rules for this route. The mobile app sends:
  - `file`: (Multipart file bytes, usually `image/jpeg` or `image/png`)
  - `type`: (String, e.g., "POD", "SELFIE")
- **JSON Compliance**: Ensure that **all** validation failures return a JSON response (standard Laravel behavior for `Accept: application/json`). Do NOT return an HTML redirect or error page.
- **Example 422 Response**:
  ```json
  {
    "message": "The given data was invalid.",
    "errors": {
      "file": ["The file field is required."],
      "type": ["The selected type is invalid."]
    }
  }
  ```

### 3. Global JSON Requirement
Ensure that the `api/mbl` route group strictly returns JSON for all error states (404, 500, 401, etc.). The mobile app uses the `Accept: application/json` header, and the backend must respect it to avoid `FormatException` errors in the client.

### Summary of Mobile-Side Changes Made:
- Standardized on **uppercase types** (`POD`, `SELFIE`).
- Fixed a bug where `barcode` was being sent as `null`.
- Enforced relative paths to ensure the `api/mbl` prefix is respected.
- Enabled detailed error body logging in the mobile client for better debugging.
