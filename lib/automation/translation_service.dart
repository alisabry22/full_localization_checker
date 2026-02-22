import 'dart:convert';

import 'package:http/http.dart' as http;

/// Auto-translation service supporting multiple providers
class TranslationService {
  final String apiKey;
  final TranslationProvider provider;
  final bool verbose;

  TranslationService({
    required this.apiKey,
    required this.provider,
    this.verbose = false,
  });

  /// Translates ARB files to multiple languages
  Future<Map<String, Map<String, dynamic>>> translateArbToLanguages({
    required Map<String, dynamic> sourceArb,
    required List<String> targetLanguages,
    String sourceLanguage = 'en',
  }) async {
    final results = <String, Map<String, dynamic>>{};

    for (final targetLanguage in targetLanguages) {
      if (verbose) {
        print('🌍 Translating to $targetLanguage...');
      }

      try {
        final translatedArb = await translateArb(
          sourceArb: sourceArb,
          targetLanguage: targetLanguage,
          sourceLanguage: sourceLanguage,
        );
        results[targetLanguage] = translatedArb;

        if (verbose) {
          print('✅ Translation completed for $targetLanguage');
        }
      } catch (e) {
        if (verbose) {
          print('❌ Translation failed for $targetLanguage: $e');
        }
        // Create a fallback ARB with source text
        results[targetLanguage] = _createFallbackArb(sourceArb, targetLanguage);
      }
    }

    return results;
  }

  /// Translates a single ARB file
  Future<Map<String, dynamic>> translateArb({
    required Map<String, dynamic> sourceArb,
    required String targetLanguage,
    String sourceLanguage = 'en',
  }) async {
    final translatedArb = <String, dynamic>{};
    final textsToTranslate = <String, String>{};

    // Extract text entries (skip metadata entries starting with @)
    for (final entry in sourceArb.entries) {
      if (!entry.key.startsWith('@')) {
        final value = entry.value.toString();
        if (value.isNotEmpty) {
          textsToTranslate[entry.key] = value;
        }
      }
    }

    if (verbose) {
      print('📝 Found ${textsToTranslate.length} strings to translate');
    }

    // Translate in batches to optimize API calls
    final batchSize = provider == TranslationProvider.googleTranslate ? 50 : 20;
    final keys = textsToTranslate.keys.toList();

    for (int i = 0; i < keys.length; i += batchSize) {
      final batchKeys = keys.sublist(i, (i + batchSize).clamp(0, keys.length));
      final batchTexts =
          batchKeys.map((key) => textsToTranslate[key]!).toList();

      try {
        final translations = await _translateBatch(
          texts: batchTexts,
          targetLanguage: targetLanguage,
          sourceLanguage: sourceLanguage,
        );

        for (int j = 0; j < batchKeys.length; j++) {
          final key = batchKeys[j];
          final translation = j < translations.length
              ? translations[j]
              : textsToTranslate[key]!;
          translatedArb[key] = translation;

          // Copy metadata if it exists
          final metadataKey = '@$key';
          if (sourceArb.containsKey(metadataKey)) {
            translatedArb[metadataKey] = sourceArb[metadataKey];
          }
        }

        if (verbose) {
          print(
            '✅ Translated batch ${(i ~/ batchSize) + 1}/${(keys.length / batchSize).ceil()}',
          );
        }
      } catch (e) {
        if (verbose) {
          print('⚠️ Batch translation failed, using fallback: $e');
        }

        // Fallback: use original text
        for (final key in batchKeys) {
          translatedArb[key] = textsToTranslate[key]!;
          final metadataKey = '@$key';
          if (sourceArb.containsKey(metadataKey)) {
            translatedArb[metadataKey] = sourceArb[metadataKey];
          }
        }
      }

      // Rate limiting
      await Future.delayed(Duration(milliseconds: 100));
    }

    return translatedArb;
  }

  /// Translates a batch of texts
  Future<List<String>> _translateBatch({
    required List<String> texts,
    required String targetLanguage,
    required String sourceLanguage,
  }) async {
    switch (provider) {
      case TranslationProvider.googleTranslate:
        return _translateWithGoogle(texts, targetLanguage, sourceLanguage);
      case TranslationProvider.deepL:
        return _translateWithDeepL(texts, targetLanguage, sourceLanguage);
      case TranslationProvider.azure:
        return _translateWithAzure(texts, targetLanguage, sourceLanguage);
      case TranslationProvider.aws:
        return _translateWithAWS(texts, targetLanguage, sourceLanguage);
      case TranslationProvider.libre:
        return _translateWithLibreTranslate(
          texts,
          targetLanguage,
          sourceLanguage,
        );
    }
  }

