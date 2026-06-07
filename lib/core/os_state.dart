import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'shell/app_catalog.dart';
import 'platform/system_bridge.dart';

enum DeviceType { mobile, tablet, laptop }
enum UserRole   { admin, powerUser, user }
enum NotifType  { system, security, network, warning }
enum TaskbarPosition { bottom, top, left, right }
enum TaskbarAlignment { left, center, right }

class OsNotification {
  final String id;
  final String title;
  final String body;
  final NotifType type;
  final DateTime time;
  bool read;

  OsNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    required this.time,
    this.read = false,
  });
}

class OsState extends ChangeNotifier {
  // Default is USER ? admin only granted via wired connection to admin device
  UserRole _role = UserRole.user;
  UserRole get role => _role;

  // Admin grant via wired connection (USB/direct)
  bool _wiredAdminConnected = false;
  bool get wiredAdminConnected => _wiredAdminConnected;
  void connectWiredAdmin(String authCode) {
  // In production this verifies a cryptographic challenge from the admin device
    if (authCode == 'ADMIN-WIRE-AUTH') {
      _role = UserRole.admin;
      _wiredAdminConnected = true;
      addNotification('Admin Access', 'Admin role granted via wired connection', NotifType.security);
      notifyListeners();
    }
  }
  void disconnectAdmin() {
    _role = UserRole.user;
    _wiredAdminConnected = false;
    addNotification('Admin Access', 'Admin role revoked ? device is now USER', NotifType.security);
    notifyListeners();
  }

  // - Device Type -
  DeviceType _deviceType = DeviceType.laptop;
  DeviceType get deviceType => _deviceType;
  void setDeviceType(double width) {
    _deviceType = width >= 1100 ? DeviceType.laptop
        : width >= 600 ? DeviceType.tablet
        : DeviceType.mobile;
    notifyListeners();
  }

  // - Lock Screen -
  bool _isLocked = true;
  bool get isLocked => _isLocked;
  void lock() { _isLocked = true; notifyListeners(); }
  void unlock() { _isLocked = false; notifyListeners(); }

  // - Display sleep (shell dims session; not full OS suspend) -
  bool _displaySleep = false;
  bool get displaySleep => _displaySleep;
  void enterDisplaySleep() {
    _displaySleep = true;
    notifyListeners();
  }

  void wakeFromDisplaySleep() {
    _displaySleep = false;
    notifyListeners();
  }

  // - Overlays -
  bool _isControlCenterOpen = false;
  bool get isControlCenterOpen => _isControlCenterOpen;
  void toggleControlCenter() { _isControlCenterOpen = !_isControlCenterOpen; _isStartMenuOpen = false; notifyListeners(); }

  bool _isStartMenuOpen = false;
  bool get isStartMenuOpen => _isStartMenuOpen;
  void toggleStartMenu() { _isStartMenuOpen = !_isStartMenuOpen; _isControlCenterOpen = false; notifyListeners(); }

  // - Admin Wire -
  bool _isWiredToAdmin = false;
  bool get isWiredToAdmin => _isWiredToAdmin;
  bool get hasAdminPermissions => _role == UserRole.admin;
  void toggleAdminWire() {
    if (_isWiredToAdmin) { disconnectAdmin(); _isWiredToAdmin = false; notifyListeners(); }
    else { connectWiredAdmin('ADMIN-WIRE-AUTH'); _isWiredToAdmin = _wiredAdminConnected; }
  }

  // - System -
  double _brightness = 1.0;
  double get brightness => _brightness;
  void setBrightness(double v) {
    _brightness = v;
    notifyListeners();
    _save();
    SystemBridge.setBrightness((v * 100).round());
  }

  double _volume = 0.7;
  double get volume => _volume;
  void setVolume(double v) {
    _volume = v;
    notifyListeners();
    _save();
    SystemBridge.audioSetVolume((v * 100).round());
  }

