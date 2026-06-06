import 'package:flutter/foundation.dart';
import 'device_model.dart';

class DeviceRegistry extends ChangeNotifier {
  bool _scanning = false;
  bool get scanning => _scanning;

  final List<ConnectedDevice> _devices = [
  // Simulated devices ? will be replaced with real discovery later
    ConnectedDevice(
      id: 'drone-001',
      name: 'Drone Alpha',
      category: DeviceCategory.drone,
      connectionType: ConnectionType.wifiDirect,
      status: DeviceStatus.online,
      accessLevel: AccessLevel.full,
      ipAddress: '192.168.4.1',
      signalStrength: 87,
      capabilities: {
        'camera': true, 'gps': true, 'telemetry': true,
        'control': true, 'stream': true,
      },
      firstSeen: DateTime.now().subtract(const Duration(days: 2)),
      lastSeen: DateTime.now(),
      trusted: true,
      accessToken: 'A3K9MXPQ2RVWZ7TNBCDE8FG',
    ),
    ConnectedDevice(
      id: 'cam-001',
      name: 'Security Cam 01',
      category: DeviceCategory.camera,
      connectionType: ConnectionType.wifi,
      status: DeviceStatus.online,
      accessLevel: AccessLevel.readOnly,
      ipAddress: '192.168.1.45',
      signalStrength: 92,
      capabilities: {'stream': true, 'record': true, 'ptz': false},
      firstSeen: DateTime.now().subtract(const Duration(days: 5)),
      lastSeen: DateTime.now(),
      trusted: true,
      accessToken: 'B7YH3NKQP1MXWZ4RVCE9TFG',
    ),
    ConnectedDevice(
      id: 'robot-001',
      name: 'Ground Unit 01',
      category: DeviceCategory.robot,
      connectionType: ConnectionType.rf,
      status: DeviceStatus.offline,
      accessLevel: AccessLevel.none,
      signalStrength: 0,
      capabilities: {'control': true, 'camera': true, 'arm': true},
      firstSeen: DateTime.now().subtract(const Duration(hours: 3)),
      lastSeen: DateTime.now().subtract(const Duration(hours: 1)),
      trusted: true,
    ),
    ConnectedDevice(
      id: 'gps-001',
      name: 'GPS Tracker 01',
      category: DeviceCategory.gps,
      connectionType: ConnectionType.bluetooth,
      status: DeviceStatus.online,
      accessLevel: AccessLevel.readOnly,
      signalStrength: 74,
      capabilities: {'location': true, 'history': true},
      firstSeen: DateTime.now().subtract(const Duration(days: 1)),
      lastSeen: DateTime.now(),
      trusted: true,
      accessToken: 'C2ZX8PLMQ5RVWK9TNBDE3FGH',
    ),
    ConnectedDevice(
      id: 'unknown-001',
      name: 'Unknown Device',
      category: DeviceCategory.unknown,
      connectionType: ConnectionType.wifi,
      status: DeviceStatus.pairing,
      accessLevel: AccessLevel.none,
      ipAddress: '192.168.1.99',
      signalStrength: 45,
      capabilities: {},
      firstSeen: DateTime.now().subtract(const Duration(minutes: 5)),
      lastSeen: DateTime.now(),
      trusted: false,
    ),
  ];

  List<ConnectedDevice> get devices => List.unmodifiable(_devices);

  List<ConnectedDevice> get trustedDevices   => _devices.where((d) => d.trusted).toList();
  List<ConnectedDevice> get onlineDevices    => _devices.where((d) => d.status == DeviceStatus.online).toList();
  List<ConnectedDevice> get pendingDevices   => _devices.where((d) => !d.trusted).toList();

  ConnectedDevice? getById(String id) {
    try { return _devices.firstWhere((d) => d.id == id); }
    catch (_) { return null; }
  }

  // - Scanning -
  Future<void> startScan() async {
    _scanning = true;
    notifyListeners();
    await Future.delayed(const Duration(seconds: 3));
    _scanning = false;
    notifyListeners();
  }

  // - Trust / Pair -
  String trustDevice(String id) {
    final d = getById(id);
    if (d == null) return '';
    d.trusted = true;
    d.accessToken = ConnectedDevice.generateToken();
    d.status = DeviceStatus.online;
    d.accessLevel = AccessLevel.limited;
    notifyListeners();
    return d.accessToken!;
  }

  void revokeDevice(String id) {
    final d = getById(id);
    if (d == null) return;
    d.trusted = false;
    d.accessToken = null;
    d.accessLevel = AccessLevel.none;
    d.status = DeviceStatus.offline;
    notifyListeners();
  }

  void setAccessLevel(String id, AccessLevel level) {
    final d = getById(id);
    if (d == null) return;
    d.accessLevel = level;
    notifyListeners();
  }

  void removeDevice(String id) {
    _devices.removeWhere((d) => d.id == id);
    notifyListeners();
  }
}