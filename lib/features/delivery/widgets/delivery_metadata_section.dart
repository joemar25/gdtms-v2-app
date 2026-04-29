// DOCS: docs/development-standards.md
// DOCS: docs/features/delivery.md — update that file when you edit this one.

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:fsi_courier_app/design_system/design_system.dart';
import 'package:fsi_courier_app/features/delivery/widgets/delivery_form_helpers.dart';
import 'package:fsi_courier_app/features/delivery/widgets/delivery_geo_location_field.dart';
import 'package:fsi_courier_app/features/delivery/widgets/delivery_update_screen_widgets.dart';

/// Bottom section of the [DeliveryUpdateScreen] showing read-only transaction 
/// metadata: the PST date/time and the current GPS coordinates.
class DeliveryUpdateMetadataSection extends StatelessWidget {
  const DeliveryUpdateMetadataSection({
    super.key,
    required this.latitude,
    required this.longitude,
    required this.geoAccuracy,
    required this.isGettingLocation,
    required this.onCaptureLocation,
  });

  final double? latitude;
  final double? longitude;
  final double? geoAccuracy;
  final bool isGettingLocation;
  final VoidCallback onCaptureLocation;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── TRANSACTION DATE ─────────────────────────────
        DeliverySectionHeader(
          label: 'delivery_update.header.transaction_date_pst'.tr(),
        ),
        DSSpacing.hSm, // _kInnerGap equivalent
        const DeliveryTransactionDateField(),

        DSSpacing.hLg, // _kSectionGap equivalent

        // ── GEO LOCATION ─────────────────────────────────
        DeliverySectionHeader(
          label: 'delivery_update.header.geo_location'.tr(),
        ),
        DSSpacing.hSm, // _kInnerGap equivalent
        DeliveryGeoLocationField(
          latitude: latitude,
          longitude: longitude,
          geoAccuracy: geoAccuracy,
          isLoading: isGettingLocation,
          onCapture: onCaptureLocation,
        ),
      ],
    );
  }
}
