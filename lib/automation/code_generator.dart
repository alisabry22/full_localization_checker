import 'dart:io';

/// Automated code generator for Flutter localization setup
class LocalizationCodeGenerator {
  final String projectPath;
  final String outputDirectory;
  final bool verbose;

  LocalizationCodeGenerator({
    required this.projectPath,
    required this.outputDirectory,
    this.verbose = false,
  });

  /// Generates complete localization setup for a Flutter project
  Future<void> generateCompleteSetup({
    required List<String> supportedLanguages,
    required Map<String, Map<String, dynamic>> translations,
    bool generateExtensions = true,
    bool updatePubspec = true,
    bool generateL10nYaml = true,
  }) async {
    if (verbose) {
      print('🏗️ Generating complete localization setup...');
    }

    // Ensure output directory exists
    final outputDir = Directory(outputDirectory);
    if (!outputDir.existsSync()) {
      outputDir.createSync(recursive: true);
    }

    // Generate ARB files for each language
    await _generateArbFiles(translations);

    // Generate l10n.yaml configuration
    if (generateL10nYaml) {
      await _generateL10nYaml(supportedLanguages);
    }

    // Update pubspec.yaml with necessary dependencies
    if (updatePubspec) {
      await _updatePubspecYaml();
    }

    // Generate helper extensions and utilities
    if (generateExtensions) {
      await _generateHelperExtensions(supportedLanguages);
      await _generateLocalizationHelpers();
    }

    // Generate app localization delegate
    await _generateAppLocalizationDelegate(supportedLanguages);

    // Generate example main.dart updates
    await _generateMainDartExample(supportedLanguages);

    if (verbose) {
      print('✅ Complete localization setup generated successfully!');
    }
  }

  /// Generates ARB files for each language
  Future<void> _generateArbFiles(
      Map<String, Map<String, dynamic>> translations) async {
    for (final entry in translations.entries) {
      final languageCode = entry.key;
      final translationMap = entry.value;

      final arbFile = File('$outputDirectory/${languageCode}.arb');
      final arbContent = _generateArbContent(translationMap);

      await arbFile.writeAsString(arbContent);

      if (verbose) {
        print('📄 Generated ${languageCode}.arb');
      }
    }
  }

  /// Generates proper ARB file content with metadata
  String _generateArbContent(Map<String, dynamic> translations) {
    final buffer = StringBuffer();
    buffer.writeln('{');

    final entries = <String>[];

    for (final entry in translations.entries) {
      final key = entry.key;
      final value = entry.value;

      if (!key.startsWith('@')) {
        entries.add('  "$key": "${value.toString().replaceAll('"', '\\"')}"');

        // Add metadata if the string has placeholders
        if (value.toString().contains('{') && value.toString().contains('}')) {
          final placeholders = _extractPlaceholdersFromValue(value.toString());
          if (placeholders.isNotEmpty) {
            final metadata = StringBuffer();
            metadata.writeln('  "@$key": {');
            metadata.writeln(
                '    "description": "Localized text with placeholders",');
            metadata.writeln('    "placeholders": {');

            final placeholderEntries = <String>[];
            for (final placeholder in placeholders) {
              placeholderEntries.add(
                  '      "$placeholder": {\n        "type": "String"\n      }');
            }
            metadata.writeln(placeholderEntries.join(',\n'));
            metadata.writeln('    }');
            metadata.write('  }');

            entries.add(metadata.toString());
          }
        }
      }
    }

    buffer.writeln(entries.join(',\n'));
    buffer.writeln('}');

    return buffer.toString();
  }

  /// Extracts placeholder names from a value string
  List<String> _extractPlaceholdersFromValue(String value) {
    final placeholderPattern = RegExp(r'\{(\w+)\}');
    final matches = placeholderPattern.allMatches(value);
    return matches.map((match) => match.group(1)!).toList();
  }

  /// Generates l10n.yaml configuration file
  Future<void> _generateL10nYaml(List<String> supportedLanguages) async {
    final l10nFile = File('$projectPath/l10n.yaml');

    final l10nContent = '''
# l10n.yaml
arb-dir: ${outputDirectory.replaceFirst(projectPath, '').replaceFirst(RegExp(r'^[/\\]'), '')}
template-arb-file: en.arb
output-localization-file: app_localizations.dart
output-class: AppLocalizations
output-dir: ${outputDirectory.replaceFirst(projectPath, '').replaceFirst(RegExp(r'^[/\\]'), '')}/generated
preferred-supported-locales: [${supportedLanguages.map((lang) => "'$lang'").join(', ')}]
''';

    await l10nFile.writeAsString(l10nContent);

    if (verbose) {
      print('📄 Generated l10n.yaml');
    }
  }

  /// Updates pubspec.yaml with necessary dependencies
  Future<void> _updatePubspecYaml() async {
    final pubspecFile = File('$projectPath/pubspec.yaml');

    if (!pubspecFile.existsSync()) {
      if (verbose) {
        print('⚠️ pubspec.yaml not found, skipping update');
      }
      return;
    }

    final content = await pubspecFile.readAsString();

    // Check if flutter_localizations is already added
    if (content.contains('flutter_localizations:')) {
      if (verbose) {
        print('ℹ️ flutter_localizations already in pubspec.yaml');
      }
      return;
    }

    // Find the flutter: section and add dependencies
    final lines = content.split('\n');
    final updatedLines = <String>[];
    bool inFlutterSection = false;
    bool addedLocalizations = false;

    for (final line in lines) {
      updatedLines.add(line);

      if (line.trim().startsWith('flutter:')) {
        inFlutterSection = true;
      } else if (inFlutterSection &&
          line.trim().startsWith('dependencies:') &&
          !addedLocalizations) {
        updatedLines.add('  flutter_localizations:');
        updatedLines.add('    sdk: flutter');
        updatedLines.add('  intl: any');
        addedLocalizations = true;
      } else if (inFlutterSection && line.trim().isEmpty) {
        inFlutterSection = false;
      }
    }

    // Add generate: true to flutter section if not present
    if (!content.contains('generate: true')) {
      final flutterSectionIndex =
          updatedLines.indexWhere((line) => line.trim().startsWith('flutter:'));
      if (flutterSectionIndex != -1) {
        updatedLines.insert(flutterSectionIndex + 1, '  generate: true');
      }
    }

    await pubspecFile.writeAsString(updatedLines.join('\n'));

    if (verbose) {
      print('📄 Updated pubspec.yaml with localization dependencies');
    }
  }

