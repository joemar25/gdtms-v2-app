import 'package:flutter/material.dart';

import 'package:fsi_courier_app/styles/color_styles.dart';

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
    final bgColor = isDark ? ColorStyles.grabCardElevatedDark : Colors.white;
    final borderColor = isDark ? Colors.white10 : Colors.grey.shade300;
    final hasFix = latitude != null && longitude != null;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: hasFix
              ? const Color(0xFF007A36).withValues(alpha: 0.4)
              : isLoading
              ? Colors.orange.withValues(alpha: 0.4)
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
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation(Color(0xFFFF6B00)),
                  ),
                )
              else
                Icon(
                  hasFix
                      ? Icons.my_location_rounded
                      : Icons.location_off_rounded,
                  size: 18,
                  color:
                      hasFix ? const Color(0xFF007A36) : Colors.grey.shade400,
                ),
              const SizedBox(width: 10),
              Expanded(
                child: isLoading
                    ? Text(
                        'Getting your location\u2026',
                        style: TextStyle(
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                          color: isDark
                              ? Colors.white54
                              : Colors.grey.shade600,
                        ),
                      )
                    : hasFix
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'GPS Coordinates Captured',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF007A36),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Lat: ${latitude!.toStringAsFixed(6)}  |  Lng: ${longitude!.toStringAsFixed(6)}',
                            style: TextStyle(
                              fontSize: 11,
                              fontFamily: 'monospace',
                              color: isDark
                                  ? Colors.white70
                                  : Colors.grey.shade700,
                            ),
                          ),
                          if (geoAccuracy != null)
                            Text(
                              'Accuracy: \u00b1${geoAccuracy!.toStringAsFixed(1)} m',
                              style: TextStyle(
                                fontSize: 10,
                                color: isDark
                                    ? Colors.white38
                                    : Colors.grey.shade500,
                              ),
                            ),
                        ],
                      )
                    : Text(
                        'Location not captured',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.white38 : Colors.grey.shade500,
                        ),
                      ),
              ),
              // Refresh icon: tap to recapture (shown only after a successful fix)
              if (hasFix && !isLoading)
                GestureDetector(
                  onTap: onCapture,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: Icon(
                      Icons.refresh_rounded,
                      size: 18,
                      color: Colors.grey.shade400,
                    ),
                  ),
                ),
            ],
          ),
          // Fallback button – only shown when auto-capture failed
          if (!hasFix && !isLoading) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.gps_fixed_rounded, size: 15),
                label: const Text(
                  'GET MY LOCATION',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: ColorStyles.grabOrange,
                  side: BorderSide(
                    color: ColorStyles.grabOrange.withValues(alpha: 0.6),
                  ),
                  minimumSize: const Size.fromHeight(40),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
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
