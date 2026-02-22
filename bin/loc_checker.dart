import 'dart:io';

import 'package:args/args.dart';
import 'package:loc_checker/automation/code_converter.dart';
import 'package:loc_checker/checker.dart';
import 'package:loc_checker/config.dart';
import 'package:loc_checker/enhanced_checker.dart';
import 'package:loc_checker/generator/arb_generator.dart';
import 'package:loc_checker/models/models.dart';

void main(List<String> arguments) async {
  final parser = ArgParser()
    // 🎯 Production-ready presets
    ..addFlag('check',
        abbr: 'c', help: 'Check for localization issues (default mode)')
    ..addFlag('fix',
        abbr: 'f', help: 'Automatically fix all localization issues')
    ..addFlag('setup',
        abbr: 's',
        help: 'Complete localization setup for new project (RECOMMENDED)')
    ..addFlag('auto-setup',
        help: 'Fully automated setup with Flutter localization dependencies')

    // ⚙️ Advanced options
    ..addFlag('verbose', abbr: 'v', help: 'Show detailed output')
    ..addFlag('dry-run', help: 'Preview changes without modifying files')
    ..addFlag('generate-arb', help: 'Generate ARB files with found strings')
    ..addFlag('convert-all', help: 'Convert all strings to localization calls')

    // 📁 Path options
    ..addOption('convert-file', help: 'Convert strings in specific file')
    ..addOption('output-dir',
        help: 'Output directory for ARB files', defaultsTo: 'lib/l10n')

    // 🔬 Single Extraction options
    ..addFlag('extract-single',
        help: 'Extract and translate a single string at a specific location')
    ..addOption('file', help: 'Path to the file for single extraction')
    ..addOption('line', help: 'Line number for single extraction')
    ..addOption('col', help: 'Column number for single extraction (optional)')

    // 🌍 Localization options
    ..addOption('languages',
        help: 'Target languages (comma-separated)', defaultsTo: 'es,fr,de')
    ..addOption('translator',
        help: 'Translation provider',
        defaultsTo: 'template',
        allowed: ['google', 'mymemory', 'libretranslate', 'template'])
    ..addOption('api-key', help: 'Translation API key (optional)')

    // 🤖 Automation options
    ..addFlag('translate', help: 'Auto-translate to target languages')
    ..addFlag('analytics', help: 'Generate coverage analytics')
    ..addFlag('ci', help: 'CI mode - fail on localization issues')

    // 📋 Information
    ..addFlag('help', abbr: 'h', help: 'Show this help message');

  late ArgResults args;
  try {
    args = parser.parse(arguments);
  } catch (e) {
    print('❌ Error parsing arguments: $e');
    _showUsage(parser);
    exit(1);
  }

  if (args['help'] as bool || arguments.isEmpty) {
    _showUsage(parser);
    return;
  }

  final verbose = args['verbose'] as bool;
  final projectPath = Directory.current.path;

  try {
    // 🚀 Auto-setup mode - Complete solution
    if (args['auto-setup'] as bool) {
      await _runAutoSetupMode(args, projectPath, verbose);
      return;
    }

    // 🎯 Quick modes
    if (args['check'] as bool) {
      await _runCheckMode(args, projectPath, verbose);
    } else if (args['fix'] as bool) {
      await _runFixMode(args, projectPath, verbose);
    } else if (args['setup'] as bool) {
      await _runSetupMode(args, projectPath, verbose);
    } else if (args['extract-single'] as bool) {
      await _runExtractSingleMode(args, projectPath, verbose);
    } else if (args['convert-all'] as bool || args['convert-file'] != null) {
      await _runConversionMode(args, projectPath, verbose);
    } else {
      // Default to check mode
      await _runCheckMode(args, projectPath, verbose);
    }
  } catch (e) {
    print('❌ Error: $e');
    if (verbose) print('Stack trace: ${StackTrace.current}');
    exit(1);
  }
}

