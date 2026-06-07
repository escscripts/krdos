import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../apps/ghost_mode_app.dart';
import '../../apps/meshcommand/meshcommand_launcher.dart';
import '../../screens/app_drawer.dart';
import '../../screens/apps/advanced_monitor_screen.dart';
import '../../screens/apps/app_installer_screen.dart';
import '../../screens/apps/audio_control_screen.dart';
import '../../screens/apps/browser_screen.dart';
import '../../screens/apps/calculator_screen.dart';
import '../../screens/apps/calendar_screen.dart';
import '../../screens/apps/clock_screen.dart';
import '../../screens/apps/editor_screen.dart';
import '../../screens/apps/file_manager_screen.dart';
import '../../screens/apps/screenshot_screen.dart';
import '../../screens/apps/speed_test_screen.dart';
import '../../screens/apps/storage_analyzer_screen.dart';
import '../../screens/apps/terminal_screen.dart';
import '../../screens/devices/device_hub_screen.dart';
import '../../screens/settings/about_screen.dart';
import '../../screens/settings/maintenance_screen.dart';
import '../../screens/settings/monitors_settings.dart';
import '../../screens/settings/network_settings.dart';
import '../../screens/settings/security_settings.dart';
import '../../screens/settings_screen.dart';
import '../../screens/user_management_screen.dart';
import '../../theme/app_theme.dart';
import '../../theme/shell_accent.dart';
import '../filesystem/vfs.dart';

/// Single source of truth for shell apps: taskbar, start menu, drawer, desktop,
/// shortcut picker, and window routing all derive from this registry.
@immutable
class ShellAppDef {
  const ShellAppDef({
    required this.id,
    required this.title,
    required this.icon,
    required this.color,
    required this.category,
    this.keywords = const [],
    this.showOnDesktopByDefault = false,
    this.showInShortcutPicker = true,
    this.allowTaskbarPin = true,
  });

  final String id;
  final String title;
  final IconData icon;
  final Color color;

  /// App drawer / launcher category: SYSTEM | SECURITY | TOOLS
  final String category;
  final List<String> keywords;

  /// Seed icons on the desktop for new sessions.
  final bool showOnDesktopByDefault;

  /// Listed in shortcut properties ? "Opens ? Application".
  final bool showInShortcutPicker;

  /// May appear in dock / taskbar pin lists (excludes meta launchers if false).
  final bool allowTaskbarPin;

  bool matchesQuery(String query) {
    if (query.isEmpty) return true;
    final q = query.toLowerCase();
    if (title.toLowerCase().contains(q) || id.contains(q)) return true;
    for (final k in keywords) {
      if (k.toLowerCase().contains(q)) return true;
    }
    return false;
  }

  int get colorArgb32 {
    final a = (color.a * 255).round().clamp(0, 255);
    final r = (color.r * 255).round().clamp(0, 255);
    final g = (color.g * 255).round().clamp(0, 255);
    final b = (color.b * 255).round().clamp(0, 255);
    return (a << 24) | (r << 16) | (g << 8) | b;
  }

  /// Taskbar / overlay map shape (legacy UI consumes this).
  Map<String, dynamic> toTaskbarMap() => {
        'icon': icon,
        'label': title,
        'id': id,
        'color': colorArgb32,
      };
}

/// Canonical ordered registry (display order for pickers).
class ShellAppRegistry {
  ShellAppRegistry._();

