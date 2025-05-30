import 'dart:convert';
import 'dart:io';

import 'analytics/coverage_analytics.dart';
import 'automation/code_generator.dart';
import 'automation/translation_service.dart';
import 'checker.dart';
import 'config.dart';
import 'enhanced_patterns/widget_pattern_detector.dart';
import 'models/models.dart';

/// Enhanced localization checker with end-to-end automation capabilities
class EnhancedLocalizationChecker {
  final LocalizationCheckerConfig config;
  final EnhancedLocalizationConfig enhancedConfig;
  final bool verbose;

  late final LocalizationChecker _baseChecker;
  late final EnhancedWidgetPatternDetector _patternDetector;
  late final CoverageAnalytics _analytics;

  EnhancedLocalizationChecker({
    required this.config,
    required this.enhancedConfig,
    this.verbose = false,
  }) {
    _baseChecker = LocalizationChecker(config: config);
    _patternDetector =
        EnhancedWidgetPatternDetector(config: config, verbose: verbose);
    _analytics =
        CoverageAnalytics(projectPath: config.projectPath, verbose: verbose);
  }

  /// Runs the complete enhanced localization checking and automation process
  Future<EnhancedLocalizationResult> runComplete({
    bool generateArb = true,
    bool autoTranslate = false,
    bool generateAnalytics = true,
    bool generateCode = false,
    String? arbOutputDir,
  }) async {
    if (verbose) {
      print('🚀 Starting enhanced localization checking...');
    }

    // Phase 1: Run base localization check with enhanced patterns
    if (verbose) {
      print('📝 Phase 1: Detecting non-localized strings...');
    }
    await _baseChecker.run(
        generateArb: generateArb, arbOutputDir: arbOutputDir);
    final nonLocalizedStrings = _baseChecker.results;

    // Phase 2: Generate analytics
    LocalizationAnalytics? analytics;
    if (generateAnalytics) {
      if (verbose) {
        print('📊 Phase 2: Generating analytics...');
      }
      analytics = await _generateAnalytics(nonLocalizedStrings);
    }

    // Phase 3: Auto-translation if enabled
    Map<String, Map<String, dynamic>>? translatedArbs;
    if (autoTranslate &&
        enhancedConfig.enableAutoTranslation &&
        enhancedConfig.translationApiKey.isNotEmpty) {
      if (verbose) {
        print('🌍 Phase 3: Auto-translating to multiple languages...');
      }
      translatedArbs =
          await _performAutoTranslation(arbOutputDir ?? config.projectPath);
    }

    // Phase 4: Code generation if enabled
    if (generateCode && enhancedConfig.enableCodeGeneration) {
      if (verbose) {
        print('🏗️ Phase 4: Generating localization code...');
      }
      await _generateCode(translatedArbs);
    }

    if (verbose) {
      print('✅ Enhanced localization checking completed!');
    }

    return EnhancedLocalizationResult(
      nonLocalizedStrings: nonLocalizedStrings,
      analytics: analytics,
      translatedArbs: translatedArbs,
      generatedFiles: [], // Would be populated by code generation
    );
  }

  /// Runs incremental checking for continuous integration
  Future<IncrementalCheckResult> runIncremental({
    required List<String> changedFiles,
    String? baselineReportPath,
  }) async {
    if (verbose) {
      print('🔄 Running incremental localization check...');
    }

    // Filter to only check changed files
    final filteredConfig = LocalizationCheckerConfig(
      projectPath: config.projectPath,
      scanPaths: changedFiles,
      excludeDirs: config.excludeDirs,
      excludeFiles: config.excludeFiles,
      customUiPatterns: config.customUiPatterns,
      verbose: config.verbose,
    );

    final incrementalChecker = LocalizationChecker(config: filteredConfig);
    await incrementalChecker.run();

    final newIssues = incrementalChecker.results;
    final previousIssues = await _loadPreviousIssues(baselineReportPath);

    return IncrementalCheckResult(
      newIssues: newIssues,
      resolvedIssues: _findResolvedIssues(previousIssues, newIssues),
      changedFiles: changedFiles,
    );
  }

  /// Generates comprehensive analytics
  Future<LocalizationAnalytics> _generateAnalytics(
      List<NonLocalizedString> nonLocalizedStrings) async {
    final existingTranslations = await _loadExistingTranslations();
    final dartFiles = await _collectAllDartFiles();

    return await _analytics.generateAnalytics(
      nonLocalizedStrings: nonLocalizedStrings,
      existingTranslations: existingTranslations,
      dartFiles: dartFiles,
    );
  }