/// Show simplified usage instructions
void _showUsage(ArgParser parser) {
  print('🌍 Flutter Localization Checker - Complete Solution');
  print('===================================================');
  print('');
  print('🚀 RECOMMENDED: One-Command Complete Setup');
  print(
      '  loc_checker --auto-setup     🎯 Complete Flutter localization setup');
  print('                               ✅ Adds dependencies to pubspec.yaml');
  print('                               ✅ Creates l10n.yaml configuration');
  print('                               ✅ Generates ARB files with smart keys');
  print(
      '                               ✅ Converts ALL strings with context detection');
  print(
      '                               ✅ Ready to use - just run flutter pub get!');
  print('');
  print('🎯 Quick Commands:');
  print('  loc_checker --check          📝 Check for localization issues');
  print(
      '  loc_checker --fix            🔧 Auto-fix with smart context detection');
  print('  loc_checker --setup          🚀 Advanced setup with options');
  print('');
  print('💡 Examples:');
  print('  # Complete setup (RECOMMENDED)');
  print('  loc_checker --auto-setup');
  print('');
  print('  # Complete setup with specific languages');
  print('  loc_checker --auto-setup --languages=es,fr,ar,de');
  print('');
  print('  # Quick check only');
  print('  loc_checker --check --verbose');
  print('');
  print('  # Preview what would be converted');
  print('  loc_checker --fix --dry-run');
  print('');
  print('🔧 Advanced Options:');
  print('  --languages=LANGS    Target languages (default: es,fr,de)');
  print('  --output-dir=DIR     ARB files directory (default: lib/l10n)');
  print('  --verbose           Show detailed progress');
  print('  --dry-run           Preview changes without modifying files');
  print('  --analytics         Generate coverage analytics');
  print('  --translate         Auto-translate using translation service');
  print('');
  print('🌟 Smart Context Detection:');
  print('  • AlertDialog, showDialog → context.l10n.key');
  print('  • Widget build methods → context.l10n.key');
  print('  • Static/utility methods → AppLocalizations.of(context)!.key');
  print('');
  print('📚 More help: https://github.com/your-repo/localization-checker');
}

/// Runs extraction for a single string (intended for IDE extensions)
Future<void> _runExtractSingleMode(
    ArgResults args, String projectPath, bool verbose) async {
  final file = args['file'] as String?;
  final lineStr = args['line'] as String?;
  final colStr = args['col'] as String?;

  if (file == null || lineStr == null) {
    print('❌ Error: --file and --line are required for --extract-single mode');
    exit(1);
  }

  final line = int.tryParse(lineStr);
  final col = colStr != null ? int.tryParse(colStr) : null;

  if (line == null) {
    print('❌ Error: Invalid line number');
    exit(1);
  }

  if (verbose) {
    print(
        '🎯 Extracting single string at $file:$line${col != null ? ':$col' : ''}');
  }

  // Find non-localized strings in the specific file
  final config = LocalizationCheckerConfig(
    projectPath: projectPath,
    scanPaths: [file],
    excludeDirs: [],
    excludeFiles: [],
    customUiPatterns: [],
    verbose: verbose,
  );

  final checker = LocalizationChecker(config: config);
  await checker.run();

  if (checker.results.isEmpty) {
    print('✅ No strings found in $file');
    return;
  }

  // Find the exact string at the requested position
  NonLocalizedString? targetString;
  for (final result in checker.results) {
    if (result.lineNumber == line) {
      if (col != null) {
        // If col provided, ensure it matches or is closest
        if (result.columnNumber == col ||
            (result.columnNumber > 0 &&
                result.columnNumber <= col &&
                result.columnNumber + result.length >= col)) {
          targetString = result;
          break;
        }
      } else {
        targetString = result;
        break;
      }
    }
  }

  if (targetString == null) {
    print('❌ No string found at $file:$line${col != null ? ':$col' : ''}');
    return;
  }

  // Convert just this one string
  final converter = AutoCodeConverter(
    projectPath: projectPath,
    verbose: verbose,
    dryRun: false,
  );

  final conversionResult = await converter.convertAllStrings([targetString]);

  if (conversionResult.failedConversions.isNotEmpty) {
    print(
        '❌ Failed to convert string: ${conversionResult.failedConversions.first}');
    exit(1);
  }

  // Generate ARB specifically for this string
  final outputDir = args['output-dir'] as String? ?? 'lib/l10n';
  final arbGenerator =
      ArbGenerator(outputDirectory: outputDir, verbose: verbose);

  await arbGenerator.generateSmartArb([targetString]);

  // Translate to other languages if needed
  if (args['translate'] as bool) {
    if (verbose) print('🌍 Running auto-translation for the new string...');
    final enhancedConfig = EnhancedLocalizationConfig(
      enableAutoTranslation: true,
      targetLanguages: (args['languages'] as String? ?? 'es,fr,de')
          .split(',')
          .map((e) => e.trim())
          .toList(),
      translationApiKey: args['api-key'] as String? ?? '',
      translationProvider: args['translator'] as String? ?? 'template',
      enableAnalytics: false,
      enableCodeGeneration: false,
      outputDirectory: outputDir,
    );

    final enhancedChecker = EnhancedLocalizationChecker(
      config: config,
      enhancedConfig: enhancedConfig,
      verbose: verbose,
    );
    // Run complete which translates if translation is enabled
    // This might be heavy just for one string if not optimized, but ensures consistency.
    await enhancedChecker.runComplete(
      generateArb: false, // Already generated
      autoTranslate: true,
      generateAnalytics: false,
      generateCode: false,
      arbOutputDir: outputDir,
    );
  }

  print('✅ Successfully extracted and replaced single string');
}

