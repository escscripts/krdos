import 'package:flutter/foundation.dart';
import 'dart:async';

class VPNServer {
  final String id;
  final String name;
  final String location;
  final String flag;
  final int ping;
  final int load;
  final String protocol;

  VPNServer({
    required this.id,
    required this.name,
    required this.location,
    required this.flag,
    required this.ping,
    required this.load,
    this.protocol = 'WireGuard',
  });
}

class VPNState extends ChangeNotifier {
  bool _isConnected = false;
  List<VPNServer> _hopChain = [];
  bool _killSwitchEnabled = true;
  bool _dnsLeakProtection = true;
  bool _autoReconnect = true;
  bool _ipv6LeakProtection = true;
  String _dataTransferred = '0 MB';
  Timer? _connectionTimer;
  int _connectionSeconds = 0;

  final List<VPNServer> _availableServers = [
    VPNServer(
      id: 'us-ny-01',
      name: 'New York #1',
      location: 'United States, New York',
      flag: '??',
      ping: 45,
      load: 32,
    ),
    VPNServer(
      id: 'uk-lon-01',
      name: 'London #1',
      location: 'United Kingdom, London',
      flag: '??',
      ping: 78,
      load: 45,
    ),
    VPNServer(
      id: 'de-ber-01',
      name: 'Berlin #1',
      location: 'Germany, Berlin',
      flag: '??',
      ping: 92,
      load: 28,
    ),
    VPNServer(
      id: 'jp-tok-01',
      name: 'Tokyo #1',
      location: 'Japan, Tokyo',
      flag: '??',
      ping: 156,
      load: 51,
    ),
    VPNServer(
      id: 'sg-sin-01',
      name: 'Singapore #1',
      location: 'Singapore',
      flag: '??',
      ping: 189,
      load: 38,
    ),
    VPNServer(
      id: 'au-syd-01',
      name: 'Sydney #1',
      location: 'Australia, Sydney',
      flag: '??',
      ping: 234,
      load: 42,
    ),
    VPNServer(
      id: 'ca-tor-01',
      name: 'Toronto #1',
      location: 'Canada, Toronto',
      flag: '??',
      ping: 67,
      load: 35,
    ),
    VPNServer(
      id: 'fr-par-01',
      name: 'Paris #1',
      location: 'France, Paris',
      flag: '??',
      ping: 85,
      load: 29,
    ),
    VPNServer(
      id: 'nl-ams-01',
      name: 'Amsterdam #1',
      location: 'Netherlands, Amsterdam',
      flag: '??',
      ping: 73,
      load: 41,
    ),
    VPNServer(
      id: 'se-sto-01',
      name: 'Stockholm #1',
      location: 'Sweden, Stockholm',
      flag: '??',
      ping: 98,
      load: 26,
    ),
    VPNServer(
      id: 'ch-zur-01',
      name: 'Zurich #1',
      location: 'Switzerland, Zurich',
      flag: '??',
      ping: 88,
      load: 31,
    ),
    VPNServer(
      id: 'es-mad-01',
      name: 'Madrid #1',
      location: 'Spain, Madrid',
      flag: '??',
      ping: 102,
      load: 37,
    ),
    VPNServer(
      id: 'it-mil-01',
      name: 'Milan #1',
      location: 'Italy, Milan',
      flag: '??',
      ping: 95,
      load: 44,
    ),
    VPNServer(
      id: 'br-sao-01',
      name: 'São Paulo #1',
      location: 'Brazil, São Paulo',
      flag: '??',
      ping: 178,
      load: 48,
    ),
    VPNServer(
      id: 'in-mum-01',
      name: 'Mumbai #1',
      location: 'India, Mumbai',
      flag: '??',
      ping: 167,
      load: 52,
    ),
  ];

  bool get isConnected => _isConnected;
  List<VPNServer> get hopChain => List.unmodifiable(_hopChain);
  List<VPNServer> get availableServers => List.unmodifiable(_availableServers);
  bool get killSwitchEnabled => _killSwitchEnabled;
  bool get dnsLeakProtection => _dnsLeakProtection;
  bool get autoReconnect => _autoReconnect;
  bool get ipv6LeakProtection => _ipv6LeakProtection;
  String get dataTransferred => _dataTransferred;

  int get totalLatency {
    if (_hopChain.isEmpty) return 0;
    return _hopChain.fold(0, (sum, server) => sum + server.ping);
  }

  void addToHopChain(VPNServer server) {
    if (_hopChain.length >= 5) {
      return;
    }
    if (!_hopChain.any((s) => s.id == server.id)) {
      _hopChain.add(server);
      notifyListeners();
    }
  }

  void removeFromHopChain(String serverId) {
    _hopChain.removeWhere((s) => s.id == serverId);
    notifyListeners();
  }

  void clearHopChain() {
    _hopChain.clear();
    notifyListeners();
  }

  void reorderHop(int oldIndex, int newIndex) {
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    final server = _hopChain.removeAt(oldIndex);
    _hopChain.insert(newIndex, server);
    notifyListeners();
  }

  Future<void> connect() async {
    if (_hopChain.isEmpty) return;
    
    _isConnected = true;
    _connectionSeconds = 0;
    _dataTransferred = '0 MB';
    notifyListeners();

    _connectionTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _connectionSeconds++;
      final mb = (_connectionSeconds * 0.15).toStringAsFixed(1);
      _dataTransferred = '$mb MB';
      notifyListeners();
    });
  }

  Future<void> disconnect() async {
    _isConnected = false;
    _connectionTimer?.cancel();
    _connectionTimer = null;
    _connectionSeconds = 0;
    notifyListeners();
  }

  void toggleKillSwitch() {
    _killSwitchEnabled = !_killSwitchEnabled;
    notifyListeners();
  }

  void toggleDNSLeakProtection() {
    _dnsLeakProtection = !_dnsLeakProtection;
    notifyListeners();
  }

  void toggleAutoReconnect() {
    _autoReconnect = !_autoReconnect;
    notifyListeners();
  }

  void toggleIPv6LeakProtection() {
    _ipv6LeakProtection = !_ipv6LeakProtection;
    notifyListeners();
  }

  @override
  void dispose() {
    _connectionTimer?.cancel();
    super.dispose();
  }
}
