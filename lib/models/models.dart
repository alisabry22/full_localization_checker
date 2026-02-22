class NonLocalizedString {
  final String filePath;
  final int lineNumber;
  final int columnNumber;
  final String content;
  final List<String> context;
  final int offset;
  final int length;
  final List<String> variables;
  final String? parentNode;
  final String? constructorName;
  final String? argumentName;

  NonLocalizedString({
    required this.filePath,
    required this.lineNumber,
    this.columnNumber = 0,
    required this.content,
    required this.context,
    required this.offset,
    required this.length,
    this.variables = const [],
    this.parentNode,
    this.constructorName,
    this.argumentName,
  });

  @override
  String toString() =>
      '$filePath:$lineNumber - "$content"\nContext:\n  ${context.join("\n  ")}\nParent: $parentNode';
}

class StringLiteralInfo {
  final String content;
  final int lineNumber;
  final int columnNumber;
  final bool isInterpolated;
  final String? parentNode;
  final String? constructorName;
  final String? argumentName;
  final int offset;
  final int length;
  final List<String> variables;

  StringLiteralInfo({
    required this.content,
    required this.lineNumber,
    this.columnNumber = 0,
    this.isInterpolated = false,
    this.parentNode,
    this.constructorName,
    this.argumentName,
    required this.offset,
    required this.length,
    this.variables = const [],
  });
}

/// Comprehensive localization analytics data
class LocalizationAnalytics {
  final int totalStringsFound;
  final int localizedStrings;
  final int nonLocalizedStrings;
  final Map<String, List<NonLocalizedString>> duplicateStrings;
  final List<String> unusedTranslations;
  final double coveragePercentage;
  final Map<String, FileCoverage> filesCoverage;
  final int complexityScore;
  final List<String> recommendations;
  final String summary;

  LocalizationAnalytics({
    required this.totalStringsFound,
    required this.localizedStrings,
    required this.nonLocalizedStrings,
    required this.duplicateStrings,
    required this.unusedTranslations,
    required this.coveragePercentage,
    required this.filesCoverage,
    required this.complexityScore,
    required this.recommendations,
    required this.summary,
  });
}

/// File-level coverage analysis
class FileCoverage {
  final String filePath;
  final int totalStrings;
  final int localizedStrings;
  final int nonLocalizedStrings;
  final double coveragePercentage;
  final List<String> issues;

  FileCoverage({
    required this.filePath,
    required this.totalStrings,
    required this.localizedStrings,
    required this.nonLocalizedStrings,
    required this.coveragePercentage,
    required this.issues,
  });
}

/// Complexity analysis for localization requirements
class ComplexityAnalysis {
  final int complexityScore;
  final int simpleStrings;
  final int interpolatedStrings;
  final int longStrings;
  final int complexStrings;

  ComplexityAnalysis({
    required this.complexityScore,
    required this.simpleStrings,
    required this.interpolatedStrings,
    required this.longStrings,
    required this.complexStrings,
  });
}

/// Configuration for enhanced localization features
class EnhancedLocalizationConfig {
  final bool enableAutoTranslation;
  final List<String> targetLanguages;
  final String translationApiKey;
  final String translationProvider;
  final bool enableAnalytics;
  final bool enableCodeGeneration;
  final String outputDirectory;
  final Map<String, dynamic> customSettings;

  EnhancedLocalizationConfig({
    this.enableAutoTranslation = false,
    this.targetLanguages = const ['es', 'fr', 'de', 'it'],
    this.translationApiKey = '',
    this.translationProvider = 'google',
    this.enableAnalytics = true,
    this.enableCodeGeneration = false,
    this.outputDirectory = 'lib/l10n',
    this.customSettings = const {},
  });
}
