# 🌍 Enhanced Flutter Localization Checker

**The most powerful and comprehensive Flutter localization automation tool available!**

A complete end-to-end solution for detecting, analyzing, translating, and automating Flutter app localization. From simple string detection to full localization setup with auto-translation and analytics - this package does it all!

## 🚀 What Makes This Special?

This isn't just another localization checker. It's a **complete localization automation platform** that:

- 🧠 **AST-Based Code Rewriting**: Safely injects `context.l10n` into your Dart files by parsing the raw AST and intelligently stripping invalid `const` modifiers!
- 🔍 **Intelligent String Detection (99% Accuracy)**: Context-aware semantic filtering prioritizing UI string parameters (`title`, `label`, `message`) in standard and custom widgets, while ignoring code IDs, hex metrics, and asset paths.
- 🧩 **String Interpolation Handling**: Automatically extracts variables (`$name`) into parameterized ARB values (`{param0}`) and maps them accurately into the generated l10n methods.
- ✨ **VS Code Quick Fix**: Real-time `💡 Extract and Translate` IDE integration via the companion VS Code Extension.
- 🤖 **Auto-Translation**: Automatically translates your strings to multiple languages using Google Translate, DeepL, Azure, AWS, or LibreTranslate
- 📊 **Comprehensive Analytics**: Provides detailed coverage analysis, complexity scoring, and actionable recommendations
- 🏗️ **Code Generation**: Generates complete localization setup including ARB files, helper extensions, and boilerplate code
- 🔄 **CI/CD Integration**: Supports incremental checking for continuous integration pipelines
- 📈 **Performance Insights**: Analyzes localization complexity and provides optimization suggestions

## 📥 Installation

### As a dev dependency:

```sh
dart pub add --dev loc_checker
```

### Install globally:

```sh
dart pub global activate loc_checker
```

## 🎯 Quick Start

### Basic Usage (Legacy Mode)
```sh
dart run loc_checker --generate-arb /path/to/flutter/project
```

### 🚀 Enhanced Mode (Recommended)
```sh
dart run loc_checker --enhanced --analytics /path/to/flutter/project
```

### 🌍 Full Automation with Auto-Translation
```sh
dart run loc_checker --enhanced --auto-translate --code-generation \
  --translation-api-key=YOUR_GOOGLE_API_KEY \
  --target-languages=es,fr,de,it,ja,ko \
  /path/to/flutter/project
```

### 🔄 CI/CD Integration
```sh
dart run loc_checker --incremental --baseline-report=baseline.json /path/to/project
```

## 🌟 Enhanced Features

### 🔍 Advanced Pattern Detection

Detects UI strings in **100+ patterns** including:

**Standard Flutter Widgets:**
- `Text`, `TextFormField`, `AppBar`, `SnackBar`, `AlertDialog`
- `ElevatedButton`, `TextButton`, `FloatingActionButton`
- `ListTile`, `Card`, `Chip`, `Tooltip`, `DataTable`

**State Management:**
- **Bloc**: `BlocBuilder`, `BlocConsumer`, `BlocListener`
- **Provider**: `Consumer`, `Selector`, `ChangeNotifierProvider`
- **Riverpod**: `ConsumerWidget`, `HookConsumer`, `StateNotifierProvider`
- **GetX**: `GetBuilder`, `Obx`, `GetX`

**Navigation & Routing:**
- **GoRouter**: `context.go()`, `context.push()`
- **AutoRoute**: `AutoRouter`, `context.router`
- **Flutter Navigation**: `Navigator.pushNamed()`, `Route`

**Form Validation:**
- `TextFormField` validators, error messages
- Custom form builders and validation patterns

**Platform-Specific:**
- Cupertino widgets: `CupertinoAlertDialog`, `CupertinoButton`
- Material design patterns and accessibility widgets

### 🤖 Auto-Translation

Supports multiple translation providers:

