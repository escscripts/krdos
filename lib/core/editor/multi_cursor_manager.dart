import 'package:flutter/material.dart';

class CursorPosition {
  final int line;
  final int column;

  CursorPosition(this.line, this.column);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CursorPosition && line == other.line && column == other.column;

  @override
  int get hashCode => line.hashCode ^ column.hashCode;
}

class MultiCursorManager extends ChangeNotifier {
  final List<CursorPosition> _cursors = [];
  
  List<CursorPosition> get cursors => List.unmodifiable(_cursors);
  
  void addCursor(int line, int column) {
    final cursor = CursorPosition(line, column);
    if (!_cursors.contains(cursor)) {
      _cursors.add(cursor);
      notifyListeners();
    }
  }
  
  void removeCursor(int line, int column) {
    _cursors.removeWhere((c) => c.line == line && c.column == column);
    notifyListeners();
  }
  
  void clearCursors() {
    _cursors.clear();
    notifyListeners();
  }
  
  void setPrimaryCursor(int line, int column) {
    _cursors.clear();
    _cursors.add(CursorPosition(line, column));
    notifyListeners();
  }
  
  bool hasCursor(int line, int column) {
    return _cursors.any((c) => c.line == line && c.column == column);
  }
  
  int get cursorCount => _cursors.length;
}
