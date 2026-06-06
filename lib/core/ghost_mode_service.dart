import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';

class GhostModeService extends ChangeNotifier {
  // IP Rotation
  bool _ipRotationEnabled = false;
  String _currentIP = '192.168.1.100';
  String _currentMAC = '00:11:22:33:44:55';
  int _ipRotationInterval = 5;
  Timer? _ipRotationTimer;

  // Location Spoofing
  bool _locationSpoofEnabled = false;
  double _latitude = 40.7128;
  double _longitude = -74.0060;
  String _locationName = 'New York, USA';
  String _timezone = 'America/New_York';
  Timer? _locationTimer;

  // Fingerprint Rotation
  bool _fingerprintRotationEnabled = false;
  String _userAgent = '';
  String _browser = 'Chrome';
  String _os = 'Windows 10';
  String _language = 'en-US';
  String _screenResolution = '1920x1080';
  int _hardwareConcurrency = 8;
  int _deviceMemory = 8;
  Timer? _fingerprintTimer;

  // DNS Rotation
  bool _dnsRotationEnabled = false;
  String _currentDNS = '1.1.1.1';
  Timer? _dnsTimer;

  // WebRTC Protection
  bool _webrtcProtection = true;

  // Canvas/Audio Fingerprint
  bool _canvasNoiseEnabled = true;
  bool _audioNoiseEnabled = true;

  // Battery Spoofing
  bool _batterySpoofEnabled = false;
  int _batteryLevel = 100;
  bool _batteryCharging = true;

  // Getters
  bool get ipRotationEnabled => _ipRotationEnabled;
  String get currentIP => _currentIP;
  String get currentMAC => _currentMAC;
  int get ipRotationInterval => _ipRotationInterval;

  bool get locationSpoofEnabled => _locationSpoofEnabled;
  double get latitude => _latitude;
  double get longitude => _longitude;
  String get locationName => _locationName;
  String get timezone => _timezone;

  bool get fingerprintRotationEnabled => _fingerprintRotationEnabled;
  String get userAgent => _userAgent;
  String get browser => _browser;
  String get os => _os;
  String get language => _language;
  String get screenResolution => _screenResolution;
  int get hardwareConcurrency => _hardwareConcurrency;
  int get deviceMemory => _deviceMemory;

  bool get dnsRotationEnabled => _dnsRotationEnabled;
  String get currentDNS => _currentDNS;

  bool get webrtcProtection => _webrtcProtection;
  bool get canvasNoiseEnabled => _canvasNoiseEnabled;
  bool get audioNoiseEnabled => _audioNoiseEnabled;

  bool get batterySpoofEnabled => _batterySpoofEnabled;
  int get batteryLevel => _batteryLevel;
  bool get batteryCharging => _batteryCharging;

  // Master switch
  bool get isGhostModeActive =>
      _ipRotationEnabled ||
      _locationSpoofEnabled ||
      _fingerprintRotationEnabled ||
      _dnsRotationEnabled;

  // IP Rotation Methods
  void toggleIPRotation() {
    _ipRotationEnabled = !_ipRotationEnabled;
    if (_ipRotationEnabled) {
      _startIPRotation();
    } else {
      _stopIPRotation();
    }
    notifyListeners();
  }

  void setIPRotationInterval(int seconds) {
    _ipRotationInterval = seconds;
    if (_ipRotationEnabled) {
      _stopIPRotation();
      _startIPRotation();
    }
    notifyListeners();
  }

  void _startIPRotation() {
    _rotateIP();
    _ipRotationTimer = Timer.periodic(Duration(seconds: _ipRotationInterval), (_) {
      _rotateIP();
    });
  }

  void _stopIPRotation() {
    _ipRotationTimer?.cancel();
  }

  Future<void> _rotateIP() async {
    final random = Random();
    final octet1 = random.nextInt(223) + 1;
    final octet2 = random.nextInt(256);
    final octet3 = random.nextInt(256);
    final octet4 = random.nextInt(254) + 1;
    _currentIP = '$octet1.$octet2.$octet3.$octet4';

    _currentMAC = List.generate(6, (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0')).join(':');

    if (!kIsWeb) {
      try {
        await Process.run('sudo', ['ip', 'addr', 'flush', 'dev', 'eth0']);
        await Process.run('sudo', ['ip', 'addr', 'add', '$_currentIP/24', 'dev', 'eth0']);
        await Process.run('sudo', ['ip', 'link', 'set', 'dev', 'eth0', 'address', _currentMAC]);
      } catch (e) {
        debugPrint('IP rotation failed: $e');
      }
    }

    notifyListeners();
  }

  // Location Spoofing Methods
  void toggleLocationSpoof() {
    _locationSpoofEnabled = !_locationSpoofEnabled;
    if (_locationSpoofEnabled) {
      _injectLocationSpoof();
    }
    notifyListeners();
  }

  void setLocation(double lat, double lng, String name, String tz) {
    _latitude = lat;
    _longitude = lng;
    _locationName = name;
    _timezone = tz;
    if (_locationSpoofEnabled) {
      _injectLocationSpoof();
    }
    notifyListeners();
  }

  void randomLocation() {
    final locations = [
      {'name': 'New York, USA', 'lat': 40.7128, 'lng': -74.0060, 'tz': 'America/New_York'},
      {'name': 'London, UK', 'lat': 51.5074, 'lng': -0.1278, 'tz': 'Europe/London'},
      {'name': 'Tokyo, Japan', 'lat': 35.6762, 'lng': 139.6503, 'tz': 'Asia/Tokyo'},
      {'name': 'Paris, France', 'lat': 48.8566, 'lng': 2.3522, 'tz': 'Europe/Paris'},
      {'name': 'Dubai, UAE', 'lat': 25.2048, 'lng': 55.2708, 'tz': 'Asia/Dubai'},
      {'name': 'Sydney, Australia', 'lat': -33.8688, 'lng': 151.2093, 'tz': 'Australia/Sydney'},
    ];
    final random = Random();
    final loc = locations[random.nextInt(locations.length)];
    setLocation(loc['lat'] as double, loc['lng'] as double, loc['name'] as String, loc['tz'] as String);
  }

  void setCustomLocation(double lat, double lon, String name, String tz) {
    _latitude = lat;
    _longitude = lon;
    _locationName = name;
    _timezone = tz;
    if (_locationSpoofEnabled) {
      _injectLocationSpoof();
    }
    notifyListeners();
  }

  Future<void> _injectLocationSpoof() async {
    if (!kIsWeb) {
      try {
        await Process.run('sudo', ['timedatectl', 'set-timezone', _timezone]);
      } catch (e) {
        debugPrint('Location spoof failed: $e');
      }
    }
  }

  // Fingerprint Rotation Methods
  void toggleFingerprintRotation() {
    _fingerprintRotationEnabled = !_fingerprintRotationEnabled;
    if (_fingerprintRotationEnabled) {
      _startFingerprintRotation();
    } else {
      _stopFingerprintRotation();
    }
    notifyListeners();
  }

  void _startFingerprintRotation() {
    _rotateFingerprint();
    _fingerprintTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      _rotateFingerprint();
    });
  }

