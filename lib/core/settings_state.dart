import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/shell_accent.dart';

int accentColorArgb32(Color c) {
  final a = (c.a * 255).round().clamp(0, 255);
  final r = (c.r * 255).round().clamp(0, 255);
  final g = (c.g * 255).round().clamp(0, 255);
  final b = (c.b * 255).round().clamp(0, 255);
  return (a << 24) | (r << 16) | (g << 8) | b;
}

class SettingsState extends ChangeNotifier {
  // -
  // DISPLAY SETTINGS
  // -
  
  // Resolution
  String _resolution = '1920x1080';
  String get resolution => _resolution;
  void setResolution(String value) {
    _resolution = value;
    notifyListeners();
    _save();
  }

  // Refresh Rate
  int _refreshRate = 60;
  int get refreshRate => _refreshRate;
  void setRefreshRate(int value) {
    _refreshRate = value;
    notifyListeners();
    _save();
  }

  // Scaling
  double _scaling = 100.0;
  double get scaling => _scaling;
  void setScaling(double value) {
    _scaling = value;
    notifyListeners();
    _save();
  }

  // Night Light
  bool _nightLightEnabled = false;
  bool get nightLightEnabled => _nightLightEnabled;
  void toggleNightLight() {
    _nightLightEnabled = !_nightLightEnabled;
    notifyListeners();
    _save();
  }

  int _nightLightTemp = 4500;
  int get nightLightTemp => _nightLightTemp;
  void setNightLightTemp(int value) {
    _nightLightTemp = value;
    notifyListeners();
    _save();
  }

  TimeOfDay _nightLightStart = const TimeOfDay(hour: 20, minute: 0);
  TimeOfDay get nightLightStart => _nightLightStart;
  void setNightLightStart(TimeOfDay value) {
    _nightLightStart = value;
    notifyListeners();
    _save();
  }

  TimeOfDay _nightLightEnd = const TimeOfDay(hour: 6, minute: 0);
  TimeOfDay get nightLightEnd => _nightLightEnd;
  void setNightLightEnd(TimeOfDay value) {
    _nightLightEnd = value;
    notifyListeners();
    _save();
  }

  // HDR
  bool _hdrEnabled = false;
  bool get hdrEnabled => _hdrEnabled;
  void toggleHDR() {
    _hdrEnabled = !_hdrEnabled;
    notifyListeners();
    _save();
  }

  // Font Settings
  double _fontSize = 14.0;
  double get fontSize => _fontSize;
  void setFontSize(double value) {
    _fontSize = value;
    notifyListeners();
    _save();
  }

  String _fontFamily = 'System Default';
  String get fontFamily => _fontFamily;
  void setFontFamily(String value) {
    _fontFamily = value;
    notifyListeners();
    _save();
  }

  // Desktop shortcuts (Explorer-style icon size).
  double _desktopIconSize = 56;
  double get desktopIconSize => _desktopIconSize;
  void setDesktopIconSize(double value) {
    final v = value.clamp(32.0, 96.0);
    final changed = v != _desktopIconSize;
    _desktopIconSize = v;
    notifyListeners();
    if (changed) _save();
  }

  bool effectiveNightLightNow([DateTime? now]) {
    if (!_nightLightEnabled) return false;
    final dt = now ?? DateTime.now();
    final cur = dt.hour * 60 + dt.minute;
    int m(TimeOfDay t) => t.hour * 60 + t.minute;
    final s = m(_nightLightStart);
    final e = m(_nightLightEnd);
    if (s <= e) {
      return cur >= s && cur < e;
    }
    return cur >= s || cur < e;
  }

  // -
  // PERSONALIZATION SETTINGS
  // -
  
  // Wallpaper
  String _wallpaper = 'gradient_1';
  String get wallpaper => _wallpaper;

  String? _wallpaperCustomB64;
  String? _lockScreenCustomB64;

  bool get hasCustomDesktopWallpaper =>
      _wallpaperCustomB64 != null && _wallpaperCustomB64!.isNotEmpty;
  bool get hasCustomLockWallpaper =>
      _lockScreenCustomB64 != null && _lockScreenCustomB64!.isNotEmpty;

  Uint8List? get desktopWallpaperBytes =>
      hasCustomDesktopWallpaper ? base64Decode(_wallpaperCustomB64!) : null;
  Uint8List? get lockWallpaperBytes =>
      hasCustomLockWallpaper ? base64Decode(_lockScreenCustomB64!) : null;

