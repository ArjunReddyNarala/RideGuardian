import 'dart:convert';

import 'package:http/http.dart' as http;

class ApiService {
  ApiService._();

  static final ApiService instance = ApiService._();

  // Replace this with your Mac's local IP.
  static const String baseUrl = 'http://192.168.1.5:3000';

  Future<Map<String, dynamic>> syncUser({
    required String firebaseIdToken,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/v1/auth/sync'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $firebaseIdToken',
      },
      body: jsonEncode({}),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        'Backend authentication failed: '
        '${response.statusCode} ${response.body}',
      );
    }

    return jsonDecode(response.body) as Map<String, dynamic>;
  }
}