  void _stopFingerprintRotation() {
    _fingerprintTimer?.cancel();
  }

  void _rotateFingerprint() {
    final random = Random();
    final userAgents = [
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:121.0) Gecko/20100101 Firefox/121.0',
      'Mozilla/5.0 (Macintosh; Intel Mac OS X 14_2) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.2 Safari/605.1.15',
      'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
    ];

    _userAgent = userAgents[random.nextInt(userAgents.length)];

    if (_userAgent.contains('Chrome')) _browser = 'Chrome';
    else if (_userAgent.contains('Firefox')) _browser = 'Firefox';
    else if (_userAgent.contains('Safari')) _browser = 'Safari';

    if (_userAgent.contains('Windows')) _os = 'Windows 10';
    else if (_userAgent.contains('Macintosh')) _os = 'macOS';
    else if (_userAgent.contains('Linux')) _os = 'Linux';

    final languages = ['en-US', 'en-GB', 'de-DE', 'fr-FR', 'es-ES', 'ja-JP'];
    _language = languages[random.nextInt(languages.length)];

    final resolutions = ['1920x1080', '2560x1440', '3840x2160', '1366x768', '1440x900'];
    _screenResolution = resolutions[random.nextInt(resolutions.length)];

    _hardwareConcurrency = [2, 4, 6, 8, 12, 16][random.nextInt(6)];
    _deviceMemory = [4, 8, 16, 32][random.nextInt(4)];

    notifyListeners();
  }

  // DNS Rotation Methods
  void toggleDNSRotation() {
    _dnsRotationEnabled = !_dnsRotationEnabled;
    if (_dnsRotationEnabled) {
      _startDNSRotation();
    } else {
      _stopDNSRotation();
    }
    notifyListeners();
  }

  void _startDNSRotation() {
    _rotateDNS();
    _dnsTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      _rotateDNS();
    });
  }

  void _stopDNSRotation() {
    _dnsTimer?.cancel();
  }

  Future<void> _rotateDNS() async {
    final dnsServers = ['1.1.1.1', '8.8.8.8', '9.9.9.9', '208.67.222.222', '94.140.14.14'];
    final random = Random();
    _currentDNS = dnsServers[random.nextInt(dnsServers.length)];

    if (!kIsWeb) {
      try {
        await Process.run('sudo', ['bash', '-c', 'echo "nameserver $_currentDNS" > /etc/resolv.conf']);
      } catch (e) {
        debugPrint('DNS rotation failed: $e');
      }
    }

    notifyListeners();
  }

  // Other Methods
  void toggleWebRTCProtection() {
    _webrtcProtection = !_webrtcProtection;
    notifyListeners();
  }

  void toggleCanvasNoise() {
    _canvasNoiseEnabled = !_canvasNoiseEnabled;
    notifyListeners();
  }

  void toggleAudioNoise() {
    _audioNoiseEnabled = !_audioNoiseEnabled;
    notifyListeners();
  }

  void toggleBatterySpoof() {
    _batterySpoofEnabled = !_batterySpoofEnabled;
    if (_batterySpoofEnabled) {
      final random = Random();
      _batteryLevel = random.nextInt(100) + 1;
      _batteryCharging = random.nextBool();
    }
    notifyListeners();
  }

  void enableAllProtections() {
    _ipRotationEnabled = true;
    _locationSpoofEnabled = true;
    _fingerprintRotationEnabled = true;
    _dnsRotationEnabled = true;
    _webrtcProtection = true;
    _canvasNoiseEnabled = true;
    _audioNoiseEnabled = true;
    _batterySpoofEnabled = true;

    _startIPRotation();
    _startFingerprintRotation();
    _startDNSRotation();
    _injectLocationSpoof();

    notifyListeners();
  }

  void disableAllProtections() {
    _ipRotationEnabled = false;
    _locationSpoofEnabled = false;
    _fingerprintRotationEnabled = false;
    _dnsRotationEnabled = false;

    _stopIPRotation();
    _stopFingerprintRotation();
    _stopDNSRotation();

    notifyListeners();
  }

  @override
  void dispose() {
    _stopIPRotation();
    _stopFingerprintRotation();
    _stopDNSRotation();
    _locationTimer?.cancel();
    super.dispose();
  }
}