  static const List<ShellAppDef> all = [
    ShellAppDef(
      id: 'browser',
      title: 'Browser',
      icon: Icons.language,
      color: Color(0xFF4285F4),
      category: 'SYSTEM',
      keywords: ['web', 'internet', 'http', 'www'],
      showOnDesktopByDefault: true,
    ),
    ShellAppDef(
      id: 'terminal',
      title: 'Terminal',
      icon: Icons.terminal,
      color: kShellDefaultAccent,
      category: 'SYSTEM',
      keywords: ['shell', 'console', 'cli', 'bash', 'cmd'],
      showOnDesktopByDefault: true,
    ),
    ShellAppDef(
      id: 'files',
      title: 'Files',
      icon: Icons.folder_open,
      color: AppTheme.warning,
      category: 'SYSTEM',
      keywords: ['folder', 'explorer', 'fs', 'directory'],
      showOnDesktopByDefault: true,
    ),
    ShellAppDef(
      id: 'editor',
      title: 'Editor',
      icon: Icons.code,
      color: Color(0xFF007ACC),
      category: 'TOOLS',
      keywords: ['code', 'ide', 'text', 'dev'],
      showOnDesktopByDefault: true,
    ),
    ShellAppDef(
      id: 'phantom',
      title: 'Ghost Mode',
      icon: Icons.visibility_off_rounded,
      color: Color(0xFF00FF41),
      category: 'SECURITY',
      keywords: ['ghost', 'privacy', 'stealth'],
      showOnDesktopByDefault: true,
    ),
    ShellAppDef(
      id: 'devices',
      title: 'Devices',
      icon: Icons.devices_other,
      color: Color(0xFF58A6FF),
      category: 'SYSTEM',
      keywords: ['usb', 'hardware', 'bluetooth', 'peripheral'],
      showOnDesktopByDefault: true,
    ),
    ShellAppDef(
      id: 'settings',
      title: 'Settings',
      icon: Icons.settings,
      color: AppTheme.textSecondary,
      category: 'SYSTEM',
      keywords: ['preferences', 'config', 'control', 'panel'],
      showOnDesktopByDefault: true,
    ),
    ShellAppDef(
      id: 'users',
      title: 'Users',
      icon: Icons.manage_accounts,
      color: AppTheme.warning,
      category: 'SYSTEM',
      keywords: ['accounts', 'login', 'profile'],
      showOnDesktopByDefault: true,
    ),
    ShellAppDef(
      id: 'security',
      title: 'Security',
      icon: Icons.security,
      color: AppTheme.danger,
      category: 'SECURITY',
      keywords: ['privacy', 'firewall', 'encryption'],
      showOnDesktopByDefault: true,
    ),
    ShellAppDef(
      id: 'network',
      title: 'Network',
      icon: Icons.wifi,
      color: kShellDefaultAccent,
      category: 'SYSTEM',
      keywords: ['wifi', 'internet', 'ethernet', 'ip'],
      showOnDesktopByDefault: true,
    ),
    ShellAppDef(
      id: 'monitor',
      title: 'System Info',
      icon: Icons.monitor_heart,
      color: kShellDefaultAccent,
      category: 'TOOLS',
      keywords: ['about', 'cpu', 'ram', 'diagnostics', 'monitor'],
      showOnDesktopByDefault: true,
    ),
    ShellAppDef(
      id: 'meshcommand',
      title: 'MeshCommand',
      icon: Icons.hub,
      color: Color(0xFF7B68FF),
      category: 'TOOLS',
      keywords: ['mesh', 'rf', 'lab', 'drone', 'signal'],
      showOnDesktopByDefault: true,
    ),
    ShellAppDef(
      id: 'vault',
      title: 'Vault',
      icon: Icons.lock,
      color: Color(0xFFFF5722),
      category: 'SECURITY',
      keywords: ['secrets', 'password', 'secure'],
    ),
    ShellAppDef(
      id: 'keys',
      title: 'Keys',
      icon: Icons.vpn_key,
      color: Color(0xFFFF4444),
      category: 'SECURITY',
      keywords: ['ssh', 'pgp', 'credentials'],
    ),
    ShellAppDef(
      id: 'firewall',
      title: 'Firewall',
      icon: Icons.shield,
      color: Color(0xFFF44336),
      category: 'SECURITY',
      keywords: ['rules', 'packet', 'block'],
    ),
    ShellAppDef(
      id: 'dns',
      title: 'DNS',
      icon: Icons.dns,
      color: Color(0xFF3F51B5),
      category: 'SECURITY',
      keywords: ['resolver', 'domain', 'nameserver'],
    ),
    ShellAppDef(
      id: 'system',
      title: 'System',
      icon: Icons.developer_board,
      color: Color(0xFF9E9E9E),
      category: 'SYSTEM',
      keywords: ['info', 'build', 'kernel'],
    ),
    ShellAppDef(
      id: 'debugger',
      title: 'Debugger',
      icon: Icons.bug_report,
      color: Color(0xFFFF5722),
      category: 'TOOLS',
      keywords: ['debug', 'trace', 'logs'],
    ),
    ShellAppDef(
      id: 'analytics',
      title: 'Analytics',
      icon: Icons.analytics,
      color: Color(0xFF00BCD4),
      category: 'TOOLS',
      keywords: ['metrics', 'stats', 'telemetry'],
    ),
    ShellAppDef(
      id: 'calculator',
      title: 'Calculator',
      icon: Icons.calculate_rounded,
      color: Color(0xFF26A69A),
      category: 'TOOLS',
      keywords: ['calc', 'math', 'numbers'],
    ),
    ShellAppDef(
      id: 'clock',
      title: 'Clock',
      icon: Icons.access_time_rounded,
      color: Color(0xFF5C6BC0),
      category: 'TOOLS',
      keywords: ['time', 'alarm', 'timer', 'stopwatch', 'world'],
    ),
    ShellAppDef(
      id: 'audio',
      title: 'Sound',
      icon: Icons.volume_up_rounded,
      color: Color(0xFFE91E63),
      category: 'SYSTEM',
      keywords: ['volume', 'sound', 'speaker', 'microphone', 'audio'],
    ),
    ShellAppDef(
      id: 'screenshot',
      title: 'Screenshot',
      icon: Icons.screenshot_monitor_rounded,
      color: Color(0xFF8BC34A),
      category: 'TOOLS',
      keywords: ['capture', 'screen', 'image', 'snap'],
    ),
    ShellAppDef(
      id: 'calendar',
      title: 'Calendar',
      icon: Icons.calendar_month_rounded,
      color: Color(0xFFFF7043),
      category: 'TOOLS',
      keywords: ['date', 'event', 'schedule', 'agenda'],
    ),
    ShellAppDef(
      id: 'monitors',
      title: 'Monitors',
      icon: Icons.monitor_rounded,
      color: Color(0xFF42A5F5),
      category: 'SYSTEM',
      keywords: ['display', 'screen', 'resolution', 'xrandr', 'multimonitor'],
    ),
    ShellAppDef(
      id: 'adv_monitor',
      title: 'Performance',
      icon: Icons.monitor_heart_rounded,
      color: Color(0xFFE91E63),
      category: 'TOOLS',
      keywords: ['cpu', 'ram', 'gpu', 'performance', 'processes', 'task manager'],
    ),
    ShellAppDef(
      id: 'installer',
      title: 'App Installer',
      icon: Icons.get_app_rounded,
      color: Color(0xFF8BC34A),
      category: 'SYSTEM',
      keywords: ['install', 'exe', 'deb', 'flatpak', 'wine', 'appimage', 'snap'],
    ),
    ShellAppDef(
      id: 'app_store',
      title: 'App Store',
      icon: Icons.storefront_rounded,
      color: Color(0xFF00BCD4),
      category: 'SYSTEM',
      keywords: ['store', 'apps', 'download', 'flatpak', 'browse'],
    ),
    ShellAppDef(
      id: 'storage',
      title: 'Storage',
      icon: Icons.pie_chart_rounded,
      color: Color(0xFF795548),
      category: 'TOOLS',
      keywords: ['disk', 'space', 'usage', 'files', 'clean'],
    ),
    ShellAppDef(
      id: 'speedtest',
      title: 'Speed Test',
      icon: Icons.speed_rounded,
      color: Color(0xFFFF7043),
      category: 'TOOLS',
      keywords: ['benchmark', 'cpu', 'disk', 'ram', 'speed', 'performance'],
    ),
    ShellAppDef(
      id: 'maintenance',
      title: 'Maintenance',
      icon: Icons.build_circle_rounded,
      color: Color(0xFF9E9E9E),
      category: 'SYSTEM',
      keywords: ['clean', 'optimize', 'health', 'startup', 'maintain'],
    ),
    ShellAppDef(
      id: 'allapps',
      title: 'All Apps',
      icon: Icons.apps_rounded,
      color: kShellDefaultAccent,
      category: 'SYSTEM',
      keywords: ['launcher', 'drawer', 'programs'],
      showOnDesktopByDefault: false,
      showInShortcutPicker: true,
    ),
  ];

