// Configuration class remains unchanged
import 'dart:convert';
import 'dart:io';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:file/local.dart';
import 'package:glob/glob.dart';
import 'package:loc_checker/ast_visitor.dart';
import 'package:path/path.dart' as path;

class LocalizationCheckerConfig {
  final String projectPath;
  final List<String> scanPaths;
  final List<String> excludeDirs;
  final List<String> excludeFiles;
  final bool verbose;
  final bool includeComments;

  LocalizationCheckerConfig({
    required this.projectPath,
    List<String>? scanPaths,
    List<String> excludeDirs = const [
      'build',
      '.dart_tool',
      '.pub',
      '.git',
      'test',
      'bin'
    ],
    List<String> excludeFiles = const [],
    this.verbose = false, // Corrected
    this.includeComments = false,
  })  : scanPaths =
            scanPaths ?? [path.join(projectPath, 'lib')], // Default to lib/
        excludeDirs = excludeDirs,
        excludeFiles =
            excludeFiles; // Use projectPath as default instead of lib folder
}

// NonLocalizedString class remains unchanged
class NonLocalizedString {
  final String filePath;
  final int lineNumber;
  final String content;
  final List<String> context;

  NonLocalizedString({
    required this.filePath,
    required this.lineNumber,
    required this.content,
    required this.context,
  });

  @override
  String toString() {
    return '$filePath:$lineNumber - "$content"\n  $context';
  }
}

class LocalizationChecker {
  final LocalizationCheckerConfig config;
  final List<NonLocalizedString> _results = [];
  final Set<String> _localizedKeys = {};

  LocalizationChecker(this.config);

  List<NonLocalizedString> get results => _results;

  Future<void> run() async {
// Should print: true
    await _findLocalizedKeys();
    await _scanDartFiles();
  }

  Future<void> _findLocalizedKeys() async {
    final fileSystem = LocalFileSystem();
    int filesProcessed = 0;

    final arbGlob = Glob('${config.projectPath}/**/**.arb');
    for (final entity in arbGlob.listFileSystemSync(fileSystem)) {
      if (entity is File) {
        try {
          final content = await (entity as File).readAsString();
          final Map<String, dynamic> arbMap = json.decode(content);
          for (final key in arbMap.keys) {
            if (!key.startsWith('@')) {
              _localizedKeys.add(key);
            }
          }
          filesProcessed++;
        } catch (e) {
          if (config.verbose) {
            print('Error parsing ARB file ${entity.path}: $e');
          }
        }
      }
    }

    final jsonGlob = Glob('${config.projectPath}/**/i18n/*.json');
    final translationsGlob =
        Glob('${config.projectPath}/**/translations/*.json');

    for (final glob in [jsonGlob, translationsGlob]) {
      for (final entity in glob.listFileSystemSync(fileSystem)) {
        if (entity is File) {
          try {
            final content = await (entity as File).readAsString();
            final Map<String, dynamic> jsonMap = json.decode(content);
            _extractKeysFromJson(jsonMap, '');
            filesProcessed++;
          } catch (e) {
            if (config.verbose) {
              print('Error parsing JSON file ${entity.path}: $e');
            }
          }
        }
      }
    }

    if (config.verbose) {
      print(
          'Found ${_localizedKeys.length} localized keys from $filesProcessed files');
    }
  }

  void _extractKeysFromJson(Map<String, dynamic> json, String prefix) {
    json.forEach((key, value) {
      final fullKey = prefix.isEmpty ? key : '$prefix.$key';
      if (value is Map<String, dynamic>) {
        _extractKeysFromJson(value, fullKey);
      } else if (value is String) {
        _localizedKeys.add(fullKey);
        _localizedKeys.add(value);
      }
    });
  }

