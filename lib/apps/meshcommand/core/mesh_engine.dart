import 'dart:async';
import 'dart:convert' show jsonDecode, jsonEncode;
import 'package:flutter/material.dart';

import '../models/device_model.dart';
import '../models/rf_lab_capture.dart';
import '../models/packet_model.dart';
import 'device_command_registry.dart';
import 'mesh_encryption.dart';

class MeshEngine extends ChangeNotifier {
  // Device management
  final Map<String, MeshDevice> devices = {};
  late MeshDevice? selfDevice;

  // Network state
  List<MeshPacket> packetHistory = [];
  Map<String, List<MeshDevice>> devicesByProtocol = {
    'LoRa': [],
    'WiFi': [],
    'Sub-GHz': [],
    'Bluetooth': [],
  };

  // Statistics
  int totalPacketsProcessed = 0;
  int totalEncryptedPackets = 0;
  DateTime lastUpdate = DateTime.now();

  // Configuration
  Map<String, String> encryptionKeys = {};
  List<String> whitelist = [];
  bool useEmergencyBroadcast = false;
  bool anonymizeTraffic = false; // Ghost Mode integration

  /// Imported lab traces / logical payloads (host-side RF hardware feeds these bytes).
  final List<RfLabCapture> rfLabCaptures = [];

  // Timers
  Timer? _discoveryTimer;
  Timer? _healthCheckTimer;

  MeshEngine() {
    _initializeSelf();
    _startDiscoveryLoop();
    _startHealthCheck();
  }

  void _initializeSelf() {
    selfDevice = MeshDevice(
      id: _generateDeviceId(),
      name: 'MeshCommand-Host',
      type: DeviceType.gateway,
      protocol: ProtocolType.wifi,
      address: '192.168.1.100',
      status: DeviceStatus.online,
    );
    _attachCommandSlots(selfDevice!);
    encryptionKeys[selfDevice!.id] = MeshEncryption.generateEncryptionKey();
  }

  /// Binds logical command IDs from [DeviceCommandRegistry] so MeshCommand surfaces can execute.
  void _attachCommandSlots(MeshDevice device) {
    for (final cmd in DeviceCommandRegistry.getCommandsForDevice(device)) {
      device.commands[cmd.id] = {'registered': true, 'label': cmd.name};
    }
  }

  /// Register a discovered device
  void registerDevice(MeshDevice device) {
    _attachCommandSlots(device);
    devices[device.id] = device;
    _categorizeDevice(device);
    notifyListeners();
  }

  void _categorizeDevice(MeshDevice device) {
    final protocolLabel = device.protocolLabel;
    if (!devicesByProtocol.containsKey(protocolLabel)) {
      devicesByProtocol[protocolLabel] = [];
    }
    if (!devicesByProtocol[protocolLabel]!.any((d) => d.id == device.id)) {
      devicesByProtocol[protocolLabel]!.add(device);
    }
  }

  // Send packet through mesh
  Future<bool> sendPacket(
    String toDeviceId,
    String payload,
    PacketType type,
  ) async {
    if (!devices.containsKey(toDeviceId)) {
      throw Exception('Device not found: $toDeviceId');
    }

    try {
      final packet = MeshPacket(
        fromDeviceId: selfDevice!.id,
        toDeviceId: toDeviceId,
        type: type,
        payload: payload,
      );

  // Encrypt if keys available
      if (encryptionKeys.containsKey(toDeviceId)) {
        final encrypted = MeshEncryption.encryptPacket(
          payload,
          encryptionKeys[toDeviceId]!,
        );
        final encryptedPacket = MeshPacket(
          id: packet.id,
          fromDeviceId: packet.fromDeviceId,
          toDeviceId: packet.toDeviceId,
          type: packet.type,
          payload: encrypted,
          encryptionKey: encryptionKeys[toDeviceId],
          isEncrypted: true,
        );
        return _processPacket(encryptedPacket);
      }

      return _processPacket(packet);
    } catch (e) {
      print('Error sending packet: $e');
      return false;
    }
  }

