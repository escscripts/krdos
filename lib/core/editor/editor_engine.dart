import 'dart:async';
import 'package:flutter/material.dart';
import '../filesystem/vfs.dart';

class EditorEngine {
  final VirtualFileSystem vfs;
  final Map<String, EditorTab> _tabs = {};
  final StreamController<void> _changeController = StreamController.broadcast();
  
  Timer? _autoSaveTimer;
  bool autoSaveEnabled = true;
  int autoSaveIntervalSeconds = 3;

  EditorEngine(this.vfs) {
    _startAutoSave();
  }

  Stream<void> get onChange => _changeController.stream;

  List<EditorTab> get tabs => _tabs.values.toList();

  EditorTab? getTab(String tabId) => _tabs[tabId];

  EditorTab openFile(String path) {
  // Check if already open
    final existing = _tabs.values.firstWhere(
      (tab) => tab.filePath == path,
      orElse: () => EditorTab(tabId: '', filePath: '', content: '', vfs: vfs),
    );
    if (existing.tabId.isNotEmpty) return existing;

  // Open new tab
    final node = vfs.resolve(path);
    if (node == null || node is VfsDir) {
      throw Exception('File not found: $path');
    }

    final tabId = DateTime.now().millisecondsSinceEpoch.toString();
    final content = (node as VfsFile).content;
    final tab = EditorTab(
      tabId: tabId,
      filePath: path,
      content: content,
      vfs: vfs,
    );
    
    _tabs[tabId] = tab;
    _changeController.add(null);
    return tab;
  }

  EditorTab createNewFile() {
    final tabId = DateTime.now().millisecondsSinceEpoch.toString();
    final tab = EditorTab(
      tabId: tabId,
      filePath: '',
      content: '',
      vfs: vfs,
      isUnsaved: true,
    );
    _tabs[tabId] = tab;
    _changeController.add(null);
    return tab;
  }

  void closeTab(String tabId) {
    _tabs.remove(tabId);
    _changeController.add(null);
  }

  void _startAutoSave() {
    _autoSaveTimer?.cancel();
    _autoSaveTimer = Timer.periodic(
      Duration(seconds: autoSaveIntervalSeconds),
      (_) => _performAutoSave(),
    );
  }

  void _performAutoSave() {
    if (!autoSaveEnabled) return;
    for (final tab in _tabs.values) {
      if (tab.isDirty && tab.filePath.isNotEmpty) {
        tab.save();
      }
    }
  }

  void dispose() {
    _autoSaveTimer?.cancel();
    _changeController.close();
    for (final tab in _tabs.values) {
      tab.dispose();
    }
  }
}

class EditorTab {
  final String tabId;
  String filePath;
  final VirtualFileSystem vfs;
  
  final TextEditingController controller;
  bool isDirty = false;
  bool isUnsaved;
  DateTime? lastSaved;
  
  final StreamController<void> _changeController = StreamController.broadcast();

  EditorTab({
    required this.tabId,
    required this.filePath,
    required String content,
    required this.vfs,
    this.isUnsaved = false,
  }) : controller = TextEditingController(text: content) {
    controller.addListener(_onContentChanged);
  }

  Stream<void> get onChange => _changeController.stream;

  String get fileName {
    if (filePath.isEmpty) return 'Untitled';
    return filePath.split('/').last;
  }

  String get fileExtension {
    if (filePath.isEmpty) return '';
    final parts = filePath.split('.');
    return parts.length > 1 ? parts.last.toLowerCase() : '';
  }

  SyntaxLanguage get language {
    switch (fileExtension) {
      case 'dart': return SyntaxLanguage.dart;
      case 'py': return SyntaxLanguage.python;
      case 'js': return SyntaxLanguage.javascript;
      case 'ts': return SyntaxLanguage.typescript;
      case 'java': return SyntaxLanguage.java;
      case 'cpp': case 'cc': case 'c': case 'h': return SyntaxLanguage.cpp;
      case 'cs': return SyntaxLanguage.csharp;
      case 'html': return SyntaxLanguage.html;
      case 'css': return SyntaxLanguage.css;
      case 'json': return SyntaxLanguage.json;
      case 'xml': return SyntaxLanguage.xml;
      case 'md': return SyntaxLanguage.markdown;
      case 'sh': case 'bash': return SyntaxLanguage.shell;
      case 'sql': return SyntaxLanguage.sql;
      case 'yaml': case 'yml': return SyntaxLanguage.yaml;
      default: return SyntaxLanguage.plaintext;
    }
  }

