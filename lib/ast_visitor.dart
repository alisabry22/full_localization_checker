import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/source/line_info.dart';
import 'package:loc_checker/models/models.dart';

class StringLiteralVisitor extends RecursiveAstVisitor<void> {
  final LineInfo lineInfo;
  final bool verbose; // Add verbose flag
  final List<StringLiteralInfo> literals = [];

  StringLiteralVisitor(this.lineInfo, {this.verbose = false});

  @override
  void visitSimpleStringLiteral(SimpleStringLiteral node) {
    _addLiteral(node, false, node.value);
  }

  @override
  void visitStringInterpolation(StringInterpolation node) {
    final parts = <String>[];
    final variables = <String>[];
    var placeholderIndex = 0;
    var hasOnlyVariables = true;

    for (final element in node.elements) {
      if (element is InterpolationString) {
        final text = element.value;
        if (text.isNotEmpty) {
          parts.add(text);
          hasOnlyVariables = false;
        }
      } else if (element is InterpolationExpression) {
        parts.add('{param$placeholderIndex}');
        variables.add(element.expression.toString());
        placeholderIndex++;
      }
    }

    final content = parts.join();
    if (!hasOnlyVariables && content.isNotEmpty) {
      _addLiteral(node, true, content, variables);
    }
  }

  @override
  void visitAdjacentStrings(AdjacentStrings node) {
    final content =
        node.strings.map((s) => s is SimpleStringLiteral ? s.value : '').join();
    if (content.isNotEmpty) {
      _addLiteral(node, false, content);
    }
  }

  void _addLiteral(AstNode node, bool isInterpolated, String content,
      [List<String> variables = const []]) {
    final location = lineInfo.getLocation(node.offset);
    final lineNumber = location.lineNumber;
    final columnNumber = location.columnNumber;

    String? constructorName;
    String? argumentName;

    AstNode? current = node.parent;
    while (current != null) {
      if (current is NamedExpression) {
        argumentName = current.name.label.name;
        final parent = current.parent;
        if (parent is ArgumentList) {
          final grandParent = parent.parent;
          if (grandParent is InstanceCreationExpression) {
            constructorName = grandParent.constructorName.toString();
          } else if (grandParent is MethodInvocation) {
            constructorName = grandParent.methodName.name;
          }
        }
        break;
      } else if (current is ArgumentList) {
        final parent = current.parent;
        if (parent is InstanceCreationExpression) {
          constructorName = parent.constructorName.toString();
          // Find positional index
          final index =
              parent.argumentList.arguments.indexOf(node as Expression);
          if (index != -1) {
            argumentName = 'positional[$index]';
          }
        }
        break;
      } else if (current is InstanceCreationExpression) {
        constructorName = current.constructorName.toString();
        break;
      }
      current = current.parent;
    }

    String? parentNode = _getParentNode(node);
    if (verbose) {
      print(
          'AST: Found "$content" at line $lineNumber:$columnNumber, constructor: $constructorName, arg: $argumentName');
    }
    literals.add(StringLiteralInfo(
      content: content,
      lineNumber: lineNumber,
      columnNumber: columnNumber,
      isInterpolated: isInterpolated,
      parentNode: parentNode,
      constructorName: constructorName,
      argumentName: argumentName,
      offset: node.offset,
      length: node.length,
      variables: variables,
    ));
  }

  String? _getParentNode(AstNode node) {
    AstNode? current = node.parent;
    while (current != null) {
      if (current is NamedExpression) {
        return '${current.name.label.name}: in ${current.parent.runtimeType}';
      } else if (current is InstanceCreationExpression) {
        return current.constructorName.toString();
      }
      current = current.parent;
    }
    return null;
  }
}