```sh
# Google Translate
--translation-provider=google --translation-api-key=YOUR_GOOGLE_KEY

# DeepL (highest quality)
--translation-provider=deepl --translation-api-key=YOUR_DEEPL_KEY

# Azure Translator
--translation-provider=azure --translation-api-key=YOUR_AZURE_KEY

# LibreTranslate (free/self-hosted)
--translation-provider=libre --translation-api-key=YOUR_LIBRE_KEY
```

**Features:**
- ✅ Batch translation for efficiency
- ✅ Placeholder preservation (`{param0}`, `{name}`)
- ✅ Rate limiting and error handling
- ✅ Fallback mechanisms
- ✅ Translation quality validation

### 📊 Comprehensive Analytics

Generates detailed reports including:

- **Coverage Analysis**: Percentage of localized vs non-localized strings
- **Complexity Scoring**: Rates localization difficulty (0-100)
- **Duplicate Detection**: Finds reusable strings to reduce redundancy
- **Unused Translation Detection**: Identifies orphaned translation keys
- **File-by-File Analysis**: Per-file coverage reports
- **Actionable Recommendations**: Smart suggestions for improvement

### 🏗️ Code Generation

Automatically generates:

**Localization Setup:**
```dart
// l10n.yaml configuration
// pubspec.yaml updates with flutter_localizations
// Complete MaterialApp setup with localization delegates
```

**Helper Extensions:**
```dart
// Easy access: context.l10n.welcomeMessage
// RTL support: context.isRTL
// Locale utilities: context.locale
```

**Boilerplate Code:**
```dart
// LocalizationConfig class
// Helper utilities for currency, dates
// Example implementations
```

## 📋 Command Reference

### Basic Options
| Option | Description | Default |
|--------|-------------|---------|
| `--verbose, -v` | Enable detailed logging | `false` |
| `--generate-arb` | Generate ARB file | `false` |
| `--output, -o` | Output report file | `report.txt` |
| `--scan-paths` | Comma-separated paths to scan | `lib/` |
| `--custom-ui` | Custom UI patterns | `None` |

### Enhanced Options
| Option | Description | Default |
|--------|-------------|---------|
| `--enhanced` | Enable advanced features | `false` |
| `--auto-translate` | Auto-translate to languages | `false` |
| `--analytics` | Generate analytics report | `true` |
| `--code-generation` | Generate setup code | `false` |
| `--incremental` | CI/CD incremental mode | `false` |

### Translation Options
| Option | Description | Default |
|--------|-------------|---------|
| `--target-languages` | Languages to translate to | `es,fr,de,it` |
| `--translation-provider` | Translation service | `google` |
| `--translation-api-key` | API key for translation | Required |
| `--l10n-output` | Localization files directory | `lib/l10n` |

## 🎨 Real-World Examples

### Example 1: Full Automation Setup

```sh
# Complete localization automation for a new project
dart run loc_checker --enhanced \
  --generate-arb \
  --auto-translate \
  --code-generation \
  --target-languages=es,fr,de,it,pt,ru,ja,ko,zh \
  --translation-provider=deepl \
  --translation-api-key=$DEEPL_API_KEY \
  --custom-ui="CustomButton,MyTextField" \
  /path/to/flutter/project
```

This will:
1. 🔍 Scan your project for non-localized strings
2. 📄 Generate `en.arb` with all found strings
3. 🌍 Auto-translate to 9 languages using DeepL
4. 🏗️ Generate complete localization setup code
5. 📊 Provide comprehensive analytics

### Example 2: CI/CD Pipeline Integration

```yaml
# .github/workflows/localization.yml
name: Localization Check
on: [pull_request]

jobs:
  localization:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: dart-lang/setup-dart@v1
      - run: dart pub global activate loc_checker
      - run: |
          dart pub global run loc_checker --incremental \
            --baseline-report=baseline_localization.json \
            --analytics \
            .
```

### Example 3: Advanced Analytics

```sh
# Generate detailed analytics for existing project
dart run loc_checker --enhanced \
  --analytics \
  --analytics-output=detailed_report.json \
  --verbose \
  /path/to/flutter/project
```

