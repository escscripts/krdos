import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'browser_models.dart';

/// Persistent browser profile (starter shortcuts, shell mode, Tor path).
class BrowserPrefsStore {
  static const _shellKey = 'custom_os_browser_shell_v1';
  static const _committedKey = 'custom_os_browser_shell_committed_v1';
  static const _promptEachOpenKey = 'custom_os_browser_prompt_shell_v1';
  static const _shortcutsKey = 'custom_os_browser_starter_shortcuts_v1';
  static const _torExeKey = 'custom_os_browser_tor_exe_v1';
  static const _torSocksHostKey = 'custom_os_browser_tor_socks_host_v1';
  static const _torSocksPortKey = 'custom_os_browser_tor_socks_port_v1';
  static const _httpsPrefKey = 'custom_os_browser_https_pref_v1';
  static const _dangerSchemesKey = 'custom_os_browser_danger_scheme_v1';
  static const _strictJsKey = 'custom_os_browser_strict_js_v1';

  static String _serializeBackend(BrowserShellBackend b) => b.name;

  /// Persisted Dart enum serialized with [BrowserShellBackend.name].
  static BrowserShellBackend _parseBackend(String? raw) {
    switch (raw) {
      case 'microsoftEdgeWebView2':
      case 'microsoftEdge':
      case 'edge':
        return BrowserShellBackend.microsoftEdgeWebView2;
      case 'torEmbeddedSocks':
      case 'torExternalCompanion':
      case 'tor':
        return BrowserShellBackend.torEmbeddedSocks;
      case 'chromiumEmbedded':
      case 'chromium':
        return BrowserShellBackend.chromiumEmbedded;
      default:
        return BrowserShellBackend.chromiumEmbedded;
    }
  }

  static Future<BrowserPrefsSnapshot> load() async {
    final sp = await SharedPreferences.getInstance();
    final shortcuts = _decodeShortcuts(sp.getString(_shortcutsKey));
    return BrowserPrefsSnapshot(
      shell: _parseBackend(sp.getString(_shellKey)),
      shellChoiceCommitted: sp.getBool(_committedKey) ?? false,
      promptShellOnEveryOpen: sp.getBool(_promptEachOpenKey) ?? false,
      starterShortcuts: shortcuts,
      torBrowserExecutablePath: sp.getString(_torExeKey),
      torSocksHost: _readSocksHost(sp),
      torSocksPort: _readSocksPort(sp),
      httpsPreferred: sp.getBool(_httpsPrefKey) ?? true,
      dangerousSchemeBlock: sp.getBool(_dangerSchemesKey) ?? true,
      strictJavaScript: sp.getBool(_strictJsKey) ?? false,
    );
  }

  static Future<void> savePrivacyHardFlags({
    required bool httpsPreferred,
    required bool dangerousSchemeBlock,
    required bool strictJavaScript,
  }) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setBool(_httpsPrefKey, httpsPreferred);
    await sp.setBool(_dangerSchemesKey, dangerousSchemeBlock);
    await sp.setBool(_strictJsKey, strictJavaScript);
  }

  static Future<void> saveShellChoice({
    required BrowserShellBackend shell,
    required bool committed,
    required bool promptOnEveryOpen,
  }) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_shellKey, _serializeBackend(shell));
    await sp.setBool(_committedKey, committed);
    await sp.setBool(_promptEachOpenKey, promptOnEveryOpen);
  }

  static Future<void> saveTorExecutablePath(String? path) async {
    final sp = await SharedPreferences.getInstance();
    if (path == null || path.trim().isEmpty) {
      await sp.remove(_torExeKey);
    } else {
      await sp.setString(_torExeKey, path.trim());
    }
  }

  static Future<void> saveStarterShortcuts(List<StarterShortcut> shortcuts) async {
    final sp = await SharedPreferences.getInstance();
    final encoded = jsonEncode(shortcuts.map((s) => s.toJson()).toList());
    await sp.setString(_shortcutsKey, encoded);
  }

  static String _readSocksHost(SharedPreferences sp) {
    final h = sp.getString(_torSocksHostKey);
    if (h == null || h.trim().isEmpty) return '127.0.0.1';
    return h.trim();
  }

  static int _readSocksPort(SharedPreferences sp) {
    final p = sp.getInt(_torSocksPortKey) ?? 9050;
    if (p < 1 || p > 65535) return 9050;
    return p;
  }

  static Future<void> saveTorSocksEndpoint({required String host, required int port}) async {
    final sp = await SharedPreferences.getInstance();
    final h = host.trim().isEmpty ? '127.0.0.1' : host.trim();
    var pr = port;
    if (pr < 1 || pr > 65535) pr = 9050;
    await sp.setString(_torSocksHostKey, h);
    await sp.setInt(_torSocksPortKey, pr);
  }

  static List<StarterShortcut> _decodeShortcuts(String? raw) {
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => StarterShortcut.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }
}

class BrowserPrefsSnapshot {
  final BrowserShellBackend shell;
  final bool shellChoiceCommitted;
  final bool promptShellOnEveryOpen;
  final List<StarterShortcut> starterShortcuts;
  final String? torBrowserExecutablePath;
  final String torSocksHost;
  final int torSocksPort;
  final bool httpsPreferred;
  final bool dangerousSchemeBlock;
  final bool strictJavaScript;

  const BrowserPrefsSnapshot({
    required this.shell,
    required this.shellChoiceCommitted,
    required this.promptShellOnEveryOpen,
    required this.starterShortcuts,
    this.torBrowserExecutablePath,
    required this.torSocksHost,
    required this.torSocksPort,
    required this.httpsPreferred,
    required this.dangerousSchemeBlock,
    required this.strictJavaScript,
  });
}
