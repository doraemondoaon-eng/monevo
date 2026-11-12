class AppConfig {
  const AppConfig._();

  /// Base URL for the MONEVO REST API (v1).
  /// Override at build/run time via:
  /// `--dart-define=API_BASE_URL=http://localhost:3000/api/v1`
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:3000/api/v1',
  );

  /// Derives the root `/health` URL from [baseUrl].
  /// According to API.md, `GET /health` has no `/api/v1` prefix.
  static String deriveHealthUrl([String baseUrl = apiBaseUrl]) {
    final String trimmed = baseUrl.trim().replaceAll(RegExp(r'/+$'), '');
    if (trimmed.endsWith('/api/v1')) {
      return '${trimmed.substring(0, trimmed.length - '/api/v1'.length)}/health';
    }
    final Uri? uri = Uri.tryParse(trimmed);
    if (uri != null && uri.hasScheme && uri.host.isNotEmpty) {
      return uri.replace(path: '/health', query: null, fragment: null).toString();
    }
    return '$trimmed/health';
  }

  static const Duration connectTimeout = Duration(seconds: 20);
  static const Duration receiveTimeout = Duration(seconds: 25);
  static const int defaultPageSize = 30;
  static const int defaultAutoLockSeconds = 60;
}
