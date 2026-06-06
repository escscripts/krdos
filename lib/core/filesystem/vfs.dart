import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';

import 'vfs_disk_store.dart';

const int _kVfsPersistVersion = 1;

abstract class VfsNode {
  String name;
  String permissions;
  String owner;
  DateTime modified;
  bool isEncrypted;
  String? encryptedPassword;

  VfsNode({
    required this.name,
    this.permissions = 'rw-r--r--',
    this.owner = 'admin',
    this.isEncrypted = false,
    this.encryptedPassword,
    DateTime? modified,
  }) : modified = modified ?? DateTime.now();
}

class VfsFile extends VfsNode {
  String content;
  Uint8List? rawBytes;

  VfsFile({
    required super.name,
    this.content = '',
    this.rawBytes,
    super.permissions,
    super.owner,
    super.isEncrypted,
    super.encryptedPassword,
    super.modified,
  });

  int get size => rawBytes?.length ?? content.length;
}

class VfsDir extends VfsNode {
  final Map<String, VfsNode> children = {};
  VfsDir({
    required super.name,
    super.permissions = 'rwxr-xr-x',
    super.owner,
    super.isEncrypted,
    super.encryptedPassword,
    super.modified,
  });
}

class VirtualFileSystem extends ChangeNotifier {
  late VfsDir _root;
  final Map<String, bool> _unlockedFolders = {};
  Timer? _persistDebounce;
  bool _persistEnabled = true;

  /// When true (default), mutations schedule a debounced disk write.
  set persistEnabled(bool v) => _persistEnabled = v;

  VirtualFileSystem({bool skipDefaultSeed = false}) {
    _root = VfsDir(name: '');
    if (!skipDefaultSeed) {
      _seedDefaults();
    }
  }

  /// Load saved tree from disk, or seed defaults if missing/invalid.
  Future<void> hydratePersisted() async {
    try {
      final data = await VfsDiskStore.readJson();
      if (data != null) {
        applyPersistenceMap(data);
        notifyListeners();
        return;
      }
    } catch (_) {
  /* corrupt or IO */
    }
    _seedDefaults();
    notifyListeners();
  }

  /// For tests: import without touching disk.
  void applyPersistenceMap(Map<String, dynamic> data) {
    final ver = data['v'];
    if (ver is! int || ver != _kVfsPersistVersion) {
      throw FormatException('Unsupported VFS snapshot version: $ver');
    }
    final tree = data['tree'];
    if (tree is! Map<String, dynamic>) {
      throw const FormatException('Invalid VFS tree');
    }
    _unlockedFolders.clear();
    final u = data['unlocked'];
    if (u is Map) {
      for (final e in u.entries) {
        _unlockedFolders['${e.key}'] = e.value == true;
      }
    }
    _root = _decodeDir(Map<String, dynamic>.from(tree));
  }

  Map<String, dynamic> exportPersistenceMap() => {
        'v': _kVfsPersistVersion,
        'unlocked': Map<String, bool>.from(_unlockedFolders),
        'tree': _encodeNode(_root),
      };

  Future<void> _flushToDisk() async {
    try {
      await VfsDiskStore.writeJson(exportPersistenceMap());
    } catch (e) {
      debugPrint('VFS persist failed: $e');
    }
  }

  void _schedulePersist() {
    if (!_persistEnabled) return;
    _persistDebounce?.cancel();
    _persistDebounce = Timer(const Duration(milliseconds: 120), () {
      _persistDebounce = null;
      unawaited(_flushToDisk());
    });
  }

  /// Cancels any pending debounced write and persists immediately (e.g. app background / quit).
  Future<void> flushPersistence() async {
    _persistDebounce?.cancel();
    _persistDebounce = null;
    await _flushToDisk();
  }

  void _notifyAndPersist() {
    notifyListeners();
    _schedulePersist();
  }

  /// Restore the simulated disk tree and encryption unlock state to defaults.
  void reset() {
    _persistDebounce?.cancel();
    _persistDebounce = null;
    _unlockedFolders.clear();
    _seedDefaults();
    notifyListeners();
    unawaited(VfsDiskStore.delete());
  }