  /// Generates helper extensions for easier localization access
  Future<void> _generateHelperExtensions(
      List<String> supportedLanguages) async {
    final extensionFile = File('$outputDirectory/localization_extensions.dart');

    final extensionContent = '''
// Generated localization helper extensions
// This file provides convenient extensions for accessing localizations

import 'package:flutter/material.dart';
import 'generated/app_localizations.dart';

/// Extension on BuildContext for easy localization access
extension LocalizationExtension on BuildContext {
  /// Get the current AppLocalizations instance
  AppLocalizations get l10n => AppLocalizations.of(this)!;
  
  /// Get the current locale
  Locale get locale => Localizations.localeOf(this);
  
  /// Check if the current locale is RTL
  bool get isRTL => Directionality.of(this) == TextDirection.rtl;
  
  /// Get text direction based on locale
  TextDirection get textDirection => isRTL ? TextDirection.rtl : TextDirection.ltr;
}

/// Extension on AppLocalizations for additional utilities
extension AppLocalizationsExtension on AppLocalizations {
  /// Format a string with parameters
  String formatString(String template, Map<String, dynamic> params) {
    String result = template;
    for (final paramEntry in params.entries) {
      result = result.replaceAll('{' + paramEntry.key + '}', paramEntry.value.toString());
    }
    return result;
  }
  
  /// Get supported language codes
  static List<String> get supportedLanguageCodes => [
    ${supportedLanguages.map((lang) => "'$lang'").join(',\n    ')}
  ];
  
  /// Get supported locales
  static List<Locale> get supportedLocales => [
    ${supportedLanguages.map((lang) => "Locale('$lang')").join(',\n    ')}
  ];
}

/// Utility class for localization helpers
class LocalizationHelper {
  /// Get device locale
  static Locale getDeviceLocale() {
    final locale = WidgetsBinding.instance.platformDispatcher.locale;
    return locale;
  }
  
  /// Check if a locale is supported
  static bool isLocaleSupported(Locale locale) {
    return AppLocalizationsExtension.supportedLanguageCodes.contains(locale.languageCode);
  }
  
  /// Get fallback locale if current is not supported
  static Locale getFallbackLocale(Locale locale) {
    if (isLocaleSupported(locale)) {
      return locale;
    }
    return const Locale('en'); // Default fallback
  }
  
  /// Format currency based on locale
  static String formatCurrency(double amount, String currencyCode, Locale locale) {
    // This would typically use intl package for proper formatting
    // For now, returning a simple format
    return currencyCode + ' ' + amount.toStringAsFixed(2);
  }
  
  /// Format date based on locale
  static String formatDate(DateTime date, Locale locale) {
    // This would typically use intl package for proper formatting
    // For now, returning a simple format
    return date.day.toString() + '/' + date.month.toString() + '/' + date.year.toString();
  }
}
''';

    await extensionFile.writeAsString(extensionContent);

    if (verbose) {
      print('📄 Generated localization_extensions.dart');
    }
  }

  /// Generates additional localization helpers
  Future<void> _generateLocalizationHelpers() async {
    final helperFile = File('$outputDirectory/localization_config.dart');

    final helperContent = '''
// Generated localization configuration and utilities
// This file provides configuration and helper methods for localization

import 'package:flutter/material.dart';
import 'generated/app_localizations.dart';

/// Configuration class for localization settings
class LocalizationConfig {
  static const List<Locale> supportedLocales = AppLocalizations.supportedLocales;
  
  /// Localization delegates for MaterialApp
  static const List<LocalizationsDelegate> localizationsDelegates = [
    AppLocalizations.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ];
  
  /// Locale resolution callback
  static Locale? localeResolutionCallback(
    List<Locale>? locales,
    Iterable<Locale> supportedLocales,
  ) {
    // If device locale is supported, use it
    if (locales != null) {
      for (final locale in locales) {
        for (final supportedLocale in supportedLocales) {
          if (supportedLocale.languageCode == locale.languageCode) {
            return supportedLocale;
          }
        }
      }
    }
    
    // Fallback to first supported locale (usually English)
    return supportedLocales.first;
  }
}

/// Widget that provides easy localization setup
class LocalizedApp extends StatelessWidget {
  final Widget child;
  final String title;
  final ThemeData? theme;
  final ThemeData? darkTheme;
  final ThemeMode themeMode;
  
  const LocalizedApp({
    Key? key,
    required this.child,
    required this.title,
    this.theme,
    this.darkTheme,
    this.themeMode = ThemeMode.system,
  }) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: title,
      theme: theme,
      darkTheme: darkTheme,
      themeMode: themeMode,
      localizationsDelegates: LocalizationConfig.localizationsDelegates,
      supportedLocales: LocalizationConfig.supportedLocales,
      localeResolutionCallback: LocalizationConfig.localeResolutionCallback,
      home: child,
    );
  }
}
''';

    await helperFile.writeAsString(helperContent);

    if (verbose) {
      print('📄 Generated localization_config.dart');
    }
  }

  /// Generates app localization delegate setup
  Future<void> _generateAppLocalizationDelegate(
      List<String> supportedLanguages) async {
    final delegateFile = File('$outputDirectory/app_localization_setup.dart');

    final delegateContent = '''
// Generated app localization setup
// This file provides the complete setup for app localization

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'generated/app_localizations.dart';

/// Complete localization setup for your Flutter app
class AppLocalizationSetup {
  /// Get localization delegates
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates = [
    AppLocalizations.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ];
  
  /// Get supported locales
  static const List<Locale> supportedLocales = [
    ${supportedLanguages.map((lang) => "Locale('$lang')").join(',\n    ')}
  ];
  
  /// Locale resolution callback
  static Locale? localeResolutionCallback(
    List<Locale>? locales,
    Iterable<Locale> supportedLocales,
  ) {
    if (locales != null) {
      for (final locale in locales) {
        for (final supportedLocale in supportedLocales) {
          if (supportedLocale.languageCode == locale.languageCode) {
            return supportedLocale;
          }
        }
      }
    }
    return supportedLocales.first;
  }
}

/// Example of how to use the localization setup in your MaterialApp
class ExampleApp extends StatelessWidget {
  const ExampleApp({Key? key}) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Localized App',
      localizationsDelegates: AppLocalizationSetup.localizationsDelegates,
      supportedLocales: AppLocalizationSetup.supportedLocales,
      localeResolutionCallback: AppLocalizationSetup.localeResolutionCallback,
      home: const HomePage(),
    );
  }
}

class HomePage extends StatelessWidget {
  const HomePage({Key? key}) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    // Example of using localizations
    final l10n = AppLocalizations.of(context)!;
    
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.appTitle ?? 'App Title'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(l10n.welcome ?? 'Welcome'),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                // Example of accessing localization via extension
                final welcomeMessage = context.l10n.welcome ?? 'Welcome';
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(welcomeMessage)),
                );
              },
              child: Text(l10n.buttonLabel ?? 'Button'),
            ),
          ],
        ),
      ),
    );
  }
}
''';

    await delegateFile.writeAsString(delegateContent);

    if (verbose) {
      print('📄 Generated app_localization_setup.dart');
    }
  }

