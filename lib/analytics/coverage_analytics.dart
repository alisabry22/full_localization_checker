import 'dart:convert';
import 'dart:io';

import '../models/models.dart';

/// Comprehensive localization analytics and coverage tracking
class CoverageAnalytics {
  final bool verbose;
  final String projectPath;

  CoverageAnalytics({
    required this.projectPath,
    this.verbose = false,
  });

  /// Generates comprehensive localization analytics
  Future<LocalizationAnalytics> generateAnalytics({
    required List<NonLocalizedString> nonLocalizedStrings,
    required Map<String, List<String>> existingTranslations,
    required List<String> dartFiles,
  }) async {
    if (verbose) {
      print('📊 Generating comprehensive localization analytics...');
    }

    final totalStrings = await _countTotalStrings(dartFiles);
    final localizedStrings = _countLocalizedStrings(existingTranslations);
    final duplicateStrings = _findDuplicateStrings(nonLocalizedStrings);
    final unusedTranslations =
        await _findUnusedTranslations(existingTranslations, dartFiles);
    final filesCoverage =
        await _analyzeFilesCoverage(dartFiles, nonLocalizedStrings);
    final complexityAnalysis = _analyzeComplexity(nonLocalizedStrings);

    final analytics = LocalizationAnalytics(
      totalStringsFound: totalStrings,
      localizedStrings: localizedStrings,
      nonLocalizedStrings: nonLocalizedStrings.length,
      duplicateStrings: duplicateStrings,
      unusedTranslations: unusedTranslations,
      coveragePercentage: _calculateCoveragePercentage(
          totalStrings, nonLocalizedStrings.length),
      filesCoverage: filesCoverage,
      complexityScore: complexityAnalysis.complexityScore,
      recommendations: _generateRecommendations(
        nonLocalizedStrings,
        duplicateStrings,
        unusedTranslations,
        complexityAnalysis,
      ),
      summary: _generateSummary(
          totalStrings, localizedStrings, nonLocalizedStrings.length),
    );

    if (verbose) {
      print('✅ Analytics generation completed');
    }

    return analytics;
  }

  /// Counts total strings in Dart files (simplified)
  Future<int> _countTotalStrings(List<String> dartFiles) async {
    int totalCount = 0;

    for (final filePath in dartFiles) {
      try {
        final file = File(filePath);
        final content = await file.readAsString();

        // Simple string counting using regex
        final stringPattern = RegExp(r'''(['"])((?:\\.|(?!\1)[^\\])*?)\1''');
        final matches = stringPattern.allMatches(content);

        for (final match in matches) {
          final stringContent = match.group(2) ?? '';
          if (stringContent.isNotEmpty && stringContent.length > 1) {
            totalCount++;
          }
        }
      } catch (e) {
        if (verbose) {
          print('⚠️ Error counting strings in $filePath: $e');
        }
      }
    }

    return totalCount;
  }

  /// Counts existing localized strings
  int _countLocalizedStrings(Map<String, List<String>> translations) {
    return translations.values.fold(0, (sum, list) => sum + list.length);
  }

  /// Finds duplicate strings
  Map<String, List<NonLocalizedString>> _findDuplicateStrings(
      List<NonLocalizedString> strings) {
    final duplicates = <String, List<NonLocalizedString>>{};
    final contentMap = <String, List<NonLocalizedString>>{};

    // Group by content
    for (final string in strings) {
      final content = string.content.trim().toLowerCase();
      if (content.isNotEmpty) {
        contentMap.putIfAbsent(content, () => []).add(string);
      }
    }

    // Find duplicates
    for (final entry in contentMap.entries) {
      if (entry.value.length > 1) {
        duplicates[entry.key] = entry.value;
      }
    }

    return duplicates;
  }

  /// Finds unused translations by scanning usage in code
  Future<List<String>> _findUnusedTranslations(
    Map<String, List<String>> translations,
    List<String> dartFiles,
  ) async {
    final unusedKeys = <String>[];
    final allKeys = <String>{};

    // Collect all translation keys
    for (final keyList in translations.values) {
      allKeys.addAll(keyList);
    }

    if (verbose) {
      print('🔍 Checking ${allKeys.length} translation keys for usage...');
    }

    // Check each key for usage in code
    for (final key in allKeys) {
      bool isUsed = false;

      for (final filePath in dartFiles) {
        try {
          final file = File(filePath);
          final content = await file.readAsString();

          // Check various usage patterns
          if (content.contains(key) ||
              content.contains('.$key') ||
              content.contains("'$key'") ||
              content.contains('"$key"') ||
              content.contains('AppLocalizations.of(context).$key') ||
              content.contains('S.of(context).$key') ||
              content.contains('context.l10n.$key')) {
            isUsed = true;
            break;
          }
        } catch (e) {
          if (verbose) {
            print('⚠️ Error checking usage in $filePath: $e');
          }
        }
      }

      if (!isUsed) {
        unusedKeys.add(key);
      }
    }

    if (verbose) {
      print('📋 Found ${unusedKeys.length} unused translation keys');
    }

    return unusedKeys;
  }

