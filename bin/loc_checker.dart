import 'dart:io';

import 'package:args/args.dart';
import 'package:loc_checker/checker.dart';
import 'package:loc_checker/config.dart';
import 'package:loc_checker/enhanced_checker.dart';
import 'package:loc_checker/models/models.dart';

void main(List<String> arguments) async {
  final parser = ArgParser()
    ..addFlag('verbose', abbr: 'v', help: 'Enable verbose output')
    ..addFlag('generate-arb',
        help: 'Generate ARB file from non-localized strings')
    ..addFlag('enhanced',
        help: 'Use enhanced mode with advanced features', defaultsTo: false)
    ..addFlag('auto-translate',
        help: 'Auto-translate to multiple languages (requires API key)',
        defaultsTo: false)
    ..addFlag('analytics',
        help: 'Generate comprehensive analytics report', defaultsTo: true)
    ..addFlag('code-generation',
        help: 'Generate localization setup code', defaultsTo: false)
    ..addFlag('incremental',
        help: 'Run incremental check (CI mode)', defaultsTo: false)
    ..addOption('arb-output',
        help: 'Directory to save ARB file', defaultsTo: null)
    ..addOption('scan-paths',
        help: 'Comma-separated paths to scan', defaultsTo: null)
    ..addOption('custom-ui',
        help: 'Comma-separated custom UI patterns', defaultsTo: null)
    ..addOption('output',
        abbr: 'o', help: 'Output file for report', defaultsTo: 'report.txt')
    ..addOption('target-languages',
        help: 'Comma-separated target languages for translation',
        defaultsTo: 'es,fr,de,it')
    ..addOption('translation-provider',
        help: 'Translation provider (google, deepl, azure, libre)',
        defaultsTo: 'google')
    ..addOption('translation-api-key',
        help: 'API key for translation service', defaultsTo: '')
    ..addOption('l10n-output',
        help: 'Output directory for localization files', defaultsTo: 'lib/l10n')
    ..addOption('analytics-output',
        help: 'Output file for analytics JSON',
        defaultsTo: 'localization_analytics.json')
    ..addOption('baseline-report',
        help: 'Baseline report for incremental checking', defaultsTo: null)
    ..addFlag('help',
        abbr: 'h', help: 'Show this help message', negatable: false);

  late final ArgResults args;
  try {
    args = parser.parse(arguments);
  } catch (e) {
    print('Error parsing arguments: $e');
    print(parser.usage);
    exit(1);
  }

  if (args['help'] as bool) {
    print('🌍 Enhanced Flutter Localization Checker v1.1.0');
    print('');
    print(
        'A powerful tool for detecting, analyzing, and automating Flutter app localization.');
    print('');
    print('Usage: loc_checker [options] [project_path]');
    print('');
    print('Basic Options:');
    print(parser.usage);
    print('');
    print('Enhanced Features:');
    print(
        '  --enhanced              Enable advanced pattern detection and features');
    print(
        '  --auto-translate        Automatically translate to multiple languages');
    print(
        '  --analytics             Generate comprehensive localization analytics');
    print(
        '  --code-generation       Generate complete localization setup code');
    print('  --incremental           Run incremental checking for CI/CD');
    print('');
    print('Examples:');
    print('  # Basic usage');
    print('  loc_checker --generate-arb /path/to/flutter/project');
    print('');
    print('  # Enhanced mode with auto-translation');
    print(
        '  loc_checker --enhanced --auto-translate --translation-api-key=YOUR_KEY /path/to/project');
    print('');
    print('  # Full automation with code generation');
    print(
        '  loc_checker --enhanced --auto-translate --code-generation --translation-api-key=YOUR_KEY /path/to/project');
    print('');
    print('  # CI/CD incremental checking');
    print(
        '  loc_checker --incremental --baseline-report=baseline.json /path/to/project');
    print('');
    return;
  }

  final projectPath =
      args.rest.isNotEmpty ? args.rest.first : Directory.current.path;
  final verbose = args['verbose'] as bool;
  final enhanced = args['enhanced'] as bool;

  try {
    if (enhanced) {
      await _runEnhancedMode(args, projectPath, verbose);
    } else {
      await _runBasicMode(args, projectPath, verbose);
    }
  } catch (e) {
    print('❌ Error: $e');
    if (verbose) {
      print('Stack trace: ${StackTrace.current}');
    }
    exit(1);
  }
}