  Future<void> _scanDartFiles() async {
    final fileSystem = LocalFileSystem();
    final filesToProcess = <File>[];
    int totalFiles = 0;

    if (config.verbose) {
      print('Project path: ${config.projectPath}');
      print('Scan paths: ${config.scanPaths}');
      print('Excluded dirs: ${config.excludeDirs}');
      print('Excluded files: ${config.excludeFiles}');
    }

    for (final scanPath in config.scanPaths) {
      final normalizedPath = path.normalize(scanPath);

      final dir = Directory(normalizedPath); // Try this first
      final entities = dir.listSync().where((e) => e.path.endsWith('.dart'));
      // Alternative for debugging: final dartGlob = Glob('$normalizedPath/*.dart');

      if (config.verbose) {
        print('Scanning path: $scanPath');
        print('Normalized path: $normalizedPath');

        print(
            'Checking directory existence: ${Directory(scanPath).existsSync()}');

        print('Directory exists: ${Directory(normalizedPath).existsSync()}');
        print('Raw entities found: ${entities.length}');
        for (final entity in entities) {
          print('Found entity: ${entity.path} (isFile: ${entity is File})');
        }
      }

      for (final entity in entities) {
        if (config.verbose) print('Processing entity: ${entity.path}');

        if (entity is File) {
          final relativePath =
              path.relative(entity.path, from: config.projectPath);
          totalFiles++;

          if (config.excludeDirs.any((dir) => relativePath.startsWith(dir))) {
            if (config.verbose) print('Excluded by dir: $relativePath');
            continue;
          }
          if (config.excludeFiles.any((file) => relativePath.endsWith(file))) {
            if (config.verbose) print('Excluded by file: $relativePath');
            continue;
          }

          filesToProcess.add(entity);
          if (config.verbose) print('Added to process: $relativePath');
        }
      }
    }

    if (config.verbose) {
      print(
          'Found ${filesToProcess.length} Dart files to scan (out of $totalFiles total files)');
    }

    const batchSize = 10;
    for (var i = 0; i < filesToProcess.length; i += batchSize) {
      final end = (i + batchSize < filesToProcess.length)
          ? i + batchSize
          : filesToProcess.length;
      final batch = filesToProcess.sublist(i, end);

      await Future.wait(batch.map((file) => _checkFile(file)));

      if (config.verbose && i + batchSize < filesToProcess.length) {
        print('Processed $end of ${filesToProcess.length} files...');
      }
    }
  }

  Future<void> _checkFile(File file) async {
    try {
      if (config.verbose) print('check file');

      final content = await file.readAsString();
      final relativePath = path.relative(file.path, from: config.projectPath);

      final parseResult = parseString(content: content);
      if (config.verbose) print('Parsed AST successfully: ${parseResult.unit}');
      final visitor = StringLiteralVisitor(parseResult.lineInfo);
      if (config.verbose) print('Starting AST visitation for $relativePath');
      parseResult.unit.visitChildren(visitor);
      if (config.verbose) print('Finished AST visitation for $relativePath');
      //Testing what are the strings
      if (config.verbose) {
        print(
            'Extracted ${visitor.stringLiterals.length} string literals from $relativePath:');
        for (final literal in visitor.stringLiterals) {
          print(' - "${literal.content}" at line ${literal.lineNumber}');
        }
      }

      final lines = content.split('\n');
      for (final literal in visitor.stringLiterals) {
        final content = literal.content;
        final lineNumber = literal.lineNumber;
        final actualLine = lines[lineNumber - 1]; // Line numbers are 1-based
        if (config.verbose) {
          print('Checking "$content" at line $lineNumber: "$actualLine"');
        }
        if (_shouldSkipString(content)) {
          if (config.verbose)
            print(
                'Skipped by _shouldSkipString: "$content" in $relativePath:$lineNumber');
          continue;
        }

        final contextLines = _getContext(lines, lineNumber);

        final isUiRelated = contextLines.any((l) =>
            // Common text widgets
            l.contains('Text(') ||
            l.contains('RichText(') ||
            // Dialog and notification widgets
            l.contains('SnackBar(') ||
            l.contains('AlertDialog(') ||
            l.contains('Dialog(') ||
            l.contains('Toast(') ||
            l.contains('Notification(') ||
            // Form fields and labels
            l.contains('labelText:') ||
            l.contains('hintText:') ||
            l.contains('helperText:') ||
            l.contains('errorText:') ||
            l.contains('prefixText:') ||
            l.contains('suffixText:') ||
            // Button text
            l.contains('ElevatedButton(') ||
            l.contains('TextButton(') ||
            l.contains('OutlinedButton(') ||
            l.contains('FloatingActionButton(') ||
            l.contains('content:') ||
            // App bar and navigation
            l.contains('AppBar(') ||
            l.contains('BottomNavigationBar(') ||
            l.contains('Drawer(') ||
            l.contains('TabBar(') ||
            l.contains('title:') ||
            // Other common UI elements with text
            l.contains('Tooltip(') ||
            l.contains('Chip(') ||
            l.contains('Card(') ||
            l.contains('ListTile(') ||
            l.contains('placeholder:') ||
            l.contains('label:'));

        final isLogOrError = contextLines.any((l) =>
            l.contains('logger.') ||
            l.contains('Exception(') ||
            l.contains('throw') ||
            l.contains('left(') ||
            l.contains('right(') ||
            l.contains('print('));

        if (isLogOrError || !isUiRelated) {
          if (config.verbose)
            print(
                'Skipped (non-UI context): "$content" in $relativePath:$lineNumber');
          continue;
        }

        final line = lines[lineNumber - 1];
        if (_isLocalizedString(line, content, content, _localizedKeys)) {
          if (config.verbose)
            print(
                'Skipped (localized): "$content" in $relativePath:$lineNumber');
          continue;
        }

        _results.add(NonLocalizedString(
          filePath: relativePath,
          lineNumber: lineNumber,
          content: content,
          context: contextLines,
        ));
      }
    } catch (e) {
      if (config.verbose) {
        print('Error processing file ${file.path}: $e');
      }
    }
  }

