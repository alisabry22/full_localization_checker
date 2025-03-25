import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/source/line_info.dart';

class StringLiteralVisitor extends RecursiveAstVisitor<void> {
  final List<StringLiteralInfo> stringLiterals = [];
  final LineInfo lineInfo; // Pass LineInfo explicitly
  int _visitedCount = 0;

  StringLiteralVisitor(this.lineInfo); // Constructor requires LineInfo

  @override
  void visitCompilationUnit(CompilationUnit node) {
    print('AST Visitor: Starting to visit compilation unit');
    super.visitCompilationUnit(node);
    print(
        'AST Visitor: Finished visiting compilation unit. Found $_visitedCount string literals.');
  }

  @override
  void visitSimpleStringLiteral(SimpleStringLiteral node) {
    _visitedCount++;
    final lineNumber = lineInfo.getLocation(node.offset).lineNumber;
    print(
        'AST Visitor: Found simple string "${node.value}" at offset ${node.offset}, line $lineNumber');
    stringLiterals.add(StringLiteralInfo(
      content: node.value,
      offset: node.offset,
      lineNumber: lineNumber, // Should match the actual line in the source
      isInterpolated: false,
    ));
  }
  // Similar adjustments for visitStringInterpolation and visitAdjacentStrings

  @override
  void visitStringInterpolation(StringInterpolation node) {
    _visitedCount++;
    final lineNumber = lineInfo.getLocation(node.offset).lineNumber;
    final content = _extractInterpolationContent(node);
    print(
        'AST Visitor: Found string interpolation "$content" at line $lineNumber');

    stringLiterals.add(StringLiteralInfo(
      content: content,
      offset: node.offset,
      lineNumber: lineNumber,
      isInterpolated: true,
    ));
  }

  @override
  void visitAdjacentStrings(AdjacentStrings node) {
    _visitedCount++;
    final lineNumber = lineInfo.getLocation(node.offset).lineNumber;
    final content =
        node.strings.map((s) => s is SimpleStringLiteral ? s.value : '').join();
    print('AST Visitor: Found adjacent strings "$content" at line $lineNumber');

    stringLiterals.add(StringLiteralInfo(
      content: content,
      offset: node.offset,
      lineNumber: lineNumber,
      isInterpolated: false,
    ));
  }

  String _extractInterpolationContent(StringInterpolation node) {
    final buffer = StringBuffer();
    for (final element in node.elements) {
      if (element is InterpolationString) {
        buffer.write(element.value);
      } else if (element is InterpolationExpression) {
        buffer.write('\${${element.expression.toString()}}');
      }
    }
    return buffer.toString();
  }
}

class StringLiteralInfo {
  final String content;
  final int offset;
  final int lineNumber;
  final bool isInterpolated;

  StringLiteralInfo({
    required this.content,
    required this.offset,
    required this.lineNumber,
    required this.isInterpolated,
  });
}