  /// Generates example main.dart with localization setup
  Future<void> _generateMainDartExample(List<String> supportedLanguages) async {
    final exampleFile = File('$outputDirectory/main_example.dart');

    final exampleContent = '''
// Example main.dart with complete localization setup
// Copy the relevant parts to your actual main.dart file

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'l10n/generated/app_localizations.dart';
import 'l10n/localization_extensions.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Localized Flutter App',
      
      // 🌍 Localization setup
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        ${supportedLanguages.map((lang) => "Locale('$lang'), // $lang").join('\n        ')}
      ],
      localeResolutionCallback: (locales, supportedLocales) {
        if (locales != null) {
          for (final locale in locales) {
            for (final supportedLocale in supportedLocales) {
              if (supportedLocale.languageCode == locale.languageCode) {
                return supportedLocale;
              }
            }
          }
        }
        return supportedLocales.first;
      },
      
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatelessWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Using the localization extension for easy access
    final l10n = context.l10n;
    
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.appTitle ?? 'My App'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.welcome ?? 'Welcome!',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 16),
            Text(
              l10n.description ?? 'This app supports multiple languages.',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 32),
            
            // Example of using localization with parameters
            if (l10n.userGreeting != null)
              Text(
                l10n.userGreeting!.replaceAll('{name}', 'Flutter Developer'),
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            
            const SizedBox(height: 32),
            
            // Language selector example
            const LanguageSelector(),
          ],
        ),
      ),
    );
  }
}

class LanguageSelector extends StatelessWidget {
  const LanguageSelector({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.selectLanguage ?? 'Select Language:',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: AppLocalizationsExtension.supportedLanguageCodes
              .map((langCode) => ElevatedButton(
                    onPressed: () {
                      // Here you would implement language switching logic
                      // This might involve using a state management solution
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Language switched to: ' + langCode),
                        ),
                      );
                    },
                    child: Text(langCode.toUpperCase()),
                  ))
              .toList(),
        ),
      ],
    );
  }
}

// Example of how to implement locale switching with state management
// You might use Provider, Riverpod, Bloc, or other state management solutions

/*
class LocaleProvider extends ChangeNotifier {
  Locale _locale = const Locale('en');
  
  Locale get locale => _locale;
  
  void setLocale(Locale locale) {
    if (AppLocalizationsExtension.supportedLocales.contains(locale)) {
      _locale = locale;
      notifyListeners();
    }
  }
}
*/
''';

    await exampleFile.writeAsString(exampleContent);

    if (verbose) {
      print('📄 Generated main_example.dart');
    }
  }

  /// Generates a flexible translation service supporting multiple backends
  Future<void> generateTranslationService({
    required List<String> supportedLanguages,
    bool includeFreeServices = true,
    bool includeTemplateApproach = true,
  }) async {
    if (verbose) {
      print('🌍 Generating flexible translation service...');
    }

    await _generateTranslationServiceBase(supportedLanguages);

    if (includeFreeServices) {
      await _generateFreeTranslationProviders();
    }

    if (includeTemplateApproach) {
      await _generateTemplateTranslationProvider();
    }

    await _generateTranslationServiceExample();

    if (verbose) {
      print('✅ Translation service generated successfully!');
    }
  }

  /// Generates the base translation service interface
  Future<void> _generateTranslationServiceBase(
      List<String> supportedLanguages) async {
    final serviceFile = File('$outputDirectory/translation_service.dart');

    final serviceContent = '''
// Flexible translation service supporting multiple free backends
// This service provides a unified interface for different translation providers

import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

/// Translation result containing the translated text and metadata
class TranslationResult {
  final String translatedText;
  final String sourceLanguage;
  final String targetLanguage;
  final String provider;
  final double? confidence;

  const TranslationResult({
    required this.translatedText,
    required this.sourceLanguage,
    required this.targetLanguage,
    required this.provider,
    this.confidence,
  });

  Map<String, dynamic> toJson() => {
    'translatedText': translatedText,
    'sourceLanguage': sourceLanguage,
    'targetLanguage': targetLanguage,
    'provider': provider,
    'confidence': confidence,
  };

  @override
  String toString() => translatedText;
}

/// Abstract base class for translation providers
abstract class TranslationProvider {
  String get name;
  List<String> get supportedLanguages;
  bool get requiresApiKey;
  bool get isOfflineCapable;
  bool get isFree;

  Future<TranslationResult> translate({
    required String text,
    required String targetLanguage,
    String? sourceLanguage,
  });

  Future<bool> isAvailable();
}

/// Main translation service that manages multiple providers
class TranslationService {
  final List<TranslationProvider> _providers = [];
  final List<String> _supportedLanguages;

  TranslationService({
    required List<String> supportedLanguages,
  }) : _supportedLanguages = supportedLanguages;

  /// Supported language codes
  static const List<String> defaultSupportedLanguages = [
    ${supportedLanguages.map((lang) => "'$lang'").join(',\n    ')}
  ];

  /// Add a translation provider
  void addProvider(TranslationProvider provider) {
    _providers.add(provider);
  }

  /// Get all available providers
  List<TranslationProvider> get providers => List.unmodifiable(_providers);

  /// Get free providers only
  List<TranslationProvider> get freeProviders => 
      _providers.where((p) => p.isFree).toList();

  /// Translate text using the best available provider
  Future<TranslationResult> translate({
    required String text,
    required String targetLanguage,
    String? sourceLanguage,
    String? preferredProvider,
  }) async {
    if (text.isEmpty) {
      throw ArgumentError('Text cannot be empty');
    }

    if (!_supportedLanguages.contains(targetLanguage)) {
      throw ArgumentError('Target language "\$targetLanguage" not supported');
    }

    // Try preferred provider first
    if (preferredProvider != null) {
      final provider = _providers.firstWhere(
        (p) => p.name == preferredProvider,
        orElse: () => throw ArgumentError('Provider "\$preferredProvider" not found'),
      );
      
      if (await provider.isAvailable()) {
        return await provider.translate(
          text: text,
          targetLanguage: targetLanguage,
          sourceLanguage: sourceLanguage,
        );
      }
    }

    // Try providers in order of preference (free first, then offline capable)
    final sortedProviders = List<TranslationProvider>.from(_providers)
      ..sort((a, b) {
        if (a.isFree && !b.isFree) return -1;
        if (!a.isFree && b.isFree) return 1;
        if (a.isOfflineCapable && !b.isOfflineCapable) return -1;
        if (!a.isOfflineCapable && b.isOfflineCapable) return 1;
        return 0;
      });

    for (final provider in sortedProviders) {
      if (await provider.isAvailable() && 
          provider.supportedLanguages.contains(targetLanguage)) {
        try {
          return await provider.translate(
            text: text,
            targetLanguage: targetLanguage,
            sourceLanguage: sourceLanguage,
          );
        } catch (e) {
          print('Provider \${provider.name} failed: \$e');
          continue;
        }
      }
    }

    throw Exception('No available translation providers for target language "\$targetLanguage"');
  }

  /// Check if translation is available for the given language pair
  Future<bool> isTranslationAvailable({
    required String targetLanguage,
    String? sourceLanguage,
  }) async {
    for (final provider in _providers) {
      if (await provider.isAvailable() && 
          provider.supportedLanguages.contains(targetLanguage)) {
        return true;
      }
    }
    return false;
  }

  /// Get translation statistics
  Map<String, dynamic> getStatistics() {
    return {
      'totalProviders': _providers.length,
      'freeProviders': freeProviders.length,
      'offlineProviders': _providers.where((p) => p.isOfflineCapable).length,
      'supportedLanguages': _supportedLanguages.length,
      'providers': _providers.map((p) => {
        'name': p.name,
        'free': p.isFree,
        'offline': p.isOfflineCapable,
        'requiresApiKey': p.requiresApiKey,
        'supportedLanguages': p.supportedLanguages.length,
      }).toList(),
    };
  }
}
''';

    await serviceFile.writeAsString(serviceContent);

    if (verbose) {
      print('📄 Generated translation_service.dart');
    }
  }