  List<String> _getContext(List<String> lines, int lineNumber) {
    // Ensure we get at least one line before and one line after when possible
    final startLine =
        (lineNumber - 1).clamp(0, lines.length - 1); // Start one line before
    final endLine =
        (lineNumber + 1).clamp(0, lines.length - 1); // End one line after
    return lines.sublist(startLine, endLine + 1);
  }

  String _cleanStringLiteral(String literal) {
    if (literal.isEmpty) return '';

    final isTripleQuoted =
        literal.startsWith("'''") || literal.startsWith('"""');
    final isSingleQuoted =
        literal.startsWith("'") && !literal.startsWith("'''");
    final isDoubleQuoted =
        literal.startsWith('"') && !literal.startsWith('"""');

    if (!(isTripleQuoted || isSingleQuoted || isDoubleQuoted)) {
      if (config.verbose) print('Invalid string literal (no quotes): $literal');
      return literal;
    }

    final quoteLength = isTripleQuoted ? 3 : 1;
    final expectedEnd =
        isTripleQuoted ? literal.substring(0, 3) : literal.substring(0, 1);

    if (!literal.endsWith(expectedEnd)) {
      if (config.verbose)
        print('Malformed string literal (unterminated): $literal');
      return literal;
    }

    String content;
    try {
      content = literal.substring(quoteLength, literal.length - quoteLength);
    } catch (e) {
      if (config.verbose)
        print('Error extracting content from literal: $literal - $e');
      return literal;
    }

    final buffer = StringBuffer();
    var i = 0;
    while (i < content.length) {
      if (content[i] == '\\' && i + 1 < content.length) {
        i++;
        switch (content[i]) {
          case 'n':
            buffer.write('\n');
            break;
          case 't':
            buffer.write('\t');
            break;
          case 'r':
            buffer.write('\r');
            break;
          case '"':
            buffer.write('"');
            break;
          case '\'':
            buffer.write('\'');
            break;
          case '\\':
            buffer.write('\\');
            break;
          case 'x':
            if (i + 2 < content.length) {
              final hex = content.substring(i + 1, i + 3);
              try {
                buffer.writeCharCode(int.parse(hex, radix: 16));
                i += 2;
              } catch (e) {
                buffer.write(r'\x');
                i -= 1;
              }
            } else {
              buffer.write(r'\x');
            }
            break;
          case 'u':
            if (i + 1 < content.length && content[i + 1] == '{') {
              final endBrace = content.indexOf('}', i + 2);
              if (endBrace != -1 && endBrace <= i + 8) {
                final hex = content.substring(i + 2, endBrace);
                try {
                  buffer.writeCharCode(int.parse(hex, radix: 16));
                  i = endBrace;
                } catch (e) {
                  buffer.write(r'\u{');
                  i += 1;
                }
              } else {
                buffer.write(r'\u');
              }
            } else if (i + 4 < content.length) {
              final hex = content.substring(i + 1, i + 5);
              try {
                buffer.writeCharCode(int.parse(hex, radix: 16));
                i += 4;
              } catch (e) {
                buffer.write(r'\u');
                i -= 1;
              }
            } else {
              buffer.write(r'\u');
            }
            break;
          default:
            buffer.write('\\');
            buffer.write(content[i]);
        }
      } else {
        buffer.write(content[i]);
      }
      i++;
    }

    return buffer.toString();
  }