  static bool isValidPngOrJpeg(Uint8List b) {
    if (b.length < 3) return false;
    if (b[0] == 0xFF && b[1] == 0xD8 && b[2] == 0xFF) return true;
    if (b.length >= 8 &&
        b[0] == 0x89 &&
        b[1] == 0x50 &&
        b[2] == 0x4E &&
        b[3] == 0x47 &&
        b[4] == 0x0D &&
        b[5] == 0x0A &&
        b[6] == 0x1A &&
        b[7] == 0x0A) {
      return true;
    }
    return false;
  }

  void setWallpaper(String value) {
    _wallpaper = value;
    _wallpaperCustomB64 = null;
    notifyListeners();
    _save();
  }

  void setDesktopWallpaperCustomBytes(Uint8List bytes) {
    if (!isValidPngOrJpeg(bytes)) return;
    if (bytes.length > 20 * 1024 * 1024) return;
    _wallpaperCustomB64 = base64Encode(bytes);
    _wallpaperSlideshow = false;
    notifyListeners();
    _save();
  }

  void clearCustomDesktopWallpaper() {
    _wallpaperCustomB64 = null;
    notifyListeners();
    _save();
  }

  String _wallpaperFit = 'fill';
  String get wallpaperFit => _wallpaperFit;
  void setWallpaperFit(String value) {
    _wallpaperFit = value;
    notifyListeners();
    _save();
  }

  bool _wallpaperSlideshow = false;
  bool get wallpaperSlideshow => _wallpaperSlideshow;
  void toggleWallpaperSlideshow() {
    _wallpaperSlideshow = !_wallpaperSlideshow;
    if (_wallpaperSlideshow) {
      _wallpaperCustomB64 = null;
    }
    notifyListeners();
    _save();
  }

  int _slideshowInterval = 30;
  int get slideshowInterval => _slideshowInterval;
  void setSlideshowInterval(int value) {
    _slideshowInterval = value;
    notifyListeners();
    _save();
  }

  // Theme
  String _themeMode = 'dark';
  String get themeMode => _themeMode;
  void setThemeMode(String value) {
    _themeMode = value;
    notifyListeners();
    _save();
  }

  /// Quick toggle for shell tiles: switches to explicit light or dark from current effective appearance.
  void toggleLightDarkTheme(Brightness platformBrightness) {
    setThemeMode(
      isEffectivelyDark(platformBrightness) ? 'light' : 'dark',
    );
  }

  /// Resolves shell brightness for `light` / `dark` / `auto` (follows platform when auto).
  bool isEffectivelyDark(Brightness platformBrightness) {
    switch (_themeMode) {
      case 'light':
        return false;
      case 'dark':
        return true;
      default:
        return platformBrightness == Brightness.dark;
    }
  }

  // Accent Color
  Color _accentColor = kShellDefaultAccent;
  Color get accentColor => _accentColor;
  void setAccentColor(Color value) {
    _accentColor = value;
    notifyListeners();
    _save();
  }

  // -
  // ACCESSIBILITY
  // -

  bool _a11yReduceMotion = false;
  bool get a11yReduceMotion => _a11yReduceMotion;
  void setA11yReduceMotion(bool v) {
    _a11yReduceMotion = v;
  // Reduce motion should also disable cosmetic animations in the shell.
    if (v) _animations = false;
    notifyListeners();
    _save();
  }

  bool _a11yHighContrast = false;
  bool get a11yHighContrast => _a11yHighContrast;
  void setA11yHighContrast(bool v) {
    _a11yHighContrast = v;
    notifyListeners();
    _save();
  }

  bool _a11yBoldText = false;
  bool get a11yBoldText => _a11yBoldText;
  void setA11yBoldText(bool v) {
    _a11yBoldText = v;
    notifyListeners();
    _save();
  }

  bool _a11yAccessibleNavigation = false;
  bool get a11yAccessibleNavigation => _a11yAccessibleNavigation;
  void setA11yAccessibleNavigation(bool v) {
    _a11yAccessibleNavigation = v;
  // In accessible navigation mode, also reduce motion.
    if (v) _a11yReduceMotion = true;
    notifyListeners();
    _save();
  }