## 📊 Sample Analytics Output

```json
{
  "summary": {
    "coverage_percentage": 87.5,
    "total_strings": 324,
    "non_localized_strings": 41,
    "complexity_score": 23
  },
  "recommendations": [
    "🎯 Medium Priority: 41 strings need localization.",
    "🔄 Duplicate Detection: Found 3 duplicate strings.",
    "🔗 Interpolation Found: 12 strings use placeholders."
  ],
  "files_coverage": {
    "lib/pages/home_page.dart": {
      "coverage_percentage": 95.2,
      "issues": ["Line 23: 'Welcome back!'"]
    }
  }
}
```

## 🔧 Configuration

Create `loc_checker.yaml` in your project root:

```yaml
enhanced_features:
  auto_translation: true
  target_languages: [es, fr, de, it, pt]
  translation_provider: deepl
  analytics: true
  code_generation: true

scan_config:
  scan_paths: [lib/, packages/]
  exclude_dirs: [build/, .dart_tool/]
  custom_ui_patterns: [CustomButton, MyTextField]

output:
  l10n_directory: lib/l10n
  analytics_file: localization_report.json
```

## 📈 Performance & Scalability

- ⚡ **Efficient Scanning**: Processes large codebases quickly with batch processing
- 🎯 **Smart Filtering**: Advanced algorithms to reduce false positives
- 📦 **Memory Optimized**: Handles projects with thousands of files
- 🔄 **Incremental Updates**: Only processes changed files in CI/CD
- 🌐 **Concurrent Translation**: Parallel API calls for faster translation

## 🛠️ Integration Examples

### With Popular State Management

**Bloc Integration:**
```dart
// Automatically detects strings in:
BlocBuilder<AuthBloc, AuthState>(
  builder: (context, state) {
    return Text('Welcome to our app'); // ✅ Detected
  },
)
```

**Riverpod Integration:**
```dart
// Automatically detects strings in:
Consumer(
  builder: (context, ref, child) {
    return Text('Loading...'); // ✅ Detected
  },
)
```

### With Navigation

**GoRouter Integration:**
```dart
// Automatically detects route names and titles:
GoRoute(
  path: '/profile',
  name: 'Profile Page', // ✅ Detected
  builder: (context, state) => ProfilePage(),
)
```

## 🎯 Advanced Use Cases

### Multi-Package Projects
```sh
dart run loc_checker --enhanced \
  --scan-paths="packages/core/lib,packages/ui/lib,lib/" \
  --l10n-output=shared/l10n \
  .
```

### Custom Widget Libraries
```sh
dart run loc_checker --enhanced \
  --custom-ui="CompanyButton,CustomDialog,MyTextField,validate" \
  .
```

### Enterprise Analytics
```sh
dart run loc_checker --enhanced \
  --analytics \
  --analytics-output=enterprise_report.json \
  --export-csv=coverage_data.csv \
  .
```

## 🚀 Roadmap

- [x] **AI-Powered Context Analysis**: Smart context understanding for better translations
- [x] **Visual Studio Code Extension**: IDE integration with real-time detection
- [ ] **Translation Management**: Integration with Crowdin, Lokalise, Phrase
- [ ] **Advanced Analytics Dashboard**: Web-based analytics viewer
- [ ] **Flutter Web Support**: Specialized web localization patterns
- [ ] **Custom Translation Models**: Support for domain-specific translations

## 🤝 Contributing

We welcome contributions! This package aims to be the definitive localization solution for Flutter.

**Priority Areas:**
- Additional widget pattern detection
- New translation service integrations
- Enhanced analytics and reporting
- Performance optimizations
- Documentation improvements

## 📜 License

MIT License - See LICENSE file for details.

---

**Made with ❤️ for the Flutter community!** 

*Transform your Flutter app's localization from a chore into an automated, intelligent process. Try the enhanced mode today and see the difference!* 🚀