/// Runs the enhanced localization checker with all advanced features
Future<void> _runEnhancedMode(
    ArgResults args, String projectPath, bool verbose) async {
  if (verbose) {
    print('🚀 Running in Enhanced Mode');
  }

  // Parse enhanced configuration
  final enhancedConfig = EnhancedLocalizationConfig(
    enableAutoTranslation: args['auto-translate'] as bool,
    targetLanguages: (args['target-languages'] as String)
        .split(',')
        .map((e) => e.trim())
        .toList(),
    translationApiKey: args['translation-api-key'] as String,
    translationProvider: args['translation-provider'] as String,
    enableAnalytics: args['analytics'] as bool,
    enableCodeGeneration: args['code-generation'] as bool,
    outputDirectory: args['l10n-output'] as String,
  );

  // Parse base configuration
  final config = _createBaseConfig(args, projectPath, verbose);

  // Create enhanced checker
  final enhancedChecker = EnhancedLocalizationChecker(
    config: config,
    enhancedConfig: enhancedConfig,
    verbose: verbose,
  );

  if (args['incremental'] as bool) {
    // Run incremental check for CI/CD
    await _runIncrementalCheck(enhancedChecker, args, verbose);
  } else {
    // Run complete enhanced check
    await _runCompleteEnhancedCheck(enhancedChecker, args, verbose);
  }
}

/// Runs the basic localization checker (legacy mode)
Future<void> _runBasicMode(
    ArgResults args, String projectPath, bool verbose) async {
  if (verbose) {
    print('📝 Running in Basic Mode');
  }

  final config = _createBaseConfig(args, projectPath, verbose);
  final checker = LocalizationChecker(config: config);

  await checker.run(
    generateArb: args['generate-arb'] as bool,
    arbOutputDir: args['arb-output'] as String?,
  );

  // Generate basic report
  final report = ReportGenerator.generate(checker.results);
  final outputFile = File(args['output'] as String);
  await outputFile.writeAsString(report);

  print('Found ${checker.results.length} non-localized strings');
  print('Report saved to: ${outputFile.path}');
}

/// Runs complete enhanced checking with all features
Future<void> _runCompleteEnhancedCheck(
  EnhancedLocalizationChecker checker,
  ArgResults args,
  bool verbose,
) async {
  final result = await checker.runComplete(
    generateArb: args['generate-arb'] as bool,
    autoTranslate: args['auto-translate'] as bool,
    generateAnalytics: args['analytics'] as bool,
    generateCode: args['code-generation'] as bool,
    arbOutputDir: args['arb-output'] as String?,
  );

  // Generate basic report
  final report = ReportGenerator.generate(result.nonLocalizedStrings);
  final outputFile = File(args['output'] as String);
  await outputFile.writeAsString(report);

  // Export comprehensive report
  await checker.exportComprehensiveReport(
    result: result,
    outputPath: args['analytics-output'] as String,
  );

  _printEnhancedSummary(result, args, verbose);
}

/// Runs incremental checking for CI/CD
Future<void> _runIncrementalCheck(
  EnhancedLocalizationChecker checker,
  ArgResults args,
  bool verbose,
) async {
  // For incremental check, we'd typically get changed files from git or CI system
  // For now, we'll scan all files but in a real implementation, you'd pass changed files
  final result = await checker.runIncremental(
    changedFiles: [], // Would be populated from git diff or CI system
    baselineReportPath: args['baseline-report'] as String?,
  );

  print('🔄 Incremental Check Results:');
  print('  New issues: ${result.newIssues.length}');
  print('  Resolved issues: ${result.resolvedIssues.length}');
  print('  Changed files: ${result.changedFiles.length}');

  // Exit with error code if new issues found (for CI/CD)
  if (result.newIssues.isNotEmpty) {
    print('❌ New localization issues found!');
    exit(1);
  } else {
    print('✅ No new localization issues found.');
  }
}

