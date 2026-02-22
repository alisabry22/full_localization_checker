import 'package:loc_checker/config.dart';
import 'package:loc_checker/models/models.dart';

class StringFilter {
  final LocalizationCheckerConfig config;
  static const _localizationPatterns = [
    r'AppLocalizations\s*\.\s*of\s*\(\s*[^)]+\s*\)\s*\.\s*[a-zA-Z0-9_]+',
    r'AppLocalizations\s*\.\s*[a-zA-Z0-9_]+',
    r'\.tr\s*(?=\()',
    r'\.trParams\s*(?=\()',
    r'"[a-zA-Z0-9_]+"\.tr\b',
    r'LocaleKeys\s*\.\s*[a-zA-Z0-9_]+\s*\.\s*tr\s*\(\s*\)',
    r'tr\s*\(\s*[a-zA-Z0-9_]+\)',
    r'Intl\s*\.\s*message\s*\(\s*.*\s*\)',
    r'Intl\s*\.\s*plural\s*\(\s*[0-9]+.*\s*\)',
    r'Intl\s*\.\s*select\s*\(\s*[^,]+,\s*\{.*\}\s*\)',
    r'I18n\s*\.\s*of\s*\(\s*[^)]+\s*\)\s*\.\s*[a-zA-Z0-9_]+',
    r'S\s*\.\s*of\s*\(\s*[^)]+\s*\)\s*\.\s*[a-zA-Z0-9_]+',
    r'S\s*\.\s*current\s*\.\s*[a-zA-Z0-9_]+',
    r'context\s*\.\s*l10n\s*\.\s*[a-zA-Z0-9_]+',
    r'translate\s*\(\s*[a-zA-Z0-9_]+\s*\)',
  ];

  static const _userFacingConstructors = {
    'Text',
    'AppBar',
    'SnackBar',
    'Tooltip',
    'AlertDialog',
    'Tab',
    'Semantics',
    'SelectableText',
    'FlatButton',
    'RaisedButton',
    'ElevatedButton',
    'TextButton',
    'OutlinedButton',
    'IconButton',
  };

  static const _userFacingArguments = {
    'data',
    'title',
    'label',
    'labelText',
    'hintText',
    'errorText',
    'helperText',
    'tooltip',
    'message',
    'hint',
    'value',
    'content',
    'placeholder',
  };

  StringFilter(this.config);

  bool shouldSkip(StringLiteralInfo literal) {
    final content = literal.content;
    if (content.isEmpty || content.trim().isEmpty) return true;

    // RULE 1: Semantic Override - If it's a known user-facing parameter, NEVER skip it
    if (_isKnownUserFacing(literal)) return false;

    // RULE 2: Length threshold
    if (content.length <= 1) return true;

    // RULE 3: Technical strings (obviously not natural language)
    if (RegExp(r'^[0-9.,\-+*/%=<>!&|^]+$').hasMatch(content))
      return true; // Math/Numbers
    if (RegExp(r'^#[0-9a-fA-F]{3,8}$').hasMatch(content))
      return true; // Hex colors
    if (RegExp(r'^[a-z]+[A-Z][a-z]+').hasMatch(content))
      return true; // camelCase
    if (RegExp(r'^[a-z]+(_[a-z]+)+$').hasMatch(content))
      return true; // snake_case
    if (content.contains('\n') && content.contains('  '))
      return true; // Likely code or long log

    // RULE 4: Resource indicators
    if (content.startsWith('http://') ||
        content.startsWith('https://') ||
        content.startsWith('/')) return true; // URLs and API endpoints
    if (content.startsWith('assets/') ||
        content.startsWith('package:') ||
        content.contains('.dart') ||
        content.contains('.png') ||
        content.contains('.svg')) return true;

    // RULE 5: Natural Language Heuristics
    // If it has spaces and looks like words, keep it
    if (content.contains(' ') && content.length > 2) return false;

    // If it starts with a Capital letter (usually UI labels like "Login", "Save")
    if (RegExp(r'^[A-Z]').hasMatch(content) && content.length >= 2)
      return false;

    // Default: Skip if we are unsure (to avoid noise)
    return true;
  }

  bool _isKnownUserFacing(StringLiteralInfo literal) {
    // 1. Check custom patterns from user configuration
    if (config.customUiPatterns.isNotEmpty) {
      final customMatch = config.customUiPatterns.any((pattern) {
        return (literal.constructorName != null &&
                RegExp(pattern).hasMatch(literal.constructorName!)) ||
            (literal.argumentName != null &&
                RegExp(pattern).hasMatch(literal.argumentName!));
      });
      if (customMatch) return true;
    }

    // 2. Named Arguments are the strongest signal across ANY custom component
    // (e.g., param 'title: "Profile"' in CustomProfileCard)
    if (literal.argumentName != null &&
        _userFacingArguments.contains(literal.argumentName)) {
      return true;
    }

    // 3. Negative Constructor Name Analysis (Exceptions/Loggers)
    if (literal.constructorName != null) {
      final cName = literal.constructorName!.toLowerCase();
      if (cName.contains('exception') ||
          cName.contains('error') ||
          cName.contains('logger') ||
          cName.contains('log')) {
        return false; // Force skip if it's an Exception or Logger
      }
    }

    // 4. Constructor Name Analysis (Standard & Custom UI)
    if (literal.constructorName != null) {
      bool isUiComponent =
          _userFacingConstructors.contains(literal.constructorName);

      // Analyze dynamic suffixes if it's not a standard Flutter widget
      if (!isUiComponent) {
        final customSuffixRegex = RegExp(
            r'(Button|Text|Label|Title|Card|Tile|Dialog|Alert|Toast|Snackbar|Message|Banner|Headline|Subtitle|Input)$',
            caseSensitive: false);
        if (customSuffixRegex.hasMatch(literal.constructorName!)) {
          isUiComponent = true;
        }
      }

      // If identified as a UI component, positional[0] is typically text (e.g. MyPrimaryButton("Click Here"))
      if (isUiComponent && literal.argumentName == 'positional[0]') {
        return true;
      }
    }

    return false;
  }

  bool isLocalized(String line, String content, Set<String> localizedKeys) {
    if (_localizationPatterns
        .any((pattern) => RegExp(pattern).hasMatch(line))) {
      if (config.verbose) print('Matched localization pattern in: $line');
      return true;
    }
    if (localizedKeys.contains(content.trim())) {
      if (config.verbose) print('Matched localized key: $content');
      return true;
    }
    if (!config.includeComments &&
        (line.trim().startsWith('//') ||
            line.trim().startsWith('/*') ||
            line.trim().endsWith('*/'))) {
      return true;
    }
    return false;
  }
}
