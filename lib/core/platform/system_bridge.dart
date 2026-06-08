import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Dart-side MethodChannel bridge to the Linux system layer.
///
/// Every method is a no-op (returns a safe default) on non-Linux platforms so
/// the UI builds and runs on Windows / macOS / Web during development.
/// On real hardware the C++ handler in linux/runner/system_channel.cc executes
/// the actual system commands.
class SystemBridge {
  static const _ch = MethodChannel('krdos/system');

  static bool get _live => !kIsWeb && Platform.isLinux;

  // - WiFi -

  static Future<bool> wifiEnable()  => _bool('wifi.enable');
  static Future<bool> wifiDisable() => _bool('wifi.disable');
  static Future<String> wifiStatus() => _str('wifi.status');

  /// Scan for nearby WiFi networks. Returns list of:
  /// {ssid, signal (0-100), secured, connected, security}
  static Future<List<Map<String, dynamic>>> wifiScan() async {
    if (!_live) return [];
    try {
      final r = await _ch.invokeListMethod<Map>('wifi.scan');
      return r?.map((e) => Map<String, dynamic>.from(e)).toList() ?? [];
    } catch (_) { return []; }
  }

  /// Connect to a WiFi network. [password] may be empty for open networks.
  static Future<bool> wifiConnect(String ssid, {String password = ''}) =>
      _bool('wifi.connect', args: {'ssid': ssid, 'password': password});

  static Future<bool> wifiDisconnectNetwork() => _bool('wifi.disconnect');

  /// List saved (remembered) WiFi connection names.
  static Future<List<String>> wifiSavedNetworks() async {
    if (!_live) return [];
    try {
      final r = await _ch.invokeListMethod<String>('wifi.saved');
      return r ?? [];
    } catch (_) { return []; }
  }

  /// Current connected WiFi info: {ssid, signal, ip}
  static Future<Map<String, dynamic>> wifiCurrent() async {
    if (!_live) return {};
    try {
      final r = await _ch.invokeMapMethod<String, dynamic>('wifi.current');
      return r ?? {};
    } catch (_) { return {}; }
  }

  // - Ethernet -

  /// List wired (Ethernet) interfaces: {iface, connected, ip, speed, mac}
  static Future<List<Map<String, dynamic>>> ethernetList() async {
    if (!_live) return [];
    try {
      final r = await _ch.invokeListMethod<Map>('ethernet.list');
      return r?.map((e) => Map<String, dynamic>.from(e)).toList() ?? [];
    } catch (_) { return []; }
  }

  // - Bluetooth -

  static Future<bool> bluetoothEnable()  => _bool('bluetooth.enable');
  static Future<bool> bluetoothDisable() => _bool('bluetooth.disable');

  /// List all known Bluetooth devices: {name, mac, type, paired, connected}
  static Future<List<Map<String, dynamic>>> bluetoothList() async {
    if (!_live) return [];
    try {
      final r = await _ch.invokeListMethod<Map>('bluetooth.list');
      return r?.map((e) => Map<String, dynamic>.from(e)).toList() ?? [];
    } catch (_) { return []; }
  }

  /// Scan 8 s for new devices, returns discovered list: {name, mac}
  static Future<List<Map<String, dynamic>>> bluetoothScan() async {
    if (!_live) return [];
    try {
      final r = await _ch.invokeListMethod<Map>('bluetooth.scan');
      return r?.map((e) => Map<String, dynamic>.from(e)).toList() ?? [];
    } catch (_) { return []; }
  }

  static Future<bool> bluetoothPair(String mac) =>
      _bool('bluetooth.pair', args: {'mac': mac});

  static Future<bool> bluetoothConnectDevice(String mac) =>
      _bool('bluetooth.connect_device', args: {'mac': mac});

  static Future<bool> bluetoothDisconnectDevice(String mac) =>
      _bool('bluetooth.disconnect_device', args: {'mac': mac});

  // - Microphone (hardware kill switch via ALSA/PulseAudio) -

  static Future<bool> micMute()   => _bool('mic.mute');
  static Future<bool> micUnmute() => _bool('mic.unmute');

  // - Camera (hardware kill switch via kernel module) -

  static Future<bool> cameraDisable() => _bool('camera.disable');
  static Future<bool> cameraEnable()  => _bool('camera.enable');

  // - Network stats -

