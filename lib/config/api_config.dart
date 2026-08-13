/// Local build-time API config for KhorocBoi.
///
/// This file is gitignored — do not commit real keys.
/// Copy from `api_config.example.dart` if you clone on another machine.
class ApiConfig {
  /// Groq free API key — used automatically at app start.
  static const String groqApiKey =
      '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';

  /// Deployed khorocboi-server URL (no trailing slash).
  /// After you deploy the server to Vercel, paste that URL here.
  static const String syncServerUrl = 'khorocboi-server-6kl2f6jfc-rifatwork2nd-3878s-projects.vercel.app';
}
