
import 'dart:convert';
import 'dart:io';

import 'package:file/local.dart';
import 'package:glob/glob.dart';
import 'package:path/path.dart' as path;

/// Configuration for the localization checker
class LocalizationCheckerConfig {
  final String projectPath;
  final String scanPath;
  final List<String> excludeDirs;
  final List<String> excludeFiles;
  final bool verbose;
  final bool includeComments;

  LocalizationCheckerConfig({
    required this.projectPath,
    String? scanPath,
    this.excludeDirs = const ['build', '.dart_tool', '.pub', '.git', 'test', 'bin'],
    this.excludeFiles = const [],
    this.verbose = false,
    this.includeComments = false,
  }):scanPath = scanPath ?? path.join(projectPath, 'lib');
}

/// Result of a non-localized string detection
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

/// Main class for detecting non-localized strings in Flutter apps
class LocalizationChecker {
  final LocalizationCheckerConfig config;
  final List<NonLocalizedString> _results = [];
  final Set<String> _localizedKeys = {};

  LocalizationChecker(this.config);

  /// Get the list of detected non-localized strings
  List<NonLocalizedString> get results => _results;

  /// Run the localization check on the project
  Future<void> run() async {
    // First, try to find and parse the localization files to extract existing keys
    await _findLocalizedKeys();
    
    // Then scan all Dart files for non-localized strings
    await _scanDartFiles();
  }

  /// Find and parse localization files to extract existing keys
  Future<void> _findLocalizedKeys() async {
    // Common patterns for localization files in Flutter apps
    final arbGlob = Glob('${config.projectPath}/**/**.arb');
    final dartGlob = Glob('${config.projectPath}/**/l10n.dart');
    final yamlGlob = Glob('${config.projectPath}/**/l10n.yaml');
    
    final fileSystem = LocalFileSystem();

    // Process ARB files (Flutter's official localization format)
    for (final entity in arbGlob.listFileSystemSync(fileSystem)) {
      if (entity is File) {
        try {
          final content = await (entity as File).readAsString();
          // ARB files are JSON format, so use json.decode instead of loadYaml
          final Map<String, dynamic> arbMap = json.decode(content) as Map<String, dynamic>;
          
          // Extract keys from ARB file (excluding metadata keys starting with @)
          for (final key in arbMap.keys) {
            if (!key.startsWith('@')) {
              _localizedKeys.add(key);
            }
          }
        } catch (e) {
          if (config.verbose) {
            print('Error parsing ARB file ${entity.path}: $e');
          }
        }
      }
    }
    
    if (config.verbose) {
      print('Found ${_localizedKeys.length} localized keys');
    }
  }

Future<void> _scanDartFiles() async {
  final dartGlob = Glob('${config.scanPath}/**/*.dart');
  
  for (final entity in dartGlob.listFileSystemSync(LocalFileSystem())) {
    if (entity is File) {
      final relativePath = path.relative(entity.path, from: config.projectPath);
      
      // Skip excluded directories
      if (config.excludeDirs.any((dir) => relativePath.startsWith(dir))) {
        continue;
      }
      
      // Skip excluded files
      if (config.excludeFiles.any((file) => relativePath.endsWith(file))) {
        continue;
      }
      
      // Skip test or CLI files explicitly
      if (relativePath.contains('test/') || relativePath.contains('bin/')) {
        continue;
      }
      
      await _checkFile(entity as File);
    }
  }
}
  /// Check a single Dart file for non-localized strings
  Future<void> _checkFile(File file) async {
    try {
      final lines = await file.readAsLines();
      final relativePath = path.relative(file.path, from: config.projectPath);
      
      for (int i = 0; i < lines.length; i++) {
        final line = lines[i];
        final lineNumber = i + 1;
        
        // Skip comments if not explicitly included
        if (!config.includeComments && (line.trim().startsWith('//') || line.trim().startsWith('/*'))) {
          continue;
        }
        
        // Find string literals in the line
        _findStringLiterals(line, lineNumber, relativePath, lines);
      }
    } catch (e) {
      if (config.verbose) {
        print('Error processing file ${file.path}: $e');
      }
    }
  }