  static Future<Map<String, dynamic>> networkStats() async {
    if (!_live) return _fakeNetStats();
    try {
      final r = await _ch.invokeMapMethod<String, dynamic>('network.stats');
      return r ?? _fakeNetStats();
    } catch (_) {
      return _fakeNetStats();
    }
  }

  static Future<String> publicIp() => _str('network.publicip');

  // - IP rotation -

  static Future<bool> rotateIp({String iface = 'wlan0'}) =>
      _bool('ip.rotate', args: {'interface': iface});

  // - VPN -

  static Future<bool> vpnConnect({
    required String config,
    String protocol = 'wireguard',
  }) => _bool('vpn.connect', args: {'config': config, 'protocol': protocol});

  static Future<bool> vpnDisconnect() => _bool('vpn.disconnect');
  static Future<String> vpnStatus()   => _str('vpn.status');

  // - System stats -

  static Future<Map<String, dynamic>> systemStats() async {
    if (!_live) return _fakeSystemStats();
    try {
      final r = await _ch.invokeMapMethod<String, dynamic>('system.stats');
      return r ?? _fakeSystemStats();
    } catch (_) {
      return _fakeSystemStats();
    }
  }

  static Future<List<Map<String, dynamic>>> processList() async {
    if (!_live) return [];
    try {
      final r = await _ch.invokeListMethod<Map>('process.list');
      return r?.map((e) => Map<String, dynamic>.from(e)).toList() ?? [];
    } catch (_) {
      return [];
    }
  }

  // - Terminal passthrough -

  /// Executes [command] in a real shell on the target Linux machine.
  /// [cwd] sets the working directory (defaults to /home/admin).
  /// Returns combined stdout + stderr.
  static Future<String> terminalExecute(String command, {String cwd = '/home/admin'}) async {
    if (!_live) {
      return '[platform: not executing on ${Platform.operatingSystem}]';
    }
    try {
      final r = await _ch.invokeMethod<String>(
        'terminal.execute',
        {'command': command, 'cwd': cwd},
      );
      return r ?? '';
    } on PlatformException catch (e) {
      return '[error: ${e.message}]';
    }
  }

  // - Audio -

  static Future<int> audioGetVolume() async {
    if (!_live) return 70;
    try {
      final r = await _ch.invokeMethod<int>('audio.get_volume');
      return r ?? 70;
    } on PlatformException { return 70; }
  }

  static Future<bool> audioSetVolume(int percent) =>
      _bool('audio.set_volume', args: {'percent': percent});

  static Future<int> micGetVolume() async {
    if (!_live) return 80;
    try {
      final r = await _ch.invokeMethod<int>('audio.get_mic_volume');
      return r ?? 80;
    } on PlatformException { return 80; }
  }

  static Future<bool> micSetVolume(int percent) =>
      _bool('audio.set_mic_volume', args: {'percent': percent});

  // - Screenshot -

  /// Takes a screenshot and saves it to [outputPath].
  /// Returns the actual path used on success, empty string on failure.
  static Future<String> screenshot({String? outputPath}) async {
    if (!_live) return '';
    try {
      final r = await _ch.invokeMethod<String>(
        'screenshot.take',
        {'path': outputPath ?? '/home/admin/Pictures/screenshot.png'},
      );
      return r ?? '';
    } on PlatformException { return ''; }
  }

  // - Multi-monitor / display -

  static Future<List<Map<String, dynamic>>> detectMonitors() async {
    if (!_live) return _fakeMonitors();
    try {
      final r = await _ch.invokeListMethod<Map>('display.detect_monitors');
      return r?.map((e) => Map<String, dynamic>.from(e)).toList() ?? _fakeMonitors();
    } catch (_) { return _fakeMonitors(); }
  }

  static Future<bool> setMonitorResolution({
    required String output,
    required String resolution,
    int refreshRate = 60,
  }) => _bool('display.set_resolution', args: {
    'output': output,
    'resolution': resolution,
    'refresh': refreshRate,
  });

  static Future<bool> setMonitorArrangement({
    required String primary,
    required Map<String, Map<String, dynamic>> outputs,
  }) => _bool('display.set_arrangement', args: {
    'primary': primary,
    'outputs': outputs,
  });