/// Runs conversion mode for automatic code conversion
Future<void> _runConversionMode(
    ArgResults args, String projectPath, bool verbose) async {
  final convertAll = args['convert-all'] as bool;
  final convertFile = args['convert-file'] as String?;
  final dryRun = args['dry-run'] as bool;

  if (verbose) {
    print('🔄 Running Code Conversion Mode');
    if (dryRun) {
      print('🔍 DRY RUN MODE - No files will be modified');
    }
  }

  // Create auto code converter
  final converter = AutoCodeConverter(
    projectPath: projectPath,
    verbose: verbose,
    dryRun: dryRun,
  );

  if (convertFile != null) {
    // Convert specific file
    await _convertSpecificFile(converter, convertFile, verbose, dryRun);
  } else if (convertAll) {
    // Convert all files
    await _convertAllFiles(converter, args, projectPath, verbose, dryRun);
  }
}

/// Convert strings in a specific file
Future<void> _convertSpecificFile(AutoCodeConverter converter, String filePath,
    bool verbose, bool dryRun) async {
  if (verbose) {
    print('🎯 Converting strings in: $filePath');
  }

  // First, find non-localized strings in the specific file
  final config = LocalizationCheckerConfig(
    projectPath: converter.projectPath,
    scanPaths: [filePath],
    excludeDirs: [],
    excludeFiles: [],
    customUiPatterns: [],
    verbose: verbose,
  );

  final checker = LocalizationChecker(config: config);
  await checker.run();

  if (checker.results.isEmpty) {
    print('✅ No non-localized strings found in $filePath');
    return;
  }

  // Convert the found strings
  final result = await converter.convertAllStrings(checker.results);

  _printConversionResults(result, dryRun);
}

/// Convert all files in the project
Future<void> _convertAllFiles(AutoCodeConverter converter, ArgResults args,
    String projectPath, bool verbose, bool dryRun) async {
  if (verbose) {
    print('🚀 Converting all strings in project: $projectPath');
  }

  // First, run the checker to find all non-localized strings
  final config = _createBaseConfig(args, projectPath, verbose);
  final checker = LocalizationChecker(config: config);
  await checker.run();

  if (checker.results.isEmpty) {
    print('✅ No non-localized strings found in the project');
    return;
  }

  print('Found ${checker.results.length} non-localized strings to convert');

  // Convert all found strings
  final result = await converter.convertAllStrings(checker.results);

  _printConversionResults(result, dryRun);

  // Generate ARB files after conversion if requested
  if (args['generate-arb'] as bool && !dryRun) {
    print('📄 Generating ARB files after conversion...');
    // Re-run checker to get any remaining strings after conversion
    await checker.run();

    final outputDir = args['output-dir'] as String? ?? projectPath;
    final arbGenerator =
        ArbGenerator(outputDirectory: outputDir, verbose: verbose);
    await arbGenerator.generateSmartArb(checker.results);

    if (verbose) {
      print('✅ ARB files generated');
    }
  }
}