  bool _shouldSkipString(String content) {
    if (content.isEmpty || content.trim().isEmpty) return true;
    if (content.length == 1) return true;
    if (RegExp(r'^[0-9.,]+$').hasMatch(content)) return true;
    if (RegExp(r'^[!@#$%^&*()_\-+=<>?/|\\{}\[\]]+$').hasMatch(content))
      return true;
    if (content.startsWith('http://') || content.startsWith('https://'))
      return true;
    if (RegExp(r'^www\.[a-zA-Z0-9-]+(\.[a-zA-Z]{2,})+').hasMatch(content))
      return true;
    if (content.startsWith('assets/')) return true;
    if (content.startsWith('/') && content.length <= 20) return true;
    if (content.contains('/') &&
        (content.endsWith('.dart') ||
            content.endsWith('.json') ||
            content.endsWith('.arb') ||
            content.endsWith('.yaml') ||
            content.endsWith('.svg') ||
            content.endsWith('.png') ||
            content.endsWith('.jpg') ||
            content.endsWith('.mp4') ||
            content.endsWith('.ttf') ||
            content.endsWith('.otf') ||
            content.endsWith('.gif'))) return true;
    if (RegExp(r'^#[0-9a-fA-F]{3,8}$').hasMatch(content)) return true;
    if (RegExp(r'^rgba?\(\s*\d+\s*,\s*\d+\s*,\s*\d+\s*(,\s*[\d\.]+)?\s*\)$')
        .hasMatch(content)) return true;
    if (RegExp(r'^[yMdHhmsaZ\-/:\s]+$').hasMatch(content)) return true;
    if (RegExp(r'^[a-zA-Z0-9_\-]{10,}$').hasMatch(content)) return true;
    if (content.contains('com.') ||
        content.contains('.info') ||
        content.contains('video.') ||
        content.contains('oauth_') ||
        content.contains('api.') ||
        content.contains('.api')) {
      return true;
    }
    if (content == 'Content-Type' ||
        content == 'Content-Length' ||
        content == 'Content-Range' ||
        content.contains('application/') ||
        content.contains('video/') ||
        content.contains('image/') ||
        content.contains('multipart/') ||
        content.contains('text/')) {
      return true;
    }

    final technicalTerms = [
      'fail',
      'error',
      'logger',
      'upload',
      'connect',
      'push',
      'process',
      'debug',
      'info',
      'warning',
      'exception',
      'null',
      'undefined',
      'timeout',
      'connection',
      'server',
      'client',
      'request',
      'response'
    ];
    for (final term in technicalTerms) {
      if (content.toLowerCase().contains(term)) return true;
    }

    // Don't skip strings just because they contain parentheses or braces
    // Only skip if they appear to be code or formatting patterns
    if ((content.contains('format(') && content.contains('%')) ||
        (content.contains('??') && content.contains('null'))) {
      return true;
    }
    // Only skip JSON-like strings if they have multiple key-value pairs
    if (content.contains(',') &&
        content.contains(':') &&
        content.contains('(') &&
        content.split(':').length > 2) return true;

    // Skip email addresses
    if (RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$')
        .hasMatch(content)) return true;

    // Don't skip strings that look like they might be UI text
    if (content.length > 3 &&
        content.contains(' ') &&
        !content.contains('://') &&
        !content.contains('.dart') &&
        !content.contains('.json')) {
      return false;
    }

    return false;
  }

