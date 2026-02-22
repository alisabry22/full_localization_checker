# Changelog

## 2.0.2
- **Simplified ARB Generation**: Removed verbose metadata from the generated `.arb` files (such as `source_file`, `source_line`, `widget_context`), keeping only the essential `@key` metadata used for string interpolation (`placeholders`). This creates much cleaner ARB files that contain "just the text and the value".

## 2.0.1
- **Strict Clean Architecture Filtering**: The `LocalizationChecker` now actively ignores Dart files located within `data/`, `domain/`, `services/`, and API related layers, completely eliminating false positives from non-UI architecture layers.
- **Exception & Logger Noise Reduction**: The `SmartStringFilter` now rejects any strings passed to constructors containing `Exception`, `Error`, `Logger`, or `Log` (e.g. `ApiException(...)`), as well as API endpoint URL structures.

## 2.0.0 (Major Automation Overhaul)
- **AST-Based Rewriting Engine**: `loc_checker` now safely rewrites your code using the Dart Analyzer AST, automatically stripping invalid `const` modifiers instead of causing compilation errors.
- **Intelligent String Detection (99% Accuracy)**: Highly contextual semantic detection that identifies UI text using parameter names (`title`, `label`, `message`) and widget constructors (`Text`, `AppBar`), reducing false positives like hex colors or asset paths.
- **Dynamic Imports & Clean Architecture**: Automatically injects absolute `package:` imports and prevents context pollution in pure `domain`/`data`/`bloc` layers.
- **String Interpolation Handling**: Automatically extracts `$variables` into ARB placeholders (`{param0}`) and injects them appropriately into the rewritten method call.
- **VS Code Extension Integration**: Added CLI support (`--extract-single`) for the companion VS Code Extension that provides native `💡 Extract and Translate` Quick Fix actions.

## 1.0.0
- Initial release.
- Detect non-localized strings in Dart files.
- Generate `en.arb` with camelCase keys and named placeholders.
- Support custom UI components.