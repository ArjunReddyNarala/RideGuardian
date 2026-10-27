class GuardianRelationship {
  const GuardianRelationship({
    required this.id,
    required this.guardianId,
    required this.riderId,
    required this.status,
    this.invitedAt,
    this.acceptedAt,
    this.revokedAt,
    this.guardian,
    this.rider,
  });

  final String id;
  final String guardianId;
  final String riderId;
  final String status;

  final DateTime? invitedAt;
  final DateTime? acceptedAt;
  final DateTime? revokedAt;

  final RelationshipUser? guardian;
  final RelationshipUser? rider;

  bool get isAccepted => status.toUpperCase() == 'ACCEPTED';

  bool get isRevoked => status.toUpperCase() == 'REVOKED';

  factory GuardianRelationship.fromJson(Map<String, dynamic> json) {
    return GuardianRelationship(
      id: json['id'] as String,
      guardianId: json['guardianId'] as String,
      riderId: json['riderId'] as String,
      status: json['status'] as String? ?? 'PENDING',
      invitedAt: _parseDate(json['invitedAt']),
      acceptedAt: _parseDate(json['acceptedAt']),
      revokedAt: _parseDate(json['revokedAt']),
      guardian: json['guardian'] is Map<String, dynamic>
          ? RelationshipUser.fromJson(
              json['guardian'] as Map<String, dynamic>,
            )
          : null,
      rider: json['rider'] is Map<String, dynamic>
          ? RelationshipUser.fromJson(
              json['rider'] as Map<String, dynamic>,
            )
          : null,
    );
  }

  static DateTime? _parseDate(dynamic value) {
    if (value is! String) return null;
    return DateTime.tryParse(value);
  }
}

class RelationshipUser {
  const RelationshipUser({
    required this.id,
    required this.name,
    this.email,
    this.phone,
    this.profileImageUrl,
  });

  final String id;
  final String name;
  final String? email;
  final String? phone;
  final String? profileImageUrl;

  String get contact => email ?? phone ?? '';

  factory RelationshipUser.fromJson(Map<String, dynamic> json) {
    return RelationshipUser(
      id: json['id'] as String,
      name: json['name'] as String? ?? 'Unknown user',
      email: json['email'] as String?,
      phone: json['phone'] as String?,
      profileImageUrl: json['profileImageUrl'] as String?,
    );
  }
}