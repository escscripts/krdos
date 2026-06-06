import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/mesh_engine.dart';
import '../models/device_model.dart';
import '../ui/mesh_tokens.dart';
import '../widgets/camera_operator_deck.dart';
import '../widgets/drone_operator_deck.dart';
import '../widgets/lab_ethics_banner.dart';
import '../widgets/sensor_operator_deck.dart';

class DeviceDetailScreen extends StatefulWidget {
  const DeviceDetailScreen({Key? key}) : super(key: key);

  @override
  State<DeviceDetailScreen> createState() => _DeviceDetailScreenState();
}

class _DeviceDetailScreenState extends State<DeviceDetailScreen> {
  MeshDevice? selectedDevice;

  @override
  Widget build(BuildContext context) {
    return Consumer<MeshEngine>(
      builder: (context, meshEngine, child) {
        return Scaffold(
          backgroundColor: MeshTokens.bg(),
          body: selectedDevice == null
              ? _buildDeviceList(meshEngine)
              : _buildDeviceDetail(meshEngine),
        );
      },
    );
  }

  Widget _buildDeviceList(MeshEngine meshEngine) {
    if (meshEngine.devices.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.devices_other, size: 64, color: Colors.grey.shade700),
            const SizedBox(height: 16),
            const Text(
              'No devices found',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    final sortedDevices = meshEngine.devices.values.toList()
      ..sort((a, b) => a.status.index.compareTo(b.status.index));

    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: sortedDevices.length,
      itemBuilder: (context, index) {
        final device = sortedDevices[index];
        return _buildDeviceListTile(device);
      },
    );
  }