  static Future<bool> setMonitorEnabled({
    required String output,
    required bool enabled,
  }) => _bool('display.set_enabled', args: {
    'output': output,
    'enabled': enabled,
  });

  // - Brightness -

  static Future<bool> setBrightness(int percent) =>
      _bool('display.set_brightness', args: {'percent': percent});

  // - Filesystem -

  /// List directory contents. Each entry: {name, is_dir, is_link, size, modified, owner, perms}
  static Future<List<Map<String, dynamic>>> fsList(String path) async {
    if (!_live) return [];
    try {
      final r = await _ch.invokeListMethod<Map>('fs.list', {'path': path});
      return r?.map((e) => Map<String, dynamic>.from(e)).toList() ?? [];
    } catch (_) { return []; }
  }

  static Future<String> fsReadText(String path) async {
    if (!_live) return '';
    try {
      return await _ch.invokeMethod<String>('fs.read_text', {'path': path}) ?? '';
    } on PlatformException { return ''; }
  }

  static Future<bool> fsDelete(String path) =>
      _bool('fs.delete', args: {'path': path});

  static Future<bool> fsRename(String from, String to) =>
      _bool('fs.rename', args: {'from': from, 'to': to});

  static Future<bool> fsMkdir(String path) =>
      _bool('fs.mkdir', args: {'path': path});

  static Future<bool> fsWriteText(String path, String content) =>
      _bool('fs.write_text', args: {'path': path, 'content': content});

  // - USB / Drives -

  /// Returns raw lsblk JSON string; parse with json.decode on Dart side.
  static Future<String> usbList() async {
    if (!_live) return '{}';
    try {
      return await _ch.invokeMethod<String>('usb.list') ?? '{}';
    } on PlatformException { return '{}'; }
  }

  static Future<String> usbMount(String device) async {
    if (!_live) return '';
    try {
      return await _ch.invokeMethod<String>('usb.mount', {'device': device}) ?? '';
    } on PlatformException { return ''; }
  }

  static Future<bool> usbUnmount(String device) =>
      _bool('usb.unmount', args: {'device': device});

  // - Battery -

  /// Returns {level (-1 if no battery), status, charging, plugged, has_battery}
  static Future<Map<String, dynamic>> batteryStatus() async {
    if (!_live) return {'level': -1, 'status': 'AC', 'charging': false, 'plugged': true, 'has_battery': false};
    try {
      final r = await _ch.invokeMapMethod<String, dynamic>('battery.status');
      return r ?? {'level': -1, 'has_battery': false};
    } catch (_) { return {'level': -1, 'has_battery': false}; }
  }

  // - Browser -

  /// Open a URL in an external browser process (right-click → open external).
  static Future<void> browserOpen({String url = 'about:blank'}) async {
    if (!_live) return;
    await _ch.invokeMethod<void>('browser.open', {'url': url});
  }

  // - Embedded WebKit2GTK browser window -
  // The C++ layer maintains a single borderless GtkWindow with override-redirect
  // (so matchbox WM never fullscreens it) positioned below Flutter's URL bar.

  /// Show the native WebKit window at the exact content-area rect (logical px)
  /// and navigate to [url].  x/y/w/h come from RenderBox.localToGlobal so they
  /// are absolute screen coordinates regardless of where the browser window is.
  static Future<void> browserWebViewShow(
      String url, int x, int y, int w, int h) async {
    if (!_live) return;
    try {
      await _ch.invokeMethod<void>('browser.webview_show',
          {'url': url, 'x': x, 'y': y, 'w': w, 'h': h});
    } catch (_) {}
  }

  /// Reposition the already-visible WebKit window (e.g. browser app window moved).
  static Future<void> browserWebViewReposition(
      int x, int y, int w, int h) async {
    if (!_live) return;
    try {
      await _ch.invokeMethod<void>(
          'browser.webview_reposition', {'x': x, 'y': y, 'w': w, 'h': h});
    } catch (_) {}
  }

  /// Hide the native WebKit window (kept in memory for fast re-show).
  static Future<void> browserWebViewHide() async {
    if (!_live) return;
    try { await _ch.invokeMethod<void>('browser.webview_hide'); } catch (_) {}
  }

  /// Navigate the embedded WebKit window to [url] (normalised in C++).
  static Future<void> browserWebViewNavigate(String url) async {
    if (!_live) return;
    try { await _ch.invokeMethod<void>('browser.webview_navigate', url); } catch (_) {}
  }

