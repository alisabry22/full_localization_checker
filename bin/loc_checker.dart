import 'dart:io';

import 'package:args/args.dart';
import 'package:colorize/colorize.dart';
import 'package:loc_checker/arb_generator.dart';
import 'package:loc_checker/main.dart';
import 'package:path/path.dart' as path;

void main(List<String> arguments) async {
  print('arguments are: $arguments'); // Keep your debug line

  final parser = ArgParser()
    ..addFlag('help',
        abbr: 'h', negatable: false, help: 'Print this usage information.')
    ..addFlag('verbose',
        abbr: 'v', negatable: false, help: 'Show verbose output.')
    ..addFlag('include-comments',
        negatable: false, help: 'Include strings in comments.')
    ..addFlag('generate-arb',
        abbr: 'a',
        negatable: false,
        help: 'Generate an ARB file with non-localized strings.')
    ..addMultiOption('exclude-dir',
        abbr: 'd',
        help: 'Directories to exclude from scanning.',
        defaultsTo: ['build', '.dart_tool', '.pub', '.git', 'test', 'bin'])
    ..addMultiOption('exclude-file',
        abbr: 'f', help: 'Files to exclude from scanning.', defaultsTo: [])
    ..addMultiOption('scan-paths',
        abbr: 's',
        help:
            'Directories to scan (comma-separated or multiple flags). Defaults to lib.',
        defaultsTo: [])
    ..addOption('output',
        abbr: 'o',
        help:
            'Output file for the report. If not specified, prints to stdout.');

  try {
    final results = parser.parse(arguments);

    if (results['help']) {
      _printUsage(parser);
      exit(0);
    }

    final projectPath =
        results.rest.isEmpty ? Directory.current.path : results.rest.first;

    final projectDir = Directory(projectPath);
    if (!projectDir.existsSync()) {
      _printError('Project directory does not exist: $projectPath');
      exit(1);
    }

    final pubspecFile = File(path.join(projectPath, 'pubspec.yaml'));
    if (!pubspecFile.existsSync()) {
      _printWarning(
          'No pubspec.yaml found. This might not be a Flutter project.');
    } else {
      final pubspecContent = await pubspecFile.readAsString();
      if (!pubspecContent.contains('flutter:') &&
          !pubspecContent.contains('sdk: flutter')) {
        _printWarning(
            'This might not be a Flutter project. Continuing anyway...');
      }
    }

    // Debug raw scan-paths
    if (results['verbose']) print('Raw scan-paths: ${results['scan-paths']}');

    // Fix scanPaths parsing
    List<String> scanPaths = results['scan-paths'].isNotEmpty
        ? (results['scan-paths'] as List<dynamic>)
            .map((p) =>
                path.isAbsolute(p as String) ? p : path.join(projectPath, p))
            .toList()
        : [path.join(projectPath, 'lib')];

    List<String> excludeDirs =
        (results['exclude-dir'] as List<dynamic>).cast<String>();
    // Adjust excludeDirs dynamically based on scanPaths
    if (scanPaths.any((p) => p.contains('test_files')) &&
        excludeDirs.contains('test')) {
      excludeDirs = excludeDirs.where((dir) => dir != 'test').toList();
      if (results['verbose'])
        print('Removed "test" from excludeDirs to scan test_files');
    }

    final config = LocalizationCheckerConfig(
      projectPath: projectPath,
      scanPaths: scanPaths,
      excludeDirs: excludeDirs,
      excludeFiles: (results['exclude-file'] as List<dynamic>).cast<String>(),
      verbose: results['verbose'],
      includeComments: results['include-comments'],
    );

    final checker = LocalizationChecker(config);

    _printInfo('Scanning project for non-localized strings...');
    await checker.run();

    final report = generateReport(checker.results);

    final outputPath = results['output'];
    if (outputPath != null) {
      final outputFile = File(outputPath);
      await outputFile.writeAsString(report);
      _printSuccess('Report written to $outputPath');
    } else {
      print(report);
    }

    // Generate ARB file if requested
    if (results['generate-arb'] && checker.results.isNotEmpty) {
      await writeArbFile(checker.results, projectPath);
      final arbPath =
          path.join(projectPath, 'lib', 'l10n', 'missing_strings.arb');
      _printSuccess('ARB file with non-localized strings written to $arbPath');
    }

    final count = checker.results.length;
    if (count > 0) {
      _printWarning(
          'Found $count non-localized strings that should be reviewed.');
    } else {
      _printSuccess('No non-localized strings found!');
    }
  } catch (e) {
// Print the full stack trace if in verbose mode
    _printError('Error: $e');
    _printUsage(parser);
    exit(1);
  }
}

// Helper functions for pretty printing
void _printUsage(ArgParser parser) {
  print('Usage: full_localization_checker [options] [project_path]\n');
  print(
      'A CLI tool that scans Flutter apps to detect non-localized strings.\n');
  print('Options:');
  print(parser.usage);
}

void _printError(String message) {
  final text = Colorize(message);
  text.red();
  print(text);
}

void _printWarning(String message) {
  final text = Colorize(message);
  text.yellow();
  print(text);
}

void _printInfo(String message) {
  final text = Colorize(message);
  text.blue();
  print(text);
}

void _printSuccess(String message) {
  final text = Colorize(message);
  text.green();
  print(text);
}