  /// Performs auto-translation using configured service
  Future<Map<String, Map<String, dynamic>>> _performAutoTranslation(
      String arbOutputDir) async {
    final sourceArbPath = '$arbOutputDir/en.arb';
    final sourceArbFile = File(sourceArbPath);

    if (!sourceArbFile.existsSync()) {
      if (verbose) {
        print('⚠️ Source ARB file not found at $sourceArbPath');
      }
      return {};
    }

    final sourceArbContent = await sourceArbFile.readAsString();
    final sourceArb = jsonDecode(sourceArbContent) as Map<String, dynamic>;

    final translationService = TranslationService(
      apiKey: enhancedConfig.translationApiKey,
      provider: _getTranslationProvider(enhancedConfig.translationProvider),
      verbose: verbose,
    );

    final translatedArbs = await translationService.translateArbToLanguages(
      sourceArb: sourceArb,
      targetLanguages: enhancedConfig.targetLanguages,
    );

    // Save translated ARB files
    for (final entry in translatedArbs.entries) {
      final language = entry.key;
      final translatedArb = entry.value;

      final outputFile = File('$arbOutputDir/$language.arb');
      await outputFile.writeAsString(
        JsonEncoder.withIndent('  ').convert(translatedArb),
      );

      if (verbose) {
        print('💾 Saved translated ARB: $language.arb');
      }
    }

    return translatedArbs;
  }

  /// Generates complete localization code setup
  Future<void> _generateCode(
      Map<String, Map<String, dynamic>>? translations) async {
    final codeGenerator = LocalizationCodeGenerator(
      projectPath: config.projectPath,
      outputDirectory: enhancedConfig.outputDirectory,
      verbose: verbose,
    );

    final supportedLanguages = ['en', ...enhancedConfig.targetLanguages];
    final translationsMap = translations ?? await _loadAllTranslations();

    await codeGenerator.generateCompleteSetup(
      supportedLanguages: supportedLanguages,
      translations: translationsMap,
    );
  }

  /// Loads existing translations from ARB files
  Future<Map<String, List<String>>> _loadExistingTranslations() async {
    final translations = <String, List<String>>{};
    final l10nDir = Directory(enhancedConfig.outputDirectory);

    if (!l10nDir.existsSync()) {
      return translations;
    }

    await for (final entity in l10nDir.list()) {
      if (entity is File && entity.path.endsWith('.arb')) {
        try {
          final content = await entity.readAsString();
          final arbData = jsonDecode(content) as Map<String, dynamic>;
          final language = entity.path.split('/').last.replaceAll('.arb', '');

          final keys =
              arbData.keys.where((key) => !key.startsWith('@')).toList();
          translations[language] = keys;
        } catch (e) {
          if (verbose) {
            print('⚠️ Error loading ARB file ${entity.path}: $e');
          }
        }
      }
    }

    return translations;
  }

  /// Loads all translation ARB files as maps
  Future<Map<String, Map<String, dynamic>>> _loadAllTranslations() async {
    final translations = <String, Map<String, dynamic>>{};
    final l10nDir = Directory(enhancedConfig.outputDirectory);

    if (!l10nDir.existsSync()) {
      return translations;
    }

    await for (final entity in l10nDir.list()) {
      if (entity is File && entity.path.endsWith('.arb')) {
        try {
          final content = await entity.readAsString();
          final arbData = jsonDecode(content) as Map<String, dynamic>;
          final language = entity.path.split('/').last.replaceAll('.arb', '');
          translations[language] = arbData;
        } catch (e) {
          if (verbose) {
            print('⚠️ Error loading ARB file ${entity.path}: $e');
          }
        }
      }
    }

    return translations;
  }

  /// Collects all Dart files in the project
  Future<List<String>> _collectAllDartFiles() async {
    final dartFiles = <String>[];

    for (final scanPath in config.scanPaths) {
      final dir = Directory(scanPath);
      if (dir.existsSync()) {
        await for (final entity in dir.list(recursive: true)) {
          if (entity is File && entity.path.endsWith('.dart')) {
            dartFiles.add(entity.path);
          }
        }
      }
    }

    return dartFiles;
  }