  static Future<void> browserWebViewBack()    async {
    if (!_live) return;
    try { await _ch.invokeMethod<void>('browser.webview_back'); } catch (_) {}
  }

  static Future<void> browserWebViewForward() async {
    if (!_live) return;
    try { await _ch.invokeMethod<void>('browser.webview_forward'); } catch (_) {}
  }

  static Future<void> browserWebViewReload()  async {
    if (!_live) return;
    try { await _ch.invokeMethod<void>('browser.webview_reload'); } catch (_) {}
  }

  static Future<void> browserWebViewStop()    async {
    if (!_live) return;
    try { await _ch.invokeMethod<void>('browser.webview_stop'); } catch (_) {}
  }

  /// Poll current browser state: url, title, canGoBack, canGoForward,
  /// isLoading, progress (0.0–1.0).  Returns {} if no WebView is active.
  static Future<Map<String, dynamic>> browserWebViewGetInfo() async {
    if (!_live) return {};
    try {
      final r = await _ch.invokeMethod<Map>('browser.webview_get_info');
      return r != null ? Map<String, dynamic>.from(r) : {};
    } catch (_) { return {}; }
  }

  /// Delete all cookies stored in the WebKit cookie manager.
  static Future<void> browserCookiesClear() async {
    if (!_live) return;
    try { await _ch.invokeMethod<void>('browser.cookies_clear'); } catch (_) {}
  }

  /// Run arbitrary JavaScript in the currently loaded WebKit page.
  /// Fire-and-forget — no return value is exposed to Dart.
  static Future<void> browserJsRun(String script) async {
    if (!_live) return;
    try {
      await _ch.invokeMethod<void>('browser.js_run', {'script': script});
    } catch (_) {}
  }

  // - Software Updates -

  /// Reads /etc/krdos/update.conf and returns {repo: String, has_token: bool}.
  /// The actual token value is NEVER sent to Dart — only whether one is set.
  static Future<Map<String, dynamic>> getUpdateConfig() async {
    if (!_live) return {'repo': '', 'has_token': false};
    try {
      final r = await _ch.invokeMapMethod<String, dynamic>('update.get_config');
      return r ?? {'repo': '', 'has_token': false};
    } on PlatformException { return {'repo': '', 'has_token': false}; }
  }

  /// Returns the locally installed version string from /opt/krdos/version.
  static Future<String> getOsVersion() async {
    if (!_live) return 'dev-build';
    try {
      return await _ch.invokeMethod<String>('update.get_version') ?? 'unknown';
    } on PlatformException { return 'unknown'; }
  }

  /// Hits the GitHub releases API for [repo] (e.g. "meeru/krdos").
  /// Returns raw JSON string — parse in UpdateState.
  static Future<String> checkForUpdate(String repo) async {
    if (!_live) return '{}';
    try {
      return await _ch.invokeMethod<String>('update.check', {'repo': repo}) ?? '{}';
    } on PlatformException { return '{}'; }
  }

  /// Launches krdos-update in background. Flutter will be restarted by the
  /// service restart — caller should show a "Restarting…" screen first.
  static Future<bool> applyUpdate() => _bool('update.apply');

  /// Returns current contents of /tmp/krdos-update.log (live progress).
  static Future<String> updateLog() async {
    if (!_live) return '';
    try {
      return await _ch.invokeMethod<String>('update.read_log') ?? '';
    } on PlatformException { return ''; }
  }

  // - System info -

  /// {hostname, kernel, cpu_model, cpu_cores, ram, disk_root, arch}
  static Future<Map<String, dynamic>> systemInfo() async {
    if (!_live) return {};
    try {
      final r = await _ch.invokeMapMethod<String, dynamic>('system.info');
      return r ?? {};
    } catch (_) { return {}; }
  }

  // - Disk info -

  static Future<List<Map<String, dynamic>>> diskUsage() async {
    if (!_live) return [];
    try {
      final r = await _ch.invokeListMethod<Map>('system.disk_usage');
      return r?.map((e) => Map<String, dynamic>.from(e)).toList() ?? [];
    } catch (_) { return []; }
  }

  // - Power -

  static Future<void> shutdown() async {
    if (!_live) return;
    await _ch.invokeMethod<void>('power.shutdown');
  }