  Future<bool> _processPacket(MeshPacket packet) async {
  // Simulate network transmission delay
    await Future.delayed(const Duration(milliseconds: 100));

    packetHistory.add(packet);
    totalPacketsProcessed++;
    if (packet.isEncrypted) totalEncryptedPackets++;

  // Handle based on type
    switch (packet.type) {
      case PacketType.command:
        _handleCommand(packet);
        break;
      case PacketType.broadcast:
      case PacketType.emergency:
        _handleBroadcast(packet);
        break;
      case PacketType.heartbeat:
        _updateDeviceLastSeen(packet.fromDeviceId);
        break;
      default:
        break;
    }

    notifyListeners();
    return true;
  }

  Future<void> quickCommand(
    String deviceId,
    String commandId,
    Map<String, dynamic> params,
  ) async {
    try {
      await executeDeviceCommand(deviceId, commandId, params);
      notifyListeners();
    } catch (e, st) {
      debugPrint('MeshEngine.quickCommand: $e\n$st');
    }
  }

  void setGhostMode(bool value) {
    if (anonymizeTraffic == value) return;
    anonymizeTraffic = value;
    notifyListeners();
  }

  void setEmergencyBroadcastEnabled(bool value) {
    if (useEmergencyBroadcast == value) return;
    useEmergencyBroadcast = value;
    notifyListeners();
  }

  void addRfLabCapture(RfLabCapture capture) {
    rfLabCaptures.removeWhere((c) => c.id == capture.id);
    rfLabCaptures.insert(0, capture);
    notifyListeners();
  }

  void removeRfLabCapture(String id) {
    rfLabCaptures.removeWhere((c) => c.id == id);
    notifyListeners();
  }

  /// Wraps decoded payload as sandbox command frame toward a registered node simulator.
  Future<void> simulateReplayLabCapture({
    required String targetDeviceId,
    required String captureId,
  }) async {
    RfLabCapture? cap;
    for (final c in rfLabCaptures) {
      if (c.id == captureId) {
        cap = c;
        break;
      }
    }
    if (cap == null) return;
    if (!devices.containsKey(targetDeviceId)) return;

    final payload = jsonEncode({
      'rf_lab': 'sandbox_sim',
      'captureId': cap.id,
      'hex': cap.normalizedHex,
      'title': cap.title,
      'hints': {'modulation': cap.modulationHint, 'frequency': cap.frequencyHint},
    });
    await sendPacket(targetDeviceId, payload, PacketType.command);
  }