  bool _wifiEnabled = true;
  bool get wifiEnabled => _wifiEnabled;
  void toggleWifi() {
    _wifiEnabled = !_wifiEnabled;
    notifyListeners();
    _save();
    if (_wifiEnabled) {
      SystemBridge.wifiEnable();
    } else {
      SystemBridge.wifiDisable();
    }
  }

  bool _vpnEnabled = false;
  bool get vpnEnabled => _vpnEnabled;
  void toggleVpn() { _vpnEnabled = !_vpnEnabled; _addNotif(OsNotification(
    id: DateTime.now().toIso8601String(),
    title: 'VPN',
    body: _vpnEnabled ? 'VPN disconnected' : 'VPN connected ? traffic encrypted',
    type: NotifType.security,
    time: DateTime.now(),
  )); notifyListeners(); _save(); }

  bool _firewallEnabled = true;
  bool get firewallEnabled => _firewallEnabled;
  void toggleFirewall() { _firewallEnabled = !_firewallEnabled; notifyListeners(); _save(); }

  bool _ipMasked = true;
  bool get ipMasked => _ipMasked;
  void toggleIpMask() { _ipMasked = !_ipMasked; notifyListeners(); _save(); }

  bool _soundAlerts = true;
  bool get soundAlerts => _soundAlerts;
  void toggleSoundAlerts() { _soundAlerts = !_soundAlerts; notifyListeners(); _save(); }

  bool _uiSounds = true;
  bool get uiSounds => _uiSounds;
  void toggleUiSounds() { _uiSounds = !_uiSounds; notifyListeners(); _save(); }

  bool _doNotDisturb = false;
  bool get doNotDisturb => _doNotDisturb;
  void toggleDoNotDisturb() { _doNotDisturb = !_doNotDisturb; notifyListeners(); _save(); }

  // - Settings -
  bool _isSettingsOpen = false;
  bool get isSettingsOpen => _isSettingsOpen;
  void toggleSettings() { _isSettingsOpen = !_isSettingsOpen; notifyListeners(); }

  // - Taskbar Settings -
  TaskbarPosition _taskbarPosition = TaskbarPosition.bottom;
  TaskbarPosition get taskbarPosition => _taskbarPosition;
  void setTaskbarPosition(TaskbarPosition pos) { _taskbarPosition = pos; notifyListeners(); _save(); }

  TaskbarAlignment _taskbarAlign = TaskbarAlignment.center;
  TaskbarAlignment get taskbarAlign => _taskbarAlign;
  void setTaskbarAlign(TaskbarAlignment align) { _taskbarAlign = align; notifyListeners(); _save(); }

  double _taskbarIconSize = 26.0;
  double get taskbarIconSize => _taskbarIconSize;
  void setTaskbarIconSize(double size) { _taskbarIconSize = size; notifyListeners(); _save(); }

  bool _taskbarAutoHide = false;
  bool get taskbarAutoHide => _taskbarAutoHide;
  void toggleTaskbarAutoHide() { _taskbarAutoHide = !_taskbarAutoHide; notifyListeners(); _save(); }

  bool _showTaskbarLabels = false;
  bool get showTaskbarLabels => _showTaskbarLabels;
  void toggleTaskbarLabels() { _showTaskbarLabels = !_showTaskbarLabels; notifyListeners(); _save(); }

  double _taskbarSize = 64.0;
  double get taskbarSize => _taskbarSize;
  void setTaskbarSize(double size) { _taskbarSize = size; notifyListeners(); _save(); }

  double _taskbarOpacity = 0.95;
  double get taskbarOpacity => _taskbarOpacity;
  void setTaskbarOpacity(double opacity) { _taskbarOpacity = opacity; notifyListeners(); _save(); }