  static Future<void> reboot() async {
    if (!_live) return;
    await _ch.invokeMethod<void>('power.reboot');
  }

  static Future<void> sleep() async {
    if (!_live) return;
    await _ch.invokeMethod<void>('power.sleep');
  }

  // - CPU per-core + temperature -

  static Future<Map<String, dynamic>> cpuDetail() async {
    if (!_live) return {};
    try {
      final r = await _ch.invokeMapMethod<String, dynamic>('cpu.detail');
      return r ?? {};
    } catch (_) { return {}; }
  }

  // - Disk I/O stats -

  static Future<Map<String, dynamic>> diskIoStats() async {
    if (!_live) return {};
    try {
      final r = await _ch.invokeMapMethod<String, dynamic>('disk.io_stats');
      return r ?? {};
    } catch (_) { return {}; }
  }

  // - GPU stats -

  static Future<Map<String, dynamic>> gpuStats() async {
    if (!_live) return {};
    try {
      final r = await _ch.invokeMapMethod<String, dynamic>('gpu.stats');
      return r ?? {};
    } catch (_) { return {}; }
  }

  // - Process management -

  static Future<List<Map<String, dynamic>>> processListFull() async {
    if (!_live) return [];
    try {
      final r = await _ch.invokeListMethod<Map>('process.list_full');
      return r?.map((e) => Map<String, dynamic>.from(e)).toList() ?? [];
    } catch (_) { return []; }
  }

  static Future<bool> processKill(int pid, {int signal = 9}) =>
      _bool('process.kill', args: {'pid': pid, 'signal': signal});

  // - Memory management -

  static Future<bool> dropCaches() => _bool('memory.drop_caches');

  static Future<bool> setCpuGovernor(String governor) =>
      _bool('cpu.set_governor', args: {'governor': governor});

  // - App installation -

  static Future<String> appInstall(String filePath) async {
    if (!_live) return 'not on Linux';
    try {
      final r = await _ch.invokeMethod<String>('app.install', {'path': filePath});
      return r ?? 'error';
    } on PlatformException catch (e) { return e.message ?? 'error'; }
  }

  // - Flatpak App Store -

  static Future<List<Map<String, dynamic>>> flatpakSearch(String query) async {
    if (!_live) return [];
    try {
      final r = await _ch.invokeListMethod<Map>('flatpak.search', {'query': query});
      return r?.map((e) => Map<String, dynamic>.from(e)).toList() ?? [];
    } catch (_) { return []; }
  }

  static Future<String> flatpakInstall(String appId) async {
    if (!_live) return 'not on Linux';
    try {
      final r = await _ch.invokeMethod<String>('flatpak.install', {'app_id': appId});
      return r ?? 'error';
    } on PlatformException catch (e) { return e.message ?? 'error'; }
  }

  static Future<List<Map<String, dynamic>>> flatpakList() async {
    if (!_live) return [];
    try {
      final r = await _ch.invokeListMethod<Map>('flatpak.list');
      return r?.map((e) => Map<String, dynamic>.from(e)).toList() ?? [];
    } catch (_) { return []; }
  }

  // - Maintenance -

  static Future<bool> maintenanceRun() => _bool('maintenance.run');
  static Future<String> maintenanceStatus() => _str('maintenance.status');

  // - Startup manager -

  static Future<List<Map<String, dynamic>>> startupList() async {
    if (!_live) return [];
    try {
      final r = await _ch.invokeListMethod<Map>('startup.list');
      return r?.map((e) => Map<String, dynamic>.from(e)).toList() ?? [];
    } catch (_) { return []; }
  }

  static Future<bool> startupToggle(String service, bool enable) =>
      _bool('startup.toggle', args: {'service': service, 'enable': enable});

  // - System optimization -

  static Future<bool> systemOptimize() => _bool('system.optimize');

  // - Storage analyzer -

  static Future<List<Map<String, dynamic>>> storageAnalyze(String path) async {
    if (!_live) return [];
    try {
      final r = await _ch.invokeListMethod<Map>('storage.analyze', {'path': path});
      return r?.map((e) => Map<String, dynamic>.from(e)).toList() ?? [];
    } catch (_) { return []; }
  }

  static Future<String> diskHealth(String device) async {
    if (!_live) return 'unavailable';
    try {
      final r = await _ch.invokeMethod<String>('disk.health', {'device': device});
      return r ?? 'unavailable';
    } on PlatformException { return 'unavailable'; }
  }

