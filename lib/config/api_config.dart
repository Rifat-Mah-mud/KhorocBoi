/// Local build-time API config for KhorocBoi.
///
/// This file is gitignored — do not commit real keys.
/// Copy from `api_config.example.dart` if you clone on another machine.
class ApiConfig {
  /// Groq free API key — used automatically at app start.
  static const String groqApiKey =
      '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';

  /// Google Cloud **Web** OAuth client ID (Android `serverClientId`).
  /// Leave placeholder until you create credentials — backup UI will explain.
  static const String googleWebClientId =
      '285448988371-su4lunj71mfih3u1rlccp5b9t1nlhppc.apps.googleusercontent.com';
}
