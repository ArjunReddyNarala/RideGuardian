import 'package:flutter_dotenv/flutter_dotenv.dart';

class EnvConfig {
  EnvConfig._();

  static const String _defaultBackendUrl = 'http://192.168.1.11:3000';

  static String get backendBaseUrl {
    final value = dotenv.env['BACKEND_BASE_URL']?.trim();

    var baseUrl = (value == null || value.isEmpty) ? _defaultBackendUrl : value;

    final markdownLink = RegExp(r'^\[[^\]]+\]\((https?://[^)]+)\)$')
        .firstMatch(baseUrl);
    if (markdownLink != null) {
      baseUrl = markdownLink.group(1)!;
    }

    while (baseUrl.startsWith('BACKEND_BASE_URL=')) {
      baseUrl = baseUrl.substring('BACKEND_BASE_URL='.length).trim();
    }

    return baseUrl.replaceFirst(RegExp(r'/+$'), '');
  }
}
