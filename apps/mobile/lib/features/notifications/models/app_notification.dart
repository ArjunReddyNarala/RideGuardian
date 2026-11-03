class AppNotification {
  const AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.isRead,
    required this.createdAt,
    this.safetyAlertId,
    this.readAt,
  });

  final String id;
  final String type;
  final String title;
  final String body;
  final bool isRead;
  final DateTime createdAt;
  final String? safetyAlertId;
  final DateTime? readAt;

  AppNotification copyWith({bool? isRead, DateTime? readAt}) => AppNotification(
    id: id,
    type: type,
    title: title,
    body: body,
    isRead: isRead ?? this.isRead,
    createdAt: createdAt,
    safetyAlertId: safetyAlertId,
    readAt: readAt ?? this.readAt,
  );

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final type = json['type'];
    final title = json['title'];
    final body = json['body'];
    final createdAt = DateTime.tryParse('${json['createdAt'] ?? ''}');

    if (id is! String ||
        type is! String ||
        title is! String ||
        body is! String ||
        createdAt == null) {
      throw const FormatException('Invalid notification response.');
    }

    return AppNotification(
      id: id,
      type: type,
      title: title,
      body: body,
      isRead: json['isRead'] == true,
      createdAt: createdAt,
      safetyAlertId: json['safetyAlertId'] as String?,
      readAt: json['readAt'] is String
          ? DateTime.tryParse(json['readAt'] as String)
          : null,
    );
  }
}
