import 'dart:async';
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config/env_config.dart';
/// Represents an error returned by the API client.
class ApiException implements Exception {
  const ApiException({
    required this.message,
    this.statusCode,
    this.cause,
  });
  final String message;
  final int? statusCode;
  final Object? cause;
  @override
  String toString() {
    if (statusCode != null) {
      return 'API error ($statusCode): $message';
    }
    return message;
  }
}
class ApiClient {
  ApiClient({
    http.Client? httpClient,
    FirebaseAuth? firebaseAuth,
    this.timeout = const Duration(seconds: 30),
  })  : _httpClient = httpClient ?? http.Client(),
        _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance;
  final http.Client _httpClient;
  final FirebaseAuth _firebaseAuth;
  /// Maximum time allowed for an HTTP request.
  final Duration timeout;
  /// Builds a URI while avoiding duplicate or missing slashes.
  Uri _buildUri(
    String path, {
    Map<String, String>? queryParameters,
  }) {
    final baseUrl = EnvConfig.backendBaseUrl.trim();
    if (baseUrl.isEmpty) {
      throw const ApiException(
        message: 'Backend base URL is not configured.',
      );
    }
    final normalizedBaseUrl = baseUrl.replaceFirst(
      RegExp(r'/+$'),
      '',
    );
    final normalizedPath = path.startsWith('/')
        ? path
        : '/$path';
    final uri = Uri.parse('$normalizedBaseUrl$normalizedPath');
    if (queryParameters == null || queryParameters.isEmpty) {
      return uri;
    }
    return uri.replace(
      queryParameters: queryParameters,
    );
  }
  /// Creates request headers with the Firebase ID token.
  Future<Map<String, String>> _headers({
    bool jsonContent = true,
  }) async {
    final user = _firebaseAuth.currentUser;
    if (user == null) {
      throw const ApiException(
        message: 'You must be signed in to perform this action.',
      );
    }
    try {
      final token = await user.getIdToken().timeout(timeout);
      if (token == null || token.isEmpty) {
        throw const ApiException(
          message: 'Unable to obtain the Firebase authentication token. '
              'Please sign in again.',
        );
      }
      return {
        'Accept': 'application/json',
        if (jsonContent) 'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };
    } on ApiException {
      rethrow;
    } on TimeoutException catch (error) {
      throw ApiException(
        message: 'Authentication timed out. Please try again.',
        cause: error,
      );
    } on FirebaseAuthException catch (error) {
      debugPrint(
        'Firebase authentication error: ${error.code} - ${error.message}',
      );
      throw ApiException(
        message: _firebaseErrorMessage(error),
        cause: error,
      );
    } catch (error) {
      debugPrint('Failed to obtain Firebase ID token: $error');
      throw ApiException(
        message: 'Unable to authenticate your request. '
            'Please sign in again and retry.',
        cause: error,
      );
    }
  }
  /// Sends a GET request.
  Future<dynamic> get(
    String path, {
    Map<String, String>? queryParameters,
  }) {
    return _request(
      method: 'GET',
      path: path,
      queryParameters: queryParameters,
      jsonContent: false,
    );
  }
  /// Sends a POST request.
  Future<dynamic> post(
    String path, {
    Map<String, dynamic>? body,
  }) {
    return _request(
      method: 'POST',
      path: path,
      body: body ?? <String, dynamic>{},
    );
  }
  /// Sends a PATCH request.
  Future<dynamic> patch(
    String path, {
    Map<String, dynamic>? body,
  }) {
    return _request(
      method: 'PATCH',
      path: path,
      body: body ?? <String, dynamic>{},
    );
  }
  /// Sends a PUT request.
  Future<dynamic> put(
    String path, {
    required Map<String, dynamic> body,
  }) {
    return _request(
      method: 'PUT',
      path: path,
      body: body,
    );
  }
  /// Centralized request execution and error handling.
  Future<dynamic> _request({
    required String method,
    required String path,
    Map<String, dynamic>? body,
    Map<String, String>? queryParameters,
    bool jsonContent = true,
  }) async {
    try {
      final uri = _buildUri(
        path,
        queryParameters: queryParameters,
      );
      final headers = await _headers(
        jsonContent: jsonContent,
      );
      debugPrint('API request: $method $uri');
      late final http.Response response;
      switch (method) {
        case 'GET':
          response = await _httpClient
              .get(
                uri,
                headers: headers,
              )
              .timeout(timeout);
        case 'POST':
          response = await _httpClient
              .post(
                uri,
                headers: headers,
                body: jsonEncode(body ?? <String, dynamic>{}),
              )
              .timeout(timeout);
        case 'PATCH':
          response = await _httpClient
              .patch(
                uri,
                headers: headers,
                body: jsonEncode(body ?? <String, dynamic>{}),
              )
              .timeout(timeout);
        case 'PUT':
          response = await _httpClient
              .put(
                uri,
                headers: headers,
                body: jsonEncode(body ?? <String, dynamic>{}),
              )
              .timeout(timeout);
        default:
          throw ApiException(
            message: 'Unsupported HTTP method: $method',
          );
      }
      debugPrint(
        'API response: $method $uri '
        '-> ${response.statusCode}',
      );
      return _decodeResponse(response);
    } on ApiException {
      rethrow;
    } on TimeoutException catch (error) {
      debugPrint('API request timed out: $method $path');
      throw ApiException(
        message: 'The request timed out. Check your connection '
            'and try again.',
        cause: error,
      );
    } on http.ClientException catch (error) {
      debugPrint('Network request failed: $error');
      throw ApiException(
        message: 'Unable to connect to the backend. '
            'Check your network connection and make sure the server '
            'is running and accessible.',
        cause: error,
      );
    } on FormatException catch (error) {
      debugPrint('Request formatting error: $error');
      throw ApiException(
        message: 'Unable to process the request or response format.',
        cause: error,
      );
    } catch (error, stackTrace) {
      debugPrint('Unexpected API error: $error');
      debugPrintStack(stackTrace: stackTrace);
      throw ApiException(
        message: 'An unexpected error occurred. Please try again.',
        cause: error,
      );
    }
  }
  /// Decodes the response and converts unsuccessful HTTP responses
  /// into ApiException instances.
  dynamic _decodeResponse(http.Response response) {
    final responseBody = response.body.trim();
    dynamic decoded;
    if (responseBody.isNotEmpty) {
      try {
        decoded = jsonDecode(responseBody);
      } on FormatException {
        // Some APIs return plain-text responses.
        decoded = responseBody;
      }
    }
    if (response.statusCode >= 200 &&
        response.statusCode < 300) {
      return decoded;
    }
    final message = _extractErrorMessage(
      decoded,
      response.statusCode,
    );
    debugPrint(
      'API error: HTTP ${response.statusCode} - $message',
    );
    throw ApiException(
      message: message,
      statusCode: response.statusCode,
    );
  }
  /// Extracts a useful message from common API error formats.
  String _extractErrorMessage(
    dynamic decoded,
    int statusCode,
  ) {
    String? serverMessage;
    if (decoded is Map) {
      final message = decoded['message'];
      if (message is String && message.trim().isNotEmpty) {
        serverMessage = message.trim();
      } else if (message is List && message.isNotEmpty) {
        serverMessage = message
            .map((item) => item.toString())
            .join(', ');
      }
      if (serverMessage == null || serverMessage.isEmpty) {
        final error = decoded['error'];
        if (error is String && error.trim().isNotEmpty) {
          serverMessage = error.trim();
        }
      }
      if (serverMessage == null || serverMessage.isEmpty) {
        final detail = decoded['detail'];
        if (detail is String && detail.trim().isNotEmpty) {
          serverMessage = detail.trim();
        }
      }
    } else if (decoded is String && decoded.isNotEmpty) {
      serverMessage = decoded;
    }
    if (serverMessage != null && serverMessage.isNotEmpty) {
      return serverMessage;
    }
    switch (statusCode) {
      case 400:
        return 'Invalid request. Please check the information entered.';
      case 401:
        return 'Your session is invalid or has expired. Please sign in again.';
      case 403:
        return 'You do not have permission to perform this action.';
      case 404:
        return 'The requested resource was not found.';
      case 409:
        return 'This operation conflicts with existing data.';
      case 422:
        return 'The submitted information could not be processed.';
      case 429:
        return 'Too many requests. Please wait a moment and try again.';
      case 500:
        return 'The backend encountered an internal error.';
      case 502:
      case 503:
      case 504:
        return 'The backend is temporarily unavailable. Please try again.';
      default:
        if (statusCode >= 500) {
          return 'A server error occurred. Please try again later.';
        }
        return 'The request could not be completed (HTTP $statusCode).';
    }
  }
  /// Provides user-friendly Firebase authentication errors.
  String _firebaseErrorMessage(FirebaseAuthException error) {
    switch (error.code) {
      case 'user-token-expired':
      case 'invalid-user-token':
        return 'Your session has expired. Please sign in again.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'network-request-failed':
        return 'Unable to reach the authentication service. '
            'Check your internet connection.';
      default:
        return 'Authentication failed. Please sign in again.';
    }
  }
  /// Closes the underlying HTTP client.
  ///
  /// Call this only when the ApiClient is no longer needed.
  void close() {
    _httpClient.close();
  }
}