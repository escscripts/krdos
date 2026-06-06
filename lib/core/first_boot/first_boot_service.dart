import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// First-boot setup service.
///
/// Runs once ? on the very first launch after installation ? then marks itself
/// done permanently by writing a flag both to SharedPreferences (fast) and to
/// /etc/KrdOS/first_boot_done on Linux (survives data wipe / app update).
///
/// Call [check] from main.dart BEFORE rendering the first screen.
class FirstBootService {
  static const _prefKey = 'first_boot_done_v1';
  static const _flagFile = '/etc/KrdOS/first_boot_done';

  /// Returns true if this is the very first boot.
  static Future<bool> isFirstBoot() async {
  // Fast path: SharedPreferences already set
    final p = await SharedPreferences.getInstance();
    if (p.getBool(_prefKey) == true) return false;

  // Slow path: check the filesystem flag
    if (!kIsWeb && Platform.isLinux) {
      if (await File(_flagFile).exists()) {
        await p.setBool(_prefKey, true); // sync to prefs
        return false;
      }
    }
    return true;
  }

  /// Run all first-boot setup tasks and mark as done.
  static Future<void> runSetup({void Function(String step)? onStep}) async {
    onStep?.call('Creating directory structure?');
    await _createDirectories();

    onStep?.call('Configuring environment?');
    await _writeEnvConfig();

    onStep?.call('Starting background services?');
    await _startServices();

    onStep?.call('Configuring network?');
    await _configureNetwork();

    onStep?.call('Applying speed optimizations?');
    await _runOptimizations();

    onStep?.call('Setting up sudoers?');
    await _configureSudoers();

    onStep?.call('Finalising?');
    await _markDone();
  }

  static Future<void> _createDirectories() async {
    if (kIsWeb) return;
    const dirs = [
      '/home/admin/Desktop',
      '/home/admin/Documents',
      '/home/admin/Downloads',
      '/home/admin/Pictures',
      '/home/admin/Videos',
      '/home/admin/.config/KrdOS',
      '/etc/KrdOS',
      '/opt/KrdOS/vpn',
      '/var/log/KrdOS',
    ];
    for (final d in dirs) {
      try {
        await Directory(d).create(recursive: true);
      } catch (_) {}
    }
  }

  static Future<void> _writeEnvConfig() async {
    if (kIsWeb) return;
    try {
      await File('/etc/KrdOS/env.conf').writeAsString('''
KrdOS_VERSION=1.0.0
KrdOS_HOME=/opt/KrdOS
KrdOS_SHELL=1
KrdOS_USER=admin
''');
    } catch (_) {}
  }

  static Future<void> _startServices() async {
    if (kIsWeb || !Platform.isLinux) return;
    const services = ['NetworkManager', 'weston', 'KrdOS'];
    for (final svc in services) {
      try {
        await Process.run('systemctl', ['enable', '--now', svc]);
      } catch (_) {}
    }
  }

  static Future<void> _configureNetwork() async {
    if (kIsWeb || !Platform.isLinux) return;
    try {
  // Enable NetworkManager if not already running
      await Process.run('systemctl', ['start', 'NetworkManager']);
  // Randomise MAC on wlan0 for privacy
      await Process.run('macchanger', ['-r', 'wlan0']);
    } catch (_) {}
  }

  static Future<void> _runOptimizations() async {
    if (kIsWeb || !Platform.isLinux) return;
    try {
      await Process.run('bash', ['/usr/local/bin/optimize.sh']);
    } catch (_) {}
  }

  static Future<void> _configureSudoers() async {
    if (kIsWeb || !Platform.isLinux) return;
    const content = '''
# KrdOS ? auto-generated on first boot
KrdOS ALL=(ALL) NOPASSWD: /usr/sbin/rfkill, /usr/bin/nmcli, /sbin/modprobe, /usr/bin/wg-quick, /usr/sbin/openvpn, /sbin/ip, /usr/bin/macchanger, /bin/systemctl, /sbin/reboot, /sbin/poweroff, /usr/bin/amixer, /usr/bin/pactl
''';
    try {
      final f = File('/etc/sudoers.d/KrdOS');
      if (!await f.exists()) {
        await f.writeAsString(content);
        await Process.run('chmod', ['440', f.path]);
      }
    } catch (_) {}
  }

  static Future<void> _markDone() async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(_prefKey, true);
    if (!kIsWeb && Platform.isLinux) {
      try {
        await File(_flagFile).writeAsString(DateTime.now().toIso8601String());
      } catch (_) {}
    }
  }
}