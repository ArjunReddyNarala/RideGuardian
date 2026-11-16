class EnvConfig {
  EnvConfig._();

  static const String _defaultBackendUrl =
      'https://rideguardian-backend.onrender.com';

  static String get backendBaseUrl {
    const configuredUrl = String.fromEnvironment('BACKEND_BASE_URL');
    final baseUrl = configuredUrl.trim().isEmpty
        ? _defaultBackendUrl
        : configuredUrl.trim();
    final uri = Uri.tryParse(baseUrl);
    if (uri == null ||
        (uri.scheme != 'https' && uri.scheme != 'http') ||
        uri.host.isEmpty) {
      throw StateError('BACKEND_BASE_URL must be a valid HTTP or HTTPS URL.');
    }
    return baseUrl.replaceFirst(RegExp(r'/+$'), '');
  }
}
