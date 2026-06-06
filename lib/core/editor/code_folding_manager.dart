import 'package:flutter/material.dart';

class FoldingRegion {
  final int startLine;
  final int endLine;
  bool isCollapsed;

  FoldingRegion({
    required this.startLine,
    required this.endLine,
    this.isCollapsed = false,
  });

  bool contains(int line) => line >= startLine && line <= endLine;
}

class CodeFoldingManager extends ChangeNotifier {
  final List<FoldingRegion> _regions = [];
  
  List<FoldingRegion> get regions => List.unmodifiable(_regions);
  
  void analyzeFolding(String content) {
    _regions.clear();
    final lines = content.split('\n');
    final stack = <int>[];
    
    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      final trimmed = line.trim();
      
  // Detect opening braces
      if (trimmed.endsWith('{') || trimmed.endsWith('[') || trimmed.contains('class ') || trimmed.contains('function ') || trimmed.contains('def ')) {
        stack.add(i);
      }
      
  // Detect closing braces
      if (trimmed.startsWith('}') || trimmed.startsWith(']')) {
        if (stack.isNotEmpty) {
          final start = stack.removeLast();
          if (i - start > 2) { // Only fold if more than 2 lines
            _regions.add(FoldingRegion(startLine: start, endLine: i));
          }
        }
      }
    }
    
    notifyListeners();
  }
  
  void toggleFold(int line) {
    for (final region in _regions) {
      if (region.startLine == line) {
        region.isCollapsed = !region.isCollapsed;
        notifyListeners();
        return;
      }
    }
  }
  
  bool isLineFolded(int line) {
    for (final region in _regions) {
      if (region.isCollapsed && line > region.startLine && line <= region.endLine) {
        return true;
      }
    }
    return false;
  }
  
  bool canFold(int line) {
    return _regions.any((r) => r.startLine == line);
  }
  
  bool isFolded(int line) {
    final region = _regions.firstWhere(
      (r) => r.startLine == line,
      orElse: () => FoldingRegion(startLine: -1, endLine: -1),
    );
    return region.startLine != -1 && region.isCollapsed;
  }
  
  void expandAll() {
    for (final region in _regions) {
      region.isCollapsed = false;
    }
    notifyListeners();
  }
  
  void collapseAll() {
    for (final region in _regions) {
      region.isCollapsed = true;
    }
    notifyListeners();
  }
}