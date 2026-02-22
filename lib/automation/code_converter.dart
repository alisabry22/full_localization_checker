import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'dart:io';

import '../models/models.dart';

/// Automatic code converter that transforms hardcoded strings to localization calls
class AutoCodeConverter {
  final String projectPath;
  final bool verbose;
  final bool dryRun;

  AutoCodeConverter({
    required this.projectPath,
    this.verbose = false,
    this.dryRun = false,
  });

  /// Convert all non-localized strings to AppLocalizations calls
  Future<ConversionResult> convertAllStrings(
      List<NonLocalizedString> nonLocalizedStrings) async {
    if (verbose) {
      print('🔄 Starting automatic code conversion...');
      if (dryRun) {
        print('🔍 DRY RUN MODE - No files will be modified');
      }
    }

    final conversions = <CodeConversion>[];
    final failedConversions = <String>[];
    final filesModified = <String>{};

    // Group strings by file for efficient processing
    final stringsByFile = <String, List<NonLocalizedString>>{};
    for (final string in nonLocalizedStrings) {
      stringsByFile.putIfAbsent(string.filePath, () => []).add(string);
    }

    for (final entry in stringsByFile.entries) {
      final filePath = entry.key;
      final strings = entry.value;

      try {
        final result = await _convertFile(filePath, strings);
        conversions.addAll(result.conversions);
        if (result.conversions.isNotEmpty) {
          filesModified.add(filePath);
        }
      } catch (e) {
        failedConversions.add('$filePath: $e');
        if (verbose) {
          print('❌ Failed to convert $filePath: $e');
        }
      }
    }

    final result = ConversionResult(
      conversions: conversions,
      failedConversions: failedConversions,
      filesModified: filesModified.toList(),
      totalStringsProcessed: nonLocalizedStrings.length,
    );

    if (verbose) {
      print('✅ Code conversion completed:');
      print('   - Files modified: ${filesModified.length}');
      print('   - Strings converted: ${conversions.length}');
      print('   - Failed conversions: ${failedConversions.length}');
    }

    return result;
  }

  Future<FileConversionResult> _convertFile(
      String filePath, List<NonLocalizedString> strings) async {
    final file = File('$projectPath/$filePath');
    if (!await file.exists()) {
      throw Exception('File not found: $filePath');
    }

    final originalContent = await file.readAsString();
    final parseResult = parseString(content: originalContent);
    final unit = parseResult.unit;
    final lines = originalContent.split('\n');
    String modifiedContent = originalContent;

    final conversions = <CodeConversion>[];
    final Map<int, SourceEdit> editsMap = {};
    bool needsImport = false;

    for (final string in strings) {
      final conversion = _generateConversion(string, lines);
      if (conversion != null) {
        conversions.add(conversion);
        needsImport = true;

        // 1. Add edit for the string itself
        editsMap[string.offset] = SourceEdit(
            offset: string.offset,
            length: string.length,
            replacement: conversion.localizationCall);

        // 2. Add edits to remove parent const modifiers
        _findConstRemovals(unit, string.offset, editsMap);

        if (verbose) {
          print(
              '🔄 Converted: "${string.content}" → ${conversion.localizationCall}');
        }
      }
    }

    // Apply edits backwards (bottom to top) to avoid offset shifting
    final sortedEdits = editsMap.values.toList()..sort();
    for (final edit in sortedEdits) {
      // Small optimization: If we remove 'const ', we might leave an extra space but the dart formatter can fix it
      // Let's check if the char after 'const' is a space, and remove it too to be clean.
      int editLength = edit.length;
      if (edit.replacement.isEmpty &&
          edit.offset + editLength < modifiedContent.length &&
          modifiedContent[edit.offset + editLength] == ' ') {
        editLength += 1; // Remove trailing space after const
      }

      modifiedContent = modifiedContent.replaceRange(
          edit.offset, edit.offset + editLength, edit.replacement);
    }

    // Add import if needed
    if (needsImport && !_hasLocalizationImport(originalContent)) {
      modifiedContent = await _addLocalizationImport(modifiedContent);
      if (verbose) {
        print('📦 Added localization import to $filePath');
      }
    }

    // Write the modified content
    if (!dryRun && modifiedContent != originalContent) {
      await file.writeAsString(modifiedContent);
    }

    return FileConversionResult(
      filePath: filePath,
      conversions: conversions,
      originalContent: originalContent,
      modifiedContent: modifiedContent,
    );
  }

