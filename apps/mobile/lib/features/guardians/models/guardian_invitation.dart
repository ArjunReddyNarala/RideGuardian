class GuardianInvitation {
  const GuardianInvitation({
    required this.id,
    required this.status,
    required this.relationshipType,
    this.inviterId,
    this.inviterName,
    this.inviterEmail,
    this.inviterPhone,
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
  final String? inviterName;
  final String? inviterEmail;
  final String? inviterPhone;

  final String? inviteeEmail;
  final String? inviteePhone;

  final String? token;

  final DateTime? expiresAt;
  final DateTime? acceptedAt;
  final DateTime? createdAt;

  bool get isPending => status.toUpperCase() == 'PENDING';

  String get senderContact =>
      inviterEmail ??
      inviterPhone ??
      inviterName ??
      'Sender details unavailable';

  String get recipientContact =>
      inviteeEmail ?? inviteePhone ?? 'Recipient details unavailable';

  factory GuardianInvitation.fromJson(Map<String, dynamic> json) {
    final inviter = json['inviter'];

    final inviterData = inviter is Map
        ? Map<String, dynamic>.from(inviter)
        : <String, dynamic>{};

    return GuardianInvitation(
      id: json['id'] as String,
      status: json['status'] as String? ?? 'PENDING',
      relationshipType: json['relationshipType'] as String? ?? '',
      inviterId: json['inviterId'] as String? ?? inviterData['id'] as String?,
      inviterName: inviterData['name'] as String?,
      inviterEmail: inviterData['email'] as String?,
      inviterPhone: inviterData['phone'] as String?,
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
