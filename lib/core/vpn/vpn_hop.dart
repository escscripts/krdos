import 'package:flutter/foundation.dart';
import 'vpn_server.dart';

/// Represents a single hop in the VPN chain
class VpnHop {
  final String id;
  final VpnServer server;
  final int hopNumber; // 1 = entry, 2 = middle, 3+ = exit
  final String encryptionKey; // Base64 encoded key for this hop
  final DateTime createdAt;
  bool isConnected = false;
  double? latency; // in milliseconds
  int? packetsLost; // percentage

  VpnHop({
    required this.id,
    required this.server,
    required this.hopNumber,
    required this.encryptionKey,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory VpnHop.fromJson(Map<String, dynamic> json) {
    return VpnHop(
      id: json['id'] ?? '',
      server: VpnServer.fromJson(json['server']),
      hopNumber: json['hopNumber'] ?? 1,
      encryptionKey: json['encryptionKey'] ?? '',
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'server': server.toJson(),
    'hopNumber': hopNumber,
    'encryptionKey': encryptionKey,
    'createdAt': createdAt.toIso8601String(),
  };

  String get description => '${server.country} (${server.region})';
  String get connectionStatus => isConnected ? '? Connected' : '? Disconnected';
  String get latencyDisplay =>
      latency != null ? '${latency?.toStringAsFixed(1)}ms' : 'N/A';

  @override
  String toString() =>
      'Hop #$hopNumber: ${server.country} via ${server.protocol}';
}

/// VPN Chain configuration - stores multiple hops
class VpnChain {
  final String id;
  final String name;
  final String description;
  final List<VpnHop> hops;
  final DateTime createdAt;
  final DateTime? lastModified;
  bool isActive = false;
  bool autoReconnect = true;
  int reconnectAttempts = 3;

  VpnChain({
    required this.id,
    required this.name,
    required this.description,
    required this.hops,
    DateTime? createdAt,
    this.lastModified,
    this.autoReconnect = true,
    this.reconnectAttempts = 3,
  }) : createdAt = createdAt ?? DateTime.now();

  factory VpnChain.fromJson(Map<String, dynamic> json) {
    return VpnChain(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      hops:
          (json['hops'] as List<dynamic>?)
              ?.map((h) => VpnHop.fromJson(h as Map<String, dynamic>))
              .toList() ??
          [],
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
      lastModified: json['lastModified'] != null
          ? DateTime.parse(json['lastModified'])
          : null,
      autoReconnect: json['autoReconnect'] ?? true,
      reconnectAttempts: json['reconnectAttempts'] ?? 3,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'description': description,
    'hops': hops.map((h) => h.toJson()).toList(),
    'createdAt': createdAt.toIso8601String(),
    'lastModified': lastModified?.toIso8601String(),
    'autoReconnect': autoReconnect,
    'reconnectAttempts': reconnectAttempts,
  };

  String get hopCountDisplay =>
      '${hops.length} hop${hops.length != 1 ? 's' : ''}';
  String get routeDisplay => hops.map((h) => h.server.countryCode).join(' ? ');

  double? get averageLatency {
    if (hops.isEmpty || hops.any((h) => h.latency == null)) return null;
    final sum = hops.fold<double>(0, (acc, h) => acc + (h.latency ?? 0));
    return sum / hops.length;
  }

  bool get allConnected => hops.every((h) => h.isConnected);
  bool get anyConnected => hops.any((h) => h.isConnected);

  @override
  String toString() => '$name ($hopCountDisplay): $routeDisplay';
}
