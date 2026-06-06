import 'package:flutter/material.dart';

enum DeviceType { drone, camera, sensor, gateway, relay, mobile, unknown }

enum DeviceStatus { online, offline, connecting, paused, error }

enum ProtocolType { lora, wifi, subghz, bluetooth }

class MeshDevice {
  final String id;
  final String name;
  final DeviceType type;
  final ProtocolType protocol;
  final String address;
  late double latitude;
  late double longitude;
  late double signalStrength; // -120 to -30 dBm
  late int hopDistance;
  late int batteryPercent;
  late String lastSeen;
  late DeviceStatus status;
  late Map<String, dynamic>
  commands; // Available commands for this device
  late Map<String, dynamic> metadata;

  MeshDevice({
    required this.id,
    required this.name,
    required this.type,
    required this.protocol,
    required this.address,
    double latitude = 0.0,
    double longitude = 0.0,
    double signalStrength = -100.0,
    int hopDistance = 1,
    int batteryPercent = 100,
    String lastSeen = 'now',
    DeviceStatus status = DeviceStatus.offline,
    Map<String, dynamic>? commands,
    Map<String, dynamic>? metadata,
  }) {
    this.latitude = latitude;
    this.longitude = longitude;
    this.signalStrength = signalStrength;
    this.hopDistance = hopDistance;
    this.batteryPercent = batteryPercent;
    this.lastSeen = lastSeen;
    this.status = status;
    this.commands = commands ?? {};
    this.metadata = metadata ?? {};
  }

  Color get statusColor {
    switch (status) {
      case DeviceStatus.online:
        return Colors.green;
      case DeviceStatus.offline:
        return Colors.grey;
      case DeviceStatus.connecting:
        return Colors.orange;
      case DeviceStatus.paused:
        return Colors.yellow;
      case DeviceStatus.error:
        return Colors.red;
    }
  }

  IconData get typeIcon {
    switch (type) {
      case DeviceType.drone:
        return Icons.airplanemode_active;
      case DeviceType.camera:
        return Icons.camera;
      case DeviceType.sensor:
        return Icons.sensors;
      case DeviceType.gateway:
        return Icons.router;
      case DeviceType.relay:
        return Icons.repeat;
      case DeviceType.mobile:
        return Icons.phone_android;
      case DeviceType.unknown:
        return Icons.help_outline;
    }
  }

  String get protocolLabel {
    switch (protocol) {
      case ProtocolType.lora:
        return 'LoRa';
      case ProtocolType.wifi:
        return 'WiFi';
      case ProtocolType.subghz:
        return 'Sub-GHz';
      case ProtocolType.bluetooth:
        return 'Bluetooth';
    }
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'type': type.toString(),
    'protocol': protocol.toString(),
    'address': address,
    'latitude': latitude,
    'longitude': longitude,
    'signalStrength': signalStrength,
    'hopDistance': hopDistance,
    'batteryPercent': batteryPercent,
    'lastSeen': lastSeen,
    'status': status.toString(),
    'commands': commands,
    'metadata': metadata,
  };

  static MeshDevice fromJson(Map<String, dynamic> json) {
    return MeshDevice(
      id: json['id'] as String,
      name: json['name'] as String,
      type: DeviceType.values.firstWhere(
        (e) => e.toString() == json['type'],
        orElse: () => DeviceType.unknown,
      ),
      protocol: ProtocolType.values.firstWhere(
        (e) => e.toString() == json['protocol'],
        orElse: () => ProtocolType.wifi,
      ),
      address: json['address'] as String,
      latitude: json['latitude'] as double? ?? 0.0,
      longitude: json['longitude'] as double? ?? 0.0,
      signalStrength: json['signalStrength'] as double? ?? -100.0,
      hopDistance: json['hopDistance'] as int? ?? 1,
      batteryPercent: json['batteryPercent'] as int? ?? 100,
      lastSeen: json['lastSeen'] as String? ?? 'unknown',
      status: DeviceStatus.values.firstWhere(
        (e) => e.toString() == json['status'],
        orElse: () => DeviceStatus.offline,
      ),
      commands: json['commands'] as Map<String, dynamic>? ?? {},
      metadata: json['metadata'] as Map<String, dynamic>? ?? {},
    );
  }
}

class DeviceCommand {
  final String id;
  final String name;
  final String description;
  final String category;
  final List<String> parameters;
  final String expectedResponse;
  final bool requiresConfirmation;

  DeviceCommand({
    required this.id,
    required this.name,
    required this.description,
    required this.category,
    this.parameters = const [],
    required this.expectedResponse,
    this.requiresConfirmation = false,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'description': description,
    'category': category,
    'parameters': parameters,
    'expectedResponse': expectedResponse,
    'requiresConfirmation': requiresConfirmation,
  };
}