  /// Legacy key `pinnedApps` ? kept for compatibility; shell pins live in [DockSettings].
  List<String> _pinnedApps = List<String>.from(ShellAppRegistry.defaultPinnedIds);
  List<String> get pinnedApps => List.unmodifiable(_pinnedApps);
  void addPinnedApp(String app) { if (!_pinnedApps.contains(app)) { _pinnedApps.add(app); notifyListeners(); _save(); } }
  void removePinnedApp(String app) { _pinnedApps.remove(app); notifyListeners(); _save(); }
  void reorderPinnedApps(int oldIndex, int newIndex) {
    if (newIndex > oldIndex) newIndex--;
    final app = _pinnedApps.removeAt(oldIndex);
    _pinnedApps.insert(newIndex, app);
    notifyListeners();
    _save();
  }

  // - WiFi Networks -
  String _connectedWifi = '';
  String get connectedWifi => _connectedWifi;
  int _connectedWifiSignal = 0;
  int get connectedWifiSignal => _connectedWifiSignal;
  String _connectedWifiIp = '';
  String get connectedWifiIp => _connectedWifiIp;
  bool _scanningWifi = false;
  bool get scanningWifi => _scanningWifi;

  final List<Map<String, dynamic>> _wifiNetworks = [];
  List<Map<String, dynamic>> get wifiNetworks => List.unmodifiable(_wifiNetworks);

  Future<void> scanWifi() async {
    _scanningWifi = true;
    notifyListeners();
    try {
      final results = await SystemBridge.wifiScan();
      _wifiNetworks.clear();
      _wifiNetworks.addAll(results);
      // Refresh current connection info
      final cur = await SystemBridge.wifiCurrent();
      _connectedWifi = (cur['ssid'] as String?) ?? '';
      _connectedWifiSignal = (cur['signal'] as int?) ?? 0;
      _connectedWifiIp = (cur['ip'] as String?) ?? '';
    } catch (_) {
      // Keep existing list on error
    }
    _scanningWifi = false;
    notifyListeners();
  }

  Future<void> connectWifi(String ssid, {String password = ''}) async {
    final ok = await SystemBridge.wifiConnect(ssid, password: password);
    if (ok) {
      // Update connected flags in list
      for (final n in _wifiNetworks) n['connected'] = n['ssid'] == ssid;
      _connectedWifi = ssid;
      addNotification('WiFi', 'Connected to $ssid', NotifType.network);
      notifyListeners();
    } else {
      addNotification('WiFi', 'Failed to connect to $ssid', NotifType.warning);
    }
  }

  Future<void> disconnectWifi() async {
    await SystemBridge.wifiDisconnectNetwork();
    for (final n in _wifiNetworks) n['connected'] = false;
    final prev = _connectedWifi;
    _connectedWifi = '';
    _connectedWifiSignal = 0;
    _connectedWifiIp = '';
    if (prev.isNotEmpty) addNotification('WiFi', 'Disconnected from $prev', NotifType.network);
    notifyListeners();
  }

  // - Bluetooth -
  bool _bluetoothEnabled = false;
  bool get bluetoothEnabled => _bluetoothEnabled;
  void toggleBluetooth() {
    _bluetoothEnabled = !_bluetoothEnabled;
    notifyListeners();
    _save();
    if (_bluetoothEnabled) {
      // Enable BT stack, then wait for it to power on before refreshing device list
      SystemBridge.bluetoothEnable().then((_) async {
        await Future.delayed(const Duration(seconds: 2));
        await refreshBluetoothDevices();
      });
    } else {
      SystemBridge.bluetoothDisable();
      _btDevices.clear();
      notifyListeners();
    }
  }

  // - Microphone kill switch -
  bool _micEnabled = true;
  bool get micEnabled => _micEnabled;
  void toggleMic() {
    _micEnabled = !_micEnabled;
    notifyListeners();
    _save();
    if (_micEnabled) {
      SystemBridge.micUnmute();
    } else {
      SystemBridge.micMute();
    }
  }

  // - Camera kill switch -
  bool _cameraEnabled = true;
  bool get cameraEnabled => _cameraEnabled;
  void toggleCamera() {
    _cameraEnabled = !_cameraEnabled;
    notifyListeners();
    _save();
    if (_cameraEnabled) {
      SystemBridge.cameraEnable();
    } else {
      SystemBridge.cameraDisable();
    }
  }

