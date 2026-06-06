import 'package:flutter/foundation.dart';

class EditorPreferences extends ChangeNotifier {
  static final EditorPreferences _instance = EditorPreferences._internal();
  factory EditorPreferences() => _instance;
  EditorPreferences._internal();

  String _lastOpenPath = '/C:/Users/Admin/Documents';
  String _lastSavePath = '/C:/Users/Admin/Documents';
  bool _autoSave = true;
  int _fontSize = 14;
  bool _wordWrap = false;
  bool _showMinimap = false;
  bool _showLineNumbers = false;

  String get lastOpenPath => _lastOpenPath;
  String get lastSavePath => _lastSavePath;
  bool get autoSave => _autoSave;
  int get fontSize => _fontSize;
  bool get wordWrap => _wordWrap;
  bool get showMinimap => _showMinimap;
  bool get showLineNumbers => _showLineNumbers;

  void setLastOpenPath(String path) {
  // Extract directory from file path
    final parts = path.split('/');
    if (parts.length > 1) {
      _lastOpenPath = parts.sublist(0, parts.length - 1).join('/');
      if (_lastOpenPath.isEmpty) _lastOpenPath = '/';
      notifyListeners();
    }
  }

  void setLastSavePath(String path) {
  // Extract directory from file path
    final parts = path.split('/');
    if (parts.length > 1) {
      _lastSavePath = parts.sublist(0, parts.length - 1).join('/');
      if (_lastSavePath.isEmpty) _lastSavePath = '/';
      notifyListeners();
    }
  }

  void setAutoSave(bool value) {
    _autoSave = value;
    notifyListeners();
  }

  void setFontSize(int size) {
    _fontSize = size;
    notifyListeners();
  }

  void setWordWrap(bool value) {
    _wordWrap = value;
    notifyListeners();
  }

  void setShowMinimap(bool value) {
    _showMinimap = value;
    notifyListeners();
  }

  void setShowLineNumbers(bool value) {
    _showLineNumbers = value;
    notifyListeners();
  }
}