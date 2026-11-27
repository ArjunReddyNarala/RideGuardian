import '../../../core/constants/api_urls.dart';
import '../../../core/network/api_client.dart';
import '../models/app_notification.dart';

class NotificationsApiService {
  const NotificationsApiService(this._apiClient);

  final ApiClient _apiClient;

  Future<List<AppNotification>> getNotifications({int limit = 50}) async {
    final response = await _apiClient.get(
      ApiUrls.notifications,
      queryParameters: {'page': '1', 'limit': '$limit'},
    );
    dynamic data = response;
    if (data is Map<String, dynamic> && data['data'] is Map) {
      data = data['data'];
    }
    if (data is Map<String, dynamic>) data = data['data'];
    if (data is! List) {
      throw const FormatException('Invalid notifications response.');
    }

    return data.map((item) {
      if (item is! Map<String, dynamic>) {
        throw const FormatException('Invalid notification item.');
      }
      return AppNotification.fromJson(item);
    }).toList();
  }

  Future<int> getUnreadCount() async {
    final response = await _apiClient.get(ApiUrls.notificationUnreadCount);
    dynamic data = response;
    if (data is Map<String, dynamic> && data['data'] is Map) {
      data = data['data'];
    }
    if (data is Map<String, dynamic> && data['unreadCount'] is num) {
      return (data['unreadCount'] as num).toInt();
    }
    throw const FormatException('Invalid unread notification count.');
  }

  Future<void> markAsRead(String notificationId) async {
    await _apiClient.post(ApiUrls.notificationRead(notificationId));
  }

  Future<void> markAllAsRead() async {
    await _apiClient.post(ApiUrls.notificationReadAll);
  }
}
