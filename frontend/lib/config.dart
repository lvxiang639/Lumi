class AppConfig {
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:8000',
  );

  static String get wsBaseUrl {
    if (apiBaseUrl.startsWith('https')) {
      return apiBaseUrl.replaceFirst('https', 'wss');
    }
    return apiBaseUrl.replaceFirst('http', 'ws');
  }
}