/// Creates base configuration from arguments
LocalizationCheckerConfig _createBaseConfig(
    ArgResults args, String projectPath, bool verbose) {
  return LocalizationCheckerConfig(
    projectPath: projectPath,
    scanPaths: _parseScanPaths(args['scan-paths'] as String?, projectPath),
    excludeDirs: [
      'build',
      '.dart_tool',
      '.git',
      'ios',
      'android',
      'web',
      'windows',
      'macos',
      'linux'
    ],
    excludeFiles: ['.g.dart', '.freezed.dart', '.gr.dart'],
    customUiPatterns: _parseCustomUiPatterns(args['custom-ui'] as String?),
    verbose: verbose,
  );
}

/// Parses scan paths from command line argument
List<String> _parseScanPaths(String? scanPathsArg, String projectPath) {
  if (scanPathsArg != null && scanPathsArg.isNotEmpty) {
    return scanPathsArg.split(',').map((path) => path.trim()).toList();
  }
  return ['$projectPath/lib'];
}

/// Parses custom UI patterns from command line argument
List<String> _parseCustomUiPatterns(String? customUiArg) {
  if (customUiArg != null && customUiArg.isNotEmpty) {
    return customUiArg.split(',').map((pattern) => pattern.trim()).toList();
  }
  return [];
}

/// Prints enhanced summary with all features
void _printEnhancedSummary(
    EnhancedLocalizationResult result, ArgResults args, bool verbose) {
  print('');
  print('🎉 Enhanced Localization Check Complete!');
  print('==========================================');
  print('📊 Results Summary:');
  print('  Non-localized strings: ${result.nonLocalizedStrings.length}');

  if (result.analytics != null) {
    final analytics = result.analytics!;
    print('  Coverage: ${analytics.coveragePercentage.toStringAsFixed(1)}%');
    print('  Complexity score: ${analytics.complexityScore}/100');
    print('  Total strings: ${analytics.totalStringsFound}');
    print('  Duplicate groups: ${analytics.duplicateStrings.length}');
    print('  Unused translations: ${analytics.unusedTranslations.length}');
  }

  if (result.translatedArbs != null) {
    print('  Translated languages: ${result.translatedArbs!.keys.join(', ')}');
  }

  print('');
  print('📄 Generated Files:');
  print('  Basic report: ${args['output']}');
  print('  Analytics report: ${args['analytics-output']}');

  if (args['generate-arb'] as bool) {
    final arbOutput =
        args['arb-output'] as String? ?? args['l10n-output'] as String;
    print('  ARB file: $arbOutput/en.arb');
  }

  if (result.translatedArbs != null) {
    for (final lang in result.translatedArbs!.keys) {
      final arbOutput =
          args['arb-output'] as String? ?? args['l10n-output'] as String;
      print('  Translated ARB: $arbOutput/$lang.arb');
    }
  }

  if (args['code-generation'] as bool) {
    print('  Generated localization code in: ${args['l10n-output']}');
  }

  if (result.analytics?.recommendations.isNotEmpty == true) {
    print('');
    print('💡 Recommendations:');
    for (final recommendation in result.analytics!.recommendations) {
      print('  $recommendation');
    }
  }

  print('');
  print('✨ Enhanced localization checking completed successfully!');

  if (args['auto-translate'] as bool &&
      (args['translation-api-key'] as String).isEmpty) {
    print('');
    print('⚠️  Note: Auto-translation was requested but no API key provided.');
    print('   Add --translation-api-key=YOUR_KEY to enable auto-translation.');
  }
}
