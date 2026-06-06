import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:krdos_ui/core/filesystem/vfs.dart';
import 'package:krdos_ui/core/settings_state.dart';
import 'package:krdos_ui/core/shell/app_catalog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('VirtualFileSystem persistence map', () {
    test('roundtrip preserves text file', () {
      final a = VirtualFileSystem();
      a.persistEnabled = false;
      a.writeFile('/C:/Users/Admin/Documents/note.txt', 'persist-me');

      final snap = a.exportPersistenceMap();
      final b = VirtualFileSystem(skipDefaultSeed: true);
      b.persistEnabled = false;
      b.applyPersistenceMap(snap);

      final f = b.resolve('/C:/Users/Admin/Documents/note.txt') as VfsFile;
      expect(f.content, 'persist-me');
    });

    test('roundtrip preserves binary file', () {
      final a = VirtualFileSystem();
      a.persistEnabled = false;
      a.writeBinaryFile(
        '/C:/Users/Admin/Documents/blob.bin',
        Uint8List.fromList([1, 2, 3, 255]),
      );

      final b = VirtualFileSystem(skipDefaultSeed: true);
      b.persistEnabled = false;
      b.applyPersistenceMap(a.exportPersistenceMap());

      final f = b.resolve('/C:/Users/Admin/Documents/blob.bin') as VfsFile;
      expect(f.rawBytes, Uint8List.fromList([1, 2, 3, 255]));
    });

    test('unlock state is preserved in snapshot', () {
      final a = VirtualFileSystem();
      a.persistEnabled = false;
      a.mkdir('/C:/Users/Admin/Desktop/secret', isEncrypted: true, password: 'x');
      expect(a.unlockFolder('/C:/Users/Admin/Desktop/secret', 'x'), isTrue);

      final b = VirtualFileSystem(skipDefaultSeed: true);
      b.persistEnabled = false;
      b.applyPersistenceMap(a.exportPersistenceMap());

      expect(b.isLocked('/C:/Users/Admin/Desktop/secret'), isFalse);
    });
  });

  group('ShellAppRegistry', () {
    test('canonicalizeId maps aliases', () {
      expect(ShellAppRegistry.canonicalizeId('ghost'), 'phantom');
      expect(ShellAppRegistry.canonicalizeId('terminal'), 'terminal');
      expect(ShellAppRegistry.lookup('meshcommand'), isNotNull);
    });

    test('matchesQuery uses keywords', () {
      final d = ShellAppRegistry.lookup('browser')!;
      expect(d.matchesQuery('internet'), isTrue);
    });
  });

  group('SettingsState theme', () {
    test('toggleLightDarkTheme flips explicit mode', () async {
      SharedPreferences.setMockInitialValues({});
      final s = SettingsState();
      await s.load();
      s.setThemeMode('dark');
      expect(s.isEffectivelyDark(Brightness.light), isTrue);
      s.toggleLightDarkTheme(Brightness.light);
      expect(s.themeMode, 'light');
      s.toggleLightDarkTheme(Brightness.light);
      expect(s.themeMode, 'dark');
    });
  });
}
