import 'dart:math';

enum DeviceCategory { drone, camera, robot, gps, smartHome, sensor, unknown }
enum ConnectionType  { wifi, wifiDirect, bluetooth, usb, rf, lan }
enum DeviceStatus    { online, offline, connecting, pairing, error }
enum AccessLevel     { full, limited, readOnly, none }

class ConnectedDevice {
  final String id;
  final String name;
  final DeviceCategory category;
  final ConnectionType connectionType;
  DeviceStatus status;
  AccessLevel accessLevel;
  final String? ipAddress;
  final String? macAddress;
  final int signalStrength; // 0-100
  final Map<String, dynamic> capabilities;
  final DateTime firstSeen;
  DateTime lastSeen;
  bool trusted;
  String? accessToken;

  ConnectedDevice({
    required this.id,
    required this.name,
    required this.category,
    required this.connectionType,
    required this.status,
    required this.accessLevel,
    this.ipAddress,
    this.macAddress,
    required this.signalStrength,
    required this.capabilities,
    required this.firstSeen,
    required this.lastSeen,
    this.trusted = false,
    this.accessToken,
  });

  static String generateToken() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final rng = Random.secure();
    return List.generate(24, (_) => chars[rng.nextInt(chars.length)]).join();
  }

  String get categoryLabel {
    switch (category) {
      case DeviceCategory.drone:     return 'DRONE';
      case DeviceCategory.camera:    return 'CAMERA';
      case DeviceCategory.robot:     return 'ROBOT';
      case DeviceCategory.gps:       return 'GPS';
      case DeviceCategory.smartHome: return 'SMART HOME';
      case DeviceCategory.sensor:    return 'SENSOR';
      case DeviceCategory.unknown:   return 'UNKNOWN';
    }
  }

  String get connectionLabel {
    switch (connectionType) {
      case ConnectionType.wifi:       return 'WiFi';
      case ConnectionType.wifiDirect: return 'WiFi Direct';
      case ConnectionType.bluetooth:  return 'Bluetooth';
      case ConnectionType.usb:        return 'USB';
      case ConnectionType.rf:         return 'RF';
      case ConnectionType.lan:        return 'LAN';
    }
  }
}