  /// Analyzes coverage per file
  Future<Map<String, FileCoverage>> _analyzeFilesCoverage(
    List<String> dartFiles,
    List<NonLocalizedString> nonLocalizedStrings,
  ) async {
    final coverage = <String, FileCoverage>{};

    for (final filePath in dartFiles) {
      final relativeFilePath = filePath
          .replaceFirst(projectPath, '')
          .replaceFirst(RegExp(r'^[/\\]'), '');
      final fileStrings = nonLocalizedStrings
          .where((s) => s.filePath == relativeFilePath)
          .toList();

      try {
        final file = File(filePath);
        final content = await file.readAsString();
        final totalStringsInFile = await _countTotalStringsInFile(content);

        final coveragePercentage = totalStringsInFile > 0
            ? ((totalStringsInFile - fileStrings.length) /
                totalStringsInFile *
                100)
            : 100.0;

        coverage[relativeFilePath] = FileCoverage(
          filePath: relativeFilePath,
          totalStrings: totalStringsInFile,
          localizedStrings: totalStringsInFile - fileStrings.length,
          nonLocalizedStrings: fileStrings.length,
          coveragePercentage: coveragePercentage,
          issues: fileStrings
              .map((s) => '${s.lineNumber}: "${s.content}"')
              .toList(),
        );
      } catch (e) {
        if (verbose) {
          print('⚠️ Error analyzing coverage for $filePath: $e');
        }
      }
    }

    return coverage;
  }

  /// Counts total strings in a single file
  Future<int> _countTotalStringsInFile(String content) async {
    final stringPattern = RegExp(r'''(['"])((?:\\.|(?!\1)[^\\])*?)\1''');
    final matches = stringPattern.allMatches(content);

    int count = 0;
    for (final match in matches) {
      final stringContent = match.group(2) ?? '';
      if (stringContent.isNotEmpty && stringContent.length > 1) {
        count++;
      }
    }

    return count;
  }

  /// Analyzes complexity of localization requirements
  ComplexityAnalysis _analyzeComplexity(List<NonLocalizedString> strings) {
    int simpleStrings = 0;
    int interpolatedStrings = 0;
    int longStrings = 0;
    int complexStrings = 0;

    for (final string in strings) {
      final content = string.content;

      if (content.contains('{') && content.contains('}')) {
        interpolatedStrings++;
      }

      if (content.length > 50) {
        longStrings++;
      }

      if (content.contains('\n') || content.split(' ').length > 10) {
        complexStrings++;
      } else {
        simpleStrings++;
      }
    }

    // Calculate complexity score (0-100)
    final totalStrings = strings.length;
    if (totalStrings == 0) {
      return ComplexityAnalysis(
        complexityScore: 0,
        simpleStrings: 0,
        interpolatedStrings: 0,
        longStrings: 0,
        complexStrings: 0,
      );
    }

    final complexityScore =
        ((interpolatedStrings * 2 + longStrings * 1.5 + complexStrings * 3) /
                totalStrings *
                20)
            .clamp(0, 100)
            .toInt();

    return ComplexityAnalysis(
      complexityScore: complexityScore,
      simpleStrings: simpleStrings,
      interpolatedStrings: interpolatedStrings,
      longStrings: longStrings,
      complexStrings: complexStrings,
    );
  }

  /// Calculates coverage percentage
  double _calculateCoveragePercentage(
      int totalStrings, int nonLocalizedStrings) {
    if (totalStrings == 0) return 100.0;
    return ((totalStrings - nonLocalizedStrings) / totalStrings * 100)
        .clamp(0, 100);
  }