/// Print conversion results summary
void _printConversionResults(ConversionResult result, bool dryRun) {
  print('');
  print('🔄 Code Conversion Results');
  print('==========================');
  print('📊 Summary:');
  print('  Total strings processed: ${result.totalStringsProcessed}');
  print('  Successful conversions: ${result.conversions.length}');
  print('  Failed conversions: ${result.failedConversions.length}');
  print('  Files modified: ${result.filesModified.length}');
  print('  Success rate: ${(result.successRate * 100).toStringAsFixed(1)}%');

  if (result.conversions.isNotEmpty) {
    print('');
    print('✅ Converted Strings:');
    for (final conversion in result.conversions.take(10)) {
      final contextType =
          conversion.conversionType == ConversionType.widgetContext
              ? 'widget context'
              : 'static access';
      print(
          '  [${conversion.pattern}] "${conversion.originalString}" → ${conversion.localizationCall} ($contextType)');
    }

    if (result.conversions.length > 10) {
      print('  ... and ${result.conversions.length - 10} more conversions');
    }
  }

  if (result.failedConversions.isNotEmpty) {
    print('');
    print('❌ Failed Conversions:');
    for (final failure in result.failedConversions.take(5)) {
      print('  $failure');
    }

    if (result.failedConversions.length > 5) {
      print('  ... and ${result.failedConversions.length - 5} more failures');
    }
  }

  if (result.filesModified.isNotEmpty) {
    print('');
    print('📝 Modified Files:');
    for (final file in result.filesModified) {
      print('  $file');
    }
  }

  print('');
  if (dryRun) {
    print('🔍 DRY RUN COMPLETE - No files were actually modified');
    print('💡 Remove --dry-run flag to apply these changes');
  } else {
    print('✅ Code conversion completed successfully!');

    if (result.conversions.isNotEmpty) {
      print('');
      print('🔧 Smart Context Detection Applied:');
      final widgetContextCount = result.conversions
          .where((c) => c.conversionType == ConversionType.widgetContext)
          .length;
      final staticAccessCount = result.conversions
          .where((c) => c.conversionType == ConversionType.staticAccess)
          .length;

      print('  - Widget context (context.l10n.key): $widgetContextCount');
      print(
          '  - Static access (AppLocalizations.of(context)!.key): $staticAccessCount');
    }
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
    enableAutoTranslation: args['translate'] as bool,
    targetLanguages: (args['languages'] as String? ?? 'es,fr,de')
        .split(',')
        .map((e) => e.trim())
        .toList(), // Fix null safety
    translationApiKey: args['api-key'] as String? ?? '', // Fix null safety
    translationProvider:
        args['translator'] as String? ?? 'template', // Fix null safety
    enableAnalytics: args['analytics'] as bool,
    enableCodeGeneration: false, // Code generation is now handled by --setup
    outputDirectory:
        args['output-dir'] as String? ?? 'lib/l10n', // Fix null safety
  );

  // Parse base configuration
  final config = _createBaseConfig(args, projectPath, verbose);

  // Create enhanced checker
  final enhancedChecker = EnhancedLocalizationChecker(
    config: config,
    enhancedConfig: enhancedConfig,
    verbose: verbose,
  );

  if (args['ci'] as bool) {
    // Run incremental check for CI/CD
    await _runIncrementalCheck(enhancedChecker, args, verbose);
  } else {
    // Run complete enhanced check
    await _runCompleteEnhancedCheck(
        enhancedChecker, args, projectPath, verbose);
  }
}

