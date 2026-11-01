class Ride {
  const Ride({
    required this.id,
    required this.rideCode,
    required this.riderId,
    required this.status,
    required this.startedAt,
    this.endedAt,
    this.createdAt,
  });

  final String id;
  final String rideCode;
  final String riderId;
  final String status;
  final DateTime startedAt;
  final DateTime? endedAt;
  final DateTime? createdAt;

  bool get isActive => status.toUpperCase() == 'ACTIVE';

  bool get isCompleted => status.toUpperCase() == 'COMPLETED';

  factory Ride.fromJson(Map<String, dynamic> json) {
    return Ride(
      id: _requiredString(json, 'id'),
      rideCode: _requiredString(json, 'rideCode'),
      riderId: _requiredString(json, 'riderId'),
      status: _requiredString(json, 'status'),
      startedAt: _requiredDate(json, 'startedAt'),
      endedAt: _optionalDate(json['endedAt']),
      createdAt: _optionalDate(json['createdAt']),
    );
  }

  static String _requiredString(
    Map<String, dynamic> json,
    String key,
  ) {
    final value = json[key];

    if (value is! String || value.trim().isEmpty) {
      throw FormatException(
        'Invalid or missing ride field: $key',
      );
    }

    return value;
  }

  static DateTime _requiredDate(
    Map<String, dynamic> json,
    String key,
  ) {
    final date = _optionalDate(json[key]);

    if (date == null) {
      throw FormatException(
        'Invalid or missing ride date: $key',
      );
    }

    return date;
  }

  static DateTime? _optionalDate(dynamic value) {
    if (value == null) return null;

    if (value is DateTime) return value;

    if (value is String) {
      return DateTime.tryParse(value);
    }

    return null;
  }
}