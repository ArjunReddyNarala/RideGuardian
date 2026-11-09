class RideSummary {
  const RideSummary({
    required this.distanceKm,
    required this.averageSpeedKmh,
    required this.durationSeconds,
    required this.locationCount,
    this.maxSpeedKmh,
  });

  final double distanceKm;
  final double averageSpeedKmh;
  final double? maxSpeedKmh;
  final int durationSeconds;
  final int locationCount;

  factory RideSummary.fromJson(Map<String, dynamic> json) {
    return RideSummary(
      distanceKm: _toDouble(json['distanceKm']) ?? 0,
      averageSpeedKmh: _toDouble(json['averageSpeedKmh']) ?? 0,
      maxSpeedKmh: _toDouble(json['maxSpeedKmh']),
      durationSeconds: _toInt(json['durationSeconds']) ?? 0,
      locationCount: _toInt(json['locationCount']) ?? 0,
    );
  }

  static double? _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  static int? _toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }
}
