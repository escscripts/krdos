import 'package:flutter/material.dart';
import 'filesystem/vfs.dart';

class ClipboardItem {
  final String path;
  final VfsNode node;
  final bool isCut;
  
  ClipboardItem({required this.path, required this.node, required this.isCut});
}

class ClipboardManager extends ChangeNotifier {
  ClipboardItem? _item;
  
  ClipboardItem? get item => _item;
  bool get hasItem => _item != null;
  bool get isCut => _item?.isCut ?? false;
  
  void copy(String path, VfsNode node) {
    _item = ClipboardItem(path: path, node: node, isCut: false);
    notifyListeners();
  }
  
  void cut(String path, VfsNode node) {
    _item = ClipboardItem(path: path, node: node, isCut: true);
    notifyListeners();
  }
  
  void clear() {
    _item = null;
    notifyListeners();
  }
}