  /// Loads previous issues for incremental checking
  Future<List<NonLocalizedString>> _loadPreviousIssues(
      String? baselineReportPath) async {
    if (baselineReportPath == null) {
      return [];
    }

    try {
      final file = File(baselineReportPath);
      if (!file.existsSync()) {
        return [];
      }

      final content = await file.readAsString();
      final jsonData = jsonDecode(content) as Map<String, dynamic>;
      final issuesJson = jsonData['issues'] as List<dynamic>? ?? [];

      return issuesJson
          .map((issue) => NonLocalizedString(
                filePath: issue['filePath'] as String,
                lineNumber: issue['lineNumber'] as int,
                content: issue['content'] as String,
                context: (issue['context'] as List<dynamic>).cast<String>(),
              ))
          .toList();
    } catch (e) {
      if (verbose) {
        print('⚠️ Error loading previous issues: $e');
      }
      return [];
    }
  }

  /// Finds resolved issues by comparing old and new
  List<NonLocalizedString> _findResolvedIssues(
    List<NonLocalizedString> previousIssues,
    List<NonLocalizedString> currentIssues,
  ) {
    final currentIssueKeys = currentIssues
        .map(
            (issue) => '${issue.filePath}:${issue.lineNumber}:${issue.content}')
        .toSet();

    return previousIssues.where((previousIssue) {
      final key =
          '${previousIssue.filePath}:${previousIssue.lineNumber}:${previousIssue.content}';
      return !currentIssueKeys.contains(key);
    }).toList();
  }

  /// Converts string provider name to enum
  TranslationProvider _getTranslationProvider(String provider) {
    switch (provider.toLowerCase()) {
      case 'google':
        return TranslationProvider.googleTranslate;
      case 'deepl':
        return TranslationProvider.deepL;
      case 'azure':
        return TranslationProvider.azure;
      case 'aws':
        return TranslationProvider.aws;
      case 'libre':
        return TranslationProvider.libre;
      default:
        return TranslationProvider.googleTranslate;
    }
  }

  /// Exports comprehensive report
  Future<void> exportComprehensiveReport({
    required EnhancedLocalizationResult result,
    required String outputPath,
  }) async {
    final reportData = {
      'timestamp': DateTime.now().toIso8601String(),
      'project_path': config.projectPath,
      'configuration': {
        'enhanced_features': {
          'auto_translation': enhancedConfig.enableAutoTranslation,
          'analytics': enhancedConfig.enableAnalytics,
          'code_generation': enhancedConfig.enableCodeGeneration,
          'target_languages': enhancedConfig.targetLanguages,
        },
        'scan_paths': config.scanPaths,
        'custom_ui_patterns': config.customUiPatterns,
      },
      'results': {
        'non_localized_strings': result.nonLocalizedStrings
            .map((s) => {
                  'file': s.filePath,
                  'line': s.lineNumber,
                  'content': s.content,
                  'context': s.context,
                })
            .toList(),
        'analytics': result.analytics != null
            ? {
                'coverage_percentage': result.analytics!.coveragePercentage,
                'total_strings': result.analytics!.totalStringsFound,
                'complexity_score': result.analytics!.complexityScore,
                'recommendations': result.analytics!.recommendations,
              }
            : null,
        'translations': result.translatedArbs?.keys.toList(),
      },
    };

    final file = File(outputPath);
    await file.writeAsString(JsonEncoder.withIndent('  ').convert(reportData));

    if (verbose) {
      print('📄 Comprehensive report exported to: $outputPath');
    }
  }
}

/// Result of enhanced localization checking
class EnhancedLocalizationResult {
  final List<NonLocalizedString> nonLocalizedStrings;
  final LocalizationAnalytics? analytics;
  final Map<String, Map<String, dynamic>>? translatedArbs;
  final List<String> generatedFiles;

  EnhancedLocalizationResult({
    required this.nonLocalizedStrings,
    this.analytics,
    this.translatedArbs,
    required this.generatedFiles,
  });
}

/// Result of incremental checking
class IncrementalCheckResult {
  final List<NonLocalizedString> newIssues;
  final List<NonLocalizedString> resolvedIssues;
  final List<String> changedFiles;

  IncrementalCheckResult({
    required this.newIssues,
    required this.resolvedIssues,
    required this.changedFiles,
  });
}
