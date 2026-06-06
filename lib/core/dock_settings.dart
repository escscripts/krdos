import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'shell/app_catalog.dart';

enum DockPosition { bottom, top, left, right }
enum DockAlignment { start, center, end }

class DockSettings extends ChangeNotifier {
  DockPosition _position = DockPosition.bottom;
  DockAlignment _alignment = DockAlignment.start;
  double _size = 60.0;
  double _iconSize = 26.0;
  double _opacity = 0.85;
  bool _autoHide = false;
  List<String> _pinnedApps = List<String>.from(ShellAppRegistry.defaultPinnedIds);

  DockPosition get position => _position;
  DockAlignment get alignment => _alignment;
  double get size => _size;
  double get iconSize => _iconSize;
  double get opacity => _opacity;
  bool get autoHide => _autoHide;
  List<String> get pinnedApps => List.unmodifiable(_pinnedApps);

  void setPosition(DockPosition pos) {
    _position = pos;
    notifyListeners();
    _save();
  }

  void setAlignment(DockAlignment align) {
    _alignment = align;
    notifyListeners();
    _save();
  }

  void setSize(double s) {
    _size = s.clamp(50.0, 100.0);
    notifyListeners();
    _save();
  }

  void setIconSize(double s) {
    _iconSize = s.clamp(18.0, 40.0);
    notifyListeners();
    _save();
  }

  void setOpacity(double o) {
    _opacity = o.clamp(0.3, 1.0);
    notifyListeners();
    _save();
  }

  void toggleAutoHide() {
    _autoHide = !_autoHide;
    notifyListeners();
    _save();
  }

  void addPinnedApp(String appId) {
    if (!ShellAppRegistry.validPinIds.contains(appId)) return;
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

  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    _position = DockPosition.values[p.getInt('dock_position') ?? 0];
    _alignment = DockAlignment.values[p.getInt('dock_alignment') ?? 0];
    _size = p.getDouble('dock_size') ?? 60.0;
    _iconSize = p.getDouble('dock_icon_size') ?? 26.0;
    _opacity = p.getDouble('dock_opacity') ?? 0.85;
    _autoHide = p.getBool('dock_auto_hide') ?? false;
    final raw = p.getStringList('dock_pinned_apps') ??
        List<String>.from(ShellAppRegistry.defaultPinnedIds);
    _pinnedApps = raw
        .where((id) => ShellAppRegistry.validPinIds.contains(id))
        .toList();
    if (_pinnedApps.isEmpty) {
      _pinnedApps = List<String>.from(ShellAppRegistry.defaultPinnedIds);
    }
    notifyListeners();
  }

  Future<void> _save() async {
    final p = await SharedPreferences.getInstance();
    await p.setInt('dock_position', _position.index);
    await p.setInt('dock_alignment', _alignment.index);
    await p.setDouble('dock_size', _size);
    await p.setDouble('dock_icon_size', _iconSize);
    await p.setDouble('dock_opacity', _opacity);
    await p.setBool('dock_auto_hide', _autoHide);
    await p.setStringList('dock_pinned_apps', _pinnedApps);
  }

  void resetToDefaults() {
    _position = DockPosition.bottom;
    _alignment = DockAlignment.start;
    _size = 60.0;
    _iconSize = 26.0;
    _opacity = 0.85;
    _autoHide = false;
    _pinnedApps = List<String>.from(ShellAppRegistry.defaultPinnedIds);
    notifyListeners();
    _save();
  }
}