  /// Generates free translation provider implementations
  Future<void> _generateFreeTranslationProviders() async {
    final providersFile =
        File('$outputDirectory/free_translation_providers.dart');

    final providersContent = '''
// Free translation provider implementations
// This file contains implementations for various free translation services

import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'translation_service.dart';

/// LibreTranslate provider - Free, open source, self-hostable
class LibreTranslateProvider extends TranslationProvider {
  final String apiUrl;
  final String? apiKey;

  LibreTranslateProvider({
    this.apiUrl = 'https://libretranslate.com',
    this.apiKey,
  });

  @override
  String get name => 'LibreTranslate';

  @override
  List<String> get supportedLanguages => [
    'en', 'es', 'fr', 'de', 'it', 'pt', 'ru', 'ja', 'ko', 'zh', 'ar', 'hi'
  ];

  @override
  bool get requiresApiKey => apiKey != null;

  @override
  bool get isOfflineCapable => apiUrl.contains('localhost') || apiUrl.contains('127.0.0.1');

  @override
  bool get isFree => true;

  @override
  Future<bool> isAvailable() async {
    try {
      final response = await http.get(
        Uri.parse(apiUrl + '/languages'),
        headers: apiKey != null ? {'Authorization': 'Bearer ' + apiKey!} : {},
      ).timeout(const Duration(seconds: 5));
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  @override
  Future<TranslationResult> translate({
    required String text,
    required String targetLanguage,
    String? sourceLanguage,
  }) async {
    final body = jsonEncode({
      'q': text,
      'source': sourceLanguage ?? 'auto',
      'target': targetLanguage,
      'format': 'text',
    });

    final response = await http.post(
      Uri.parse(apiUrl + '/translate'),
      headers: {
        'Content-Type': 'application/json',
        if (apiKey != null) 'Authorization': 'Bearer ' + apiKey!,
      },
      body: body,
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return TranslationResult(
        translatedText: data['translatedText'],
        sourceLanguage: sourceLanguage ?? 'auto',
        targetLanguage: targetLanguage,
        provider: name,
      );
    } else {
      throw Exception('LibreTranslate API error: ' + response.body);
    }
  }
}

/// MyMemory provider - Free translation API with generous limits
class MyMemoryProvider extends TranslationProvider {
  @override
  String get name => 'MyMemory';

  @override
  List<String> get supportedLanguages => [
    'en', 'es', 'fr', 'de', 'it', 'pt', 'ru', 'ja', 'ko', 'zh', 'ar', 'hi',
    'nl', 'sv', 'da', 'no', 'fi', 'pl', 'cs', 'hu', 'ro', 'bg', 'hr', 'sk',
    'sl', 'et', 'lv', 'lt', 'mt', 'el', 'tr', 'he', 'th', 'vi', 'id', 'ms'
  ];

  @override
  bool get requiresApiKey => false;

  @override
  bool get isOfflineCapable => false;

  @override
  bool get isFree => true;

  @override
  Future<bool> isAvailable() async {
    try {
      final response = await http.get(
        Uri.parse('https://api.mymemory.translated.net/get?q=test&langpair=en|es'),
      ).timeout(const Duration(seconds: 5));
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  @override
  Future<TranslationResult> translate({
    required String text,
    required String targetLanguage,
    String? sourceLanguage,
  }) async {
    final langPair = (sourceLanguage ?? 'en') + '|' + targetLanguage;
    final encodedText = Uri.encodeComponent(text);
    
    final response = await http.get(
      Uri.parse('https://api.mymemory.translated.net/get?q=' + encodedText + '&langpair=' + langPair),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return TranslationResult(
        translatedText: data['responseData']['translatedText'],
        sourceLanguage: sourceLanguage ?? 'en',
        targetLanguage: targetLanguage,
        provider: name,
        confidence: double.tryParse(data['responseData']['match'].toString()),
      );
    } else {
      throw Exception('MyMemory API error: ' + response.body);
    }
  }
}

/// Offline provider for basic word-level translations using built-in dictionaries
class OfflineDictionaryProvider extends TranslationProvider {
  final Map<String, Map<String, String>> _dictionaries = {};

  OfflineDictionaryProvider() {
    _initializeBasicDictionaries();
  }

  void _initializeBasicDictionaries() {
    // Basic English to Spanish dictionary
    _dictionaries['en-es'] = {
      'hello': 'hola',
      'goodbye': 'adiós',
      'thank you': 'gracias',
      'please': 'por favor',
      'yes': 'sí',
      'no': 'no',
      'welcome': 'bienvenido',
      'home': 'inicio',
      'settings': 'configuración',
      'search': 'buscar',
      'save': 'guardar',
      'cancel': 'cancelar',
      'ok': 'ok',
      'error': 'error',
      'loading': 'cargando',
    };

    // Basic English to French dictionary
    _dictionaries['en-fr'] = {
      'hello': 'bonjour',
      'goodbye': 'au revoir',
      'thank you': 'merci',
      'please': 's\\'il vous plaît',
      'yes': 'oui',
      'no': 'non',
      'welcome': 'bienvenue',
      'home': 'accueil',
      'settings': 'paramètres',
      'search': 'rechercher',
      'save': 'enregistrer',
      'cancel': 'annuler',
      'ok': 'ok',
      'error': 'erreur',
      'loading': 'chargement',
    };

    // Add more basic dictionaries as needed
  }

  @override
  String get name => 'OfflineDictionary';

  @override
  List<String> get supportedLanguages => ['en', 'es', 'fr'];

  @override
  bool get requiresApiKey => false;

  @override
  bool get isOfflineCapable => true;

  @override
  bool get isFree => true;

  @override
  Future<bool> isAvailable() async => true;

  @override
  Future<TranslationResult> translate({
    required String text,
    required String targetLanguage,
    String? sourceLanguage,
  }) async {
    final source = sourceLanguage ?? 'en';
    final dictionaryKey = source + '-' + targetLanguage;
    final dictionary = _dictionaries[dictionaryKey];

    if (dictionary == null) {
      throw Exception('No offline dictionary available for ' + source + ' to ' + targetLanguage);
    }

    final lowerText = text.toLowerCase().trim();
    final translation = dictionary[lowerText] ?? text; // Fallback to original text

    return TranslationResult(
      translatedText: translation,
      sourceLanguage: source,
      targetLanguage: targetLanguage,
      provider: name,
      confidence: dictionary.containsKey(lowerText) ? 1.0 : 0.0,
    );
  }

  /// Add custom dictionary entries
  void addDictionaryEntry({
    required String sourceLanguage,
    required String targetLanguage,
    required String sourceText,
    required String targetText,
  }) {
    final key = sourceLanguage + '-' + targetLanguage;
    _dictionaries.putIfAbsent(key, () => {});
    _dictionaries[key]![sourceText.toLowerCase()] = targetText;
  }
}
''';

    await providersFile.writeAsString(providersContent);

    if (verbose) {
      print('📄 Generated free_translation_providers.dart');
    }
  }

