import 'package:flutter/foundation.dart';

/// Represents a VPN server that can be part of a hop chain
class VpnServer {
  final String id;
  final String name;
  final String country;
  final String countryCode;
  final String region;
  final String address; // Server IP or hostname
  final int port;
  final String protocol; // 'wireguard', 'openvpn', 'ikev2'
  final double latitude;
  final double longitude;
  final int load; // Server load percentage (0-100)
  final bool isRecommended;
  final DateTime lastUpdated;

  VpnServer({
    required this.id,
    required this.name,
    required this.country,
    required this.countryCode,
    required this.region,
    required this.address,
    required this.port,
    required this.protocol,
    required this.latitude,
    required this.longitude,
    this.load = 50,
    this.isRecommended = false,
    DateTime? lastUpdated,
  }) : lastUpdated = lastUpdated ?? DateTime.now();

  factory VpnServer.fromJson(Map<String, dynamic> json) {
    return VpnServer(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      country: json['country'] ?? '',
      countryCode: json['countryCode'] ?? '',
      region: json['region'] ?? '',
      address: json['address'] ?? '',
      port: json['port'] ?? 443,
      protocol: json['protocol'] ?? 'wireguard',
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0,
      load: json['load'] ?? 50,
      isRecommended: json['isRecommended'] ?? false,
      lastUpdated: json['lastUpdated'] != null
          ? DateTime.parse(json['lastUpdated'])
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'country': country,
    'countryCode': countryCode,
    'region': region,
    'address': address,
    'port': port,
    'protocol': protocol,
    'latitude': latitude,
    'longitude': longitude,
    'load': load,
    'isRecommended': isRecommended,
    'lastUpdated': lastUpdated.toIso8601String(),
  };

  @override
  String toString() => '$country - $region ($protocol)';
}

/// Mock VPN server database
class VpnServerRegistry {
  static final List<VpnServer> mockServers = [
    VpnServer(
      id: 'us-east-1',
      name: 'US East 1',
      country: 'United States',
      countryCode: 'US',
      region: 'New York',
      address: '203.0.113.1',
      port: 51820,
      protocol: 'wireguard',
      latitude: 40.7128,
      longitude: -74.0060,
      load: 45,
      isRecommended: true,
    ),
    VpnServer(
      id: 'nl-west-1',
      name: 'NL West 1',
      country: 'Netherlands',
      countryCode: 'NL',
      region: 'Amsterdam',
      address: '203.0.113.2',
      port: 51820,
      protocol: 'wireguard',
      latitude: 52.3676,
      longitude: 4.9041,
      load: 35,
      isRecommended: true,
    ),
    VpnServer(
      id: 'jp-east-1',
      name: 'JP East 1',
      country: 'Japan',
      countryCode: 'JP',
      region: 'Tokyo',
      address: '203.0.113.3',
      port: 51820,
      protocol: 'wireguard',
      latitude: 35.6762,
      longitude: 139.6503,
      load: 62,
    ),
    VpnServer(
      id: 'de-central-1',
      name: 'DE Central 1',
      country: 'Germany',
      countryCode: 'DE',
      region: 'Frankfurt',
      address: '203.0.113.4',
      port: 51820,
      protocol: 'wireguard',
      latitude: 50.1109,
      longitude: 8.6821,
      load: 28,
      isRecommended: true,
    ),
    VpnServer(
      id: 'sg-southeast-1',
      name: 'SG Southeast 1',
      country: 'Singapore',
      countryCode: 'SG',
      region: 'Singapore',
      address: '203.0.113.5',
      port: 51820,
      protocol: 'wireguard',
      latitude: 1.3521,
      longitude: 103.8198,
      load: 71,
    ),
    VpnServer(
      id: 'ca-north-1',
      name: 'CA North 1',
      country: 'Canada',
      countryCode: 'CA',
      region: 'Toronto',
      address: '203.0.113.6',
      port: 51820,
      protocol: 'wireguard',
      latitude: 43.6532,
      longitude: -79.3832,
      load: 42,
    ),
    VpnServer(
      id: 'gb-west-1',
      name: 'GB West 1',
      country: 'United Kingdom',
      countryCode: 'GB',
      region: 'London',
      address: '203.0.113.7',
      port: 51820,
      protocol: 'wireguard',
      latitude: 51.5074,
      longitude: -0.1278,
      load: 55,
      isRecommended: true,
    ),
  ];

  static List<VpnServer> getAll() => mockServers;

  static List<VpnServer> getByCountry(String country) =>
      mockServers.where((s) => s.country == country).toList();

  static List<String> getCountries() =>
      mockServers.map((s) => s.country).toSet().toList()..sort();

  static List<String> getCountryCodes() =>
      mockServers.map((s) => s.countryCode).toSet().toList()..sort();

  static VpnServer? getById(String id) {
    try {
      return mockServers.firstWhere((s) => s.id == id);
    } catch (e) {
      return null;
    }
  }
}
