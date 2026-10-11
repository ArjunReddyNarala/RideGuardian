import 'api_client.dart';

class UserApi {
  UserApi._();

  static final UserApi instance = UserApi._();

  final ApiClient _apiClient = ApiClient.instance;

  Future<Map<String, dynamic>> getMe() async {
    return _apiClient.get('/api/v1/users/me');
  }

  Future<Map<String, dynamic>> updateMe({
    String? name,
    String? phone,
    String? profileImageUrl,
  }) async {
    return _apiClient.patch(
      '/api/v1/users/me',
      body: {
        if (name != null) 'name': name,
        if (phone != null) 'phone': phone,
        if (profileImageUrl != null) 'profileImageUrl': profileImageUrl,
      },
    );
  }
}