  final List<Map<String, dynamic>> _btDevices = [];
  List<Map<String, dynamic>> get btDevices => List.unmodifiable(_btDevices);
  bool _scanningBluetooth = false;
  bool get scanningBluetooth => _scanningBluetooth;

  /// Refresh paired/connected device list (fast — no scan).
  Future<void> refreshBluetoothDevices() async {
    try {
      final results = await SystemBridge.bluetoothList();
      _btDevices.clear();
      _btDevices.addAll(results);
      notifyListeners();
    } catch (_) {}
  }

  /// Active scan for nearby devices (~8 seconds), then refresh list.
  Future<void> scanBluetooth() async {
    _scanningBluetooth = true;
    notifyListeners();
    try {
      final results = await SystemBridge.bluetoothScan();
      _btDevices.clear();
      _btDevices.addAll(results);
    } catch (_) {}
    _scanningBluetooth = false;
    notifyListeners();
  }

  Future<void> connectBluetooth(String mac) async {
    final ok = await SystemBridge.bluetoothConnectDevice(mac);
    if (ok) {
      for (final d in _btDevices) {
        if (d['mac'] == mac) { d['connected'] = true; d['paired'] = true; }
      }
      final name = _btDevices.firstWhere((d) => d['mac'] == mac, orElse: () => {'name': mac})['name'] as String;
      addNotification('Bluetooth', 'Connected to $name', NotifType.network);
      notifyListeners();
    }
  }

  Future<void> disconnectBluetooth(String mac) async {
    await SystemBridge.bluetoothDisconnectDevice(mac);
    for (final d in _btDevices) {
      if (d['mac'] == mac) d['connected'] = false;
    }
    notifyListeners();
  }

  Future<void> pairBluetooth(String mac) async {
    final ok = await SystemBridge.bluetoothPair(mac);
    if (ok) {
      for (final d in _btDevices) {
        if (d['mac'] == mac) d['paired'] = true;
      }
      notifyListeners();
    }
  }

  // - Battery -
  int _batteryLevel = -1;
  bool _batteryCharging = false;
  bool _hasBattery = false;
  String _batteryStatus = 'AC';
  int get batteryLevel => _batteryLevel;
  bool get batteryCharging => _batteryCharging;
  bool get hasBattery => _hasBattery;
  String get batteryStatusText => _batteryStatus;

  Timer? _batteryTimer;

  Future<void> _pollBattery() async {
    try {
      final info = await SystemBridge.batteryStatus();
      _batteryLevel = (info['level'] as int?) ?? -1;
      _batteryCharging = (info['charging'] as bool?) ?? false;
      _hasBattery = (info['has_battery'] as bool?) ?? false;
      _batteryStatus = (info['status'] as String?) ?? 'AC';
      notifyListeners();
    } catch (_) {}
  }

  void startBatteryPolling() {
    _pollBattery();
    _batteryTimer = Timer.periodic(const Duration(seconds: 30), (_) => _pollBattery());
  }

  void stopBatteryPolling() {
    _batteryTimer?.cancel();
    _batteryTimer = null;
  }

  // - Notifications -
  final List<OsNotification> _notifications = [
    OsNotification(id: '1', title: 'System', body: 'All services running normally', type: NotifType.system, time: DateTime.now()),
    OsNotification(id: '2', title: 'Security', body: 'Firewall active ? 0 threats detected', type: NotifType.security, time: DateTime.now()),
    OsNotification(id: '3', title: 'Network', body: 'Connected ? IP masked', type: NotifType.network, time: DateTime.now()),
  ];

  List<OsNotification> get notifications => List.unmodifiable(_notifications);
  int get unreadCount => _notifications.where((n) => !n.read).length;

  void _addNotif(OsNotification n) { _notifications.insert(0, n); notifyListeners(); }

  void markAllRead() {
    for (final n in _notifications) n.read = true;
    notifyListeners();
  }

  void dismissNotif(String id) {
    _notifications.removeWhere((n) => n.id == id);
    notifyListeners();
  }