  // Transparency
  double _windowTransparency = 0.95;
  double get windowTransparency => _windowTransparency;
  void setWindowTransparency(double value) {
    _windowTransparency = value;
    notifyListeners();
    _save();
  }

  double _taskbarTransparency = 0.90;
  double get taskbarTransparency => _taskbarTransparency;
  void setTaskbarTransparency(double value) {
    _taskbarTransparency = value;
    notifyListeners();
    _save();
  }

  // Blur Effects
  bool _blurEffects = true;
  bool get blurEffects => _blurEffects;
  void toggleBlurEffects() {
    _blurEffects = !_blurEffects;
    notifyListeners();
    _save();
  }

  // Animations
  bool _animations = true;
  bool get animations => _animations;
  void toggleAnimations() {
    _animations = !_animations;
    notifyListeners();
    _save();
  }

  // Lock Screen
  String _lockScreenWallpaper = 'gradient_2';
  String get lockScreenWallpaper => _lockScreenWallpaper;
  void setLockScreenWallpaper(String value) {
    _lockScreenWallpaper = value;
    _lockScreenCustomB64 = null;
    notifyListeners();
    _save();
  }

  void setLockWallpaperCustomBytes(Uint8List bytes) {
    if (!isValidPngOrJpeg(bytes)) return;
    if (bytes.length > 20 * 1024 * 1024) return;
    _lockScreenCustomB64 = base64Encode(bytes);
    notifyListeners();
    _save();
  }

  void clearCustomLockWallpaper() {
    _lockScreenCustomB64 = null;
    notifyListeners();
    _save();
  }

  bool _lockScreenBlur = true;
  bool get lockScreenBlur => _lockScreenBlur;
  void toggleLockScreenBlur() {
    _lockScreenBlur = !_lockScreenBlur;
    notifyListeners();
    _save();
  }

  // -
  // NETWORK SETTINGS
  // -
  
  // VPN
  List<Map<String, dynamic>> _vpnServers = [
    {'name': 'US East', 'location': 'New York', 'ping': 45, 'load': 35, 'connected': false},
    {'name': 'US West', 'location': 'Los Angeles', 'ping': 78, 'load': 52, 'connected': false},
    {'name': 'EU Central', 'location': 'Frankfurt', 'ping': 120, 'load': 28, 'connected': false},
    {'name': 'Asia Pacific', 'location': 'Singapore', 'ping': 180, 'load': 45, 'connected': false},
  ];
  List<Map<String, dynamic>> get vpnServers => List.unmodifiable(_vpnServers);

  void connectVPN(String name) {
    for (var server in _vpnServers) {
      server['connected'] = server['name'] == name;
    }
    notifyListeners();
  }

  void disconnectVPN() {
    for (var server in _vpnServers) {
      server['connected'] = false;
    }
    notifyListeners();
  }

  // Firewall Rules
  List<Map<String, dynamic>> _firewallRules = [
    {'name': 'Block Incoming', 'type': 'Inbound', 'action': 'Block', 'enabled': true},
    {'name': 'Allow HTTP/HTTPS', 'type': 'Outbound', 'action': 'Allow', 'enabled': true},
    {'name': 'Block Telemetry', 'type': 'Outbound', 'action': 'Block', 'enabled': true},
  ];
  List<Map<String, dynamic>> get firewallRules => List.unmodifiable(_firewallRules);

  void toggleFirewallRule(int index) {
    _firewallRules[index]['enabled'] = !_firewallRules[index]['enabled'];
    notifyListeners();
    _save();
  }

  void addFirewallRule(String name, String type, String action) {
    _firewallRules.add({
      'name': name,
      'type': type,
      'action': action,
      'enabled': true,
    });
    notifyListeners();
    _save();
  }

  void removeFirewallRule(int index) {
    _firewallRules.removeAt(index);
    notifyListeners();
    _save();
  }

  // DNS
  String _dnsMode = 'automatic';
  String get dnsMode => _dnsMode;
  void setDNSMode(String value) {
    _dnsMode = value;
    notifyListeners();
    _save();
  }

  String _primaryDNS = '8.8.8.8';
  String get primaryDNS => _primaryDNS;
  void setPrimaryDNS(String value) {
    _primaryDNS = value;
    notifyListeners();
    _save();
  }

  String _secondaryDNS = '8.8.4.4';
  String get secondaryDNS => _secondaryDNS;
  void setSecondaryDNS(String value) {
    _secondaryDNS = value;
    notifyListeners();
    _save();
  }

