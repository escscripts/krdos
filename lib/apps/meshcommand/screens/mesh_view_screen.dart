import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/mesh_engine.dart';
import '../models/device_model.dart';
import '../ui/mesh_tokens.dart';

class MeshViewScreen extends StatefulWidget {
  const MeshViewScreen({Key? key}) : super(key: key);

  @override
  State<MeshViewScreen> createState() => _MeshViewScreenState();
}

class _MeshViewScreenState extends State<MeshViewScreen> {
  @override
  Widget build(BuildContext context) {
    return Consumer<MeshEngine>(
      builder: (context, meshEngine, child) {
        return Scaffold(
          backgroundColor: MeshTokens.bg(),
          body: Column(
            children: [
  // Network stats
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A1A),
                  border: Border(
                    bottom: BorderSide(
                      color: Colors.white.withValues(alpha: 0.1),
                    ),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _statItem(
                      'Devices',
                      '${meshEngine.devices.length}',
                      Colors.blue,
                    ),
                    _statItem(
                      'Online',
                      '${meshEngine.devices.values.where((d) => d.status == DeviceStatus.online).length}',
                      Colors.green,
                    ),
                    _statItem(
                      'Packets',
                      '${meshEngine.totalPacketsProcessed}',
                      Colors.cyan,
                    ),
                    _statItem(
                      'Encrypted',
                      '${meshEngine.totalEncryptedPackets}',
                      Colors.purple,
                    ),
                  ],
                ),
              ),

  // Graph visualization
              Expanded(
                child: Stack(
                  children: [
                    CustomPaint(
                      painter: MeshGraphPainter(
                        devices: meshEngine.devices.values.toList(),
                        selfDevice: meshEngine.selfDevice,
                      ),
                      size: Size.infinite,
                    ),

  // Device nodes overlay
                    ..._buildDeviceNodes(meshEngine),
                  ],
                ),
              ),

  // Connection info panel
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A1A),
                  border: Border(
                    top: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Network Information',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _infoRow('Total Bandwidth', '~256 kbps'),
                    _infoRow('Latency (avg)', '~145 ms'),
                    _infoRow('Packet Loss', '~2.3%'),
                    _infoRow('Uptime', '2d 14h 32m'),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  List<Widget> _buildDeviceNodes(MeshEngine meshEngine) {
    final nodes = <Widget>[];
    final size = MediaQuery.of(context).size;
    const nodeRadius = 30.0;

  // Center device
    if (meshEngine.selfDevice != null) {
      nodes.add(
        Positioned(
          left: size.width / 2 - nodeRadius / 2,
          top: size.height / 3 - nodeRadius / 2,
          child: _buildNodeWidget(meshEngine.selfDevice!, isCenter: true),
        ),
      );
    }

  // Peripheral devices in ring
    final peripheralCount = meshEngine.devices.length;
    final devices = meshEngine.devices.values.toList();

    for (int i = 0; i < devices.length; i++) {
      final angle = (i / peripheralCount) * 2 * math.pi;
      final radius = 150.0;

      final x = size.width / 2 + radius * math.cos(angle) - nodeRadius / 2;
      final y = size.height / 3 + radius * math.sin(angle) - nodeRadius / 2;

      nodes.add(
        Positioned(left: x, top: y, child: _buildNodeWidget(devices[i])),
      );
    }

    return nodes;
  }

  Widget _buildNodeWidget(MeshDevice device, {bool isCenter = false}) {
    const nodeRadius = 30.0;

    return Tooltip(
      message: '${device.name}\n${device.type.name}',
      child: Container(
        width: nodeRadius,
        height: nodeRadius,
        decoration: BoxDecoration(
          color: isCenter ? Colors.green : device.statusColor,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: isCenter ? 3 : 2),
          boxShadow: [
            BoxShadow(
              color: (isCenter ? Colors.green : device.statusColor).withValues(
                alpha: 0.5,
              ),
              blurRadius: isCenter ? 16 : 8,
            ),
          ],
        ),
        child: Icon(
          device.typeIcon,
          color: Colors.white,
          size: isCenter ? 18 : 16,
        ),
      ),
    );
  }

  Widget _statItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(color: Colors.grey.shade600, fontSize: 11),
        ),
      ],
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class MeshGraphPainter extends CustomPainter {
  final List<MeshDevice> devices;
  final MeshDevice? selfDevice;

  MeshGraphPainter({required this.devices, required this.selfDevice});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

  // Draw connections (simple hub topology)
    final center = Offset(size.width / 2, size.height / 3);
    const radius = 150.0;

    for (int i = 0; i < devices.length; i++) {
      final angle = (i / devices.length) * 2 * math.pi;
      final x = center.dx + radius * math.cos(angle);
      final y = center.dy + radius * math.sin(angle);

  // Connection line
      canvas.drawLine(center, Offset(x, y), paint);
    }

  // Grid background
    final gridPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.02)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5;

    const gridSpacing = 40.0;
    for (double x = 0; x < size.width; x += gridSpacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (double y = 0; y < size.height; y += gridSpacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}