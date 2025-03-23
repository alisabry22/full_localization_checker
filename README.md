# Flutter Localization Checker

A CLI tool that scans Flutter apps to detect non-localized strings, helping you identify text that should be internationalized.

## Overview

When developing Flutter applications for international audiences, it's important to ensure all user-facing strings are properly localized. This tool helps you identify hardcoded strings in your codebase that should be localized using Flutter's internationalization framework.

## Features

- Scans all Dart files in your Flutter project for non-localized strings
- Automatically detects and parses ARB localization files to avoid false positives
- Excludes common patterns that don't need localization (URLs, color codes, etc.)
- Generates detailed reports with file locations and context
- Configurable to exclude specific directories or files

## Installation

```bash
dart pub global activate full_localization_checker
```

Or add it to your project's `pubspec.yaml` as a dev dependency:

```yaml
dev_dependencies:
  full_localization_checker: ^1.0.0
```

## Usage

Run the tool in your Flutter project directory:

```bash
full_localization_checker
```

Or specify a different project path:

```bash
full_localization_checker /path/to/flutter/project
```

### Command-line Options

```
Usage: full_localization_checker [options] [project_path]

A CLI tool that scans Flutter apps to detect non-localized strings.

Options:
  -h, --help                  Print this usage information.
  -v, --verbose               Show verbose output.
      --include-comments      Include strings in comments.
  -d, --exclude-dir           Directories to exclude from scanning.
                              (defaults to "build", ".dart_tool", ".pub", ".git")
  -f, --exclude-file          Files to exclude from scanning.
  -o, --output                Output file for the report. If not specified, prints to stdout.
```

### Examples

Exclude additional directories:

```bash
full_localization_checker --exclude-dir=build --exclude-dir=generated
```

Generate a report file:

```bash
full_localization_checker --output=localization_report.txt
```

Include strings in comments:

```bash
full_localization_checker --include-comments
```

## How It Works

The tool performs the following steps:

1. Scans your project for ARB localization files and extracts existing localized keys
2. Searches all Dart files for string literals
3. Filters out strings that are likely not needing localization (URLs, color codes, etc.)
4. Checks if each string is already being used with a localization method
5. Generates a report of all potentially non-localized strings

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

This project is licensed under the MIT License - see the LICENSE file for details.
