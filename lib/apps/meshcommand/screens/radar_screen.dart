import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../core/mesh_engine.dart';
import '../models/device_model.dart';
import '../ui/mesh_tokens.dart';

class RadarScreen extends StatefulWidget {
  const RadarScreen({Key? key}) : super(key: key);

  @override
  State<RadarScreen> createState() => _RadarScreenState();
}

class _RadarScreenState extends State<RadarScreen>
    with TickerProviderStateMixin {
  late AnimationController _sweepController;
  late AnimationController _pulseController;
  double _sweepAngle = 0;
  MeshDevice? _selectedDevice;
  bool _showDevicePanel = false;
  bool _scanningForDevices = false;

  @override
  void initState() {
    super.initState();
    _sweepController = AnimationController(
      duration: const Duration(seconds: 4),
      vsync: this,
    )..repeat();

    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat();

    _sweepController.addListener(() {
      setState(() {
        _sweepAngle = _sweepController.value * 2 * math.pi;
      });
    });
  }

  @override
  void dispose() {
    _sweepController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<MeshEngine>(
      builder: (context, meshEngine, child) {
        return Scaffold(
          backgroundColor: MeshTokens.bg(),
          body: Stack(
            children: [
  // Main radar interface
              Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: Wrap(
                        spacing: 10,
                        alignment: WrapAlignment.end,
                        children: [
                          _buildScanButton(),
                          _buildConnectButton(),
                        ],
                      ),
                    ),
                  ),

  // Radar Display
                  Expanded(
                    child: Row(
                      children: [
  // Radar visualization
                        Expanded(
                          flex: 3,
                          child: Center(
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
  // Background circles and grid
                                _buildRadarGrid(),

  // Sweep animation
                                _buildRadarSweep(),

  // Device markers
                                ..._buildDeviceMarkers(meshEngine),

  // Center indicator
                                Container(
                                  width: 16,
                                  height: 16,
                                  decoration: BoxDecoration(
                                    color: Colors.green,
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.green.withOpacity(0.5),
                                        blurRadius: 12,
                                      ),
                                    ],
                                  ),
                                ),

  // Scanning indicator
                                if (_scanningForDevices)
                                  Container(
                                    width: 100,
                                    height: 100,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF7B68FF).withOpacity(0.1),
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: const Color(0xFF7B68FF),
                                        width: 2,
                                      ),
                                    ),
                                    child: const Center(
                                      child: Text(
                                        'SCANNING...',
                                        style: TextStyle(
                                          color: Color(0xFF7B68FF),
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ).animate().scale(duration: 1.seconds, curve: Curves.easeInOut),
                              ],
                            ),
                          ),
                        ),

  // Device list panel
                        Container(
                          width: 300,
                          decoration: BoxDecoration(
                            color: const Color(0xFF1A1A1A),
                            border: Border(
                              left: BorderSide(color: Colors.white.withOpacity(0.08)),
                            ),
                          ),
                          child: Column(
                            children: [
  // Panel header
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  border: Border(
                                    bottom: BorderSide(color: Colors.white.withOpacity(0.08)),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    const Text(
                                      'Connected Devices',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const Spacer(),
                                    Text(
                                      '${meshEngine.devices.length}',
                                      style: TextStyle(
                                        color: const Color(0xFF7B68FF),
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),

  // Device list
                              Expanded(
                                child: meshEngine.devices.isEmpty
                                    ? _buildEmptyState()
                                    : ListView(
                                        padding: const EdgeInsets.all(8),
                                        children: meshEngine.devices.values
                                            .map((device) => _buildDeviceListItem(device))
                                            .toList(),
                                      ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

  // Device control panel (slides in from right)
              if (_showDevicePanel && _selectedDevice != null)
                Positioned(
                  right: 0,
                  top: 0,
                  bottom: 0,
                  width: 400,
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A1A1A),
                      border: Border(
                        left: BorderSide(color: Colors.white.withOpacity(0.08)),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 10,
                          offset: const Offset(-5, 0),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
  // Panel header
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            border: Border(
                              bottom: BorderSide(color: Colors.white.withOpacity(0.08)),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                _selectedDevice!.typeIcon,
                                color: _selectedDevice!.statusColor,
                                size: 24,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _selectedDevice!.name,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(
                                      _selectedDevice!.protocolLabel,
                                      style: TextStyle(
                                        color: Colors.white.withOpacity(0.6),
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.close,
                                  color: Colors.white,
                                  size: 20,
                                ),
                                onPressed: () => setState(() => _showDevicePanel = false),
                              ),
                            ],
                          ),
                        ),

  // Device controls
                        Expanded(
                          child: _buildDeviceControls(_selectedDevice!),
                        ),
                      ],
                    ),
                  ).animate().slideX(begin: 1, end: 0, duration: 300.ms),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildScanButton() {
    return ElevatedButton.icon(
      onPressed: _scanningForDevices ? null : _startDeviceScan,
      style: ElevatedButton.styleFrom(
        backgroundColor: _scanningForDevices
            ? Colors.grey.withOpacity(0.2)
            : const Color(0xFF7B68FF).withOpacity(0.2),
        foregroundColor: _scanningForDevices
            ? Colors.grey
            : const Color(0xFF7B68FF),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      icon: _scanningForDevices
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.radar, size: 16),
      label: Text(_scanningForDevices ? 'Scanning...' : 'Scan Network'),
    );
  }

  Widget _buildConnectButton() {
    return ElevatedButton.icon(
      onPressed: () => _showDeviceConnectionDialog(),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.green.withOpacity(0.2),
        foregroundColor: Colors.green,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      icon: const Icon(Icons.add_link, size: 16),
      label: const Text('Connect Device'),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.device_unknown,
            color: Colors.white.withOpacity(0.3),
            size: 48,
          ),
          const SizedBox(height: 16),
          Text(
            'No devices detected',
            style: TextStyle(
              color: Colors.white.withOpacity(0.6),
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Use "Scan Network" to discover devices',
            style: TextStyle(
              color: Colors.white.withOpacity(0.4),
              fontSize: 12,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildRadarGrid() {
    return CustomPaint(painter: RadarGridPainter(), size: const Size(500, 500));
  }

  Widget _buildRadarSweep() {
    return Transform.rotate(
      angle: _sweepAngle,
      child: SizedBox(
        width: 500,
        height: 500,
        child: CustomPaint(painter: RadarSweepPainter()),
      ),
    );
  }

  List<Widget> _buildDeviceMarkers(MeshEngine meshEngine) {
    final markers = <Widget>[];
    const radarRadius = 250.0;

    for (final device in meshEngine.devices.values) {
  // Convert signal strength to distance (closer = stronger signal)
      final distance = (device.signalStrength + 120) / 90 * radarRadius;

  // Use device coordinates if available, otherwise random angle
      final angle = device.latitude != 0 || device.longitude != 0
          ? math.atan2(device.longitude, device.latitude)
          : math.Random().nextDouble() * 2 * math.pi;

      final x = distance * math.sin(angle);
      final y = distance * math.cos(angle);

      markers.add(
        Positioned(
          left: 250 + x - 12,
          top: 250 + y - 12,
          child: _buildDeviceMarker(device),
        ),
      );
    }

    return markers;
  }

  Widget _buildDeviceMarker(MeshDevice device) {
    final isSelected = _selectedDevice?.id == device.id;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedDevice = device;
          _showDevicePanel = true;
        });
      },
      child: AnimatedBuilder(
        animation: _pulseController,
        builder: (context, child) {
          return Transform.scale(
            scale: isSelected ? 1.2 : 0.8 + (_pulseController.value * 0.2),
            child: Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: device.statusColor,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? Colors.white : Colors.white.withOpacity(0.5),
                  width: isSelected ? 3 : 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: device.statusColor.withOpacity(0.6),
                    blurRadius: isSelected ? 16 : 8,
                  ),
                ],
              ),
              child: Icon(device.typeIcon, size: 12, color: Colors.white),
            ),
          );
        },
      ),
    );
  }

  Widget _buildDeviceListItem(MeshDevice device) {
    final isSelected = _selectedDevice?.id == device.id;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isSelected
            ? const Color(0xFF7B68FF).withOpacity(0.2)
            : Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isSelected
              ? const Color(0xFF7B68FF)
              : device.statusColor.withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(device.typeIcon, color: device.statusColor, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  device.name,
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '${device.signalStrength.toStringAsFixed(0)} dBm ? ${device.protocolLabel} ? Hops: ${device.hopDistance}',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.6),
                    fontSize: 11,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: device.statusColor.withOpacity(0.2),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              device.status.name.toUpperCase(),
              style: TextStyle(
                color: device.statusColor,
                fontSize: 9,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeviceControls(MeshDevice device) {
    switch (device.type) {
      case DeviceType.drone:
        return _buildDroneControls(device);
      case DeviceType.camera:
        return _buildCameraControls(device);
      case DeviceType.sensor:
        return _buildSensorControls(device);
      default:
        return _buildGenericControls(device);
    }
  }

  Widget _buildDroneControls(MeshDevice device) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildControlSection('Flight Control', [
          _buildActionButton('Take Off', Icons.flight_takeoff, () {
  // Send takeoff command
          }),
          _buildActionButton('Land', Icons.flight_land, () {
  // Send land command
          }),
          _buildActionButton('Hover', Icons.pause_circle, () {
  // Send hover command
          }),
        ]),
        const SizedBox(height: 24),
        _buildControlSection('Navigation', [
          _buildActionButton('Go Home', Icons.home, () {
  // Send return home command
          }),
          _buildActionButton('Follow Me', Icons.person, () {
  // Send follow command
          }),
          _buildLocationInput(),
        ]),
        const SizedBox(height: 24),
        _buildControlSection('Camera', [
          _buildActionButton('Start Recording', Icons.videocam, () {
  // Send record command
          }),
          _buildActionButton('Take Photo', Icons.camera, () {
  // Send photo command
          }),
        ]),
      ],
    );
  }

  Widget _buildCameraControls(MeshDevice device) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
  // Live camera feed placeholder
        Container(
          height: 200,
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Center(
            child: Icon(
              Icons.videocam_off,
              color: Colors.white54,
              size: 48,
            ),
          ),
        ),
        const SizedBox(height: 16),
        _buildControlSection('Recording', [
          _buildActionButton('Start Recording', Icons.videocam, () {
  // Send record command
          }),
          _buildActionButton('Stop Recording', Icons.stop, () {
  // Send stop command
          }),
          _buildActionButton('Take Photo', Icons.camera, () {
  // Send photo command
          }),
        ]),
        const SizedBox(height: 24),
        _buildControlSection('Controls', [
          _buildSliderControl('Zoom', 1.0, 10.0, 1.0, (value) {
  // Send zoom command
          }),
          _buildSliderControl('Pan', -180, 180, 0, (value) {
  // Send pan command
          }),
          _buildSliderControl('Tilt', -90, 90, 0, (value) {
  // Send tilt command
          }),
        ]),
      ],
    );
  }

  Widget _buildSensorControls(MeshDevice device) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildControlSection('Readings', [
          _buildSensorDisplay('Temperature', '24.5°C'),
          _buildSensorDisplay('Humidity', '65%'),
          _buildSensorDisplay('Pressure', '1013 hPa'),
          _buildSensorDisplay('Light', '450 lux'),
        ]),
        const SizedBox(height: 24),
        _buildControlSection('Actions', [
          _buildActionButton('Calibrate', Icons.tune, () {
  // Send calibrate command
          }),
          _buildActionButton('Reset', Icons.refresh, () {
  // Send reset command
          }),
        ]),
      ],
    );
  }

  Widget _buildGenericControls(MeshDevice device) {
    return const Center(
      child: Text(
        'Device controls not available',
        style: TextStyle(color: Colors.white54),
      ),
    );
  }

  Widget _buildControlSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        ...children,
      ],
    );
  }

  Widget _buildActionButton(String label, IconData icon, VoidCallback onPressed) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF7B68FF).withOpacity(0.1),
          foregroundColor: const Color(0xFF7B68FF),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18),
            const SizedBox(width: 8),
            Text(label),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationInput() {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Go to Location',
            style: TextStyle(
              color: Colors.white,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Lat, Lon',
                    hintStyle: TextStyle(color: Colors.white.withOpacity(0.4)),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.05),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () {
  // Send goto command
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF7B68FF),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                child: const Text('Go'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSliderControl(String label, double min, double max, double value, ValueChanged<double> onChanged) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                ),
              ),
              Text(
                value.toStringAsFixed(1),
                style: TextStyle(
                  color: Colors.white.withOpacity(0.6),
                  fontSize: 12,
                ),
              ),
            ],
          ),
          Slider(
            value: value,
            min: min,
            max: max,
            onChanged: onChanged,
            activeColor: const Color(0xFF7B68FF),
          ),
        ],
      ),
    );
  }

  Widget _buildSensorDisplay(String label, String value) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Color(0xFF7B68FF),
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  void _startDeviceScan() {
    setState(() => _scanningForDevices = true);

  // Simulate device discovery
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() => _scanningForDevices = false);
  // Add mock devices for demo
        final meshEngine = context.read<MeshEngine>();
        meshEngine.registerDevice(MeshDevice(
          id: 'drone-001',
          name: 'Recon Drone Alpha',
          type: DeviceType.drone,
          protocol: ProtocolType.lora,
          address: 'AA:BB:CC:DD:EE:FF',
          signalStrength: -45,
          hopDistance: 1,
          batteryPercent: 85,
          latitude: 37.7749,
          longitude: -122.4194,
          status: DeviceStatus.online,
        ));
      }
    });
  }

  void _showDeviceConnectionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text(
          'Connect New Device',
          style: TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildConnectionOption('WiFi Device', Icons.wifi, () {
              Navigator.pop(context);
              _connectWifiDevice();
            }),
            const SizedBox(height: 12),
            _buildConnectionOption('LoRa Device', Icons.satellite, () {
              Navigator.pop(context);
              _connectLoraDevice();
            }),
            const SizedBox(height: 12),
            _buildConnectionOption('Bluetooth Device', Icons.bluetooth, () {
              Navigator.pop(context);
              _connectBluetoothDevice();
            }),
            const SizedBox(height: 12),
            _buildConnectionOption('Sub-GHz Device', Icons.radio, () {
              Navigator.pop(context);
              _connectSubGHzDevice();
            }),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  Widget _buildConnectionOption(String label, IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(icon, color: const Color(0xFF7B68FF), size: 24),
            const SizedBox(width: 12),
            Text(
              label,
              style: const TextStyle(color: Colors.white, fontSize: 14),
            ),
            const Spacer(),
            const Icon(
              Icons.chevron_right,
              color: Colors.white54,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  void _connectWifiDevice() {
  // Implement WiFi device connection
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('WiFi device connection not implemented yet')),
    );
  }

  void _connectLoraDevice() {
  // Implement LoRa device connection
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('LoRa device connection not implemented yet')),
    );
  }

  void _connectBluetoothDevice() {
  // Implement Bluetooth device connection
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Bluetooth device connection not implemented yet')),
    );
  }

  void _connectSubGHzDevice() {
  // Implement Sub-GHz device connection
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Sub-GHz device connection not implemented yet')),
    );
  }
}

