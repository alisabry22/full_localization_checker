import 'dart:convert';
import 'dart:io';

import '../models/models.dart';

class ArbGenerator {
  final String outputDirectory;
  final bool verbose;

  ArbGenerator({required this.outputDirectory, this.verbose = false});

  /// Smart ARB generation with intelligent merging
  Future<void> generateSmartArb(
      List<NonLocalizedString> nonLocalizedStrings) async {
    if (verbose) {
      print('🔧 Generating smart ARB files with intelligent merging...');
    }

    final arbPath = '$outputDirectory/app_en.arb';
    final arbFile = File(arbPath);

    // Load existing ARB content if it exists
    Map<String, dynamic> existingArb = {};
    if (await arbFile.exists()) {
      try {
        final content = await arbFile.readAsString();
        existingArb = json.decode(content) as Map<String, dynamic>;
        if (verbose) {
          print('📖 Loaded existing ARB with ${existingArb.length} entries');
        }
      } catch (e) {
        if (verbose) {
          print('⚠️ Error reading existing ARB: $e. Creating new one.');
        }
      }
    }

    // Process new strings and merge intelligently
    final newEntries = <String, dynamic>{};
    final skippedEntries = <String>[];

    for (final nonLocalizedString in nonLocalizedStrings) {
      final key = _generateKey(nonLocalizedString.content);
      final value = nonLocalizedString.content;

      // Check if key or value already exists
      if (_entryExists(existingArb, key, value)) {
        skippedEntries.add(key);
        if (verbose) {
          print('⏭️ Skipped existing: "$key" = "$value"');
        }
        continue;
      }

      // Add new entry with metadata
      newEntries[key] = value;

      final metadata = <String, dynamic>{};

      if (nonLocalizedString.variables.isNotEmpty) {
        final placeholders = <String, dynamic>{};
        for (int i = 0; i < nonLocalizedString.variables.length; i++) {
          placeholders['param$i'] = {
            'type': 'String',
            'example': nonLocalizedString.variables[i],
          };
        }
        metadata['placeholders'] = placeholders;
      }

      if (metadata.isNotEmpty) {
        newEntries['@$key'] = metadata;
      }
    }

    if (newEntries.isEmpty) {
      if (verbose) {
        print('✅ No new strings to add. All strings already exist in ARB.');
      }
      return;
    }

    // Merge and sort alphabetically
    final mergedArb = _mergeAndSort(existingArb, newEntries);

    // Write back to file with beautiful formatting
    await _writeFormattedArb(arbFile, mergedArb);

    if (verbose) {
      print('✅ Smart ARB generation completed:');
      print(
          '   - New entries added: ${newEntries.length ~/ 2}'); // Divide by 2 because of metadata
      print('   - Existing entries skipped: ${skippedEntries.length}');
      print('   - Total entries: ${mergedArb.length ~/ 2}');
      print('   - File: $arbPath');
    }
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
    for (int i = 1; i < words.length; i++) {
      if (words[i].isNotEmpty) {
        key += words[i][0].toUpperCase() + words[i].substring(1);
      }
    }

    // Ensure it starts with a letter
    if (!RegExp(r'^[a-zA-Z]').hasMatch(key)) {
      key = 'key$key';
    }

    // Limit length
    if (key.length > 50) {
      key = key.substring(0, 47) + '...';
    }

    return key;
  }

  /// Check if an entry already exists (by key or value)
  bool _entryExists(Map<String, dynamic> arb, String key, String value) {
    // Check if exact key exists
    if (arb.containsKey(key)) {
      return true;
    }

    // Check if value already exists under a different key
    for (final entry in arb.entries) {
      if (!entry.key.startsWith('@') && entry.value == value) {
        return true;
      }
    }

    return false;
  }

  /// Merge existing and new ARB entries, sorting alphabetically
  Map<String, dynamic> _mergeAndSort(
      Map<String, dynamic> existing, Map<String, dynamic> newEntries) {
    final merged = <String, dynamic>{};

    // Start with existing entries
    merged.addAll(existing);

    // Add new entries
    merged.addAll(newEntries);

    // Separate keys and metadata
    final regularKeys = <String>[];
    final metadataEntries = <String, dynamic>{};

    for (final entry in merged.entries) {
      if (entry.key.startsWith('@')) {
        metadataEntries[entry.key] = entry.value;
      } else {
        regularKeys.add(entry.key);
      }
    }

    // Sort regular keys alphabetically
    regularKeys.sort();

    // Build sorted ARB
    final sortedArb = <String, dynamic>{};

    for (final key in regularKeys) {
      sortedArb[key] = merged[key];

      // Add metadata if it exists
      final metadataKey = '@$key';
      if (metadataEntries.containsKey(metadataKey)) {
        sortedArb[metadataKey] = metadataEntries[metadataKey];
      }
    }

    return sortedArb;
  }

