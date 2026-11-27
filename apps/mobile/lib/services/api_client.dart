import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

import '../core/config/env_config.dart';

class ApiClient {
  ApiClient._();

  static final ApiClient instance = ApiClient._();

  String get baseUrl => EnvConfig.backendBaseUrl;

  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;

  Future<Map<String, String>> _headers() async {
    final user = _firebaseAuth.currentUser;

    if (user == null) {
      throw FirebaseAuthException(
        code: 'not-authenticated',
        message: 'No Firebase user is currently signed in.',
      );
    }

    final idToken = await user.getIdToken(true);

    if (idToken == null) {
      throw FirebaseAuthException(
        code: 'token-unavailable',
        message: 'Firebase ID token was not available.',
      );
    }

    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $idToken',
    };
  }

  Future<Map<String, dynamic>> get(String path) async {
    final response = await http.get(
      Uri.parse('$baseUrl$path'),
      headers: await _headers(),
    );

    return _handleResponse(response);
  }

  Future<Map<String, dynamic>> post(
    String path, {
    Map<String, dynamic>? body,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl$path'),
      headers: await _headers(),
      body: body == null ? null : jsonEncode(body),
    );

    return _handleResponse(response);
  }

  Future<Map<String, dynamic>> patch(
    String path, {
    Map<String, dynamic>? body,
  }) async {
    final response = await http.patch(
      Uri.parse('$baseUrl$path'),
      headers: await _headers(),
      body: body == null ? null : jsonEncode(body),
    );

    return _handleResponse(response);
  }

  Future<Map<String, dynamic>> delete(String path) async {
    final response = await http.delete(
      Uri.parse('$baseUrl$path'),
      headers: await _headers(),
    );

    return _handleResponse(response);
  }

  Map<String, dynamic> _handleResponse(http.Response response) {
    final responseBody = response.body.isEmpty
        ? <String, dynamic>{}
        : jsonDecode(response.body) as Map<String, dynamic>;

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message = responseBody['message'] ?? response.body;

      throw Exception(
        'API request failed: '
        '${response.statusCode} $message',
      );
    }

    return responseBody;
  }
}
