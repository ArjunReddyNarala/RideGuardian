import 'package:flutter_dotenv/flutter_dotenv.dart';

class EnvConfig {
  EnvConfig._();

  static const String _defaultBackendUrl =
      'https://rideguardian-backend.onrender.com';

  static String get backendBaseUrl {
    final value = dotenv.env['BACKEND_BASE_URL']?.trim();

    final baseUrl = (value == null || value.isEmpty)
        ? _defaultBackendUrl
        : value;

    return baseUrl.replaceFirst(RegExp(r'/+$'), '');
  }
}