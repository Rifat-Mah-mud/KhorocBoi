import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';

/// Free AI fallback using Groq (Llama) — OpenAI-compatible chat API.
/// Key comes from [ApiConfig.groqApiKey].
class AiService {
  static const _endpoint = 'https://api.groq.com/openai/v1/chat/completions';
  static const _model = 'llama-3.1-8b-instant';

  String? _apiKey;

  Future<void> init() async {
    final bakedIn = ApiConfig.groqApiKey.trim();
    _apiKey = bakedIn.isEmpty ? null : bakedIn;
  }

  String? get apiKey => _apiKey;

  bool get isConfigured => _apiKey != null && _apiKey!.isNotEmpty;

  /// Translate an unrecognized Bangla/Banglish expense term to clean English.
  /// Returns null on any failure so callers can keep the raw text.
  Future<String?> translateTerm(String term) async {
    if (!isConfigured) return null;
    final cleaned = term.trim();
    if (cleaned.isEmpty) return null;

    try {
      final response = await http
          .post(
            Uri.parse(_endpoint),
            headers: {
              'Authorization': 'Bearer $_apiKey',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'model': _model,
              'temperature': 0,
              'max_tokens': 32,
              'messages': [
                {
                  'role': 'system',
                  'content':
                      'You translate Bangla or Banglish expense-related words '
                      'into clean short English product/service names. '
                      'Reply with ONLY the English translation, no quotes, '
                      'no punctuation, no explanation.',
                },
                {
                  'role': 'user',
                  'content': cleaned,
                },
              ],
            }),
          )
          .timeout(const Duration(seconds: 12));

      if (response.statusCode < 200 || response.statusCode >= 300) {
        return null;
      }

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final choices = body['choices'] as List<dynamic>?;
      if (choices == null || choices.isEmpty) return null;

      final message = choices.first['message'] as Map<String, dynamic>?;
      final content = (message?['content'] as String?)?.trim();
      if (content == null || content.isEmpty) return null;

      final firstLine = content.split('\n').first.trim();
      final sanitized = firstLine
          .replaceAll(RegExp(r'''^["']+|["']+$'''), '')
          .trim();
      if (sanitized.length > 60) return null;
      return sanitized;
    } catch (_) {
      return null;
    }
  }
}