  void _seedDefaults() {
    _root = VfsDir(name: '');

    _mkdirRaw('/C:');
    _mkdirRaw('/D:');

    _mkdirRaw('/C:/Users');
    _mkdirRaw('/C:/Users/Admin');
    _mkdirRaw('/C:/Users/Admin/Desktop');
    _mkdirRaw('/C:/Users/Admin/Documents');
    _mkdirRaw('/C:/Users/Admin/Downloads');
    _mkdirRaw('/C:/Users/Admin/Pictures');
    _mkdirRaw('/C:/Users/Admin/Videos');
    _mkdirRaw('/C:/Users/Admin/Music');
    _mkdirRaw('/C:/Program Files');
    _mkdirRaw('/C:/Program Files/KrdOS');
    _mkdirRaw('/C:/Program Files/Tools');
    _mkdirRaw('/C:/Program Files/Apps');
    _mkdirRaw('/C:/Windows');
    _mkdirRaw('/C:/Windows/System32');

    _mkdirRaw('/D:/Data');
    _mkdirRaw('/D:/Backup');
    _mkdirRaw('/D:/Projects');

    _mkdirRaw('/bin');
    _mkdirRaw('/etc');
    _mkdirRaw('/home');
    _mkdirRaw('/home/admin');
    _mkdirRaw('/var');
    _mkdirRaw('/var/log');
    _mkdirRaw('/tmp');
    _mkdirRaw('/usr');
    _mkdirRaw('/proc');
    _mkdirRaw('/sys');
    _mkdirRaw('/dev');

    _touchRaw(
      '/C:/Users/Admin/Documents/readme.txt',
      content:
          'Welcome to KrdOS File System\n\nThis is a professional file manager with:\n- Drive support (C:, D:)\n- Encrypted private folders\n- Multi-selection\n- Search functionality\n- And much more!',
    );
    _touchRaw('/C:/Users/Admin/Pictures/sample.txt',
        content: 'Image files go here');
    _touchRaw(
      '/C:/Users/Admin/Pictures/sample.png',
      rawBytes: base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
      ),
    );
    _touchRaw(
        '/C:/Users/Admin/Videos/sample.txt', content: 'Video files go here');
    _touchRaw('/C:/Users/Admin/Downloads/example.txt',
        content: 'Downloaded files appear here');

    _touchRaw('/C:/Windows/System32/config.sys',
        content: '[System Configuration]\nVersion=1.0\nBoot=Fast');

