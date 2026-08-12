/// Copy this file to `api_config.dart` and fill in your keys.
class ApiConfig {
  /// Groq free API key — used automatically at app start.
  static const String groqApiKey = 'gsk_YOUR_KEY_HERE';

  /// Google Cloud **Web** OAuth client ID (used as Android serverClientId).
  /// Create at https://console.cloud.google.com/apis/credentials
  /// Also enable "Google Drive API", and add an Android OAuth client with
  /// package `com.khoroboi.khoroboi` + your SHA-1.
  static const String googleWebClientId = 'YOUR_WEB_CLIENT_ID.apps.googleusercontent.com';
}