  void _findConstRemovals(
      CompilationUnit unit, int stringOffset, Map<int, SourceEdit> editsMap) {
    final finder = OffsetNodeFinder(stringOffset);
    unit.visitChildren(finder);
    AstNode? node = finder.targetNode;
    if (node == null) return;

    AstNode? current = node;
    while (current != null) {
      Token? constToken;
      bool replaceWithFinal = false;

      if (current is InstanceCreationExpression) {
        if (current.keyword?.lexeme == 'const') {
          constToken = current.keyword;
        }
      } else if (current is TypedLiteral) {
        if (current.constKeyword?.lexeme == 'const') {
          constToken = current.constKeyword;
        }
      } else if (current is VariableDeclarationList) {
        if (current.keyword?.lexeme == 'const') {
          constToken = current.keyword;
          replaceWithFinal = true;
        }
      }

      if (constToken != null) {
        editsMap[constToken.offset] = SourceEdit(
          offset: constToken.offset,
          length: constToken.length,
          replacement: replaceWithFinal ? 'final' : '',
        );
      }
      current = current.parent;
    }
  }

  bool _isCleanArchitectureNonUi(String filePath) {
    final path = filePath.toLowerCase();
    return path.contains('/domain/') ||
        path.contains('/data/') ||
        path.contains('/bloc/') ||
        path.contains('/cubit') ||
        path.contains('/usecases/') ||
        path.contains('/repositories/') ||
        path.endsWith('_bloc.dart') ||
        path.endsWith('_cubit.dart') ||
        path.endsWith('_repository.dart') ||
        path.endsWith('_usecase.dart');
  }

  /// Generate a conversion for a specific string
  CodeConversion? _generateConversion(
      NonLocalizedString string, List<String> fileLines) {
    if (_isCleanArchitectureNonUi(string.filePath)) {
      if (verbose) {
        print(
            '⏭️ Skipped (Clean Architecture): "${string.content}" in ${string.filePath} (Non-UI layer)');
      }
      return null;
    }

    final key = _generateKey(string.content);
    final pattern = _detectWidgetPattern(string.context);
    final args =
        string.variables.isNotEmpty ? '(${string.variables.join(', ')})' : '';

    // Enhanced context detection with priority order
    String localizationCall;
    ConversionType conversionType;

    // PRIORITY 1: Check if we're in a widget file context (most reliable)
    if (_isInWidgetFileContext(fileLines, string.lineNumber)) {
      // Use context.l10n for all widget file contexts
      localizationCall = 'context.l10n.$key$args';
      conversionType = ConversionType.widgetContext;
    }
    // PRIORITY 2: Check immediate context for dialog/builder patterns
    else if (_isInDialogContext(string.context) ||
        _isInBuilderContext(string.context)) {
      // Use context.l10n for dialogs and builders
      localizationCall = 'context.l10n.$key$args';
      conversionType = ConversionType.widgetContext;
    }
    // PRIORITY 3: Check immediate widget context
    else if (_isInWidgetContext(string.context)) {
      // Use context.l10n for immediate widget context
      localizationCall = 'context.l10n.$key$args';
      conversionType = ConversionType.widgetContext;
    }
    // FALLBACK: Use static access only if definitely not in widget context
    else {
      localizationCall = 'AppLocalizations.of(context)!.$key$args';
      conversionType = ConversionType.staticAccess;
    }

    return CodeConversion(
      originalString: string.content,
      localizationKey: key,
      localizationCall: localizationCall,
      filePath: string.filePath,
      lineNumber: string.lineNumber,
      pattern: pattern,
      conversionType: conversionType,
    );
  }

