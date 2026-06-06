import 'dart:convert';
import 'package:crypto/crypto.dart';

enum PacketType { data, command, response, heartbeat, broadcast, emergency }

class MeshPacket {
  final String id;
  final String fromDeviceId;
  final String toDeviceId;
  final PacketType type;
  final String payload;
  final String? encryptionKey;
  final int hopLimit;
  final int currentHop;
  final DateTime timestamp;
  final Map<String, dynamic> metadata;
  final bool isEncrypted;

  MeshPacket({
    String? id,
    required this.fromDeviceId,
    required this.toDeviceId,
    required this.type,
    required this.payload,
    this.encryptionKey,
    this.hopLimit = 32,
    this.currentHop = 0,
    DateTime? timestamp,
    Map<String, dynamic>? metadata,
    this.isEncrypted = false,
  }) : id = id ?? _generateId(),
       timestamp = timestamp ?? DateTime.now(),
       metadata = metadata ?? {};

  static String _generateId() {
    return DateTime.now().millisecondsSinceEpoch.toString() +
        (DateTime.now().microsecond).toString();
  }

  // Calculate packet hash for integrity verification
  String calculateHash() {
    final content =
        '$fromDeviceId$toDeviceId$payload${timestamp.millisecondsSinceEpoch}';
    return sha256.convert(utf8.encode(content)).toString().substring(0, 16);
  }

  // Check if packet should be relayed (TTL-based)
  bool shouldRelay() {
    return currentHop < hopLimit;
  }

  // Create relay copy with incremented hop
  MeshPacket relayPacket() {
    return MeshPacket(
      id: id,
      fromDeviceId: fromDeviceId,
      toDeviceId: toDeviceId,
      type: type,
      payload: payload,
      encryptionKey: encryptionKey,
      hopLimit: hopLimit,
      currentHop: currentHop + 1,
      timestamp: timestamp,
      metadata: metadata,
      isEncrypted: isEncrypted,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'from': fromDeviceId,
    'to': toDeviceId,
    'type': type.toString(),
    'payload': payload,
    'hopLimit': hopLimit,
    'currentHop': currentHop,
    'timestamp': timestamp.toIso8601String(),
    'isEncrypted': isEncrypted,
    'hash': calculateHash(),
    'metadata': metadata,
  };

  static MeshPacket fromJson(Map<String, dynamic> json) {
    return MeshPacket(
      id: json['id'] as String,
      fromDeviceId: json['from'] as String,
      toDeviceId: json['to'] as String,
      type: PacketType.values.firstWhere(
        (e) => e.toString() == json['type'],
        orElse: () => PacketType.data,
      ),
      payload: json['payload'] as String,
      hopLimit: json['hopLimit'] as int? ?? 32,
      currentHop: json['currentHop'] as int? ?? 0,
      timestamp: DateTime.parse(json['timestamp'] as String),
      isEncrypted: json['isEncrypted'] as bool? ?? false,
      metadata: json['metadata'] as Map<String, dynamic>? ?? {},
    );
  }
}
