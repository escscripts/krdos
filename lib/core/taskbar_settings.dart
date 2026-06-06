import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum TaskbarPosition { bottom, top, left, right }
enum TaskbarAlignment { left, center, right }
enum TaskbarSize { small, medium, large }

class TaskbarSettings extends ChangeNotifier {
  TaskbarPosition _position = TaskbarPosition.bottom;
  TaskbarAlignment _alignment = TaskbarAlignment.center;
  TaskbarSize _size = TaskbarSize.medium;
  bool _autoHide = false;
  bool _showLabels = false;
  bool _showWindowPreviews = true;
  bool _combineButtons = true;
  double _iconSize = 24.0;
  double _taskbarHeight = 56.0;
  List<String> _pinnedApps = ['terminal', 'files', 'devices', 'settings'];

  TaskbarPosition get position => _position;
  TaskbarAlignment get alignment => _alignment;
  TaskbarSize get size => _size;
  bool get autoHide => _autoHide;
  bool get showLabels => _showLabels;
  bool get showWindowPreviews => _showWindowPreviews;
  bool get combineButtons => _combineButtons;
  double get iconSize => _iconSize;
  double get taskbarHeight => _taskbarHeight;
  List<String> get pinnedApps => List.unmodifiable(_pinnedApps);

  void setPosition(TaskbarPosition pos) {
    _position = pos;
    _updateTaskbarDimensions();
    notifyListeners();
    _save();
  }

  void setAlignment(TaskbarAlignment align) {
    _alignment = align;
    notifyListeners();
    _save();
  }

  void setSize(TaskbarSize s) {
    _size = s;
    _updateTaskbarDimensions();
    notifyListeners();
    _save();
  }

  void _updateTaskbarDimensions() {
    switch (_size) {
      case TaskbarSize.small:
        _iconSize = 20.0;
        _taskbarHeight = 48.0;
        break;
      case TaskbarSize.medium:
        _iconSize = 24.0;
        _taskbarHeight = 56.0;
        break;
      case TaskbarSize.large:
        _iconSize = 28.0;
        _taskbarHeight = 64.0;
        break;
    }
  }

  void toggleAutoHide() {
    _autoHide = !_autoHide;
    notifyListeners();
    _save();
  }

  void toggleShowLabels() {
    _showLabels = !_showLabels;
    notifyListeners();
    _save();
  }

  void toggleWindowPreviews() {
    _showWindowPreviews = !_showWindowPreviews;
    notifyListeners();
    _save();
  }

  void toggleCombineButtons() {
    _combineButtons = !_combineButtons;
    notifyListeners();
    _save();
  }

  void addPinnedApp(String appId) {
    if (!_pinnedApps.contains(appId)) {
      _pinnedApps.add(appId);
      notifyListeners();
      _save();
    }
  }

  void removePinnedApp(String appId) {
    _pinnedApps.remove(appId);
    notifyListeners();
    _save();
  }

  void reorderPinnedApps(int oldIndex, int newIndex) {
    if (oldIndex < newIndex) newIndex--;
    final item = _pinnedApps.removeAt(oldIndex);
    _pinnedApps.insert(newIndex, item);
    notifyListeners();
    _save();
  }

  bool isAppPinned(String appId) => _pinnedApps.contains(appId);

  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    _position = TaskbarPosition.values[p.getInt('taskbar_position') ?? 0];
    _alignment = TaskbarAlignment.values[p.getInt('taskbar_alignment') ?? 1];
    _size = TaskbarSize.values[p.getInt('taskbar_size') ?? 1];
    _autoHide = p.getBool('taskbar_autoHide') ?? false;
    _showLabels = p.getBool('taskbar_showLabels') ?? false;
    _showWindowPreviews = p.getBool('taskbar_windowPreviews') ?? true;
    _combineButtons = p.getBool('taskbar_combineButtons') ?? true;
    _pinnedApps = p.getStringList('taskbar_pinnedApps') ?? ['terminal', 'files', 'devices', 'settings'];
    _updateTaskbarDimensions();
    notifyListeners();
  }

  Future<void> _save() async {
    final p = await SharedPreferences.getInstance();
    await p.setInt('taskbar_position', _position.index);
    await p.setInt('taskbar_alignment', _alignment.index);
    await p.setInt('taskbar_size', _size.index);
    await p.setBool('taskbar_autoHide', _autoHide);
    await p.setBool('taskbar_showLabels', _showLabels);
    await p.setBool('taskbar_windowPreviews', _showWindowPreviews);
    await p.setBool('taskbar_combineButtons', _combineButtons);
    await p.setStringList('taskbar_pinnedApps', _pinnedApps);
  }
}
