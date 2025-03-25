import 'dart:convert';
import 'dart:io';

import 'package:loc_checker/models/models.dart';
import 'package:path/path.dart' as path;

class ArbGenerator {
  final String outputDir;
  final bool verbose;

  ArbGenerator({required this.outputDir, this.verbose = false});

  void generateArbFile(List<NonLocalizedString> nonLocalizedStrings) {
    final arbFile = File(path.join(outputDir, 'en.arb'));
    final arbMap = _createArbMap(nonLocalizedStrings);

    final encoder = JsonEncoder.withIndent('  ');
    arbFile.writeAsStringSync(encoder.convert(arbMap));
    if (verbose)
      print(
          'Generated ARB file at ${arbFile.path} with ${arbMap.length ~/ 2} entries');
  }

  Map<String, dynamic> _createArbMap(List<NonLocalizedString> strings) {
    final arbMap = <String, dynamic>{};
    final valueToKeyMap = <String, String>{};
    var counter = 0;

    for (final string in strings) {
      final content = string.content.trim();
      if (content.isEmpty) {
        if (verbose)
          print(
              'Skipped empty string at ${string.filePath}:${string.lineNumber}');
        continue;
      }

      if (valueToKeyMap.containsKey(content)) {
        if (verbose)
          print('Reusing key ${valueToKeyMap[content]} for "$content"');
        continue;
      }

      var baseKey = _toCamelCase(content);
      if (!_isValidArbKey(baseKey)) {
        baseKey = 'string${counter++}';
      }

      var key = baseKey;
      while (arbMap.containsKey(key) || arbMap.containsKey('@$key')) {
        counter++;
        key = '$baseKey$counter';
      }

      valueToKeyMap[content] = key;
      arbMap[key] = content;
      if (content.contains('{')) {
        arbMap['@$key'] = {
          'description':
              'String with placeholders from ${string.filePath}:${string.lineNumber}',
          'placeholders': _extractPlaceholders(content),
        };
      }
      if (verbose) print('Added to ARB: $key: "$content"');
    }

    return arbMap;
  }

  Map<String, dynamic> _extractPlaceholders(String content) {
    final placeholders = <String, dynamic>{};
    final matches = RegExp(r'\{param(\d+)\}').allMatches(content);
    for (final match in matches) {
      final index = match.group(1)!;
      placeholders['param$index'] = {};
    }
    return placeholders;
  }

  String _toCamelCase(String text) {
    final cleanedText = text.replaceAll(RegExp(r'\{param[0-9]+\}'), '');
    final words = cleanedText.trim().split(RegExp(r'\s+'));
    if (words.isEmpty || words.every((w) => w.isEmpty)) return 'unnamedString';

    final camelCaseWords = <String>[];
    for (var i = 0; i < words.length; i++) {
      final word = words[i];
      if (word.isEmpty) continue;
      if (i == 0) {
        camelCaseWords.add(word.toLowerCase());
      } else {
        camelCaseWords
            .add('${word[0].toUpperCase()}${word.substring(1).toLowerCase()}');
      }
    }
    return camelCaseWords.join().replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');
  }

  bool _isValidArbKey(String key) {
    return RegExp(r'^[a-zA-Z][a-zA-Z0-9_]*$').hasMatch(key);
  }
}
