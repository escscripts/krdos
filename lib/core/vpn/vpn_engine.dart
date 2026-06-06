import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'vpn_server.dart';
import 'vpn_hop.dart';
import 'vpn_encryption.dart';

enum VpnConnectionState {
  disconnected,
  connecting,
  connected,
  disconnecting,
  error,
}

enum VpnProtocol { wireguard, openvpn, ikev2 }

/// Core VPN Engine - manages multi-hop connections at the OS level
class VpnEngine extends ChangeNotifier {
  VpnConnectionState _state = VpnConnectionState.disconnected;
  VpnChain? _activeChain;
  final List<VpnChain> _savedChains = [];
  final Map<String, dynamic> _connectionStats = {
    'bytesUp': 0,
    'bytesDown': 0,
    'packetsUp': 0,
    'packetsDown': 0,
    'startTime': null,
    'lastPacketTime': null,
  };

  String? _errorMessage;
  Timer? _statsTimer;
  Timer? _healthCheckTimer;
  bool _killSwitchEnabled = false;
  String? _originalIp;
  String? _vpnIp;
  double? _currentLatency;

  // Connection timeouts
  static const int connectionTimeout = 30000; // 30 seconds
  static const int hopConnectTimeout = 10000; // 10 seconds per hop

  VpnEngine() {
    _loadSavedChains();
  }

  // ==================== Getters ====================
  VpnConnectionState get state => _state;
  VpnChain? get activeChain => _activeChain;
  List<VpnChain> get savedChains => _savedChains;
  String? get errorMessage => _errorMessage;
  bool get isConnected => _state == VpnConnectionState.connected;
  bool get isConnecting => _state == VpnConnectionState.connecting;
  bool get killSwitchEnabled => _killSwitchEnabled;
  String? get originalIp => _originalIp;
  String? get vpnIp => _vpnIp;
  double? get currentLatency => _currentLatency;

  Map<String, dynamic> get connectionStats => Map.from(_connectionStats);

  // ==================== Connection Management ====================

  /// Connect using a saved VPN chain
  Future<bool> connectToChain(String chainId) async {
    try {
      final chain = _savedChains.firstWhere(
        (c) => c.id == chainId,
        orElse: () => throw Exception('Chain not found: $chainId'),
      );
      return await connect(chain);
    } catch (e) {
      _setError('Failed to connect to chain: $e');
      return false;
    }
  }

  /// Connect to a VPN chain
  Future<bool> connect(VpnChain chain) async {
    if (_state == VpnConnectionState.connecting ||
        _state == VpnConnectionState.connected) {
      _setError('Already connected or connecting');
      return false;
    }

    _state = VpnConnectionState.connecting;
    _errorMessage = null;
    _activeChain = chain;
    chain.isActive = true;
    notifyListeners();

    try {
  // Get original IP before connection
      _originalIp = await _detectPublicIp();

  // Connect each hop sequentially with timeout
      for (int i = 0; i < chain.hops.length; i++) {
        final hop = chain.hops[i];
        final timeoutDuration = Duration(milliseconds: hopConnectTimeout);

        final hopConnected =
            await Future.delayed(const Duration(milliseconds: 500), () async {
              if (await _connectToHop(hop, i + 1)) {
                hop.isConnected = true;
                hop.latency = (100 + i * 50 + (i * 10)).toDouble();
                notifyListeners();
                return true;
              }
              return false;
            }).timeout(
              timeoutDuration,
              onTimeout: () {
                _setError('Hop ${i + 1} connection timeout');
                return false;
              },
            );

        if (!hopConnected && !chain.autoReconnect) {
          throw Exception('Failed to connect to hop ${i + 1}');
        }
      }

  // All hops connected
      _state = VpnConnectionState.connected;
      _vpnIp = await _detectPublicIp();
      _connectionStats['startTime'] = DateTime.now();
      _startStatCollection();
      _startHealthChecks();
      notifyListeners();

      if (kDebugMode) {
        print('? VPN Connected: ${chain.hops.length} hops active');
      }

      return true;
    } catch (e) {
      await disconnect();
      _setError('Connection failed: $e');
      return false;
    }
  }

  /// Disconnect from VPN
  Future<void> disconnect() async {
    if (_state == VpnConnectionState.disconnected) return;

    _state = VpnConnectionState.disconnecting;
    notifyListeners();

    try {
      if (_activeChain != null) {
        for (final hop in _activeChain!.hops) {
          await _disconnectFromHop(hop);
          hop.isConnected = false;
          hop.latency = null;
          hop.packetsLost = null;
        }
        _activeChain?.isActive = false;
        _activeChain = null;
      }

      _stopStatCollection();
      _stopHealthChecks();
      _state = VpnConnectionState.disconnected;
      _vpnIp = null;
      _currentLatency = null;
      notifyListeners();

      if (kDebugMode) print('? VPN Disconnected');
    } catch (e) {
      _setError('Disconnect failed: $e');
      _state = VpnConnectionState.error;
      notifyListeners();
    }
  }

  // ==================== Hop Management ====================

