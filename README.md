# Flutter Localization Checker

A CLI tool that scans Flutter apps to detect non-localized strings, helping you identify text that should be internationalized.

[![Version](https://img.shields.io/badge/version-1.1.0-blue.svg)](https://github.com/your-username/loc_checker)
[![License](https://img.shields.io/badge/license-MIT-green.svg)](https://opensource.org/licenses/MIT)

## Overview

When developing Flutter applications for international audiences, it's important to ensure all user-facing strings are properly localized. This tool helps you identify hardcoded strings in your codebase that should be localized using Flutter's internationalization framework.

## Features

- Scans all Dart files in your Flutter project for non-localized strings
- Automatically detects and parses ARB localization files to avoid false positives
- Excludes common patterns that don't need localization (URLs, color codes, etc.)
- Generates detailed reports with file locations and context
- Configurable to exclude specific directories or files
- Can generate ARB files with missing strings for easy integration

## Installation

```bash
dart pub global activate loc_checker
```

Or add it to your project's `pubspec.yaml` as a dev dependency:

```yaml
dev_dependencies:
  loc_checker: ^1.1.0
```

## Usage

Run the tool in your Flutter project directory:

```bash
loc_checker
```

Or specify a different project path:

```bash
loc_checker /path/to/flutter/project
```

### Command-line Options

```
Usage: loc_checker [options] [project_path]

A CLI tool that scans Flutter apps to detect non-localized strings.

Options:
  -h, --help                  Print this usage information.
  -v, --verbose               Show verbose output.
      --include-comments      Include strings in comments.
  -a, --generate-arb          Generate an ARB file with non-localized strings.
  -d, --exclude-dir           Directories to exclude from scanning.
                              (defaults to "build", ".dart_tool", ".pub", ".git", "test", "bin")
  -f, --exclude-file          Files to exclude from scanning.
  -s, --scan-paths            Directories to scan (comma-separated or multiple flags). Defaults to lib.
  -o, --output                Output file for the report. If not specified, prints to stdout.
```

### Examples

Exclude additional directories:

```bash
loc_checker --exclude-dir=build --exclude-dir=generated
```

Generate a report file:

```bash
loc_checker --output=localization_report.txt
```

Include strings in comments:

```bash
loc_checker --include-comments
```

Generate an ARB file with missing strings:

```bash
loc_checker --generate-arb
```

Specify custom scan paths:

```bash
loc_checker --scan-paths=lib/ui --scan-paths=lib/screens
```

## How It Works

The tool performs the following steps:

1. Scans your project for ARB localization files and extracts existing localized keys
2. Also checks for other localization formats (JSON files in i18n/ or translations/ directories)
3. Searches all Dart files for string literals using Dart's analyzer package
4. Filters out strings that are likely not needing localization (URLs, color codes, etc.)
5. Checks if each string is already being used with a localization method
6. Generates a report of all potentially non-localized strings

### ARB File Generation

When using the `--generate-arb` option, the tool will create a file at `lib/l10n/missing_strings.arb` containing all detected non-localized strings. The keys are automatically generated based on the string content, following these rules:

- Keys are converted to camelCase
- Special characters are removed
- Keys are limited to 30 characters
- Keys always start with a letter

This makes it easy to integrate the missing strings into your existing localization workflow.

## Best Practices for Flutter Localization

1. Use Flutter's `intl` package and the `flutter_localizations` package for internationalization
2. Extract all user-facing strings to ARB files
3. Use the generated localization class to access strings in your code
4. Run this tool regularly to catch any missed strings
5. Consider adding this tool to your CI/CD pipeline

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

This project is licensed under the MIT License - see the LICENSE file for details.
