import 'package:geolocator/geolocator.dart';

/// A device-reported speed and optional uncertainty, converted to km/h.
class GpsSpeedReading {
  const GpsSpeedReading({required this.speedKmh, required this.accuracyKmh});

  final double? speedKmh;
  final double? accuracyKmh;

  factory GpsSpeedReading.fromPosition(Position position) {
    return GpsSpeedReading.fromValues(
      speedKmh: position.hasSpeed ? position.speed * 3.6 : null,
      accuracyKmh: position.hasSpeedAccuracy
          ? position.speedAccuracy * 3.6
          : null,
    );
  }

  factory GpsSpeedReading.fromValues({
    required double? speedKmh,
    double? accuracyKmh,
  }) {
    final validAccuracy =
        accuracyKmh != null &&
            accuracyKmh.isFinite &&
            accuracyKmh >= 0 &&
            accuracyKmh <= 350
        ? accuracyKmh
        : null;
    final validSpeed =
        speedKmh != null &&
            speedKmh.isFinite &&
            speedKmh >= 0 &&
            speedKmh <= 350
        ? speedKmh
        : null;

    if (validSpeed == null) {
      return GpsSpeedReading(speedKmh: null, accuracyKmh: validAccuracy);
    }

    return GpsSpeedReading(
      // Preserve the device's current speed sample. GPS uncertainty is shown
      // separately so a valid low-speed reading is not rounded down to zero.
      speedKmh: validSpeed,
      accuracyKmh: validAccuracy,
    );
  }
}
