import 'package:flutter/material.dart';

enum SplitOrientation { horizontal, vertical }

class EditorSplit {
  final String id;
  String? activeTabId;
  final List<String> tabIds;

  EditorSplit({
    required this.id,
    this.activeTabId,
    List<String>? tabIds,
  }) : tabIds = tabIds ?? [];
}

class SplitEditorManager extends ChangeNotifier {
  final List<EditorSplit> _splits = [EditorSplit(id: 'main')];
  SplitOrientation _orientation = SplitOrientation.vertical;

  List<EditorSplit> get splits => List.unmodifiable(_splits);
  SplitOrientation get orientation => _orientation;

  void addSplit() {
    final newSplit = EditorSplit(id: 'split_${DateTime.now().millisecondsSinceEpoch}');
    _splits.add(newSplit);
    notifyListeners();
  }

  void removeSplit(String splitId) {
    if (_splits.length <= 1) return;
    _splits.removeWhere((s) => s.id == splitId);
    notifyListeners();
  }

  void toggleOrientation() {
    _orientation = _orientation == SplitOrientation.vertical
        ? SplitOrientation.horizontal
        : SplitOrientation.vertical;
    notifyListeners();
  }

  void addTabToSplit(String splitId, String tabId) {
    final split = _splits.firstWhere((s) => s.id == splitId);
    if (!split.tabIds.contains(tabId)) {
      split.tabIds.add(tabId);
      split.activeTabId = tabId;
      notifyListeners();
    }
  }

  void removeTabFromSplit(String splitId, String tabId) {
    final split = _splits.firstWhere((s) => s.id == splitId);
    split.tabIds.remove(tabId);
    if (split.activeTabId == tabId) {
      split.activeTabId = split.tabIds.isNotEmpty ? split.tabIds.last : null;
    }
    notifyListeners();
  }

  void setActiveSplitTab(String splitId, String tabId) {
    final split = _splits.firstWhere((s) => s.id == splitId);
    split.activeTabId = tabId;
    notifyListeners();
  }

  EditorSplit? getSplit(String splitId) {
    try {
      return _splits.firstWhere((s) => s.id == splitId);
    } catch (e) {
      return null;
    }
  }
}