  /// Generates recommendations based on analysis
  List<String> _generateRecommendations(
    List<NonLocalizedString> nonLocalizedStrings,
    Map<String, List<NonLocalizedString>> duplicates,
    List<String> unusedTranslations,
    ComplexityAnalysis complexity,
  ) {
    final recommendations = <String>[];

    if (nonLocalizedStrings.length > 50) {
      recommendations.add(
          '🎯 High Priority: You have ${nonLocalizedStrings.length} non-localized strings. Consider implementing gradual localization by starting with the most user-visible strings.');
    } else if (nonLocalizedStrings.length > 10) {
      recommendations.add(
          '📝 Medium Priority: ${nonLocalizedStrings.length} strings need localization. This is a manageable amount to tackle in one sprint.');
    } else if (nonLocalizedStrings.isNotEmpty) {
      recommendations.add(
          '✨ Low Priority: Only ${nonLocalizedStrings.length} strings need localization. You\'re almost there!');
    } else {
      recommendations.add('🎉 Excellent! All strings are localized.');
    }

    if (duplicates.isNotEmpty) {
      recommendations.add(
          '🔄 Duplicate Detection: Found ${duplicates.length} duplicate strings. Consider creating reusable translation keys to reduce redundancy.');
    }

    if (unusedTranslations.length > 10) {
      recommendations.add(
          '🧹 Cleanup Needed: ${unusedTranslations.length} unused translations detected. Consider removing them to reduce bundle size.');
    }

    if (complexity.complexityScore > 70) {
      recommendations.add(
          '🏗️ High Complexity: Your localization has complex patterns. Consider using Flutter\'s Intl package for better placeholder management.');
    } else if (complexity.complexityScore > 40) {
      recommendations.add(
          '⚖️ Moderate Complexity: Some strings have placeholders or complex formatting. Ensure translators understand the context.');
    }

    if (complexity.interpolatedStrings > 0) {
      recommendations.add(
          '🔗 Interpolation Found: ${complexity.interpolatedStrings} strings use placeholders. Make sure placeholders are properly documented for translators.');
    }

    return recommendations;
  }

  /// Generates a summary report
  String _generateSummary(
      int totalStrings, int localizedStrings, int nonLocalizedStrings) {
    final coveragePercentage =
        _calculateCoveragePercentage(totalStrings, nonLocalizedStrings);

    final buffer = StringBuffer();
    buffer.writeln('📊 LOCALIZATION SUMMARY');
    buffer.writeln('======================');
    buffer.writeln('Total Strings: $totalStrings');
    buffer.writeln('Localized: ${totalStrings - nonLocalizedStrings}');
    buffer.writeln('Non-Localized: $nonLocalizedStrings');
    buffer.writeln('Coverage: ${coveragePercentage.toStringAsFixed(1)}%');
    buffer.writeln();

    if (coveragePercentage >= 90) {
      buffer.writeln('🎉 Excellent localization coverage!');
    } else if (coveragePercentage >= 70) {
      buffer.writeln('👍 Good localization coverage.');
    } else if (coveragePercentage >= 50) {
      buffer.writeln('📈 Fair localization coverage. Room for improvement.');
    } else {
      buffer.writeln('⚠️ Low localization coverage. Significant work needed.');
    }

    return buffer.toString();
  }

  /// Exports analytics to JSON file
  Future<void> exportAnalyticsToJson(
      LocalizationAnalytics analytics, String outputPath) async {
    final jsonData = {
      'timestamp': DateTime.now().toIso8601String(),
      'project_path': projectPath,
      'summary': {
        'total_strings': analytics.totalStringsFound,
        'localized_strings': analytics.localizedStrings,
        'non_localized_strings': analytics.nonLocalizedStrings,
        'coverage_percentage': analytics.coveragePercentage,
        'complexity_score': analytics.complexityScore,
      },
      'duplicates': analytics.duplicateStrings.map((key, value) => MapEntry(
            key,
            value
                .map((s) => {
                      'file': s.filePath,
                      'line': s.lineNumber,
                      'content': s.content,
                    })
                .toList(),
          )),
      'unused_translations': analytics.unusedTranslations,
      'files_coverage': analytics.filesCoverage.map((key, value) => MapEntry(
            key,
            {
              'coverage_percentage': value.coveragePercentage,
              'total_strings': value.totalStrings,
              'non_localized_strings': value.nonLocalizedStrings,
              'issues': value.issues,
            },
          )),
      'recommendations': analytics.recommendations,
    };

    final file = File(outputPath);
    await file.writeAsString(JsonEncoder.withIndent('  ').convert(jsonData));

    if (verbose) {
      print('📄 Analytics exported to: $outputPath');
    }
  }
}
