import 'package:fsi_courier_app/core/models/failed_delivery_reason.dart';

/// Model for the remote application configuration.
///
/// Endpoint: `GET /api/mbl/app-config`
class AppConfig {
  final bool success;
  final ConfigData data;

  AppConfig({required this.success, required this.data});

  factory AppConfig.fromJson(Map<String, dynamic> json) {
    return AppConfig(
      success: json['success'] ?? false,
      data: ConfigData.fromJson(json['data'] ?? {}),
    );
  }
}

class ConfigData {
  final double minFreeStorageGb;
  final int syncRetentionDays;
  final List<String> supportedMediaExtensions;
  final List<String> supportedMediaTypes;
  final int maxBarcodesPerBatch;
  final int maxFailedDeliveryAttempts;
  final int tatDays;

  /// NEW v3.6 — Localized reasons if included in config.
  final List<FailedDeliveryReason> failedDeliveryReasons;

  ConfigData({
    required this.minFreeStorageGb,
    required this.syncRetentionDays,
    required this.supportedMediaExtensions,
    required this.supportedMediaTypes,
    required this.maxBarcodesPerBatch,
    required this.maxFailedDeliveryAttempts,
    required this.tatDays,
    this.failedDeliveryReasons = const [],
  });

  factory ConfigData.fromJson(Map<String, dynamic> json) {
    return ConfigData(
      minFreeStorageGb: (json['min_free_storage_gb'] ?? 1.0).toDouble(),
      syncRetentionDays: json['sync_retention_days'] ?? 30,
      supportedMediaExtensions: List<String>.from(
        json['supported_media_extensions'] ?? [],
      ),
      supportedMediaTypes: List<String>.from(
        json['supported_media_types'] ?? [],
      ),
      maxBarcodesPerBatch: json['max_barcodes_per_batch'] ?? 500,
      maxFailedDeliveryAttempts: json['max_failed_delivery_attempts'] ?? 3,
      tatDays: json['tat_days'] ?? 5,
      failedDeliveryReasons: (json['failed_delivery_reasons'] as List? ?? [])
          .map((e) => FailedDeliveryReason.fromJson(e))
          .toList(),
    );
  }
}
