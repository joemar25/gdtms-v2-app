// DOCS: docs/development-standards.md
// DOCS: docs/features/delivery.md — update that file when you edit this one.

import 'package:flutter/material.dart';
import 'package:fsi_courier_app/design_system/design_system.dart';

class DeliveryGeoLocationField extends StatelessWidget {
  const DeliveryGeoLocationField({
    super.key,
    required this.isLoading,
    required this.onCapture,
    this.latitude,
    this.longitude,
    this.geoAccuracy,
  });

  final bool isLoading;
  final VoidCallback onCapture;
  final double? latitude;
  final double? longitude;
  final double? geoAccuracy;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? DSColors.cardElevatedDark : DSColors.white;
    final borderColor = isDark
        ? DSColors.separatorDark
        : DSColors.separatorLight;
    final hasFix = latitude != null && longitude != null;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: DSSpacing.md,
        vertical: DSSpacing.md,
      ),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: DSStyles.cardRadius,
        border: Border.all(
          color: hasFix
              ? DSColors.success.withValues(alpha: DSStyles.alphaMuted)
              : isLoading
              ? DSColors.warning.withValues(alpha: DSStyles.alphaMuted)
              : borderColor,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Icon area: spinner while loading, status icon otherwise
              if (isLoading)
                const SizedBox(
                  width: DSIconSize.lg,
                  height: DSIconSize.lg,
                  child: CircularProgressIndicator(
                    strokeWidth: DSStyles.strokeWidth,
                    valueColor: AlwaysStoppedAnimation(DSColors.pending),
                  ),
                )
              else
                Icon(
                  hasFix
                      ? Icons.my_location_rounded
                      : Icons.location_off_rounded,
                  size: DSIconSize.md,
                  color: hasFix ? DSColors.success : DSColors.labelSecondary,
                ),
              DSSpacing.wMd,
              Expanded(
                child: isLoading
                    ? Text(
                        'Getting your location\u2026',
                        style: DSTypography.caption().copyWith(
                          fontSize: DSTypography.sizeSm,
                          fontStyle: FontStyle.italic,
                          color: isDark
                              ? DSColors.labelSecondaryDark
                              : DSColors.labelSecondary,
                        ),
                      )
                    : hasFix
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'GPS Coordinates Captured',
                            style: DSTypography.label().copyWith(
                              fontSize: DSTypography.sizeSm,
                              fontWeight: FontWeight.w700,
                              color: DSColors.success,
                            ),
                          ),
                          DSSpacing.hXs,
                          Text(
                            'Lat: ${latitude!.toStringAsFixed(6)}  |  Lng: ${longitude!.toStringAsFixed(6)}',
                            style: DSTypography.body().copyWith(
                              fontSize: DSTypography.sizeSm,
                              fontFamily: 'monospace',
                              color: isDark
                                  ? DSColors.labelSecondaryDark
                                  : DSColors.labelPrimary,
                            ),
                          ),
                          if (geoAccuracy != null)
                            Text(
                              'Accuracy: \u00b1${geoAccuracy!.toStringAsFixed(1)} m',
                              style: DSTypography.caption().copyWith(
                                fontSize: DSTypography.sizeXs,
                                color: isDark
                                    ? DSColors.labelTertiaryDark
                                    : DSColors.labelTertiary,
                              ),
                            ),
                        ],
                      )
                    : Text(
                        'Location not captured',
                        style: DSTypography.caption().copyWith(
                          fontSize: DSTypography.sizeSm,
                          color: isDark
                              ? DSColors.labelTertiaryDark
                              : DSColors.labelTertiary,
                        ),
                      ),
              ),
              // Refresh icon: tap to recapture (shown only after a successful fix)
              if (hasFix && !isLoading)
                GestureDetector(
                  onTap: onCapture,
                  child: Padding(
                    padding: EdgeInsets.only(left: DSSpacing.sm),
                    child: Icon(
                      Icons.refresh_rounded,
                      size: DSIconSize.md,
                      color: DSColors.labelSecondary,
                    ),
                  ),
                ),
            ],
          ),
          // Fallback button – only shown when auto-capture failed
          if (!hasFix && !isLoading) ...[
            DSSpacing.hMd,
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.gps_fixed_rounded, size: DSIconSize.sm),
                label: Text(
                  'GET MY LOCATION',
                  style: DSTypography.button().copyWith(
                    fontSize: DSTypography.sizeSm,
                    fontWeight: FontWeight.w700,
                    letterSpacing: DSTypography.lsLoose,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: DSColors.error,
                  side: BorderSide(
                    color: DSColors.error.withValues(
                      alpha: DSStyles.alphaMuted,
                    ),
                  ),
                  minimumSize: const Size.fromHeight(40),
                  shape: RoundedRectangleBorder(
                    borderRadius: DSStyles.cardRadius,
                  ),
                ),
                onPressed: onCapture,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
