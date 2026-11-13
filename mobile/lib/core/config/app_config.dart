class AppConfig {
  const AppConfig._();

  /// Base URL for the MONEVO REST API (v1).
  /// Override at build/run time via:
  /// `--dart-define=API_BASE_URL=http://localhost:3000/api/v1`
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://monevo-api-45ht.onrender.com/api/v1',
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

  static const String appVersion = String.fromEnvironment(
    'APP_VERSION',
    defaultValue: '1.0.0',
  );
  static const int appBuildNumber = int.fromEnvironment(
    'APP_BUILD_NUMBER',
    defaultValue: 1,
  );
  static const String updateManifestUrl = String.fromEnvironment(
    'UPDATE_MANIFEST_URL',
    defaultValue:
        'https://github.com/doraemondoaon-eng/monevo/releases/download/v1.0.0/version.json',
  );
}