  /// Generate a camelCase key from the string content
  String _generateKey(String content) {
    // Remove special characters and normalize
    String normalized =
        content.replaceAll(RegExp(r'[^\w\s]'), '').trim().toLowerCase();

    // Convert to camelCase
    final words = normalized.split(RegExp(r'\s+'));
    if (words.isEmpty) return 'unknownKey';

    String key = words.first;
    for (int i = 1; i < words.length && i < 8; i++) {
      // Limit to 8 words max
      if (words[i].isNotEmpty) {
        key += words[i][0].toUpperCase() + words[i].substring(1);
      }
    }

    // Ensure it starts with a letter
    if (!RegExp(r'^[a-zA-Z]').hasMatch(key)) {
      key = 'text$key';
    }

    // Remove any remaining invalid characters
    key = key.replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '');

    // Limit length to 50 characters max for valid ARB keys
    if (key.length > 50) {
      key = key.substring(0, 47) + 'etc';
    }

    // Ensure it's not empty
    if (key.isEmpty) {
      key = 'textKey';
    }

    return key;
  }

  /// Detect the widget pattern where the string was found
  String _detectWidgetPattern(List<String> contextLines) {
    final patterns = <String, String>{
      'Text(': 'Text widget',
      'TextFormField(': 'Form field',
      'AppBar(': 'App bar',
      'SnackBar(': 'Snack bar',
      'AlertDialog(': 'Dialog',
      'ElevatedButton(': 'Button',
      'TextButton(': 'Button',
      'FloatingActionButton(': 'FAB',
      'ListTile(': 'List item',
      'Tooltip(': 'Tooltip',
      'validator:': 'Validation',
      'labelText:': 'Label',
      'hintText:': 'Hint',
      'errorText:': 'Error',
    };

    for (final line in contextLines) {
      for (final entry in patterns.entries) {
        if (line.contains(entry.key)) {
          return entry.value;
        }
      }
    }

    return 'Unknown';
  }

  /// Check if the string is in a widget context (can use context.l10n)
  bool _isInWidgetContext(List<String> contextLines) {
    // Always prefer context.l10n in Flutter widget contexts
    // This includes dialogs, widgets within showDialog, etc.

    final widgetPatterns = [
      'class ',
      'extends StatelessWidget',
      'extends StatefulWidget',
      'Widget build(BuildContext context)',
      '@override',
      'builder: (context)',
      'builder: (BuildContext context)',
      'AlertDialog(',
      'SimpleDialog(',
      'Dialog(',
      'showDialog(',
      'showModalBottomSheet(',
      'BottomSheet(',
      'Scaffold(',
      'AppBar(',
      'FloatingActionButton(',
      'Drawer(',
      'Column(',
      'Row(',
      'Container(',
      'Card(',
      'ListTile(',
      'Text(',
      'ElevatedButton(',
      'TextButton(',
      'OutlinedButton(',
      'IconButton(',
      'TextFormField(',
      'TextField(',
      'SnackBar(',
      'Tooltip(',
    ];

    // Check if we're in any widget context
    for (final line in contextLines) {
      for (final pattern in widgetPatterns) {
        if (line.contains(pattern)) {
          return true;
        }
      }
    }

    return false;
  }

  /// Enhanced context detection for specific scenarios
  bool _isInDialogContext(List<String> contextLines) {
    final dialogPatterns = [
      'AlertDialog(',
      'SimpleDialog(',
      'Dialog(',
      'showDialog(',
      'showModalBottomSheet(',
      'showCupertinoDialog(',
      'CupertinoAlertDialog(',
    ];

    return contextLines
        .any((line) => dialogPatterns.any((pattern) => line.contains(pattern)));
  }

  /// Check if we're in a builder function context
  bool _isInBuilderContext(List<String> contextLines) {
    final builderPatterns = [
      'builder: (context)',
      'builder: (BuildContext context)',
      'itemBuilder: (context',
      'itemBuilder: (BuildContext context',
      'separatorBuilder: (context',
      'separatorBuilder: (BuildContext context',
    ];

    return contextLines.any(
        (line) => builderPatterns.any((pattern) => line.contains(pattern)));
  }

  /// Check if we're in a widget file context (most comprehensive check)
  bool _isInWidgetFileContext(List<String> fileLines, int lineNumber) {
    // Look in a broader range around the string location
    final startLine = (lineNumber - 20).clamp(0, fileLines.length - 1);
    final endLine = (lineNumber + 10).clamp(0, fileLines.length - 1);

    // Check if this file contains widget classes
    for (int i = 0; i < fileLines.length; i++) {
      final line = fileLines[i].trim();

      // Strong indicators that this is a widget file
      if (line.contains('extends StatelessWidget') ||
          line.contains('extends StatefulWidget') ||
          line.contains('Widget build(BuildContext context)') ||
          line.contains('class ') && line.contains('Widget')) {
        return true;
      }
    }

    // Check if we're within a widget method or builder function
    for (int i = startLine; i <= endLine; i++) {
      final line = fileLines[i].trim();

      if (line.contains('Widget build(') ||
          line.contains('builder: (context') ||
          line.contains('builder: (BuildContext context') ||
          line.contains('itemBuilder:') ||
          line.contains('separatorBuilder:') ||
          line.contains('showDialog(') ||
          line.contains('showModalBottomSheet(') ||
          line.contains('AlertDialog(') ||
          line.contains('SimpleDialog(') ||
          line.contains('BottomSheet(')) {
        return true;
      }
    }

    // Check the specific method/function we're in
    return _isInWidgetMethodContext(fileLines, lineNumber);
  }

  /// Check if we're inside a widget method context
  bool _isInWidgetMethodContext(List<String> fileLines, int lineNumber) {
    // Look backwards to find the method we're in
    for (int i = lineNumber - 1; i >= 0; i--) {
      final line = fileLines[i].trim();

      // Found a widget-related method
      if (line.contains('Widget ') && line.contains('(') ||
          line.contains('build(BuildContext context)') ||
          line.contains('builder: (context') ||
          line.contains('builder: (BuildContext context')) {
        return true;
      }

      // Stop if we hit a class declaration or other method
      if (line.startsWith('class ') ||
          (line.contains('(') &&
              line.contains(')') &&
              line.contains('{') &&
              !line.contains('Widget') &&
              !line.contains('builder:'))) {
        break;
      }
    }

    return false;
  }

  /// Check if the file already has localization import
  bool _hasLocalizationImport(String content) {
    return content.contains('flutter_gen/gen_l10n/app_localizations.dart') ||
        content.contains('generated/l10n.dart') ||
        content.contains('app_localizations.dart');
  }

  /// Read package name from pubspec.yaml
  Future<String> _getPackageName() async {
    final pubspecFile = File('$projectPath/pubspec.yaml');
    if (await pubspecFile.exists()) {
      final content = await pubspecFile.readAsString();
      final match = RegExp(r'^name:\s*([a-zA-Z0-9_]+)', multiLine: true)
          .firstMatch(content);
      if (match != null) {
        return match.group(1)!;
      }
    }
    return 'app'; // fallback
  }

  /// Add localization import to the file
  Future<String> _addLocalizationImport(String content) async {
    final packageName = await _getPackageName();
    final lines = content.split('\n');
    int importInsertIndex = 0;

    // Find the best place to insert the import
    for (int i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.startsWith('import ') && line.contains('package:flutter/')) {
        importInsertIndex = i + 1;
      } else if (line.startsWith('import ') && !line.contains('dart:')) {
        importInsertIndex = i;
        break;
      }
    }

    // Insert the AppLocalizations import only if not already present
    if (!content.contains('flutter_gen/gen_l10n/app_localizations.dart')) {
      final importLine =
          "import 'package:flutter_gen/gen_l10n/app_localizations.dart';";
      lines.insert(importInsertIndex, importLine);
      importInsertIndex++;
    }

    // Insert the extension import for context.l10n support
    if (!content.contains('app_localizations_extension.dart')) {
      final extensionImport =
          "import 'package:$packageName/l10n/app_localizations_extension.dart';";
      lines.insert(importInsertIndex, extensionImport);
    }

    return lines.join('\n');
  }

  /// Convert specific patterns with custom logic
  Future<void> convertSpecificPattern({
    required String pattern,
    required String replacement,
    List<String>? fileExtensions,
  }) async {
    if (verbose) {
      print('🎯 Converting specific pattern: $pattern → $replacement');
    }

    final extensions = fileExtensions ?? ['.dart'];
    await for (final file in _getAllFiles(extensions)) {
      if (await file.exists()) {
        final content = await file.readAsString();
        final newContent = content.replaceAll(RegExp(pattern), replacement);

        if (content != newContent && !dryRun) {
          await file.writeAsString(newContent);
          if (verbose) {
            print('📝 Updated: ${file.path}');
          }
        }
      }
    }
  }

  /// Get all files with specified extensions
  Stream<File> _getAllFiles(List<String> extensions) async* {
    final directory = Directory(projectPath);
    await for (final entity in directory.list(recursive: true)) {
      if (entity is File) {
        final extension = entity.path.split('.').last;
        if (extensions.contains('.$extension')) {
          yield entity;
        }
      }
    }
  }
}