  bool _isLocalizedString(String line, String stringLiteral, String content,
      Set<String> localizedKeys) {
    final localizationPatterns = [
      // Flutter's official AppLocalizations
      RegExp(
          r'AppLocalizations\s*\.\s*of\s*\(\s*[^)]+\s*\)\s*\.\s*[a-zA-Z0-9_]+'),
      RegExp(r'AppLocalizations\s*\.\s*[a-zA-Z0-9_]+'), // Direct static access
      // Removed RegExp(r'(\d+)') as it’s too broad; replace if specific intent exists
      // GetX localization
      RegExp(r'\.tr\s*(?=\()'), // Must be followed by (
      RegExp(r'\.trParams\s*(?=\()'),
      RegExp(r'"[a-zA-Z0-9_]+"\.tr\b'), // "key".tr pattern

      // Easy Localization
      RegExp(r'LocaleKeys\s*\.\s*[a-zA-Z0-9_]+\s*\.\s*tr\s*\(\s*\)'),
      RegExp(r'tr\s*\(\s*[a-zA-Z0-9_]+\)'), // Fixed extra \s*

      // Intl package
      RegExp(r'Intl\s*\.\s*message\s*\(\s*.*\s*\)'),
      RegExp(r'Intl\s*\.\s*plural\s*\(\s*[0-9]+.*\s*\)'),
      RegExp(r'Intl\s*\.\s*select\s*\(\s*[^,]+,\s*\{.*\}\s*\)'),
      RegExp(r'Intl\s*\.\s*gender\s*\(\s*.*\s*\)'),

      // Common i18n patterns
      RegExp(r'I18n\s*\.\s*of\s*\(\s*[^)]+\s*\)\s*\.\s*[a-zA-Z0-9_]+'),
      RegExp(r'S\s*\.\s*of\s*\(\s*[^)]+\s*\)\s*\.\s*[a-zA-Z0-9_]+'),
      RegExp(r'S\s*\.\s*current\s*\.\s*[a-zA-Z0-9_]+'),

      // Context extensions
      RegExp(r'context\s*\.\s*l10n\s*\.\s*[a-zA-Z0-9_]+'),
      RegExp(r'context\s*\.\s*tr\s*\.\s*[a-zA-Z0-9_]+'),
      RegExp(r'context\s*\.\s*translate\s*\(\s*.*\s*\)'),

      // Custom translation functions
      RegExp(r'translate\s*\(\s*[a-zA-Z0-9_]+\s*\)'),
      RegExp(r'''localize\s*\(\s*["\'][a-zA-Z0-9_]+["\']\s*\)'''),
      RegExp(r'''i18n\s*\(\s*["\'][a-zA-Z0-9_]+["\']\s*\)'''),
      RegExp(r'''l10n\s*\(\s*["\'][a-zA-Z0-9_]+["\']\s*\)'''),

      // Generated localization classes
      RegExp(r'''[A-Z][a-zA-Z0-9]*Messages\s*\.\s*[a-zA-Z0-9_]+'''),
      RegExp(r'[A-Z][a-zA-Z0-9]*Strings\s*\.\s*[a-zA-Z0-9_]+'),
    ];

    for (final pattern in localizationPatterns) {
      if (pattern.hasMatch(line)) {
        if (config.verbose) {
          print(
              'Matched localization pattern: ${pattern.pattern} in line: $line');
        }
        return true;
      }
    }

    if (localizedKeys.contains(content.trim())) {
      if (config.verbose) {
        print('Matched localized key: $content');
      }
      return true;
    }

    // Only consider test-related strings as localized if they're in a test file
    if ((line.contains('expect(') ||
            line.contains('test(') ||
            line.contains('assert(')) &&
        config.excludeDirs.contains('test')) {
      return true;
    }

    // Only skip comments if includeComments is false
    if (!config.includeComments &&
        (line.trim().startsWith('//') ||
            line.trim().startsWith('/*') ||
            line.trim().endsWith('*/'))) {
      return true;
    }

    // String interpolation alone doesn't mean it's localized
    // Only consider it localized if it's part of a localization pattern
    // String interpolation alone doesn't mean it's localized
    // Only consider it localized if it's part of a localization pattern or contains only variables
    if (line.contains(r'${') && line.contains('}')) {
      // Check if the string contains only interpolation variables and no actual text
      final interpolationPattern = RegExp(r'\$\{[^}]+\}');
      final withoutInterpolation = line.replaceAll(interpolationPattern, '');

      // If it has only variables or is part of a localization pattern, consider it localized
      if (localizationPatterns.any((pattern) => pattern.hasMatch(line))) {
        return true;
      }
      return false;
    }

    return false;
  }
}

String generateReport(List<NonLocalizedString> results) {
  final buffer = StringBuffer();
  buffer.writeln('Found ${results.length} non-localized strings:\n');
  for (var i = 0; i < results.length; i++) {
    final result = results[i];
    buffer.writeln(
        '${i + 1}. ${result.filePath}:${result.lineNumber} - "${result.content}"');
    buffer.writeln('Context:');
    // Calculate the starting line number for context
    // The _getContext method already gets lines starting from lineNumber-1
    final contextStartLine = result.lineNumber - 1;
    for (int j = 0; j < result.context.length; j++) {
      final contextLineNum = contextStartLine + j;
      // Fix: Compare with the actual line number (contextLineNum + 1) instead of contextLineNum
      final indicator = (contextLineNum + 1) == result.lineNumber ? '>' : ' ';
      buffer.writeln('$indicator ${contextLineNum + 1}: ${result.context[j]}');
    }
    buffer.writeln();
  }
  return buffer.toString();
}
