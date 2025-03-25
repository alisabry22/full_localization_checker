import 'dart:convert';
import 'dart:io';

import 'package:loc_checker/main.dart';
import 'package:path/path.dart' as path;

/// Generates an ARB file from a list of non-localized strings
String generateArbContent(List<NonLocalizedString> results) {
  final Map<String, dynamic> arbMap = {};
  
  // Add the @@locale property for English locale
  arbMap['@@locale'] = 'en';

  // Process each non-localized string
  for (var i = 0; i < results.length; i++) {
    final result = results[i];
    final content = result.content;

    // Generate a key based on the content
    final key = _generateKeyFromString(content, i);

    // Add to ARB map
    arbMap[key] = content;
  }

  // Convert to JSON with proper formatting
  return JsonEncoder.withIndent('  ').convert(arbMap);
}

/// Writes the ARB content to a file
Future<void> writeArbFile(
    List<NonLocalizedString> results, String projectPath) async {
  final arbContent = generateArbContent(results);

  // Determine the output path
  final outputPath =
      path.join(projectPath, 'lib', 'l10n', 'missing_strings.arb');

  // Ensure the directory exists
  final directory = Directory(path.dirname(outputPath));
  if (!directory.existsSync()) {
    directory.createSync(recursive: true);
  }

  // Write the file
  final outputFile = File(outputPath);
  await outputFile.writeAsString(arbContent);

  return;
}

/// Generates a key from a string content
String _generateKeyFromString(String content, int index) {
  // Clean the string to create a valid key
  var key = content
      .trim()
      .toLowerCase()
      // Remove special characters
      .replaceAll(RegExp(r'[^\w\s]'), '')
      // Ensure it starts with a letter
      .replaceAll(RegExp(r'^[^a-zA-Z]+'), '');

  // Convert to camelCase
  var words = key.split(RegExp(r'\s+'));
  if (words.isNotEmpty) {
    key = words[0]; // First word stays lowercase
    // Capitalize first letter of remaining words
    for (var i = 1; i < words.length; i++) {
      if (words[i].isNotEmpty) {
        key += words[i][0].toUpperCase() + words[i].substring(1);
      }
    }
  }

  // Limit key length
  if (key.length > 30) {
    key = key.substring(0, 30);
  }

  // If key is empty or doesn't start with a letter, use a default
  if (key.isEmpty || !RegExp(r'^[a-zA-Z]').hasMatch(key)) {
    key = 'string$index';
  }

  return key;
}