  // Proxy
  bool _proxyEnabled = false;
  bool get proxyEnabled => _proxyEnabled;
  void toggleProxy() {
    _proxyEnabled = !_proxyEnabled;
    notifyListeners();
    _save();
  }

  String _proxyAddress = '';
  String get proxyAddress => _proxyAddress;
  void setProxyAddress(String value) {
    _proxyAddress = value;
    notifyListeners();
    _save();
  }

  String _proxyPort = '8080';
  String get proxyPort => _proxyPort;
  void setProxyPort(String value) {
    _proxyPort = value;
    notifyListeners();
    _save();
  }

  // -
  // APPS SETTINGS
  // -
  
  List<Map<String, dynamic>> _installedApps = [
    {'name': 'Files', 'icon': 'folder', 'size': '45 MB', 'installed': true},
    {'name': 'Terminal', 'icon': 'terminal', 'size': '12 MB', 'installed': true},
    {'name': 'Settings', 'icon': 'settings', 'size': '8 MB', 'installed': true},
    {'name': 'Browser', 'icon': 'web', 'size': '120 MB', 'installed': true},
    {'name': 'Calculator', 'icon': 'calculate', 'size': '5 MB', 'installed': true},
  ];
  List<Map<String, dynamic>> get installedApps => List.unmodifiable(_installedApps);

  void uninstallApp(int index) {
    _installedApps[index]['installed'] = false;
    notifyListeners();
    _save();
  }

  // Default Apps
  Map<String, String> _defaultApps = {
    'Browser': 'KrdOS Browser',
    'Email': 'Mail',
    'Music': 'Music Player',
    'Video': 'Video Player',
    'Photos': 'Photos',
    'Files': 'File Manager',
  };
  Map<String, String> get defaultApps => Map.unmodifiable(_defaultApps);

  void setDefaultApp(String category, String app) {
    _defaultApps[category] = app;
    notifyListeners();
    _save();
  }

  // Startup Apps
  List<Map<String, dynamic>> _startupApps = [
    {'name': 'Security Monitor', 'enabled': true},
    {'name': 'Cloud Sync', 'enabled': false},
    {'name': 'Update Service', 'enabled': true},
  ];
  List<Map<String, dynamic>> get startupApps => List.unmodifiable(_startupApps);

  void toggleStartupApp(int index) {
    _startupApps[index]['enabled'] = !_startupApps[index]['enabled'];
    notifyListeners();
    _save();
  }

  // -
  // PERSISTENCE
  // -
  
  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    
  // Display
    _resolution = prefs.getString('resolution') ?? '1920x1080';
    _refreshRate = prefs.getInt('refreshRate') ?? 60;
    _scaling = prefs.getDouble('scaling') ?? 100.0;
    _nightLightEnabled = prefs.getBool('nightLightEnabled') ?? false;
    _nightLightTemp = prefs.getInt('nightLightTemp') ?? 4500;
    _hdrEnabled = prefs.getBool('hdrEnabled') ?? false;
    _fontSize = prefs.getDouble('fontSize') ?? 14.0;
    _fontFamily = prefs.getString('fontFamily') ?? 'System Default';
    _desktopIconSize = prefs.getDouble('desktopIconSize') ?? 56.0;

    _nightLightStart = TimeOfDay(
      hour: prefs.getInt('nightLightStartH') ?? 20,
      minute: prefs.getInt('nightLightStartM') ?? 0,
    );
    _nightLightEnd = TimeOfDay(
      hour: prefs.getInt('nightLightEndH') ?? 6,
      minute: prefs.getInt('nightLightEndM') ?? 0,
    );

  // Personalization
    _wallpaper = prefs.getString('wallpaper') ?? 'gradient_1';
    _wallpaperFit = prefs.getString('wallpaperFit') ?? 'fill';
    _wallpaperSlideshow = prefs.getBool('wallpaperSlideshow') ?? false;
    _slideshowInterval = prefs.getInt('slideshowInterval') ?? 30;
    _themeMode = prefs.getString('themeMode') ?? 'dark';
    final accentValue =
        prefs.getInt('accentColor') ?? accentColorArgb32(kShellDefaultAccent);
    _accentColor = Color(accentValue);
    _windowTransparency = prefs.getDouble('windowTransparency') ?? 0.95;
    _taskbarTransparency = prefs.getDouble('taskbarTransparency') ?? 0.90;
    _blurEffects = prefs.getBool('blurEffects') ?? true;
    _animations = prefs.getBool('animations') ?? true;
    _lockScreenWallpaper = prefs.getString('lockScreenWallpaper') ?? 'gradient_2';
    _lockScreenBlur = prefs.getBool('lockScreenBlur') ?? true;