/// Result of the conversion process
class ConversionResult {
  final List<CodeConversion> conversions;
  final List<String> failedConversions;
  final List<String> filesModified;
  final int totalStringsProcessed;

  ConversionResult({
    required this.conversions,
    required this.failedConversions,
    required this.filesModified,
    required this.totalStringsProcessed,
  });

  double get successRate => totalStringsProcessed > 0
      ? conversions.length / totalStringsProcessed
      : 0.0;
}

/// Result of converting a single file
class FileConversionResult {
  final String filePath;
  final List<CodeConversion> conversions;
  final String originalContent;
  final String modifiedContent;

  FileConversionResult({
    required this.filePath,
    required this.conversions,
    required this.originalContent,
    required this.modifiedContent,
  });
}

/// Details of a single code conversion
class CodeConversion {
  final String originalString;
  final String localizationKey;
  final String localizationCall;
  final String filePath;
  final int lineNumber;
  final String pattern;
  final ConversionType conversionType;

  CodeConversion({
    required this.originalString,
    required this.localizationKey,
    required this.localizationCall,
    required this.filePath,
    required this.lineNumber,
    required this.pattern,
    required this.conversionType,
  });

  @override
  String toString() {
    return '[CONVERTED] "$originalString" → $localizationCall (${filePath}:${lineNumber})';
  }
}

/// Type of conversion applied
enum ConversionType {
  widgetContext, // Uses context.l10n.key
  staticAccess, // Uses AppLocalizations.of(context)!.key
}

class SourceEdit implements Comparable<SourceEdit> {
  final int offset;
  final int length;
  final String replacement;

  SourceEdit(
      {required this.offset, required this.length, required this.replacement});

  @override
  int compareTo(SourceEdit other) => other.offset.compareTo(offset);
}

class OffsetNodeFinder extends GeneralizingAstVisitor<void> {
  final int offset;
  AstNode? targetNode;

  OffsetNodeFinder(this.offset);

  @override
  void visitNode(AstNode node) {
    if (node.offset <= offset && offset < node.offset + node.length) {
      targetNode = node;
      super.visitNode(node);
    }
  }
}