  Widget _buildDeviceListTile(MeshDevice device) {
    return GestureDetector(
      onTap: () => setState(() => selectedDevice = device),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          border: Border.all(color: device.statusColor.withValues(alpha: 0.3)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: device.statusColor.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(device.typeIcon, color: device.statusColor, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    device.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${device.type.name.capitalize()} ? ${device.protocolLabel}',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 11),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.signal_cellular_alt,
                        size: 12,
                        color: Colors.cyan,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${device.signalStrength.toStringAsFixed(0)} dBm',
                        style: TextStyle(
                          color: Colors.grey.shade700,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: device.statusColor.withValues(alpha: 0.2),
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
      ),
    );
  }

  Widget _buildDeviceDetail(MeshEngine meshEngine) {
    final device = selectedDevice!;

    return DefaultTabController(
      key: ValueKey(device.id),
      length: 3,
      child: Column(
        children: [
          _detailChrome(device),
          TabBar(
            labelColor: MeshTokens.accent(),
            unselectedLabelColor: MeshTokens.textSecondary(),
            indicatorColor: MeshTokens.accent(),
            dividerColor: MeshTokens.border().withValues(alpha: 0.35),
            tabs: [
              const Tab(icon: Icon(Icons.info_outline_rounded), text: 'Overview'),
              Tab(
                icon: Icon(_operatorTabIcon(device.type)),
                text: _operatorTabLabel(device.type),
              ),
              const Tab(icon: Icon(Icons.biotech_rounded), text: 'Rf lab hooks'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                SingleChildScrollView(child: _overviewBody(device)),
                KeyedSubtree(
                  key: ValueKey('ops-${device.id}'),
                  child: _operatorDeck(device),
                ),
                _labHooks(meshEngine, device),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailChrome(MeshDevice device) {
    return Container(
      padding: const EdgeInsets.fromLTRB(4, 8, 8, 8),
      decoration: BoxDecoration(
        color: MeshTokens.elevated(),
        border: Border(bottom: MeshTokens.hairlineBorder()),
      ),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.arrow_back_ios_new_rounded, color: MeshTokens.textSecondary()),
            onPressed: () => setState(() => selectedDevice = null),
          ),
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: device.statusColor.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(device.typeIcon, color: device.statusColor, size: 28),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  device.name,
                  style: TextStyle(
                    color: MeshTokens.textPrimary(),
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
                Row(
                  children: [
                    Icon(Icons.lens_rounded, size: 10, color: device.statusColor),
                    const SizedBox(width: 6),
                    Text(
                      device.status.name.toUpperCase(),
                      style: TextStyle(
                        color: device.statusColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Chip(
            backgroundColor: MeshTokens.accentMuted(),
            avatar: Icon(device.typeIcon, size: 16, color: MeshTokens.accent()),
            label: Text(
              device.type.name.capitalize(),
              style: TextStyle(color: MeshTokens.accent()),
            ),
          ),
        ],
      ),
    );
  }

  Widget _overviewBody(MeshDevice device) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 10),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 14),
          child: LabEthicsBanner(dense: true),
        ),
        _buildInfoSection('Basic Information', [
          ('ID', device.id),
          ('Class', '${device.type.name.capitalize()} ? ${device.protocolLabel}'),
          ('Address', device.address),
        ]),
        _buildInfoSection('Connectivity', [
          (
            'Signal Strength',
            '${device.signalStrength.toStringAsFixed(1)} dBm',
          ),
          ('Hop Distance', '${device.hopDistance}'),
          ('Battery', '${device.batteryPercent}%'),
          ('Last Seen', device.lastSeen.split('.').first),
        ]),
        if (device.latitude != 0 || device.longitude != 0)
          _buildInfoSection('Location', [
            ('Latitude', device.latitude.toStringAsFixed(4)),
            ('Longitude', device.longitude.toStringAsFixed(4)),
          ]),
        Container(
          margin: const EdgeInsets.all(12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: MeshTokens.surface().withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: MeshTokens.border()),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Signal silhouette',
                style: TextStyle(
                  color: MeshTokens.textPrimary(),
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 72,
                child: CustomPaint(
                  painter: SignalGraphPainter(device.signalStrength),
                ),
              ),
            ],
          ),
        ),
        if (device.metadata.isNotEmpty)
          _buildInfoSection('Metadata', [
            ...device.metadata.entries.map((e) => (e.key, e.value.toString())),
          ]),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _operatorDeck(MeshDevice device) {
    switch (device.type) {
      case DeviceType.drone:
        return DroneOperatorDeck(device: device);
      case DeviceType.camera:
        return CameraOperatorDeck(device: device);
      case DeviceType.sensor:
        return SensorOperatorDeck(device: device);
      default:
        return _GatewayOperatorDeck(device: device);
    }
  }

  Widget _labHooks(MeshEngine meshEngine, MeshDevice device) {
    return ListView(
      padding: MeshTokens.screenPadding(),
      children: [
        Text(
          'Replay logical captures as sandbox command frames to ${device.name}.',
          style: TextStyle(color: MeshTokens.textSecondary(), fontSize: 11),
        ),
        const SizedBox(height: 12),
        if (meshEngine.rfLabCaptures.isEmpty)
          Text(
            'Import traces in Signal Lab (sidebar) from your host RF bridge.',
            style: TextStyle(color: MeshTokens.textSecondary()),
          ),
        ...meshEngine.rfLabCaptures.take(24).map(
              (cap) => Card(
                color: MeshTokens.elevated(),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: MeshTokens.border()),
                ),
                child: ListTile(
                  title: Text(cap.title,
                      style: TextStyle(color: MeshTokens.textPrimary())),
                  subtitle: Text(
                    '${cap.normalizedHex.length ~/ 2} bytes',
                    style: TextStyle(color: MeshTokens.textSecondary(), fontSize: 11),
                  ),
                  trailing: IconButton(
                    tooltip: 'Replay (sandbox)',
                    icon: Icon(Icons.play_arrow_rounded, color: MeshTokens.accent()),
                    onPressed: () async {
                      await meshEngine.simulateReplayLabCapture(
                        targetDeviceId: device.id,
                        captureId: cap.id,
                      );
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Replay frame routed to ${device.name} simulator'),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
      ],
    );
  }

  String _operatorTabLabel(DeviceType t) {
    switch (t) {
      case DeviceType.drone:
        return 'Flight deck';
      case DeviceType.camera:
        return 'Optics';
      case DeviceType.sensor:
        return 'Sensor ops';
      case DeviceType.gateway:
        return 'Gateway';
      default:
        return 'Operator';
    }
  }

  IconData _operatorTabIcon(DeviceType t) {
    switch (t) {
      case DeviceType.drone:
        return Icons.flight_rounded;
      case DeviceType.camera:
        return Icons.photo_camera_rounded;
      case DeviceType.sensor:
        return Icons.monitor_heart_outlined;
      case DeviceType.gateway:
        return Icons.router_rounded;
      default:
        return Icons.settings_remote_rounded;
    }
  }

  Widget _buildInfoSection(String title, List<(String, String)> items) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: MeshTokens.surface().withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: MeshTokens.border()),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: MeshTokens.textPrimary(),
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 8),
          ...items.map(
            (item) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    item.$1,
                    style: TextStyle(
                      color: MeshTokens.textSecondary(),
                      fontSize: 11,
                    ),
                  ),
                  Flexible(
                    child: Text(
                      item.$2,
                      style: TextStyle(
                        color: MeshTokens.textPrimary(),
                        fontWeight: FontWeight.w600,
                        fontSize: 11,
                      ),
                      textAlign: TextAlign.end,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GatewayOperatorDeck extends StatelessWidget {
  const _GatewayOperatorDeck({required this.device});

  final MeshDevice device;

  @override
  Widget build(BuildContext context) {
    final mesh = context.watch<MeshEngine>();

    return ListView(
      padding: MeshTokens.screenPadding(),
      children: [
        Text(
          '${device.type.name.capitalize()} operator plane',
          style: TextStyle(
            color: MeshTokens.textPrimary(),
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Bind your daemon to mesh commands exposed here.',
          style: TextStyle(color: MeshTokens.textSecondary(), fontSize: 11),
        ),
        const SizedBox(height: 16),
        FilledButton.tonalIcon(
          onPressed: () => mesh.quickCommand(device.id, 'status', {}),
          icon: Icon(Icons.online_prediction_rounded, color: MeshTokens.accent()),
          label: const Text('Poll gateway status packets'),
          style: FilledButton.styleFrom(backgroundColor: MeshTokens.accentMuted()),
        ),
        const SizedBox(height: 8),
        FilledButton.tonalIcon(
          onPressed: () => mesh.quickCommand(device.id, 'restart', {}),
          icon: Icon(Icons.power_settings_new_rounded, color: MeshTokens.warning()),
          label: const Text('Controlled restart relay'),
          style: FilledButton.styleFrom(backgroundColor: MeshTokens.surface()),
        ),
      ],
    );
  }
}

class SignalGraphPainter extends CustomPainter {
  final double signal;

  SignalGraphPainter(this.signal);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.cyan
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

  // Normalize signal (-120 to -30) to canvas height
    final normalized = ((signal + 120) / 90 * size.height).clamp(
      0,
      size.height,
    );

    final path = Path();
    path.moveTo(0, size.height);
    for (double x = 0; x < size.width; x += 10) {
      path.lineTo(x, size.height - normalized + (x % 40 - 20) / 20);
    }
    path.lineTo(size.width, size.height);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

extension _StringExt on String {
  String capitalize() {
    if (isEmpty) return this;
    return '${this[0].toUpperCase()}${substring(1)}';
  }
}