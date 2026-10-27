class GuardianInvitation {
  const GuardianInvitation({
    required this.id,
    required this.status,
    required this.relationshipType,
    this.inviterId,
    this.inviteeEmail,
    this.inviteePhone,
    this.token,
    this.expiresAt,
    this.acceptedAt,
    this.createdAt,
  });

  final String id;
  final String status;
  final String relationshipType;

  final String? inviterId;
  final String? inviteeEmail;
  final String? inviteePhone;

  // The backend may intentionally omit tokens from invitation listings.
  final String? token;

  final DateTime? expiresAt;
  final DateTime? acceptedAt;
  final DateTime? createdAt;

  String get contact => inviteeEmail ?? inviteePhone ?? 'Invitation';

  bool get isPending => status.toUpperCase() == 'PENDING';

  factory GuardianInvitation.fromJson(Map<String, dynamic> json) {
    return GuardianInvitation(
      id: json['id'] as String,
      status: json['status'] as String? ?? 'PENDING',
      relationshipType: json['relationshipType'] as String? ?? '',
      inviterId: json['inviterId'] as String?,
      inviteeEmail: json['inviteeEmail'] as String?,
      inviteePhone: json['inviteePhone'] as String?,
      token: json['token'] as String?,
      expiresAt: _parseDate(json['expiresAt']),
      acceptedAt: _parseDate(json['acceptedAt']),
      createdAt: _parseDate(json['createdAt']),
    );
  }

  static DateTime? _parseDate(dynamic value) {
    if (value is! String) return null;
    return DateTime.tryParse(value);
  }
}