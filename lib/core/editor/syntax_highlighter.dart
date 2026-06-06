import 'package:flutter/material.dart';

class AdvancedSyntaxHighlighter {
  static final Map<String, List<String>> _keywords = {
    'dart': ['abstract', 'as', 'assert', 'async', 'await', 'break', 'case', 'catch', 'class', 'const', 'continue', 'default', 'do', 'else', 'enum', 'extends', 'false', 'final', 'finally', 'for', 'if', 'implements', 'import', 'in', 'is', 'library', 'new', 'null', 'return', 'super', 'switch', 'this', 'throw', 'true', 'try', 'var', 'void', 'while', 'with', 'yield'],
    'python': ['and', 'as', 'assert', 'async', 'await', 'break', 'class', 'continue', 'def', 'del', 'elif', 'else', 'except', 'False', 'finally', 'for', 'from', 'global', 'if', 'import', 'in', 'is', 'lambda', 'None', 'nonlocal', 'not', 'or', 'pass', 'raise', 'return', 'True', 'try', 'while', 'with', 'yield'],
    'javascript': ['async', 'await', 'break', 'case', 'catch', 'class', 'const', 'continue', 'debugger', 'default', 'delete', 'do', 'else', 'export', 'extends', 'false', 'finally', 'for', 'function', 'if', 'import', 'in', 'instanceof', 'let', 'new', 'null', 'return', 'super', 'switch', 'this', 'throw', 'true', 'try', 'typeof', 'var', 'void', 'while', 'with', 'yield'],
    'java': ['abstract', 'assert', 'boolean', 'break', 'byte', 'case', 'catch', 'char', 'class', 'const', 'continue', 'default', 'do', 'double', 'else', 'enum', 'extends', 'false', 'final', 'finally', 'float', 'for', 'if', 'implements', 'import', 'instanceof', 'int', 'interface', 'long', 'native', 'new', 'null', 'package', 'private', 'protected', 'public', 'return', 'short', 'static', 'super', 'switch', 'synchronized', 'this', 'throw', 'throws', 'true', 'try', 'void', 'volatile', 'while'],
  };

  static final Map<String, List<String>> _types = {
    'dart': ['int', 'double', 'String', 'bool', 'List', 'Map', 'Set', 'dynamic', 'Object', 'num', 'Future', 'Stream'],
    'python': ['int', 'float', 'str', 'bool', 'list', 'dict', 'set', 'tuple', 'bytes'],
    'javascript': ['String', 'Number', 'Boolean', 'Array', 'Object', 'Function', 'Promise'],
    'java': ['String', 'Integer', 'Double', 'Boolean', 'Long', 'Float', 'Character', 'Byte', 'Short', 'List', 'Map', 'Set'],
  };

  static TextSpan highlight(String text, String language) {
    final spans = <InlineSpan>[];
    final lines = text.split('\n');
    
    for (int i = 0; i < lines.length; i++) {
      spans.addAll(_highlightLine(lines[i], language));
      if (i < lines.length - 1) {
        spans.add(const TextSpan(text: '\n'));
      }
    }
    
    return TextSpan(children: spans);
  }

  static List<InlineSpan> _highlightLine(String line, String language) {
    final spans = <InlineSpan>[];
    int pos = 0;
    
  // Check for comments first
    if (language == 'python' && line.trimLeft().startsWith('#')) {
      return [TextSpan(text: line, style: const TextStyle(color: Color(0xFF6A9955), fontStyle: FontStyle.italic))];
    }
    if ((language == 'javascript' || language == 'java' || language == 'dart') && line.trimLeft().startsWith('//')) {
      return [TextSpan(text: line, style: const TextStyle(color: Color(0xFF6A9955), fontStyle: FontStyle.italic))];
    }
    
    final keywords = _keywords[language] ?? [];
    final types = _types[language] ?? [];
    
  // Simple tokenization
    final pattern = RegExp(r'(\w+|[^\w\s]|\s+)');
    final matches = pattern.allMatches(line);
    
    for (final match in matches) {
      final token = match.group(0)!;
      Color color = const Color(0xFFD4D4D4);
      FontWeight? weight;
      
      if (keywords.contains(token)) {
        color = const Color(0xFFC586C0); // Purple for keywords
        weight = FontWeight.w600;
      } else if (types.contains(token)) {
        color = const Color(0xFF4EC9B0); // Cyan for types
      } else if (RegExp(r'^\d+\.?\d*$').hasMatch(token)) {
        color = const Color(0xFFB5CEA8); // Light green for numbers
      } else if (token.startsWith('"') || token.startsWith("'")) {
        color = const Color(0xFFCE9178); // Orange for strings
      } else if (token == '(' || token == ')' || token == '{' || token == '}' || token == '[' || token == ']') {
        color = const Color(0xFFFFD700); // Gold for brackets
      } else if (RegExp(r'^[A-Z][a-zA-Z0-9]*$').hasMatch(token)) {
        color = const Color(0xFF4EC9B0); // Cyan for class names
      }
      
      spans.add(TextSpan(
        text: token,
        style: TextStyle(color: color, fontWeight: weight),
      ));
    }
    
    return spans;
  }
}