  void _onContentChanged() {
    isDirty = true;
    _changeController.add(null);
  }

  bool save() {
    if (filePath.isEmpty) return false;
    
    final node = vfs.resolve(filePath);
    if (node == null || node is! VfsFile) return false;

    node.content = controller.text;
    isDirty = false;
    isUnsaved = false;
    lastSaved = DateTime.now();
    _changeController.add(null);
    return true;
  }

  bool saveAs(String newPath) {
    try {
      final parts = newPath.split('/');
      final fileName = parts.last;
      final dirPath = parts.sublist(0, parts.length - 1).join('/');
      
      vfs.touch(newPath, content: controller.text);
      filePath = newPath;
      isDirty = false;
      isUnsaved = false;
      lastSaved = DateTime.now();
      _changeController.add(null);
      return true;
    } catch (e) {
      return false;
    }
  }

  void dispose() {
    controller.dispose();
    _changeController.close();
  }
}

enum SyntaxLanguage {
  plaintext,
  dart,
  python,
  javascript,
  typescript,
  java,
  cpp,
  csharp,
  html,
  css,
  json,
  xml,
  markdown,
  shell,
  sql,
  yaml,
}

class SyntaxHighlighter {
  static final Map<SyntaxLanguage, List<String>> _keywords = {
    SyntaxLanguage.dart: ['class', 'void', 'int', 'String', 'bool', 'double', 'var', 'final', 'const', 'if', 'else', 'for', 'while', 'return', 'import', 'extends', 'implements', 'async', 'await', 'try', 'catch'],
    SyntaxLanguage.python: ['def', 'class', 'if', 'else', 'elif', 'for', 'while', 'return', 'import', 'from', 'try', 'except', 'with', 'as', 'pass', 'break', 'continue', 'lambda', 'yield'],
    SyntaxLanguage.javascript: ['function', 'const', 'let', 'var', 'if', 'else', 'for', 'while', 'return', 'class', 'extends', 'import', 'export', 'async', 'await', 'try', 'catch', 'new'],
    SyntaxLanguage.java: ['public', 'private', 'protected', 'class', 'void', 'int', 'String', 'boolean', 'if', 'else', 'for', 'while', 'return', 'import', 'extends', 'implements', 'try', 'catch'],
  };

  static TextSpan highlight(String text, SyntaxLanguage language) {
    if (language == SyntaxLanguage.plaintext) {
      return TextSpan(text: text, style: const TextStyle(color: Color(0xFFD4D4D4)));
    }

    final keywords = _keywords[language] ?? [];
    final spans = <TextSpan>[];
    final lines = text.split('\n');

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      spans.addAll(_highlightLine(line, keywords));
      if (i < lines.length - 1) {
        spans.add(const TextSpan(text: '\n'));
      }
    }

    return TextSpan(children: spans);
  }

  static List<TextSpan> _highlightLine(String line, List<String> keywords) {
    final spans = <TextSpan>[];
    final regex = RegExp(r'(\w+|[^\w\s]|\s+)');
    final matches = regex.allMatches(line);

    for (final match in matches) {
      final token = match.group(0)!;
      Color color = const Color(0xFFD4D4D4); // Default text

      if (keywords.contains(token)) {
        color = const Color(0xFFC586C0); // Keywords (purple)
      } else if (RegExp(r'^\d+$').hasMatch(token)) {
        color = const Color(0xFFB5CEA8); // Numbers (green)
      } else if (token.startsWith('"') || token.startsWith("'")) {
        color = const Color(0xFFCE9178); // Strings (orange)
      } else if (token.startsWith('//') || token.startsWith('#')) {
        color = const Color(0xFF6A9955); // Comments (green)
      }

      spans.add(TextSpan(text: token, style: TextStyle(color: color)));
    }

    return spans;
  }
}