  /// Write ARB file with beautiful formatting and comments
  Future<void> _writeFormattedArb(File file, Map<String, dynamic> arb) async {
    final buffer = StringBuffer();
    buffer.writeln('{');

    // Add header comment
    buffer.writeln('  "@@locale": "en",');
    buffer
        .writeln('  "@@last_modified": "${DateTime.now().toIso8601String()}",');
    buffer.writeln('  "@@generated_by": "loc_checker",');
    buffer.writeln('  "@@description": "Auto-generated localization file",');
    buffer.writeln('');

    final entries = arb.entries.toList();
    for (int i = 0; i < entries.length; i++) {
      final entry = entries[i];
      final isLast = i == entries.length - 1;

      if (entry.key.startsWith('@') &&
          !['@@locale', '@@last_modified', '@@generated_by', '@@description']
              .contains(entry.key)) {
        // Format metadata with proper indentation
        buffer.writeln('  "${entry.key}": {');
        if (entry.value is Map) {
          final metadata = entry.value as Map<String, dynamic>;
          final metadataEntries = metadata.entries.toList();
          for (int j = 0; j < metadataEntries.length; j++) {
            final metaEntry = metadataEntries[j];
            final isLastMeta = j == metadataEntries.length - 1;
            final value = metaEntry.value is String
                ? '"${_escapeJson(metaEntry.value as String)}"'
                : metaEntry.value;
            buffer.write('    "${metaEntry.key}": $value');
            if (!isLastMeta) buffer.write(',');
            buffer.writeln();
          }
        }
        buffer.write('  }');
      } else if (!entry.key.startsWith('@')) {
        // Format regular entries
        final escapedValue = _escapeJson(entry.value.toString());
        buffer.write('  "${entry.key}": "$escapedValue"');
      } else {
        // Skip already handled @@entries
        continue;
      }

      if (!isLast) buffer.write(',');
      buffer.writeln();
    }

    buffer.writeln('}');

    await file.writeAsString(buffer.toString());
  }

  /// Escape JSON special characters
  String _escapeJson(String text) {
    return text
        .replaceAll('\\', '\\\\')
        .replaceAll('"', '\\"')
        .replaceAll('\n', '\\n')
        .replaceAll('\r', '\\r')
        .replaceAll('\t', '\\t');
  }

  /// Generate multiple language ARB files
  Future<void> generateMultiLanguageArbs(
      List<NonLocalizedString> nonLocalizedStrings,
      List<String> languages) async {
    for (final language in languages) {
      if (language == 'en') {
        await generateSmartArb(nonLocalizedStrings);
      } else {
        await _generateTemplateArb(language, nonLocalizedStrings);
      }
    }
  }

  /// Generate template ARB for other languages
  Future<void> _generateTemplateArb(
      String language, List<NonLocalizedString> nonLocalizedStrings) async {
    final arbPath = '$outputDirectory/app_$language.arb';
    final arbFile = File(arbPath);

    final arb = <String, dynamic>{
      '@@locale': language,
      '@@last_modified': DateTime.now().toIso8601String(),
      '@@generated_by': 'loc_checker',
      '@@description':
          'Template localization file for $language - NEEDS TRANSLATION',
    };

    for (final nonLocalizedString in nonLocalizedStrings) {
      final key = _generateKey(nonLocalizedString.content);
      // Keep original text as placeholder - translators will replace
      arb[key] = '[TODO: TRANSLATE] ${nonLocalizedString.content}';

      final metadata = <String, dynamic>{};

      if (nonLocalizedString.variables.isNotEmpty) {
        final placeholders = <String, dynamic>{};
        for (int i = 0; i < nonLocalizedString.variables.length; i++) {
          placeholders['param$i'] = {
            'type': 'String',
            'example': nonLocalizedString.variables[i],
          };
        }
        metadata['placeholders'] = placeholders;
      }

      if (metadata.isNotEmpty) {
        arb['@$key'] = metadata;
      }
    }

    await _writeFormattedArb(arbFile, arb);

    if (verbose) {
      print('📝 Generated template ARB for $language: $arbPath');
    }
  }
}