  /// Generates template-based translation provider
  Future<void> _generateTemplateTranslationProvider() async {
    final templateFile =
        File('$outputDirectory/template_translation_provider.dart');

    final templateContent = '''
// Template-based translation provider
// This provider uses user-provided translation templates

import 'translation_service.dart';

/// Template-based provider that uses pre-defined translation mappings
class TemplateTranslationProvider extends TranslationProvider {
  final Map<String, Map<String, String>> _translations = {};

  TemplateTranslationProvider({
    Map<String, Map<String, String>>? initialTranslations,
  }) {
    if (initialTranslations != null) {
      _translations.addAll(initialTranslations);
    }
  }

  @override
  String get name => 'Template';

  @override
  List<String> get supportedLanguages => _translations.keys.toList();

  @override
  bool get requiresApiKey => false;

  @override
  bool get isOfflineCapable => true;

  @override
  bool get isFree => true;

  @override
  Future<bool> isAvailable() async => _translations.isNotEmpty;

  @override
  Future<TranslationResult> translate({
    required String text,
    required String targetLanguage,
    String? sourceLanguage,
  }) async {
    final translations = _translations[targetLanguage];
    
    if (translations == null) {
      throw Exception('No template translations available for language: ' + targetLanguage);
    }

    final translation = translations[text] ?? text; // Fallback to original text

    return TranslationResult(
      translatedText: translation,
      sourceLanguage: sourceLanguage ?? 'en',
      targetLanguage: targetLanguage,
      provider: name,
      confidence: translations.containsKey(text) ? 1.0 : 0.0,
    );
  }

  /// Add translation for a specific language
  void addTranslation({
    required String languageCode,
    required String key,
    required String translation,
  }) {
    _translations.putIfAbsent(languageCode, () => {});
    _translations[languageCode]![key] = translation;
  }

  /// Add multiple translations for a language
  void addTranslations({
    required String languageCode,
    required Map<String, String> translations,
  }) {
    _translations.putIfAbsent(languageCode, () => {});
    _translations[languageCode]!.addAll(translations);
  }

  /// Load translations from JSON structure
  void loadFromJson(Map<String, dynamic> json) {
    for (final entry in json.entries) {
      final languageCode = entry.key;
      final translations = Map<String, String>.from(entry.value);
      addTranslations(languageCode: languageCode, translations: translations);
    }
  }

  /// Get all available translations for debugging
  Map<String, Map<String, String>> getAllTranslations() => Map.from(_translations);
}
''';

    await templateFile.writeAsString(templateContent);

    if (verbose) {
      print('📄 Generated template_translation_provider.dart');
    }
  }

  /// Generates example usage of the translation service
  Future<void> _generateTranslationServiceExample() async {
    final exampleFile = File('$outputDirectory/translation_example.dart');

    final exampleContent = '''
// Example usage of the flexible translation service
// This demonstrates how to set up and use multiple translation providers

import 'translation_service.dart';
import 'free_translation_providers.dart';
import 'template_translation_provider.dart';

/// Example class showing how to set up and use the translation service
class TranslationServiceExample {
  late final TranslationService _translationService;

  /// Initialize the translation service with multiple providers
  Future<void> initialize() async {
    _translationService = TranslationService(
      supportedLanguages: ['en', 'es', 'fr', 'de', 'it', 'pt', 'ru', 'ja', 'ko', 'zh'],
    );

    // Add template provider (highest priority - most accurate)
    final templateProvider = TemplateTranslationProvider();
    _addSampleTranslations(templateProvider);
    _translationService.addProvider(templateProvider);

    // Add offline dictionary provider (good for common words)
    _translationService.addProvider(OfflineDictionaryProvider());

    // Add LibreTranslate provider (requires internet, but free)
    _translationService.addProvider(LibreTranslateProvider());

    // Add MyMemory provider (backup free service)
    _translationService.addProvider(MyMemoryProvider());

    print('Translation service initialized with providers:');
    for (final provider in _translationService.providers) {
      print('- ' + provider.name + ' (free: ' + provider.isFree.toString() + 
            ', offline: ' + provider.isOfflineCapable.toString() + ')');
    }
  }

  /// Add sample translations to the template provider
  void _addSampleTranslations(TemplateTranslationProvider provider) {
    // Spanish translations
    provider.addTranslations(
      languageCode: 'es',
      translations: {
        'Welcome': 'Bienvenido',
        'Hello': 'Hola',
        'Goodbye': 'Adiós',
        'Thank you': 'Gracias',
        'Settings': 'Configuración',
        'Home': 'Inicio',
        'Search': 'Buscar',
        'Save': 'Guardar',
        'Cancel': 'Cancelar',
        'Loading': 'Cargando',
        'Error': 'Error',
      },
    );

    // French translations
    provider.addTranslations(
      languageCode: 'fr',
      translations: {
        'Welcome': 'Bienvenue',
        'Hello': 'Bonjour',
        'Goodbye': 'Au revoir',
        'Thank you': 'Merci',
        'Settings': 'Paramètres',
        'Home': 'Accueil',
        'Search': 'Rechercher',
        'Save': 'Enregistrer',
        'Cancel': 'Annuler',
        'Loading': 'Chargement',
        'Error': 'Erreur',
      },
    );

    // German translations
    provider.addTranslations(
      languageCode: 'de',
      translations: {
        'Welcome': 'Willkommen',
        'Hello': 'Hallo',
        'Goodbye': 'Auf Wiedersehen',
        'Thank you': 'Danke',
        'Settings': 'Einstellungen',
        'Home': 'Startseite',
        'Search': 'Suchen',
        'Save': 'Speichern',
        'Cancel': 'Abbrechen',
        'Loading': 'Wird geladen',
        'Error': 'Fehler',
      },
    );
  }

  /// Example of translating text
  Future<void> demonstrateTranslation() async {
    final textsToTranslate = ['Welcome', 'Hello', 'Thank you', 'Settings'];
    final targetLanguages = ['es', 'fr', 'de'];

    for (final text in textsToTranslate) {
      print('\\nTranslating: "' + text + '"');
      
      for (final targetLang in targetLanguages) {
        try {
          final result = await _translationService.translate(
            text: text,
            targetLanguage: targetLang,
          );
          
          print('  ' + targetLang + ': "' + result.translatedText + 
                '" (via ' + result.provider + ')');
        } catch (e) {
          print('  ' + targetLang + ': Failed - ' + e.toString());
        }
      }
    }
  }

  /// Get translation service statistics
  void printStatistics() {
    final stats = _translationService.getStatistics();
    print('\\nTranslation Service Statistics:');
    print('- Total providers: ' + stats['totalProviders'].toString());
    print('- Free providers: ' + stats['freeProviders'].toString());
    print('- Offline providers: ' + stats['offlineProviders'].toString());
    print('- Supported languages: ' + stats['supportedLanguages'].toString());
  }
}

/// Main function to demonstrate the translation service
Future<void> main() async {
  final example = TranslationServiceExample();
  
  try {
    await example.initialize();
    await example.demonstrateTranslation();
    example.printStatistics();
  } catch (e) {
    print('Error: ' + e.toString());
  }
}
''';

    await exampleFile.writeAsString(exampleContent);

    if (verbose) {
      print('📄 Generated translation_example.dart');
    }
  }