  static Future<bool> diskClean(String path) => _bool('disk.clean', args: {'path': path});

  // - Benchmarks -

  static Future<Map<String, dynamic>> benchmarkRun() async {
    if (!_live) return {};
    try {
      final r = await _ch.invokeMapMethod<String, dynamic>('benchmark.run');
      return r ?? {};
    } catch (_) { return {}; }
  }

  // - Self-healing alert -

  static Future<bool> setThermalGovernor(String governor) =>
      _bool('cpu.set_governor', args: {'governor': governor});

  // - Drives (structured lsblk output) -

  /// Returns list of all block devices (disk + part):
  /// {name, device, label, size, type, mountpoint, removable, vendor, model}
  static Future<List<Map<String, dynamic>>> drivesList() async {
    if (!_live) return [];
    try {
      final r = await _ch.invokeListMethod<Map>('drives.list');
      return r?.map((e) => Map<String, dynamic>.from(e)).toList() ?? [];
    } catch (_) { return []; }
  }

  // - App management -

  /// List manually-installed deb packages (apt-mark showmanual).
  /// Each entry: {id, name, version, size_kb, desc, source:"deb"}
  static Future<List<Map<String, dynamic>>> appsListDpkg() async {
    if (!_live) return [];
    try {
      final r = await _ch.invokeListMethod<Map>('apps.list_dpkg');
      return r?.map((e) => Map<String, dynamic>.from(e)).toList() ?? [];
    } catch (_) { return []; }
  }

  /// Uninstall a deb package (apt-get remove --purge). Returns output text.
  static Future<String> appsUninstallDeb(String package) async {
    if (!_live) return 'not on Linux';
    try {
      return await _ch.invokeMethod<String>('apps.uninstall_deb',
          {'package': package}) ?? 'error';
    } on PlatformException catch (e) { return e.message ?? 'error'; }
  }

  /// Uninstall a Flatpak app. Returns output text.
  static Future<String> appsUninstallFlatpak(String appId) async {
    if (!_live) return 'not on Linux';
    try {
      return await _ch.invokeMethod<String>('apps.uninstall_flatpak',
          {'app_id': appId}) ?? 'error';
    } on PlatformException catch (e) { return e.message ?? 'error'; }
  }

  /// Get raw dpkg-query -s output for a package.
  static Future<String> appsGetInfoDeb(String package) async {
    if (!_live) return '';
    try {
      return await _ch.invokeMethod<String>('apps.get_info_deb',
          {'package': package}) ?? '';
    } on PlatformException { return ''; }
  }

  /// Get flatpak info --show-permissions output for an app.
  static Future<String> appsGetPermissionsFlatpak(String appId) async {
    if (!_live) return '';
    try {
      return await _ch.invokeMethod<String>('apps.get_permissions_flatpak',
          {'app_id': appId}) ?? '';
    } on PlatformException { return ''; }
  }

  /// Allow or block network access for a Flatpak app via flatpak override.
  static Future<bool> appsSetNetworkFlatpak(String appId,
      {required bool allowed}) =>
      _bool('apps.set_network_flatpak',
          args: {'app_id': appId, 'allowed': allowed});

  // - Firewall (UFW) -

  static Future<Map<String, dynamic>> firewallStatus() async {
    if (!_live) return {'enabled': false, 'raw': ''};
    try {
      final r = await _ch.invokeMapMethod<String, dynamic>('firewall.status');
      return r ?? {'enabled': false, 'raw': ''};
    } catch (_) { return {'enabled': false, 'raw': ''}; }
  }

  static Future<bool> firewallEnable()  => _bool('firewall.enable');
  static Future<bool> firewallDisable() => _bool('firewall.disable');

  static Future<List<Map<String, dynamic>>> firewallListRules() async {
    if (!_live) return [];
    try {
      final r = await _ch.invokeListMethod<Map>('firewall.list_rules');
      return r?.map((e) => Map<String, dynamic>.from(e)).toList() ?? [];
    } catch (_) { return []; }
  }

  static Future<bool> firewallAddRule({
    required String port, String proto = 'tcp',
    String action = 'allow', String direction = 'in',
  }) => _bool('firewall.add_rule',
      args: {'port': port, 'proto': proto, 'action': action, 'direction': direction});