 void _findStringLiterals(String line, int lineNumber, String filePath, List<String> allLines) {
  final regex = RegExp(
    r'''(?:"""(?:[^"]|\\")*?"""|'\'(?:[^']|\\')*?\''|"(?:[^"\\]|\\.)*?"|'(?:[^'\\]|\\.)*?')''',
    multiLine: true,
  );

  final matches = regex.allMatches(line);
  for (final match in matches) {
    final stringLiteral = match.group(0)!;
    final content = _cleanStringLiteral(stringLiteral);

    if (_shouldSkipString(content)) continue;

    // Check context to see if it's UI-related
    final contextLines = _getContext(allLines, lineNumber); // Returns List<String>
    final isUiRelated = contextLines.any((l) =>
        l.contains('Text(') || l.contains('SnackBar(') || l.contains('AlertDialog(') ||
        l.contains('labelText:') || l.contains('title:'));

    final isLogOrError = contextLines.any((l) =>
        l.contains('logger.') || l.contains('Exception(') || l.contains('throw') ||
        l.contains('left(') || l.contains('right('));

    if (isLogOrError || !isUiRelated) {
      if (config.verbose) print('Skipped (non-UI context): "$content" in $filePath:$lineNumber');
      continue;
    }

    if (_isLocalizedString(line, stringLiteral, content)) continue;

    _results.add(NonLocalizedString(
      filePath: filePath,
      lineNumber: lineNumber,
      content: content,
      context: contextLines, // List<String>
    ));
  }
}


