class FavoriteGuardian {
  const FavoriteGuardian({
    required this.id,
    required this.name,
    required this.ridesSelected,
    this.profileImageUrl,
    this.lastSelectedAt,
    this.doNotDisturb = false,
  });

  final String id;
  final String name;
  final int ridesSelected;
  final String? profileImageUrl;
  final DateTime? lastSelectedAt;
  final bool doNotDisturb;

  factory FavoriteGuardian.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final name = json['name'];
    final ridesSelected = json['ridesSelected'];
    final profileImageUrl = json['profileImageUrl'];
    final lastSelectedAt = json['lastSelectedAt'];

    if (id is! String ||
        id.trim().isEmpty ||
        name is! String ||
        name.trim().isEmpty ||
        ridesSelected is! num ||
        !ridesSelected.isFinite ||
        ridesSelected < 1 ||
        ridesSelected > 10 ||
        (profileImageUrl != null && profileImageUrl is! String)) {
      throw const FormatException('Invalid favorite guardian response.');
    }

    return FavoriteGuardian(
      id: id,
      name: name,
      ridesSelected: ridesSelected.toInt(),
      profileImageUrl: profileImageUrl as String?,
      lastSelectedAt: lastSelectedAt is String
          ? DateTime.tryParse(lastSelectedAt)
          : lastSelectedAt is DateTime
          ? lastSelectedAt
          : null,
      doNotDisturb: json['doNotDisturb'] == true,
    );
  }
}