  static Future<bool> firewallDeleteRule(int num) =>
      _bool('firewall.delete_rule', args: {'num': num});

  // - SSH Key Manager -

  static Future<List<Map<String, dynamic>>> keysList() async {
    if (!_live) return [];
    try {
      final r = await _ch.invokeListMethod<Map>('keys.list');
      return r?.map((e) => Map<String, dynamic>.from(e)).toList() ?? [];
    } catch (_) { return []; }
  }

  static Future<Map<String, dynamic>> keysGenerate({
    String type = 'ed25519', String comment = 'krdos', String passphrase = '',
  }) async {
    if (!_live) return {'ok': false, 'output': 'not on Linux', 'pub_path': ''};
    try {
      final r = await _ch.invokeMapMethod<String, dynamic>('keys.generate',
          {'type': type, 'comment': comment, 'passphrase': passphrase});
      return r ?? {'ok': false, 'output': 'error', 'pub_path': ''};
    } catch (_) { return {'ok': false, 'output': 'error', 'pub_path': ''}; }
  }

  static Future<String> keysGetPublic(String pubPath) async {
    if (!_live) return '';
    try {
      return await _ch.invokeMethod<String>('keys.get_public',
          {'pub_path': pubPath}) ?? '';
    } on PlatformException { return ''; }
  }

  static Future<bool> keysDelete(String pubPath) =>
      _bool('keys.delete', args: {'pub_path': pubPath});

  // - Vault (AES-256-CBC via openssl enc) -

  static Future<Map<String, dynamic>> vaultStatus() async {
    if (!_live) return {'exists': false, 'file_count': 0};
    try {
      final r = await _ch.invokeMapMethod<String, dynamic>('vault.status');
      return r ?? {'exists': false, 'file_count': 0};
    } catch (_) { return {'exists': false, 'file_count': 0}; }
  }

  static Future<bool> vaultCreate(String passphrase) =>
      _bool('vault.create', args: {'passphrase': passphrase});

  static Future<bool> vaultVerify(String passphrase) =>
      _bool('vault.verify', args: {'passphrase': passphrase});

  static Future<List<Map<String, dynamic>>> vaultListFiles() async {
    if (!_live) return [];
    try {
      final r = await _ch.invokeListMethod<Map>('vault.list_files');
      return r?.map((e) => Map<String, dynamic>.from(e)).toList() ?? [];
    } catch (_) { return []; }
  }

  static Future<bool> vaultAddFile({
    required String srcPath, required String passphrase, required String name,
  }) => _bool('vault.add_file',
      args: {'src_path': srcPath, 'passphrase': passphrase, 'name': name});

  static Future<bool> vaultRemoveFile(String name) =>
      _bool('vault.remove_file', args: {'name': name});

  // - Internal helpers -

  static Future<bool> _bool(String method, {Map<String, dynamic>? args}) async {
    if (!_live) return true;
    try {
      final r = await _ch.invokeMethod<bool>(method, args);
      return r ?? false;
    } on PlatformException {
      return false;
    }
  }

  static Future<String> _str(String method, {Map<String, dynamic>? args}) async {
    if (!_live) return '';
    try {
      final r = await _ch.invokeMethod<String>(method, args);
      return r ?? '';
    } on PlatformException {
      return '';
    }
  }

  static Map<String, dynamic> _fakeNetStats() => {
    'rx_bytes': 0,
    'tx_bytes': 0,
    'rx_packets': 0,
    'tx_packets': 0,
    'interface': 'eth0',
  };

  static List<Map<String, dynamic>> _fakeMonitors() => [
    {
      'output': 'HDMI-1',
      'connected': true,
      'primary': true,
      'resolution': '1920x1080',
      'refresh_rate': 60,
      'x': 0, 'y': 0,
      'width_mm': 527, 'height_mm': 296,
      'available_resolutions': ['1920x1080', '1280x720', '1024x768'],
    },
  ];

  static Map<String, dynamic> _fakeSystemStats() => {
    'cpu_percent': 0.0,
    'mem_total_kb': 4096000,
    'mem_used_kb': 1024000,
    'uptime_seconds': 0.0,
    'load_avg_1': 0.0,
    'load_avg_5': 0.0,
    'load_avg_15': 0.0,
  };
}