  /// Clean a string literal by removing quotes and handling Dart escape sequences.
/// Returns the cleaned content or throws an exception for malformed literals.
String _cleanStringLiteral(String literal) {
  // Validate input
  if (literal.isEmpty) {
    return '';
  }

  // Check for valid quote types
  final isTripleQuoted = literal.startsWith("'''") || literal.startsWith('"""');
  final isSingleQuoted = literal.startsWith("'") && !literal.startsWith("'''");
  final isDoubleQuoted = literal.startsWith('"') && !literal.startsWith('"""');

  if (!(isTripleQuoted || isSingleQuoted || isDoubleQuoted)) {
    if (config.verbose) {
      print('Invalid string literal (no quotes): $literal');
    }
    return literal; // Return as-is or throw an exception depending on your needs
  }

  // Determine quote type and length
  final quoteLength = isTripleQuoted ? 3 : 1;
  final expectedEnd = isTripleQuoted
      ? literal.substring(0, 3)
      : literal.substring(0, 1);

  // Check if the string ends with the same quotes
  if (!literal.endsWith(expectedEnd)) {
    if (config.verbose) {
      print('Malformed string literal (unterminated): $literal');
    }
    return literal; // Return as-is or handle differently
  }

  // Extract content between quotes
  String content;
  try {
    content = literal.substring(quoteLength, literal.length - quoteLength);
  } catch (e) {
    if (config.verbose) {
      print('Error extracting content from literal: $literal - $e');
    }
    return literal;
  }

  // Handle escape sequences
  final buffer = StringBuffer();
  var i = 0;
  while (i < content.length) {
    if (content[i] == '\\' && i + 1 < content.length) {
      i++; // Skip the backslash
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
        case 'x': // Hex escape: \xHH
          if (i + 2 < content.length) {
            final hex = content.substring(i + 1, i + 3);
            try {
              buffer.writeCharCode(int.parse(hex, radix: 16));
              i += 2;
            } catch (e) {
              buffer.write(r'\x');
              i -= 1; // Rewind to process next char
            }
          } else {
            buffer.write(r'\x');
          }
          break;
        case 'u': // Unicode escape: \uHHHH or \u{HHHHHH}
          if (i + 1 < content.length && content[i + 1] == '{') {
            // Extended Unicode: \u{HHHHHH}
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
            // Standard Unicode: \uHHHH
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
          // Unknown escape sequence, preserve it
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
  // Existing checks
  if (content.isEmpty || content.trim().isEmpty) return true;
  if (content.startsWith('http://') || content.startsWith('https://')) return true;
  if (content.contains('/') && (content.endsWith('.dart') || content.endsWith('.json') || 
      content.endsWith('.arb') || content.endsWith('.yaml') || content.endsWith('.svg') || 
      content.endsWith('.png') || content.endsWith('.jpg') || content.endsWith('.mp4'))) return true;
  if (content.length == 1 || RegExp(r'^[0-9.,]+$').hasMatch(content)) return true;
  if (RegExp(r'^#[0-9a-fA-F]{3,8}$').hasMatch(content)) return true; // Color codes
  if (RegExp(r'^[yMdHhmsaZ\-/:\s]+$').hasMatch(content)) return true; // Date formats

  // New checks for your output
  // Skip paths and asset references
  if (content.startsWith('/') && content.length <= 20) return true; // e.g., "/tiktok"
  if (content.startsWith('assets/')) return true; // e.g., "assets/svg/linkedin.svg"

  // Skip API keys, IDs, and technical constants
  if (RegExp(r'^[a-zA-Z0-9_-]{10,}$').hasMatch(content)) return true; // e.g., "77snys45x7rmv3"
  if (content.contains('com.linkedin') || content.contains('user.info') || 
      content.contains('video.') || content.contains('oauth_')) return true; // API-specific

  // Skip HTTP headers and MIME types
  if (content == 'Content-Type' || content == 'Content-Length' || content == 'Content-Range' || 
      content.contains('application/') || content.contains('video/') || 
      content.contains('image/') || content.contains('multipart/')) return true;

  // Skip log-like or error messages (heuristic based on keywords)
  if (content.toLowerCase().contains('fail') || content.toLowerCase().contains('error') || 
      content.toLowerCase().contains('logger') || content.toLowerCase().contains('upload') || 
      content.toLowerCase().contains('connect') || content.toLowerCase().contains('push') || 
      content.toLowerCase().contains('process')) {
    return true;
  }

  // Skip code fragments
  if (content.contains(')') || content.contains('}') || content.contains(',') || 
      content.contains('??') || content.contains('format(')) {
    return true;
  }

  return false;
}

  bool _isLocalizedString(String line, String stringLiteral, String content) {
  // Existing localization patterns
  final localizationPatterns = [
    RegExp(r'AppLocalizations\.of\(context\)'),
    RegExp(r'S\.of\(context\)'),
    RegExp(r'[^a-zA-Z0-9]tr\('),
    RegExp(r'[^a-zA-Z0-9]translate\('),
    RegExp(r'[^a-zA-Z0-9]localize\('),
    RegExp(r'\.tr\b'),
    RegExp(r'LocaleKeys\.[a-zA-Z0-9_]+\.tr\(\)'),
    RegExp(r'I18n\.of\(context\)'),
  ];

  for (final pattern in localizationPatterns) {
    if (pattern.hasMatch(line)) return true;
  }

  if (_localizedKeys.contains(content)) return true;

  // Skip strings in test-related contexts
  if (line.contains('expect(') || line.contains('test(')) return true;

  return false;
}

/// Get context around a line for better understanding
List<String> _getContext(List<String> lines, int lineNumber) {
  final startLine = (lineNumber - 2).clamp(0, lines.length - 1);
  final endLine = (lineNumber + 1).clamp(0, lines.length - 1);
  return lines.sublist(startLine, endLine + 1);
}
}

String generateReport(List<NonLocalizedString> results) {
  final buffer = StringBuffer();
  buffer.writeln('Found ${results.length} non-localized strings:\n');
  for (var i = 0; i < results.length; i++) {
    final result = results[i];
    buffer.writeln('${i + 1}. ${result.filePath}:${result.lineNumber} - "${result.content}"');
    buffer.writeln('Context:');
    for (int j = 0; j < result.context.length; j++) {
      final lineNum = (result.lineNumber - 2 + j).clamp(0, result.lineNumber + 1);
      final indicator = lineNum == result.lineNumber ? '>' : ' ';
      buffer.writeln('$indicator $lineNum: ${result.context[j]}');
    }
    buffer.writeln();
  }
  return buffer.toString();
}

