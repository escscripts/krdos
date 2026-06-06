import 'package:flutter/material.dart';
import 'filesystem/vfs.dart';

/// Manages mobile home screen pages and app positions
class MobileHomeManager extends ChangeNotifier {
  // Each page contains a list of app IDs or VFS paths
  final List<List<MobileHomeItem>> _pages = [[]];
  
  List<List<MobileHomeItem>> get pages => _pages;
  
  List<MobileHomeItem> getPage(int index) {
    if (index >= _pages.length) return [];
    return List.unmodifiable(_pages[index]);
  }
  
  void addPage() {
    _pages.add([]);
    notifyListeners();
  }
  
  void removePage(int index) {
    if (_pages.length <= 1) return; // Keep at least one page
    _pages.removeAt(index);
    notifyListeners();
  }
  
  void addItem(int pageIndex, MobileHomeItem item, {int? position}) {
    if (pageIndex >= _pages.length) {
      _pages.add([]);
    }
    if (position != null && position >= 0 && position <= _pages[pageIndex].length) {
      _pages[pageIndex].insert(position, item);
    } else {
      _pages[pageIndex].add(item);
    }
    notifyListeners();
  }
  
  void removeItem(int pageIndex, int itemIndex) {
    if (pageIndex < _pages.length && itemIndex < _pages[pageIndex].length) {
      _pages[pageIndex].removeAt(itemIndex);
      notifyListeners();
    }
  }
  
  void moveItem(int fromPage, int fromIndex, int toPage, int toIndex) {
    if (fromPage >= _pages.length || fromIndex >= _pages[fromPage].length) return;
    if (toPage >= _pages.length) return;
    
    final item = _pages[fromPage].removeAt(fromIndex);
    
  // Clamp toIndex to valid range (can be at end to append)
    final clampedIndex = toIndex.clamp(0, _pages[toPage].length);
    _pages[toPage].insert(clampedIndex, item);
    
    notifyListeners();
  }
  
  /// Get all desktop items from VFS
  List<MobileHomeItem> getDesktopItems(VirtualFileSystem vfs) {
    final items = <MobileHomeItem>[];
    for (final node in vfs.desktopItems) {
      items.add(MobileHomeItem(
        type: node is VfsDir ? MobileItemType.folder : MobileItemType.file,
        id: 'vfs_${node.name}',
        label: node.name,
        icon: node is VfsDir ? Icons.folder : Icons.insert_drive_file,
        color: node is VfsDir ? const Color(0xFFFFA07A) : const Color(0xFF95A5A6),
        vfsPath: '/desktop/${node.name}',
      ));
    }
    return items;
  }
}

enum MobileItemType {
  app,      // System app
  file,     // VFS file
  folder,   // VFS folder
  shortcut, // Desktop shortcut
}

class MobileHomeItem {
  final MobileItemType type;
  final String id;
  final String label;
  final IconData icon;
  final Color color;
  final String path;  // VFS path or app ID
  final String? appId; // App ID for app type
  
  MobileHomeItem({
    required this.type,
    required this.id,
    required this.label,
    required this.icon,
    required this.color,
    String? vfsPath,
    this.appId,
  }) : path = vfsPath ?? appId ?? '';
}