/// Runs complete enhanced checking with all features
Future<void> _runCompleteEnhancedCheck(
  EnhancedLocalizationChecker checker,
  ArgResults args,
  String projectPath,
  bool verbose,
) async {
  final result = await checker.runComplete(
    generateArb: args['generate-arb'] as bool,
    autoTranslate: args['translate'] as bool,
    generateAnalytics: args['analytics'] as bool,
    generateCode: false, // Code generation is now handled by --setup
    arbOutputDir: args['output-dir'] as String?,
  );

  // Generate basic report
  final report = ReportGenerator.generate(result.nonLocalizedStrings);
  final outputFile = File(
      '$projectPath/localization_report.txt'); // Fix null safety - use default path
  await outputFile.writeAsString(report);

  // Export comprehensive report
  await checker.exportComprehensiveReport(
    result: result,
    outputPath: '$projectPath/localization_analytics.json', // Fixed path
  );

  _printEnhancedSummary(result, projectPath, verbose);
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

/// Run simple check mode
Future<void> _runCheckMode(
    ArgResults args, String projectPath, bool verbose) async {
  if (verbose) print('🔍 Running localization check...');

  // Use enhanced mode but with simplified output
  await _runEnhancedMode(args, projectPath, verbose);
}

/// Run auto-fix mode
Future<void> _runFixMode(
    ArgResults args, String projectPath, bool verbose) async {
  if (verbose) print('🔧 Running auto-fix mode...');

  // Use enhanced mode with conversion enabled
  await _runEnhancedMode(args, projectPath, verbose);
}

/// Run complete setup mode
Future<void> _runSetupMode(
    ArgResults args, String projectPath, bool verbose) async {
  if (verbose) print('🚀 Running complete localization setup...');

  // Use enhanced mode with all features enabled
  await _runEnhancedMode(args, projectPath, verbose);
}

/// Creates base configuration from arguments
LocalizationCheckerConfig _createBaseConfig(
    ArgResults args, String projectPath, bool verbose) {
  return LocalizationCheckerConfig(
    projectPath: projectPath,
    scanPaths: ['$projectPath/lib'], // Simplified - always scan lib directory
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
    customUiPatterns: [], // Simplified - no custom UI patterns
    verbose: verbose,
  );
}

/// Prints enhanced summary with all features
void _printEnhancedSummary(
    EnhancedLocalizationResult result, String projectPath, bool verbose) {
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
  print('  Basic report: $projectPath/localization_report.txt');
  print('  Analytics report: $projectPath/localization_analytics.json');

  final outputDir = '$projectPath/lib/l10n';
  print('  ARB file: $outputDir/en.arb');

  if (result.translatedArbs != null) {
    for (final lang in result.translatedArbs!.keys) {
      print('  Translated ARB: $outputDir/$lang.arb');
    }
  }

  print('  Generated localization code in: $outputDir');

  if (result.analytics?.recommendations.isNotEmpty == true) {
    print('');
    print('💡 Recommendations:');
    for (final recommendation in result.analytics!.recommendations) {
      print('  $recommendation');
    }
  }

  print('');
  print('✅ Enhanced localization checking completed successfully!');
}

/// Runs the auto-setup mode, which handles pubspec.yaml, l10n.yaml, and ARB generation
Future<void> _runAutoSetupMode(
    ArgResults args, String projectPath, bool verbose) async {
  print('🚀 Starting Complete Flutter Localization Auto-Setup');
  print('==================================================');

  try {
    // Step 1: Setup Flutter dependencies
    await _setupFlutterDependencies(projectPath, verbose);

    // Step 2: Create localization configuration
    await _setupLocalizationConfig(args, projectPath, verbose);

    // Step 3: Generate ARB files and perform conversions
    await _runCompleteLocalizationSetup(args, projectPath, verbose);

    // Step 4: Generate Flutter localization files
    await _generateFlutterLocalizations(projectPath, verbose);

    print('');
    print('🎉 Complete Flutter Localization Setup Finished!');
    print('=================================================');
    print('✅ Dependencies added to pubspec.yaml');
    print('✅ l10n.yaml configuration created');
    print('✅ ARB files generated with smart context detection');
    print(
        '✅ Code converted with context.l10n.* and AppLocalizations.of(context).*');
    print('✅ Flutter localization files generated');
    print('');
    print('🔄 Next steps:');
    print('1. Run: flutter pub get');
    print('2. Run: flutter packages get');
    print('3. Hot restart your app');
    print('4. All hardcoded strings are now localized! 🌍');
  } catch (e) {
    print('❌ Auto-setup failed: $e');
    rethrow;
  }
}

/// Setup Flutter dependencies in pubspec.yaml
Future<void> _setupFlutterDependencies(String projectPath, bool verbose) async {
  if (verbose) print('📦 Setting up Flutter localization dependencies...');

  final pubspecFile = File('$projectPath/pubspec.yaml');
  if (!await pubspecFile.exists()) {
    throw Exception(
        'pubspec.yaml not found! Please run this command from your Flutter project root.');
  }

  final content = await pubspecFile.readAsString();

  // Check if dependencies already exist
  if (content.contains('flutter_localizations:') && content.contains('intl:')) {
    if (verbose)
      print('✅ Flutter localization dependencies already configured');
  } else {
    // Add dependencies
    String updatedContent = content;

    // Find dependencies section and add flutter_localizations
    if (!content.contains('flutter_localizations:')) {
      final dependenciesMatch =
          RegExp(r'dependencies:\s*\n').firstMatch(updatedContent);
      if (dependenciesMatch != null) {
        final insertIndex = dependenciesMatch.end;
        final beforeDeps = updatedContent.substring(0, insertIndex);
        final afterDeps = updatedContent.substring(insertIndex);
        updatedContent = beforeDeps +
            '  flutter_localizations:\n    sdk: flutter\n' +
            afterDeps;
      }
    }

    // Add intl dependency
    if (!content.contains('intl:')) {
      final dependenciesMatch =
          RegExp(r'dependencies:\s*\n(?:.*\n)*?(?=\w|\n\w)')
              .firstMatch(updatedContent);
      if (dependenciesMatch != null) {
        final insertIndex = dependenciesMatch.end;
        final beforeDeps = updatedContent.substring(0, insertIndex - 1);
        final afterDeps = updatedContent.substring(insertIndex - 1);
        updatedContent = beforeDeps + '  intl: ^0.18.0\n' + afterDeps;
      }
    }

    await pubspecFile.writeAsString(updatedContent);
    print('✅ Added Flutter localization dependencies to pubspec.yaml');
  }

  // Add flutter generate config
  if (!content.contains('generate: true')) {
    String updatedContent = await pubspecFile.readAsString();

    // Find flutter section
    final flutterMatch = RegExp(r'flutter:\s*\n').firstMatch(updatedContent);
    if (flutterMatch != null) {
      final insertIndex = flutterMatch.end;
      final beforeFlutter = updatedContent.substring(0, insertIndex);
      final afterFlutter = updatedContent.substring(insertIndex);
      updatedContent = beforeFlutter + '  generate: true\n' + afterFlutter;
    } else {
      // Add flutter section if it doesn't exist
      updatedContent += '\nflutter:\n  generate: true\n';
    }

    await pubspecFile.writeAsString(updatedContent);
    print('✅ Added generate: true to flutter section');
  }
}

/// Setup l10n.yaml configuration
Future<void> _setupLocalizationConfig(
    ArgResults args, String projectPath, bool verbose) async {
  if (verbose) print('⚙️ Creating localization configuration...');

  final l10nFile = File('$projectPath/l10n.yaml');

  if (await l10nFile.exists()) {
    print('✅ l10n.yaml already exists');
    return;
  }

  final outputDir = args['output-dir'] as String? ?? 'lib/l10n';

  final l10nContent = '''arb-dir: $outputDir
template-arb-file: app_en.arb
output-localization-file: app_localizations.dart
output-class: AppLocalizations
preferred-supported-locales: ["en"]
header-file: false
use-deferred-loading: false
synthetic-package: false
''';

  await l10nFile.writeAsString(l10nContent);
  print('✅ Created l10n.yaml configuration');
}

/// Run complete localization setup with ARB generation and code conversion
Future<void> _runCompleteLocalizationSetup(
    ArgResults args, String projectPath, bool verbose) async {
  if (verbose)
    print('🔄 Running complete localization analysis and conversion...');

  // Create output directory
  final outputDir = args['output-dir'] as String? ?? 'lib/l10n';
  final outputDirPath = Directory('$projectPath/$outputDir');
  if (!await outputDirPath.exists()) {
    await outputDirPath.create(recursive: true);
    print('✅ Created localization directory: $outputDir');
  }

  // Create the context extension file
  await _createContextExtension(projectPath, outputDir, verbose);

  // Run enhanced checker to find all strings
  final config = _createBaseConfig(args, projectPath, verbose);
  final enhancedConfig = EnhancedLocalizationConfig(
    enableAutoTranslation: false, // Don't auto-translate in auto-setup
    targetLanguages: (args['languages'] as String? ?? 'es,fr,de')
        .split(',')
        .map((e) => e.trim())
        .toList(),
    translationApiKey: args['api-key'] as String? ?? '',
    translationProvider: args['translator'] as String? ?? 'template',
    enableAnalytics: true,
    enableCodeGeneration: true,
    outputDirectory: outputDir,
  );

  final checker = EnhancedLocalizationChecker(
    config: config,
    enhancedConfig: enhancedConfig,
  );

  print('🔍 Scanning project for hardcoded strings...');
  final result = await checker.runComplete(
    generateArb: true,
    autoTranslate: false,
    generateAnalytics: true,
    generateCode: false,
    arbOutputDir: outputDir,
  );

  print('✅ Found ${result.nonLocalizedStrings.length} strings to localize');
  print('✅ Generated ARB file with smart key naming');

  // Run code conversion with smart context detection
  print('🔄 Converting hardcoded strings to localization calls...');
  final converter = AutoCodeConverter(
    projectPath: projectPath,
    verbose: verbose,
    dryRun: false, // Actually perform the conversions
  );

  final conversionResult =
      await converter.convertAllStrings(result.nonLocalizedStrings);
  print(
      '✅ Converted ${conversionResult.filesModified.length} files with smart context detection');
  print('   - Widget contexts → context.l10n.key');
  print('   - Static contexts → AppLocalizations.of(context)!.key');
}

/// Create the context.l10n extension file
Future<void> _createContextExtension(
    String projectPath, String outputDir, bool verbose) async {
  final extensionFile =
      File('$projectPath/$outputDir/app_localizations_extension.dart');

  final extensionContent =
      '''// Generated extension for easy localization access
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

/// Extension on BuildContext for easy localization access
extension AppLocalizationsX on BuildContext {
  /// Get the current AppLocalizations instance
  AppLocalizations get l10n => AppLocalizations.of(this)!;
}
''';

  await extensionFile.writeAsString(extensionContent);
  if (verbose) print('✅ Created context.l10n extension file');
}

/// Generate Flutter localization files
Future<void> _generateFlutterLocalizations(
    String projectPath, bool verbose) async {
  if (verbose) print('🔧 Generating Flutter localization files...');

  try {
    // Run flutter gen-l10n
    final result = await Process.run(
      'flutter',
      ['gen-l10n'],
      workingDirectory: projectPath,
    );

    if (result.exitCode == 0) {
      print('✅ Generated Flutter localization files');
      if (verbose && result.stdout.toString().isNotEmpty) {
        print('Output: ${result.stdout}');
      }
    } else {
      print('⚠️ Flutter gen-l10n had issues:');
      print('Exit code: ${result.exitCode}');
      print('Error: ${result.stderr}');
      print('This may be normal if pubspec.yaml needs flutter pub get first.');
    }
  } catch (e) {
    print('⚠️ Could not run flutter gen-l10n: $e');
    print('Please run "flutter gen-l10n" manually after "flutter pub get"');
  }
}
