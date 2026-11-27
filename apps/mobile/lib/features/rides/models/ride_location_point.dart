class RideLocationPoint {
  const RideLocationPoint({
    required this.latitude,
    required this.longitude,
    required this.recordedAt,
    this.speedKmh,
    this.accuracyMeters,
  });

  final double latitude;
  final double longitude;
  final DateTime recordedAt;
  final double? speedKmh;
  final double? accuracyMeters;

  factory RideLocationPoint.fromJson(Map<String, dynamic> json) {
    final latitude = _toDouble(json['latitude']);
    final longitude = _toDouble(json['longitude']);
    final recordedAt = DateTime.tryParse(json['recordedAt']?.toString() ?? '');

    if (latitude == null ||
        longitude == null ||
        !latitude.isFinite ||
        !longitude.isFinite ||
        latitude < -90 ||
        latitude > 90 ||
        longitude < -180 ||
        longitude > 180 ||
        recordedAt == null) {
      throw const FormatException('Invalid ride route point.');
    }

    return RideLocationPoint(
      latitude: latitude,
      longitude: longitude,
      recordedAt: recordedAt,
      speedKmh: _toDouble(json['speedKmh']),
      accuracyMeters: _toDouble(json['accuracy']),
    );
  }

  static double? _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }
}