  void addNotification(String title, String body, NotifType type) {
    _addNotif(OsNotification(
      id: DateTime.now().toIso8601String(),
      title: title, body: body, type: type,
      time: DateTime.now(),
    ));
  }

  // - Lifecycle -
  @override
  void dispose() {
    stopBatteryPolling();
    super.dispose();
  }

  // - Persistence -
  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    _brightness     = p.getDouble('brightness')    ?? 1.0;
    _volume         = p.getDouble('volume')         ?? 0.7;
    _wifiEnabled    = p.getBool('wifi')             ?? true;
    _micEnabled     = p.getBool('mic')              ?? true;
    _cameraEnabled  = p.getBool('camera')           ?? true;
    _vpnEnabled     = p.getBool('vpn')              ?? false;
    _firewallEnabled= p.getBool('firewall')         ?? true;
    _ipMasked       = p.getBool('ipMasked')         ?? true;
    _soundAlerts    = p.getBool('soundAlerts')      ?? true;
    _uiSounds       = p.getBool('uiSounds')         ?? true;
    _doNotDisturb   = p.getBool('doNotDisturb')     ?? false;
    _taskbarIconSize = p.getDouble('taskbarIconSize') ?? 26.0;
    _taskbarSize    = p.getDouble('taskbarSize')    ?? 64.0;
    _taskbarOpacity = p.getDouble('taskbarOpacity') ?? 0.95;
    _taskbarAutoHide = p.getBool('taskbarAutoHide') ?? false;
    _showTaskbarLabels = p.getBool('showTaskbarLabels') ?? false;
    final posIndex = p.getInt('taskbarPosition') ?? 0;
    _taskbarPosition = TaskbarPosition.values[posIndex];
    final alignIndex = p.getInt('taskbarAlign') ?? 1;
    _taskbarAlign = TaskbarAlignment.values[alignIndex];
    final pinnedAppsStr = p.getStringList('pinnedApps');
    if (pinnedAppsStr != null) {
      _pinnedApps = pinnedAppsStr
          .where((id) => ShellAppRegistry.validPinIds.contains(id))
          .toList();
      if (_pinnedApps.isEmpty) {
        _pinnedApps = List<String>.from(ShellAppRegistry.defaultPinnedIds);
      }
    }
    notifyListeners();
    // Kick off real data polling after prefs load
    startBatteryPolling();
    scanWifi();
    if (_bluetoothEnabled) {
      // Re-enable BT hardware (rfkill + bluetoothctl) since it may have been off at boot
      SystemBridge.bluetoothEnable().then((_) async {
        await Future.delayed(const Duration(seconds: 2));
        await refreshBluetoothDevices();
      });
    }
  }

  Future<void> _save() async {
    final p = await SharedPreferences.getInstance();
    await p.setDouble('brightness',  _brightness);
    await p.setDouble('volume',      _volume);
    await p.setBool('wifi',          _wifiEnabled);
    await p.setBool('mic',           _micEnabled);
    await p.setBool('camera',        _cameraEnabled);
    await p.setBool('vpn',           _vpnEnabled);
    await p.setBool('firewall',      _firewallEnabled);
    await p.setBool('ipMasked',      _ipMasked);
    await p.setBool('soundAlerts',   _soundAlerts);
    await p.setBool('uiSounds',      _uiSounds);
    await p.setBool('doNotDisturb',  _doNotDisturb);
    await p.setDouble('taskbarIconSize', _taskbarIconSize);
    await p.setDouble('taskbarSize', _taskbarSize);
    await p.setDouble('taskbarOpacity', _taskbarOpacity);
    await p.setBool('taskbarAutoHide', _taskbarAutoHide);
    await p.setBool('showTaskbarLabels', _showTaskbarLabels);
    await p.setInt('taskbarPosition', _taskbarPosition.index);
    await p.setInt('taskbarAlign', _taskbarAlign.index);
    await p.setStringList('pinnedApps', _pinnedApps);
  }
}