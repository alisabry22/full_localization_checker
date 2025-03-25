class NonLocalizedString {
  final String filePath;
  final int lineNumber;
  final String content;
  final List<String> context;

  NonLocalizedString({
    required this.filePath,
    required this.lineNumber,
    required this.content,
    required this.context,
  });

  @override
  String toString() =>
      '$filePath:$lineNumber - "$content"\nContext:\n  ${context.join("\n  ")}';
}

class StringLiteralInfo {
  final String content;
  final int lineNumber;
  final bool isInterpolated;
  final String? parentNode;

  StringLiteralInfo({
    required this.content,
    required this.lineNumber,
    required this.isInterpolated,
    this.parentNode,
  });
}