  bool importRfLabFromJsonClipboard(String clip) {
    try {
      final map = jsonDecode(clip.trim()) as Map<String, dynamic>;
      if (map['schema'] != 'meshcommand.rf_lab_capture.v1') return false;
      addRfLabCapture(
        RfLabCapture(
          id: map['id'] as String? ?? 'cap-import-${DateTime.now().millisecondsSinceEpoch}',
          title: map['title'] as String? ?? 'Imported',
          capturedAt:
              DateTime.tryParse(map['capturedAt'] as String? ?? '') ?? DateTime.now(),
          hexPayload: map['hex'] as String? ?? '',
          modulationHint: map['modulationHint'] as String? ?? '',
          frequencyHint: map['frequencyHint'] as String? ?? '',
          notes: map['notes'] as String? ?? '',
          sourceTag: map['sourceTag'] as String? ?? 'Clipboard',
        ),
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  void _handleCommand(MeshPacket packet) {
    final device = devices[packet.toDeviceId];
    if (device != null) {
  // Simulate command execution
      print('Command sent to ${device.name}: ${packet.payload}');
    }
  }

  void _handleBroadcast(MeshPacket packet) {
  // Process emergency or broadcast packet
    if (packet.type == PacketType.emergency) {
      print('EMERGENCY BROADCAST from ${packet.fromDeviceId}');
    }
  }

  void _updateDeviceLastSeen(String deviceId) {
    if (devices.containsKey(deviceId)) {
      devices[deviceId]!.lastSeen = DateTime.now().toString();
    }
  }

  // Auto-discovery simulation
  void _startDiscoveryLoop() {
    _discoveryTimer?.cancel();
    _discoveryTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _simulateDeviceDiscovery();
    });
  }

  void _simulateDeviceDiscovery() {
  // In production, this would scan actual radio protocols
  // For now, we'll add mock devices
    final mockDevices = [
      MeshDevice(
        id: 'drone-001',
        name: 'Quadcopter Alpha',
        type: DeviceType.drone,
        protocol: ProtocolType.lora,
        address: 'lora:0x001',
        status: DeviceStatus.online,
        signalStrength: -85.0,
        hopDistance: 1,
        batteryPercent: 92,
      ),
      MeshDevice(
        id: 'camera-002',
        name: 'Surveillance Cam',
        type: DeviceType.camera,
        protocol: ProtocolType.wifi,
        address: '192.168.1.50',
        status: DeviceStatus.online,
        signalStrength: -65.0,
        hopDistance: 1,
        batteryPercent: 100,
      ),
      MeshDevice(
        id: 'sensor-003',
        name: 'Temperature Sensor',
        type: DeviceType.sensor,
        protocol: ProtocolType.subghz,
        address: 'subghz:0x003',
        status: DeviceStatus.online,
        signalStrength: -95.0,
        hopDistance: 2,
        batteryPercent: 45,
      ),
    ];

    for (final device in mockDevices) {
      if (!devices.containsKey(device.id)) {
        registerDevice(device);
        encryptionKeys[device.id] = MeshEncryption.generateEncryptionKey();
      }
    }
  }

  void _startHealthCheck() {
    _healthCheckTimer?.cancel();
    _healthCheckTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _performHealthCheck();
    });
  }

  void _performHealthCheck() {
    lastUpdate = DateTime.now();
  // Update device statuses, latencies, etc.
    for (final device in devices.values) {
      if (device.status == DeviceStatus.online) {
  // Simulate occasional packet loss
        if (DateTime.now().millisecond % 10 == 0) {
          device.status = DeviceStatus.offline;
        }
      } else if (device.status == DeviceStatus.offline) {
  // Simulate reconnection
        if (DateTime.now().millisecond % 15 == 0) {
          device.status = DeviceStatus.online;
        }
      }
    }
    notifyListeners();
  }

  // Command execution
  Future<String> executeDeviceCommand(
    String deviceId,
    String commandId,
    Map<String, dynamic> parameters,
  ) async {
    final device = devices[deviceId];
    if (device == null) throw Exception('Device not found');
    if (!device.commands.containsKey(commandId))
      throw Exception('Command not found');

    final packet = MeshPacket(
      fromDeviceId: selfDevice!.id,
      toDeviceId: deviceId,
      type: PacketType.command,
      payload: jsonEncode({'command': commandId, 'params': parameters}),
    );

    await _processPacket(packet);
    return 'Command executed on ${device.name}';
  }

  // Emergency broadcast
  Future<void> sendEmergencyBroadcast(String message) async {
    final packet = MeshPacket(
      fromDeviceId: selfDevice!.id,
      toDeviceId: 'broadcast',
      type: PacketType.emergency,
      payload: message,
      hopLimit: 255, // Max hops for emergency
    );

    await _processPacket(packet);
    print('Emergency broadcast sent: $message');
  }

  // Statistics
  Map<String, dynamic> getStatistics() {
    final activeDevices = devices.values
        .where((d) => d.status == DeviceStatus.online)
        .length;
    final encryptionRate = totalPacketsProcessed > 0
        ? (totalEncryptedPackets / totalPacketsProcessed * 100).toStringAsFixed(
            1,
          )
        : '0';

    return {
      'totalDevices': devices.length,
      'activeDevices': activeDevices,
      'totalPackets': totalPacketsProcessed,
      'encryptedPackets': totalEncryptedPackets,
      'encryptionRate': '$encryptionRate%',
      'lastUpdate': lastUpdate.toString(),
      'protocols': devicesByProtocol.map((k, v) => MapEntry(k, v.length)),
    };
  }

  String _generateDeviceId() {
    return 'dev-${DateTime.now().millisecondsSinceEpoch}';
  }

  @override
  void dispose() {
    _discoveryTimer?.cancel();
    _healthCheckTimer?.cancel();
    super.dispose();
  }
}