  static final Map<String, ShellAppDef> _byId = {
    for (final a in all) a.id: a,
  };

  static List<String> get defaultPinnedIds =>
      const ['terminal', 'files', 'devices', 'settings'];

  static Set<String> get knownAppIds => _byId.keys.toSet();

  /// Includes apps plus reserved launcher id `allapps`.
  static Set<String> get validPinIds => {...knownAppIds, 'allapps'};

  static ShellAppDef? lookup(String? rawId) {
    if (rawId == null || rawId.isEmpty) return null;
    final c = canonicalizeId(rawId);
    return c == null ? null : _byId[c];
  }

  /// Maps legacy / fuzzy ids from shortcuts and file associations to a canonical app id.
  static String? canonicalizeId(String raw) {
    final n = raw.toLowerCase().trim();
    if (n.isEmpty) return null;
    if (_byId.containsKey(n)) return n;

    if (n.contains('allapps') || n.contains('drawer')) return 'allapps';
    if (n.contains('meshcommand') || n.contains('mesh')) return 'meshcommand';
    if (n.contains('phantom') || n.contains('ghost')) return 'phantom';
    if (n.contains('browser')) return 'browser';

    final sorted = [...all]..sort((a, b) => b.id.length.compareTo(a.id.length));
    for (final app in sorted) {
      if (n.contains(app.id)) return app.id;
    }

    if (n.contains('file')) return 'files';
    if (n.contains('terminal') || n.contains('shell')) return 'terminal';
    if (n.contains('setting')) return 'settings';
    if (n.contains('device')) return 'devices';
    if (n.contains('user')) return 'users';
    if (n.contains('network') || n.contains('wifi')) return 'network';
    if (n.contains('security')) return 'security';
    if (n.contains('editor') || n.contains('code')) return 'editor';
    if (n.contains('monitor') || n.contains('about')) return 'monitor';

    return null;
  }