    _touchRaw('/etc/hostname', content: 'KrdOS-device');
    _touchRaw('/etc/os-release',
        content:
            'NAME="KrdOS"\nVERSION="0.1.0"\nID=KrdOS\nPRETTY_NAME="KrdOS 0.1.0"');
    _touchRaw('/var/log/syslog',
        content:
            'Jan 01 00:00:01 KrdOS kernel: KrdOS 6.1.0-custom\nJan 01 00:00:02 KrdOS systemd: Started firewalld');
    _touchRaw('/proc/cpuinfo',
        content:
            'processor\t: 0\nmodel name\t: ARM Cortex-A78 @ 3.0GHz\ncpu cores\t: 8');
    _touchRaw('/proc/meminfo',
        content: 'MemTotal:\t2097152 kB\nMemFree:\t1366016 kB');
  }

  Map<String, dynamic> _encodeNode(VfsNode node) {
    if (node is VfsFile) {
      return {
        't': 'f',
        'n': node.name,
        'perm': node.permissions,
        'own': node.owner,
        'mod': node.modified.millisecondsSinceEpoch,
        'enc': node.isEncrypted,
        if (node.encryptedPassword != null) 'ep': node.encryptedPassword,
        if (node.rawBytes != null)
          'bin': base64Encode(node.rawBytes!)
        else
          'txt': node.content,
      };
    }
    if (node is VfsDir) {
      final c = <String, dynamic>{};
      for (final e in node.children.entries) {
        c[e.key] = _encodeNode(e.value);
      }
      return {
        't': 'd',
        'n': node.name,
        'perm': node.permissions,
        'own': node.owner,
        'mod': node.modified.millisecondsSinceEpoch,
        'enc': node.isEncrypted,
        if (node.encryptedPassword != null) 'ep': node.encryptedPassword,
        'c': c,
      };
    }
    throw StateError('Unknown VFS node');
  }

  VfsDir _decodeDir(Map<String, dynamic> j) {
    final dir = VfsDir(
      name: j['n'] as String? ?? '',
      permissions: j['perm'] as String? ?? 'rwxr-xr-x',
      owner: j['own'] as String? ?? 'admin',
      isEncrypted: j['enc'] == true,
      encryptedPassword: j['ep'] as String?,
      modified: _readMod(j['mod']),
    );
    final c = j['c'] as Map<String, dynamic>? ?? {};
    for (final e in c.entries) {
      final m = Map<String, dynamic>.from(e.value as Map);
      final t = m['t'] as String?;
      if (t == 'd') {
        dir.children[e.key] = _decodeDir(m);
      } else {
        dir.children[e.key] = _decodeFile(m);
      }
    }
    return dir;
  }

  VfsFile _decodeFile(Map<String, dynamic> j) {
    Uint8List? raw;
    var content = '';
    if (j['bin'] != null) {
      raw = base64Decode(j['bin'] as String);
    } else {
      content = j['txt'] as String? ?? '';
    }
    return VfsFile(
      name: j['n'] as String,
      content: content,
      rawBytes: raw,
      permissions: j['perm'] as String? ?? 'rw-r--r--',
      owner: j['own'] as String? ?? 'admin',
      isEncrypted: j['enc'] == true,
      encryptedPassword: j['ep'] as String?,
      modified: _readMod(j['mod']),
    );
  }

  DateTime _readMod(dynamic mod) {
    if (mod is int) {
      return DateTime.fromMillisecondsSinceEpoch(mod);
    }
    return DateTime.now();
  }

  VfsNode? resolve(String path) {
    if (path == '/') return _root;
    final parts = path.split('/').where((p) => p.isNotEmpty).toList();
    VfsNode current = _root;
    for (final part in parts) {
      if (current is! VfsDir) return null;
      final next = current.children[part];
      if (next == null) return null;
      current = next;
    }
    return current;
  }

  void mkdir(String path, {bool isEncrypted = false, String? password}) {
    _mkdirRaw(path, isEncrypted: isEncrypted, password: password);
    _notifyAndPersist();
  }

  void touch(String path, {String content = ''}) {
    _touchRaw(path, content: content);
    _notifyAndPersist();
  }

  void remove(String path) {
    final parts = path.split('/').where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return;
    final parentPath = '/${parts.sublist(0, parts.length - 1).join('/')}';
    final parent = resolve(parentPath.isEmpty ? '/' : parentPath);
    if (parent is VfsDir) {
      parent.children.remove(parts.last);
      _notifyAndPersist();
    }
  }

  void writeFile(String path, String content) {
    final node = resolve(path);
    if (node is VfsFile) {
      node.content = content;
      node.rawBytes = null;
      node.modified = DateTime.now();
      _notifyAndPersist();
    } else {
      touch(path, content: content);
    }
  }

  void writeBinaryFile(String path, Uint8List data) {
    _touchRaw(path, rawBytes: data, content: '');
    _notifyAndPersist();
  }

  void rename(String path, String newName) {
    final parts = path.split('/').where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return;
    final parentPath = '/${parts.sublist(0, parts.length - 1).join('/')}';
    final parent = resolve(parentPath.isEmpty ? '/' : parentPath);
    if (parent is! VfsDir) return;
    final node = parent.children.remove(parts.last);
    if (node == null) return;
    node.name = newName;
    node.modified = DateTime.now();
    parent.children[newName] = node;
    _notifyAndPersist();
  }

  bool isLocked(String path) {
    final node = resolve(path);
    if (node == null || !node.isEncrypted) return false;
    return !(_unlockedFolders[path] ?? false);
  }

  bool unlockFolder(String path, String password) {
    final node = resolve(path);
    if (node == null || !node.isEncrypted) return false;

    final hashedInput = _hashPassword(password);
    if (node.encryptedPassword == hashedInput) {
      _unlockedFolders[path] = true;
      _notifyAndPersist();
      return true;
    }
    return false;
  }

  void lockFolder(String path) {
    _unlockedFolders.remove(path);
    _notifyAndPersist();
  }

  String _hashPassword(String password) {
    return base64Encode(utf8.encode(password + 'salt_KrdOS'));
  }

  List<VfsNode> get desktopItems {
    final dir = resolve('/C:/Users/Admin/Desktop');
    if (dir is! VfsDir) return [];
    return dir.children.values.toList()
      ..sort((a, b) {
        if (a is VfsDir && b is VfsFile) return -1;
        if (a is VfsFile && b is VfsDir) return 1;
        return a.name.compareTo(b.name);
      });
  }

  void _mkdirRaw(String path, {bool isEncrypted = false, String? password}) {
    final parts = path.split('/').where((p) => p.isNotEmpty).toList();
    VfsDir current = _root;
    for (int i = 0; i < parts.length; i++) {
      final part = parts[i];
      final isLast = i == parts.length - 1;
      current.children.putIfAbsent(
        part,
        () => VfsDir(
          name: part,
          isEncrypted: isLast && isEncrypted,
          encryptedPassword: isLast && isEncrypted && password != null
              ? _hashPassword(password)
              : null,
        ),
      );
      current = current.children[part] as VfsDir;
    }
  }

  void _touchRaw(String path,
      {String content = '', Uint8List? rawBytes, String? permissions}) {
    final parts = path.split('/').where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return;
    final parentParts = parts.sublist(0, parts.length - 1);
    VfsDir current = _root;
    for (final part in parentParts) {
      current.children.putIfAbsent(part, () => VfsDir(name: part));
      current = current.children[part] as VfsDir;
    }
    current.children[parts.last] = VfsFile(
      name: parts.last,
      content: content,
      rawBytes: rawBytes,
      permissions: permissions ?? 'rw-r--r--',
    );
  }
}