// Custom painters for radar visualization
class RadarGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5;

  // Concentric circles
    for (int i = 1; i <= 5; i++) {
      canvas.drawCircle(center, (size.width / 2) * (i / 5), paint);
    }

  // Cross hairs
    canvas.drawLine(
      Offset(center.dx, 0),
      Offset(center.dx, size.height),
      paint,
    );
    canvas.drawLine(Offset(0, center.dy), Offset(size.width, center.dy), paint);

  // 45-degree lines
    final diagonal = size.width / math.sqrt2;
    canvas.drawLine(
      Offset(center.dx - diagonal / 2, center.dy - diagonal / 2),
      Offset(center.dx + diagonal / 2, center.dy + diagonal / 2),
      paint,
    );
    canvas.drawLine(
      Offset(center.dx + diagonal / 2, center.dy - diagonal / 2),
      Offset(center.dx - diagonal / 2, center.dy + diagonal / 2),
      paint,
    );

  // Distance labels
    final textPainter = TextPainter(textDirection: TextDirection.ltr);
    for (int i = 1; i <= 5; i++) {
      textPainter.text = TextSpan(
        text: '${i * 20}m',
        style: const TextStyle(color: Colors.grey, fontSize: 10),
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(center.dx + 8, center.dy - (size.width / 2) * (i / 5) - 8),
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class RadarSweepPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    final paint = Paint()
      ..shader = LinearGradient(
        colors: [
          Colors.cyan.withOpacity(0.3),
          Colors.cyan.withOpacity(0),
        ],
      ).createShader(Rect.fromLTWH(center.dx, center.dy, radius, 0));

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      math.pi / 4,
      true,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}