  static List<Map<String, dynamic>> taskbarMapsSortedByTitle() {
    final m = all
        .where((a) => a.allowTaskbarPin)
        .map((a) => a.toTaskbarMap())
        .toList();
    m.sort(
      (a, b) =>
          (a['label'] as String).toLowerCase().compareTo((b['label'] as String).toLowerCase()),
    );
    return m;
  }

  static List<ShellAppDef> forShortcutPicker() =>
      all.where((a) => a.showInShortcutPicker).toList();

  /// App drawer uses SYSTEM / SECURITY / TOOLS tabs (see [AppDrawer]).
  /// Omits [allapps] to avoid nesting the full launcher inside itself.
  static List<ShellAppDef> forDrawerCategory(String cat) {
    Iterable<ShellAppDef> base = all.where((a) => a.id != 'allapps');
    if (cat == 'ALL') return base.toList();
    return base.where((a) => a.category == cat).toList();
  }

  /// Build the root widget for a window or full-screen push route.
  static Widget buildShellApp(
    BuildContext context,
    String id, {
    String? path,
    String? settingsInitialPage,
    int settingsInitialSubTab = 0,
  }) {
    final c = canonicalizeId(id) ?? id;
    switch (c) {
      case 'browser':
        return const BrowserScreen();
      case 'terminal':
      case 'debugger':
        return const TerminalScreen();
      case 'files':
        return FileManagerScreen(initialPath: path ?? '/root');
      case 'editor':
        return EditorScreen(
          vfs: context.read<VirtualFileSystem>(),
          initialFilePath: path,
        );
      case 'phantom':
        return const GhostModeApp();
      case 'devices':
        return const DeviceHubScreen();
      case 'settings':
        return SettingsScreen(
          initialPage: settingsInitialPage,
          initialSubTab: settingsInitialSubTab,
        );
      case 'users':
        return const UserManagementScreen();
      case 'security':
      case 'vault':
      case 'keys':
      case 'firewall':
        return const SecuritySettingsScreen();
      case 'network':
      case 'dns':
        return NetworkSettingsScreen();
      case 'monitor':
      case 'system':
      case 'analytics':
        return const AboutScreen();
      case 'allapps':
        return const AppDrawer();
      case 'meshcommand':
        return const MeshCommandLauncher();
      case 'calculator':
        return const CalculatorScreen();
      case 'clock':
        return const ClockScreen();
      case 'audio':
        return const AudioControlScreen();
      case 'screenshot':
        return const ScreenshotScreen();
      case 'calendar':
        return const CalendarScreen();
      case 'monitors':
        return const MonitorsSettingsScreen();
      case 'adv_monitor':
        return const AdvancedMonitorScreen();
      case 'installer':
      case 'app_store':
        return const AppInstallerScreen();
      case 'storage':
        return const StorageAnalyzerScreen();
      case 'speedtest':
        return const SpeedTestScreen();
      case 'maintenance':
        return const MaintenanceScreen();
      default:
        return const SizedBox.shrink();
    }
  }
}
