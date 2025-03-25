import 'dart:io';

import 'package:args/args.dart';
import 'package:loc_checker/checker.dart';
import 'package:loc_checker/config.dart';

void main(List<String> args) {
  final parser = ArgParser()
    ..addFlag('verbose',
        abbr: 'v', defaultsTo: false, help: 'Enable verbose logging')
    ..addFlag('generate-arb', defaultsTo: false, help: 'Generate en.arb file')
    ..addMultiOption('scan-paths',
        defaultsTo: [], help: 'Paths to scan (comma-separated)')
    ..addMultiOption('custom-ui', defaultsTo: [], help: 'Custom UI patterns')
    ..addOption('output',
        abbr: 'o', defaultsTo: 'report.txt', help: 'Output report file')
    ..addOption('arb-output', defaultsTo: null, help: 'Directory for ARB file');

  final results = parser.parse(args);
  final projectPath =
      results.rest.isNotEmpty ? results.rest[0] : Directory.current.path;
  final scanPaths = results['scan-paths'].isNotEmpty
      ? (results['scan-paths'] as String).split(',')
      : null;

  final config = LocalizationCheckerConfig(
    projectPath: projectPath,
    scanPaths: scanPaths,
    verbose: results['verbose'],
    customUiPatterns: (results['custom-ui'] as List).cast<String>(),
  );

  final checker = LocalizationChecker(config: config);
  checker
      .run(
    generateArb: results['generate-arb'],
    arbOutputDir: results['arb-output'],
  )
      .then((_) {
    final report = ReportGenerator.generate(checker.results);
    File(results['output']).writeAsStringSync(report);
    print('Report written to ${results['output']}');
  }).catchError((e) {
    print('Error: $e');
    exit(1);
  });
}
