import 'package:flutter_dotenv/flutter_dotenv.dart';

class EnvConfig {
  EnvConfig._();

  static String get backendBaseUrl {
    final value = dotenv.env['BACKEND_BASE_URL']?.trim();

    if (value == null || value.isEmpty) {
      throw StateError(
        'BACKEND_BASE_URL is missing from the .env configuration.',
      );
    }

    return value.replaceFirst(RegExp(r'/+$'), '');
  }
}