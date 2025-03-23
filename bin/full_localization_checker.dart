import 'dart:io';

import 'package:args/args.dart';
import 'package:colorize/colorize.dart';
import 'package:localization_checker/main.dart';
import 'package:path/path.dart' as path;

void main(List<String> arguments) async {
  // Parse command line arguments
  final parser = ArgParser()
    ..addFlag('help', abbr: 'h', negatable: false, help: 'Print this usage information.')
    ..addFlag('verbose', abbr: 'v', negatable: false, help: 'Show verbose output.')
    ..addFlag('include-comments', negatable: false, help: 'Include strings in comments.')
    ..addMultiOption('exclude-dir', 
      abbr: 'd', 
      help: 'Directories to exclude from scanning.',
      defaultsTo: ['build', '.dart_tool', '.pub', '.git'],
    )
    ..addMultiOption('exclude-file', 
      abbr: 'f', 
      help: 'Files to exclude from scanning.',
    )
    ..addOption('output', 
      abbr: 'o', 
      help: 'Output file for the report. If not specified, prints to stdout.',
    );

  try {
    final results = parser.parse(arguments);

    // Show help
    if (results['help']) {
      _printUsage(parser);
      exit(0);
    }

    // Get project path (current directory if not specified)
    final projectPath = results.rest.isEmpty 
        ? Directory.current.path 
        : results.rest.first;

    // Validate project path
    final projectDir = Directory(projectPath);
    if (!projectDir.existsSync()) {
      _printError('Project directory does not exist: $projectPath');
      exit(1);
    }

    // Check if it's a Flutter project
    final pubspecFile = File(path.join(projectPath, 'pubspec.yaml'));
    if (!pubspecFile.existsSync()) {
      _printWarning('No pubspec.yaml found. This might not be a Flutter project.');
    } else {
      final pubspecContent = await pubspecFile.readAsString();
      if (!pubspecContent.contains('flutter:') && !pubspecContent.contains('sdk: flutter')) {
        _printWarning('This might not be a Flutter project. Continuing anyway...');
      }
    }

    // Create configuration
    final config = LocalizationCheckerConfig(
      projectPath: projectPath,
      excludeDirs: results['exclude-dir'],
      excludeFiles: results['exclude-file'],
      verbose: results['verbose'],
      includeComments: results['include-comments'],
    );

    // Run the checker
    final checker = LocalizationChecker(config);
    
    _printInfo('Scanning project for non-localized strings...');
    await checker.run();

    // Generate report
    final report = generateReport(checker.results);

    // Output report
    final outputPath = results['output'];
    if (outputPath != null) {
      final outputFile = File(outputPath);
      await outputFile.writeAsString(report);
      _printSuccess('Report written to $outputPath');
    } else {
      print(report);
    }

    // Print summary
    final count = checker.results.length;
    if (count > 0) {
      _printWarning('Found $count non-localized strings that should be reviewed.');
    } else {
      _printSuccess('No non-localized strings found!');
    }
  } catch (e) {
    _printError('Error: $e');
    _printUsage(parser);
    exit(1);
  }
}

// Helper functions for pretty printing
void _printUsage(ArgParser parser) {
  print('Usage: full_localization_checker [options] [project_path]\n');
  print('A CLI tool that scans Flutter apps to detect non-localized strings.\n');
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
