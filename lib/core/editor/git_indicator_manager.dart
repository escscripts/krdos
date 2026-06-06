import 'package:flutter/material.dart';

enum ChangeType { added, modified, deleted }

class LineChange {
  final int lineNumber;
  final ChangeType type;

  LineChange({required this.lineNumber, required this.type});
}

class GitIndicatorManager extends ChangeNotifier {
  final Map<int, ChangeType> _changes = {};

  Map<int, ChangeType> get changes => Map.unmodifiable(_changes);

  void markLineAdded(int line) {
    _changes[line] = ChangeType.added;
    notifyListeners();
  }

  void markLineModified(int line) {
    _changes[line] = ChangeType.modified;
    notifyListeners();
  }

  void markLineDeleted(int line) {
    _changes[line] = ChangeType.deleted;
    notifyListeners();
  }

  void clearChanges() {
    _changes.clear();
    notifyListeners();
  }

  ChangeType? getChangeType(int line) => _changes[line];

  bool hasChanges() => _changes.isNotEmpty;

  int get changesCount => _changes.length;
}

class GitGutterIndicator extends StatelessWidget {
  final int lineNumber;
  final ChangeType? changeType;

  const GitGutterIndicator({
    super.key,
    required this.lineNumber,
    this.changeType,
  });

  @override
  Widget build(BuildContext context) {
    if (changeType == null) return const SizedBox.shrink();

    return Container(
      width: 3,
      height: 21,
      color: _getColor(changeType!),
    );
  }

  Color _getColor(ChangeType type) {
    switch (type) {
      case ChangeType.added:
        return const Color(0xFF587C0C); // Green
      case ChangeType.modified:
        return const Color(0xFF0C7D9D); // Blue
      case ChangeType.deleted:
        return const Color(0xFFE51400); // Red
    }
  }
}
