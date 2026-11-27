class RiderSafetySettings {
  const RiderSafetySettings({
    required this.id,
    required this.guardianId,
    required this.riderId,
    required this.speedAlertEnabled,
    required this.speedAlertCooldownSeconds,
    this.maxSpeedKmh,
  });

  final String id;
  final String guardianId;
  final String riderId;

  final double? maxSpeedKmh;
  final bool speedAlertEnabled;
  final int speedAlertCooldownSeconds;

  factory RiderSafetySettings.fromJson(Map<String, dynamic> json) {
    return RiderSafetySettings(
      id: json['id'] as String,
      guardianId: json['guardianId'] as String,
      riderId: json['riderId'] as String,
      maxSpeedKmh: _parseDouble(json['maxSpeedKmh']),
      speedAlertEnabled: json['speedAlertEnabled'] as bool? ?? true,
      speedAlertCooldownSeconds:
          json['speedAlertCooldownSeconds'] as int? ?? 60,
    );
  }

  static double? _parseDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }

    if (value is String) {
      return double.tryParse(value);
    }

    return null;
  }
}