  // Accessibility
    _a11yReduceMotion = prefs.getBool('a11y_reduceMotion') ?? false;
    _a11yHighContrast = prefs.getBool('a11y_highContrast') ?? false;
    _a11yBoldText = prefs.getBool('a11y_boldText') ?? false;
    _a11yAccessibleNavigation = prefs.getBool('a11y_accessibleNavigation') ?? false;
  // Derived behavior
    if (_a11yAccessibleNavigation) _a11yReduceMotion = true;
    if (_a11yReduceMotion) _animations = false;
    
  // Network
    _dnsMode = prefs.getString('dnsMode') ?? 'automatic';
    _primaryDNS = prefs.getString('primaryDNS') ?? '8.8.8.8';
    _secondaryDNS = prefs.getString('secondaryDNS') ?? '8.8.4.4';
    _proxyEnabled = prefs.getBool('proxyEnabled') ?? false;
    _proxyAddress = prefs.getString('proxyAddress') ?? '';
    _proxyPort = prefs.getString('proxyPort') ?? '8080';
    
    notifyListeners();
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    
  // Display
    await prefs.setString('resolution', _resolution);
    await prefs.setInt('refreshRate', _refreshRate);
    await prefs.setDouble('scaling', _scaling);
    await prefs.setBool('nightLightEnabled', _nightLightEnabled);
    await prefs.setInt('nightLightTemp', _nightLightTemp);
    await prefs.setBool('hdrEnabled', _hdrEnabled);
    await prefs.setDouble('fontSize', _fontSize);
    await prefs.setString('fontFamily', _fontFamily);
    await prefs.setDouble('desktopIconSize', _desktopIconSize);
    await prefs.setInt('nightLightStartH', _nightLightStart.hour);
    await prefs.setInt('nightLightStartM', _nightLightStart.minute);
    await prefs.setInt('nightLightEndH', _nightLightEnd.hour);
    await prefs.setInt('nightLightEndM', _nightLightEnd.minute);
    
  // Personalization
    await prefs.setString('wallpaper', _wallpaper);
    await prefs.setString('wallpaperFit', _wallpaperFit);
    await prefs.setBool('wallpaperSlideshow', _wallpaperSlideshow);
    await prefs.setInt('slideshowInterval', _slideshowInterval);
    await prefs.setString('themeMode', _themeMode);
    await prefs.setInt('accentColor', accentColorArgb32(_accentColor));
    await prefs.setDouble('windowTransparency', _windowTransparency);
    await prefs.setDouble('taskbarTransparency', _taskbarTransparency);
    await prefs.setBool('blurEffects', _blurEffects);
    await prefs.setBool('animations', _animations);
    await prefs.setString('lockScreenWallpaper', _lockScreenWallpaper);
    await prefs.setBool('lockScreenBlur', _lockScreenBlur);
    if (_wallpaperCustomB64 != null) {
      await prefs.setString('wallpaper_custom_b64', _wallpaperCustomB64!);
    } else {
      await prefs.remove('wallpaper_custom_b64');
    }
    if (_lockScreenCustomB64 != null) {
      await prefs.setString('lock_screen_custom_b64', _lockScreenCustomB64!);
    } else {
      await prefs.remove('lock_screen_custom_b64');
    }

  // Accessibility
    await prefs.setBool('a11y_reduceMotion', _a11yReduceMotion);
    await prefs.setBool('a11y_highContrast', _a11yHighContrast);
    await prefs.setBool('a11y_boldText', _a11yBoldText);
    await prefs.setBool('a11y_accessibleNavigation', _a11yAccessibleNavigation);
    
  // Network
    await prefs.setString('dnsMode', _dnsMode);
    await prefs.setString('primaryDNS', _primaryDNS);
    await prefs.setString('secondaryDNS', _secondaryDNS);
    await prefs.setBool('proxyEnabled', _proxyEnabled);
    await prefs.setString('proxyAddress', _proxyAddress);
    await prefs.setString('proxyPort', _proxyPort);
  }
}