  Future<bool> _connectToHop(VpnHop hop, int hopNumber) async {
    try {
      if (kDebugMode) {
        print('? Connecting to hop $hopNumber: ${hop.server.country}...');
      }

  // Simulate TCP handshake to server
  // In production: actual WireGuard/OpenVPN connection
      await _simulateServerHandshake(hop.server);

      return true;
    } catch (e) {
      if (kDebugMode) print('? Hop connection failed: $e');
      return false;
    }
  }

  Future<void> _disconnectFromHop(VpnHop hop) async {
    try {
      if (kDebugMode) print('?? Disconnecting from: ${hop.server.country}');
  // Simulate connection teardown
      await Future.delayed(const Duration(milliseconds: 200));
    } catch (e) {
      if (kDebugMode) print('?? Hop disconnect warning: $e');
    }
  }

  // ==================== Network Utilities ====================

  Future<String> _detectPublicIp() async {
  // Mock implementation - returns simulated IP
    try {
  // In production: actual HTTP request to IP detection service
      await Future.delayed(const Duration(milliseconds: 300));
      return '${(DateTime.now().millisecond % 223 + 1)}.${(DateTime.now().microsecond % 256)}.${(DateTime.now().millisecond % 200 + 50)}.${(DateTime.now().microsecond % 256)}';
    } catch (e) {
      return 'Unknown';
    }
  }

  Future<void> _simulateServerHandshake(VpnServer server) async {
  // Mock server connection simulation
    await Future.delayed(Duration(milliseconds: 100 + server.load));
  }

  // ==================== Statistics & Health ====================

  void _startStatCollection() {
    _statsTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!isConnected) {
        _statsTimer?.cancel();
        return;
      }

      _connectionStats['bytesUp'] +=
          (100 + (DateTime.now().millisecond % 50)) as int;
      _connectionStats['bytesDown'] +=
          (200 + (DateTime.now().millisecond % 100)) as int;
      _connectionStats['packetsUp']++;
      _connectionStats['packetsDown'] += 2;
      _connectionStats['lastPacketTime'] = DateTime.now();

      notifyListeners();
    });
  }

  void _stopStatCollection() {
    _statsTimer?.cancel();
    _statsTimer = null;
  }

  void _startHealthChecks() {
    _healthCheckTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (!isConnected || _activeChain == null) {
        _healthCheckTimer?.cancel();
        return;
      }

      _performHealthCheck();
    });
  }

  void _stopHealthChecks() {
    _healthCheckTimer?.cancel();
    _healthCheckTimer = null;
  }

  Future<void> _performHealthCheck() async {
    try {
      if (_activeChain == null) return;

  // Check each hop's latency and packet loss
      for (final hop in _activeChain!.hops) {
        final latency = await _measureHopLatency(hop);
        hop.latency = latency;
        hop.packetsLost = (5 + (latency / 100).toInt()).clamp(0, 30);
      }

      _currentLatency = _activeChain?.averageLatency;
      notifyListeners();
    } catch (e) {
      if (kDebugMode) print('Health check failed: $e');
    }
  }

  Future<double> _measureHopLatency(VpnHop hop) async {
  // Mock latency measurement
    await Future.delayed(const Duration(milliseconds: 50));
    return (50 + (DateTime.now().millisecond % 100)).toDouble();
  }

  // ==================== Chain Management ====================

  void saveChain(VpnChain chain) {
    if (!_savedChains.any((c) => c.id == chain.id)) {
      _savedChains.add(chain);
    }
    notifyListeners();
  }

  void deleteChain(String chainId) {
    if (_activeChain?.id == chainId) {
      return; // Can't delete active chain
    }
    _savedChains.removeWhere((c) => c.id == chainId);
    notifyListeners();
  }

  void updateChain(VpnChain chain) {
    final index = _savedChains.indexWhere((c) => c.id == chain.id);
    if (index != -1) {
      _savedChains[index] = chain;
      notifyListeners();
    }
  }

  // ==================== Kill Switch ====================

  void setKillSwitch(bool enabled) {
    _killSwitchEnabled = enabled;
    if (enabled && !isConnected) {
      _setError('Kill switch enabled: all internet blocked until VPN connects');
    }
    notifyListeners();
  }

  // ==================== Utilities ====================

  void _setError(String message) {
    _errorMessage = message;
    _state = VpnConnectionState.error;
    if (kDebugMode) print('? VPN Error: $message');
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    if (_state == VpnConnectionState.error) {
      _state = VpnConnectionState.disconnected;
    }
    notifyListeners();
  }

  String getConnectionSummary() {
    if (!isConnected) return 'Disconnected';
    if (_activeChain == null) return 'Unknown';

    return '${_activeChain!.hops.length} hops via ${_activeChain!.hops.last.server.country}\nLatency: ${_currentLatency?.toStringAsFixed(1)}ms';
  }

  void _loadSavedChains() {
  // Load from persistent storage (SharedPreferences in production)
  // Mock data for now
  }

  @override
  void dispose() {
    _stopStatCollection();
    _stopHealthChecks();
    super.dispose();
  }
}