  /// Generates comprehensive documentation for the localization package
  Future<void> generateDocumentation() async {
    if (verbose) {
      print('📚 Generating comprehensive documentation...');
    }

    await _generateReadme();
    await _generateTranslationGuide();

    if (verbose) {
      print('✅ Documentation generated successfully!');
    }
  }

  /// Generates a comprehensive README file
  Future<void> _generateReadme() async {
    final readmeFile = File('$outputDirectory/README.md');

    final readmeContent = '''
# Flutter Localization Checker - Complete Localization Solution

A comprehensive, free Flutter package that provides automated localization setup with multiple translation backends. Perfect for developers who want to internationalize their apps without breaking the bank!

## 🌟 Features

- ✅ **Completely Free** - No subscription fees or API costs
- 🌍 **Multiple Translation Backends** - Choose what works best for you
- 🔄 **Automated Code Generation** - Complete Flutter localization setup
- 📱 **Offline Support** - Works without internet when needed
- 🎯 **Template-Based** - Use community translations or your own
- 🚀 **Easy Setup** - Get started in minutes

## 🎯 Translation Solutions

### 1. Template-Based (Recommended for Free Package)
**Perfect for open-source projects and community-driven translations**

- ✅ **100% Free** - No API costs
- ✅ **High Quality** - Human translations
- ✅ **Community Driven** - Users can contribute translations
- ✅ **Offline** - No internet required

### 2. LibreTranslate (Best Free API)
**Self-hostable, open-source translation service**

- ✅ **Free & Open Source**
- ✅ **Self-hostable** - Deploy your own instance
- ✅ **Privacy-focused** - Keep data private
- ✅ **No API limits** when self-hosted
- 🌐 **Public instance available** at libretranslate.com

### 3. MyMemory API (Backup Free Service)
**Free translation API with generous limits**

- ✅ **1000 requests/day** free
- ✅ **No API key required**
- ✅ **Good quality** translations
- 🌐 **Wide language support**

### 4. Offline Dictionary (Basic Words)
**Built-in translations for common app terms**

- ✅ **Completely offline**
- ✅ **Instant translations**
- ✅ **Perfect for UI elements**
- 📝 **Expandable** - Add your own terms

## 🚀 Quick Start

### 1. Generate Localization Setup

```dart
import 'package:your_package/automation/code_generator.dart';

final generator = LocalizationCodeGenerator(
  projectPath: '/path/to/your/flutter/project',
  outputDirectory: '/path/to/your/flutter/project/lib/l10n',
  verbose: true,
);

// Generate complete localization setup
await generator.generateCompleteSetup(
  supportedLanguages: ['en', 'es', 'fr', 'de'],
  translations: {
    'en': {
      'welcome': 'Welcome',
      'hello': 'Hello',
      'settings': 'Settings',
    },
    'es': {
      'welcome': 'Bienvenido',
      'hello': 'Hola',
      'settings': 'Configuración',
    },
  },
);

// Generate translation service (optional, for dynamic translations)
await generator.generateTranslationService(
  supportedLanguages: ['en', 'es', 'fr', 'de'],
  includeFreeServices: true,
  includeTemplateApproach: true,
);
```

### 2. Update Your App

Copy the generated code to your Flutter project and update your `main.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'l10n/generated/app_localizations.dart';
import 'l10n/localization_extensions.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Localized Flutter App',
      
      // 🌍 Add these lines for localization
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('en'),
        Locale('es'),
        Locale('fr'),
        Locale('de'),
      ],
      
      home: const HomePage(),
    );
  }
}

class HomePage extends StatelessWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Easy access to localizations
    final l10n = context.l10n;
    
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.welcome ?? 'Welcome'),
      ),
      body: Text(l10n.hello ?? 'Hello'),
    );
  }
}
```

### 3. Use Dynamic Translation (Optional)

For dynamic content or user-generated translations:

```dart
import 'l10n/translation_service.dart';
import 'l10n/free_translation_providers.dart';
import 'l10n/template_translation_provider.dart';

class TranslationManager {
  late final TranslationService _service;

  Future<void> initialize() async {
    _service = TranslationService(
      supportedLanguages: ['en', 'es', 'fr', 'de'],
    );

    // Add template provider (highest priority)
    final templateProvider = TemplateTranslationProvider();
    templateProvider.addTranslations(
      languageCode: 'es',
      translations: {
        'Good morning': 'Buenos días',
        'Good night': 'Buenas noches',
      },
    );
    _service.addProvider(templateProvider);

    // Add LibreTranslate as backup
    _service.addProvider(LibreTranslateProvider());
  }

  Future<String> translate(String text, String targetLanguage) async {
    final result = await _service.translate(
      text: text,
      targetLanguage: targetLanguage,
    );
    return result.translatedText;
  }
}
```

## 💡 Cost Comparison

| Solution | Cost | Quality | Offline | API Limits |
|----------|------|---------|---------|------------|
| **Template-Based** | 🆓 Free | ⭐⭐⭐⭐⭐ Excellent | ✅ Yes | ❌ None |
| **LibreTranslate (Self-hosted)** | 🆓 Free* | ⭐⭐⭐⭐ Very Good | ✅ Yes | ❌ None |
| **LibreTranslate (Public)** | 🆓 Free | ⭐⭐⭐⭐ Very Good | ❌ No | ⚠️ Rate limited |
| **MyMemory** | 🆓 Free | ⭐⭐⭐ Good | ❌ No | ⚠️ 1000/day |
| **Google Translate** | 💰 \$20/1M chars | ⭐⭐⭐⭐⭐ Excellent | ❌ No | 💰 Paid |

*Self-hosting costs depend on your server setup

## 🛠️ Self-Hosting LibreTranslate (Recommended for Production)

### Using Docker

```bash
# Run LibreTranslate locally
docker run -ti --rm -p 5000:5000 libretranslate/libretranslate

# Your app can now use: http://localhost:5000
```

### Using Docker Compose

```yaml
version: '3.8'
services:
  libretranslate:
    image: libretranslate/libretranslate
    ports:
      - "5000:5000"
    environment:
      - LT_DISABLE_WEB_UI=false
    volumes:
      - ./data:/app/db
```

## 📁 Generated Files

After running the generator, you'll get:

```
lib/l10n/
├── en.arb                           # English translations
├── es.arb                           # Spanish translations  
├── fr.arb                           # French translations
├── generated/
│   └── app_localizations.dart       # Auto-generated by Flutter
├── localization_extensions.dart     # Convenient extensions
├── localization_config.dart         # Configuration helpers
├── app_localization_setup.dart      # Complete setup example
├── translation_service.dart         # Dynamic translation service
├── free_translation_providers.dart  # Free API implementations
├── template_translation_provider.dart # Template-based translations
├── translation_example.dart         # Usage examples
├── main_example.dart                # Example main.dart
└── README.md                        # This documentation

l10n.yaml                           # Flutter localization config
pubspec.yaml                        # Updated with dependencies
```

## 🌍 Supported Languages

The package supports all major languages including:

- **European**: English, Spanish, French, German, Italian, Portuguese, Dutch, Russian
- **Asian**: Chinese, Japanese, Korean, Hindi, Arabic, Thai, Vietnamese
- **Others**: 30+ additional languages depending on the provider

## 🤝 Community Translations

For the template-based approach, we encourage community contributions:

1. **Fork** the repository
2. **Add translations** in your language
3. **Submit a PR** with your translations
4. **Help others** by reviewing translations

### Translation Template

```json
{
  "es": {
    "welcome": "Bienvenido",
    "hello": "Hola",
    "goodbye": "Adiós",
    "settings": "Configuración",
    "save": "Guardar",
    "cancel": "Cancelar"
  }
}
```

## 🔧 Advanced Configuration

### Custom LibreTranslate Instance

```dart
final provider = LibreTranslateProvider(
  apiUrl: 'https://your-libretranslate-instance.com',
  apiKey: 'your-optional-api-key',
);
```

### Offline-First Configuration

```dart
// Prioritize offline providers
_service.addProvider(TemplateTranslationProvider()); // First
_service.addProvider(OfflineDictionaryProvider());   // Second
_service.addProvider(LibreTranslateProvider());      // Online backup
```

### Language Detection

```dart
final result = await _service.translate(
  text: 'Hello world',
  targetLanguage: 'es',
  sourceLanguage: 'auto', // Auto-detect source language
);
```

## 🐛 Troubleshooting

### Common Issues

1. **"No provider available"**
   - Ensure at least one provider is configured
   - Check internet connection for online providers
   - Verify LibreTranslate instance is running

2. **"Target language not supported"**
   - Check if the language code is in your supported languages list
   - Verify the provider supports that language

3. **Poor translation quality**
   - Use template-based approach for important UI text
   - Combine multiple providers for fallback
   - Consider professional translation for critical content

### Debug Mode

```dart
final generator = LocalizationCodeGenerator(
  projectPath: projectPath,
  outputDirectory: outputDirectory,
  verbose: true, // Enable detailed logging
);
```

## 📚 Additional Resources

- [Flutter Internationalization Guide](https://flutter.dev/docs/development/accessibility-and-localization/internationalization)
- [LibreTranslate Documentation](https://libretranslate.com/docs)
- [ARB File Format](https://github.com/google/app-resource-bundle/wiki/ApplicationResourceBundleSpecification)

## 🤝 Contributing

We welcome contributions! Please see our [Contributing Guide](CONTRIBUTING.md) for details.

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## ⭐ Support

If this package helps you, please give it a star! ⭐

For issues and feature requests, please use the [GitHub Issues](https://github.com/your-repo/issues) page.
''';

    await readmeFile.writeAsString(readmeContent);

    if (verbose) {
      print('📄 Generated README.md');
    }
  }

