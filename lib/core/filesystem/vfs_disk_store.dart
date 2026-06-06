import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Read/write raw VFS JSON on disk (no dependency on [VirtualFileSystem]).
abstract final class VfsDiskStore {
  static Future<File> _file() async {
    final base = await getApplicationSupportDirectory();
    return File(p.join(base.path, 'custom_os_vfs.json'));
  }

  static Future<void> writeJson(Map<String, dynamic> data) async {
    final f = await _file();
    await f.parent.create(recursive: true);
    await f.writeAsString(const JsonEncoder.withIndent('  ').convert(data));
  }

  static Future<Map<String, dynamic>?> readJson() async {
    final f = await _file();
    if (!await f.exists()) return null;
    final text = await f.readAsString();
    return jsonDecode(text) as Map<String, dynamic>;
  }

  static Future<void> delete() async {
    final f = await _file();
    if (await f.exists()) await f.delete();
  }
}
