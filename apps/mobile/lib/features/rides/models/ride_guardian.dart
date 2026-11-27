class RideGuardian {
  const RideGuardian({
    required this.id,
    required this.name,
    this.email,
    this.phone,
    this.profileImageUrl,
    this.addedAt,
  });

  final String id;
  final String name;
  final String? email;
  final String? phone;
  final String? profileImageUrl;
  final DateTime? addedAt;

  factory RideGuardian.fromJson(Map<String, dynamic> json) {
    final id = json['guardianId'] ?? json['id'];
    final name = json['name'];
    final addedAt = json['addedAt'];

    if (id is! String || id.isEmpty || name is! String || name.isEmpty) {
      throw const FormatException('Invalid ride guardian response.');
    }

    return RideGuardian(
      id: id,
      name: name,
      email: json['email'] as String?,
      phone: json['phone'] as String?,
      profileImageUrl: json['profileImageUrl'] as String?,
      addedAt: addedAt is String ? DateTime.tryParse(addedAt) : null,
    );
  }
}