  /// Generates a detailed translation guide
  Future<void> _generateTranslationGuide() async {
    final guideFile = File('$outputDirectory/TRANSLATION_GUIDE.md');

    final guideContent = '''
# Translation Guide

This guide explains the different translation approaches and how to choose the best one for your use case.

## 🎯 Translation Strategies

### 1. Template-Based Translations (Recommended for Free Packages)

**When to use:**
- Open source projects
- Community-driven applications
- When you want 100% accurate UI translations
- Offline-first applications

**How it works:**
- Pre-defined translation mappings
- Human-verified translations
- Community contributions
- No API costs

**Example setup:**
```dart
final templateProvider = TemplateTranslationProvider();

// Add Spanish translations
templateProvider.addTranslations(
  languageCode: 'es',
  translations: {
    'Welcome to our app': 'Bienvenido a nuestra aplicación',
    'Sign in': 'Iniciar sesión',
    'Sign up': 'Registrarse',
    'Settings': 'Configuración',
  },
);
```

### 2. LibreTranslate (Best Free API Option)

**When to use:**
- Dynamic content translation
- User-generated content
- When you can self-host
- Privacy-sensitive applications

**Advantages:**
- Completely free when self-hosted
- Good quality translations
- Privacy-focused
- Open source

**Setup:**
```bash
# Self-host with Docker
docker run -ti --rm -p 5000:5000 libretranslate/libretranslate
```

```dart
final provider = LibreTranslateProvider(
  apiUrl: 'http://localhost:5000', // Your instance
);
```

### 3. MyMemory API (Backup Free Service)

**When to use:**
- As a backup for LibreTranslate
- Low-volume applications
- Testing and development

**Limitations:**
- 1000 requests per day (free tier)
- No API key required
- Good for basic needs

### 4. Hybrid Approach (Recommended)

Combine multiple approaches for the best results:

```dart
// Priority order (highest to lowest)
_service.addProvider(TemplateTranslationProvider()); // Accurate UI text
_service.addProvider(OfflineDictionaryProvider());   // Common words offline
_service.addProvider(LibreTranslateProvider());      // Dynamic content
_service.addProvider(MyMemoryProvider());            // Backup service
```

## 🏗️ Implementation Guide

### Step 1: Generate Base Localization

```dart
final generator = LocalizationCodeGenerator(
  projectPath: 'path/to/your/project',
  outputDirectory: 'path/to/your/project/lib/l10n',
);

await generator.generateCompleteSetup(
  supportedLanguages: ['en', 'es', 'fr', 'de'],
  translations: yourInitialTranslations,
);
```

### Step 2: Add Translation Service (Optional)

```dart
await generator.generateTranslationService(
  supportedLanguages: ['en', 'es', 'fr', 'de'],
  includeFreeServices: true,
  includeTemplateApproach: true,
);
```

### Step 3: Set Up Providers

```dart
class AppTranslationService {
  late final TranslationService _service;
  
  Future<void> initialize() async {
    _service = TranslationService(
      supportedLanguages: ['en', 'es', 'fr', 'de'],
    );
    
    // Add template provider with your translations
    final templates = await _loadTemplateTranslations();
    _service.addProvider(TemplateTranslationProvider(
      initialTranslations: templates,
    ));
    
    // Add other providers as needed
    _service.addProvider(OfflineDictionaryProvider());
    _service.addProvider(LibreTranslateProvider());
  }
  
  Future<Map<String, Map<String, String>>> _loadTemplateTranslations() async {
    // Load from assets, network, or hard-coded
    return {
      'es': {
        'Welcome': 'Bienvenido',
        'Hello': 'Hola',
        // ... more translations
      },
      'fr': {
        'Welcome': 'Bienvenue',
        'Hello': 'Bonjour',
        // ... more translations
      },
    };
  }
}
```

## 🌟 Best Practices

### 1. Prioritize Template Translations

Use template translations for:
- App navigation (Home, Settings, Back, etc.)
- Common actions (Save, Cancel, Delete, etc.)
- Error messages
- Status messages (Loading, Success, Error, etc.)

### 2. Use APIs for Dynamic Content

Use translation APIs for:
- User-generated content
- Dynamic messages
- Content from external sources
- Real-time chat translations

### 3. Implement Graceful Fallbacks

```dart
Future<String> getTranslation(String text, String targetLang) async {
  try {
    // Try translation service
    final result = await translationService.translate(
      text: text,
      targetLanguage: targetLang,
    );
    return result.translatedText;
  } catch (e) {
    // Fallback to original text
    return text;
  }
}
```

### 4. Cache Translations

```dart
class TranslationCache {
  final Map<String, String> _cache = {};
  
  Future<String> translate(String text, String targetLang) async {
    final key = '\$text-\$targetLang';
    
    if (_cache.containsKey(key)) {
      return _cache[key]!;
    }
    
    final translation = await _performTranslation(text, targetLang);
    _cache[key] = translation;
    return translation;
  }
}
```

## 🚀 Performance Optimization

### 1. Lazy Loading

```dart
// Load translations only when needed
class LazyTranslationProvider extends TranslationProvider {
  Map<String, Map<String, String>>? _translations;
  
  @override
  Future<TranslationResult> translate({
    required String text,
    required String targetLanguage,
    String? sourceLanguage,
  }) async {
    _translations ??= await _loadTranslations();
    // ... translation logic
  }
}
```

### 2. Batch Translations

```dart
// Translate multiple texts at once
Future<List<TranslationResult>> translateBatch(
  List<String> texts,
  String targetLanguage,
) async {
  // Implementation depends on provider capabilities
}
```

### 3. Background Translation

```dart
// Pre-translate common content
class BackgroundTranslator {
  Future<void> preloadCommonTranslations() async {
    final commonTexts = ['Welcome', 'Hello', 'Settings', /* ... */];
    final languages = ['es', 'fr', 'de'];
    
    for (final lang in languages) {
      for (final text in commonTexts) {
        // Translate and cache in background
        _translateAndCache(text, lang);
      }
    }
  }
}
```

## 🔧 Troubleshooting

### Translation Quality Issues

1. **Use template translations for important UI text**
2. **Verify translations with native speakers**
3. **Implement user feedback for translations**
4. **Use context-aware translation keys**

### Performance Issues

1. **Implement caching**
2. **Use batch translation when possible**
3. **Preload common translations**
4. **Optimize network requests**

### Provider Failures

1. **Always have fallback providers**
2. **Implement retry logic**
3. **Monitor provider availability**
4. **Use offline providers as backup**

## 📊 Monitoring and Analytics

### Track Translation Usage

```dart
class TranslationAnalytics {
  void trackTranslation({
    required String text,
    required String sourceLanguage,
    required String targetLanguage,
    required String provider,
    required bool success,
  }) {
    // Log to your analytics service
  }
}
```

### Monitor Provider Health

```dart
class ProviderHealthMonitor {
  Future<void> checkProviderHealth() async {
    for (final provider in translationService.providers) {
      final isAvailable = await provider.isAvailable();
      if (!isAvailable) {
        // Log warning or switch providers
      }
    }
  }
}
```

## 🌍 Language-Specific Considerations

### Right-to-Left Languages (Arabic, Hebrew)

```dart
extension LocalizationExtension on BuildContext {
  bool get isRTL => Directionality.of(this) == TextDirection.rtl;
  
  TextDirection get textDirection => 
    isRTL ? TextDirection.rtl : TextDirection.ltr;
}
```

### Pluralization

```dart
// Use ICU message format for plurals
String getQuantityString(int count, AppLocalizations l10n) {
  return l10n.itemCount(count); // Defined in ARB with plural rules
}
```

### Cultural Considerations

- Date and time formats
- Number formatting
- Currency display
- Color symbolism
- Image appropriateness

## 🎯 Migration Guide

### From Hard-Coded Strings

1. **Extract strings to translation keys**
2. **Generate ARB files**
3. **Update widget code to use l10n**
4. **Test all languages**

### From Other Translation Solutions

1. **Export existing translations**
2. **Convert to ARB format**
3. **Update code to use generated localizations**
4. **Verify functionality**

This guide should help you choose and implement the best translation strategy for your Flutter app!
''';

    await guideFile.writeAsString(guideContent);

    if (verbose) {
      print('📄 Generated TRANSLATION_GUIDE.md');
    }
  }
}