  /// Google Translate implementation
  Future<List<String>> _translateWithGoogle(
    List<String> texts,
    String targetLanguage,
    String sourceLanguage,
  ) async {
    final url = 'https://translation.googleapis.com/language/translate/v2';
    final body = jsonEncode({
      'q': texts,
      'target': targetLanguage,
      'source': sourceLanguage,
      'format': 'text',
    });

    final response = await http.post(
      Uri.parse('$url?key=$apiKey'),
      headers: {'Content-Type': 'application/json'},
      body: body,
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final translations = data['data']['translations'] as List;
      return translations.map((t) => t['translatedText'] as String).toList();
    } else {
      throw Exception('Google Translate API error: ${response.statusCode}');
    }
  }

  /// DeepL implementation
  Future<List<String>> _translateWithDeepL(
    List<String> texts,
    String targetLanguage,
    String sourceLanguage,
  ) async {
    final url = 'https://api-free.deepl.com/v2/translate';
    final body = {
      'text': texts,
      'target_lang': targetLanguage.toUpperCase(),
      'source_lang': sourceLanguage.toUpperCase(),
    };

    final response = await http.post(
      Uri.parse(url),
      headers: {
        'Authorization': 'DeepL-Auth-Key $apiKey',
        'Content-Type': 'application/x-www-form-urlencoded',
      },
      body: body,
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final translations = data['translations'] as List;
      return translations.map((t) => t['text'] as String).toList();
    } else {
      throw Exception('DeepL API error: ${response.statusCode}');
    }
  }

  /// Azure Translator implementation
  Future<List<String>> _translateWithAzure(
    List<String> texts,
    String targetLanguage,
    String sourceLanguage,
  ) async {
    final url = 'https://api.cognitive.microsofttranslator.com/translate';
    final body = jsonEncode(texts.map((text) => {'text': text}).toList());

    final response = await http.post(
      Uri.parse('$url?api-version=3.0&from=$sourceLanguage&to=$targetLanguage'),
      headers: {
        'Ocp-Apim-Subscription-Key': apiKey,
        'Content-Type': 'application/json',
      },
      body: body,
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as List;
      return data
          .map((item) => item['translations'][0]['text'] as String)
          .toList();
    } else {
      throw Exception('Azure Translator API error: ${response.statusCode}');
    }
  }

  /// AWS Translate implementation
  Future<List<String>> _translateWithAWS(
    List<String> texts,
    String targetLanguage,
    String sourceLanguage,
  ) async {
    // Note: This is a simplified implementation
    // In production, you'd use the AWS SDK for proper signing
    final results = <String>[];

    for (final text in texts) {
      // For now, return the original text
      // TODO: Implement proper AWS Translate integration
      results.add(text);
    }

    return results;
  }

  /// LibreTranslate implementation (free/self-hosted)
  Future<List<String>> _translateWithLibreTranslate(
    List<String> texts,
    String targetLanguage,
    String sourceLanguage,
  ) async {
    final url = 'https://libretranslate.de/translate';
    final results = <String>[];

    for (final text in texts) {
      final body = jsonEncode({
        'q': text,
        'source': sourceLanguage,
        'target': targetLanguage,
        'format': 'text',
        'api_key': apiKey.isNotEmpty ? apiKey : null,
      });

      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: body,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        results.add(data['translatedText'] as String);
      } else {
        results.add(text); // Fallback to original text
      }

      // Rate limiting for free service
      await Future.delayed(Duration(milliseconds: 200));
    }

    return results;
  }

  /// Creates a fallback ARB file with original text
  Map<String, dynamic> _createFallbackArb(
    Map<String, dynamic> sourceArb,
    String language,
  ) {
    final fallbackArb = <String, dynamic>{};

    for (final entry in sourceArb.entries) {
      if (!entry.key.startsWith('@')) {
        fallbackArb[entry.key] = entry.value;

        // Copy metadata if it exists
        final metadataKey = '@${entry.key}';
        if (sourceArb.containsKey(metadataKey)) {
          fallbackArb[metadataKey] = sourceArb[metadataKey];
        }
      }
    }

    return fallbackArb;
  }

  /// Validates translation quality (basic checks)
  bool validateTranslation(String original, String translated) {
    // Basic validation checks
    if (translated.isEmpty) return false;
    if (translated == original && original.length > 3)
      return false; // Likely untranslated

    // Check for preserved placeholders
    final placeholderPattern = RegExp(r'\{[^}]+\}');
    final originalPlaceholders = placeholderPattern.allMatches(original);
    final translatedPlaceholders = placeholderPattern.allMatches(translated);

    if (originalPlaceholders.length != translatedPlaceholders.length) {
      return false; // Placeholders not preserved
    }

    return true;
  }
}

/// Available translation providers
enum TranslationProvider { googleTranslate, deepL, azure, aws, libre }
