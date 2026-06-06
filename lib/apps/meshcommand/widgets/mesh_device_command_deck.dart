import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/mesh_engine.dart';
import '../models/device_model.dart';
import '../models/hardware_tool_profile.dart';
import '../ui/mesh_tokens.dart';

/// Right-rail operator deck: one tab per control surface (daemon hooks land on these IDs).
class MeshDeviceCommandDeck extends StatefulWidget {
  const MeshDeviceCommandDeck({
    super.key,
    required this.device,
    required this.onClose,
  });

  final MeshDevice device;
  final VoidCallback onClose;

  @override
  State<MeshDeviceCommandDeck> createState() => _MeshDeviceCommandDeckState();
}

class _MeshDeviceCommandDeckState extends State<MeshDeviceCommandDeck>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    final n = MeshHardwareProfiles.surfacesForDeviceType(widget.device.type).length;
    _tabController = TabController(length: n, vsync: this);
  }

  @override
  void didUpdateWidget(MeshDeviceCommandDeck oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.device.id != widget.device.id ||
        oldWidget.device.type != widget.device.type) {
      _tabController.dispose();
      final n = MeshHardwareProfiles.surfacesForDeviceType(widget.device.type).length;
      _tabController = TabController(length: n, vsync: this);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final surfaces = MeshHardwareProfiles.surfacesForDeviceType(widget.device.type);
    final mesh = context.watch<MeshEngine>();

    return Material(
      color: MeshTokens.surface(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _header(),
          Container(
            decoration: BoxDecoration(
              color: MeshTokens.elevated(),
              border: Border(bottom: MeshTokens.hairlineBorder()),
            ),
            child: TabBar(
              controller: _tabController,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              labelColor: MeshTokens.accent(),
              unselectedLabelColor: MeshTokens.textSecondary(),
              indicatorColor: MeshTokens.accent(),
              indicatorWeight: 2,
              dividerColor: Colors.transparent,
              tabs: surfaces.map((s) => Tab(height: 40, text: s.label)).toList(),
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                for (var i = 0; i < surfaces.length; i++)
                  _SurfacePane(
                    surface: surfaces[i],
                    device: widget.device,
                    meshEngine: mesh,
                    quickActionsSlot: i == 0 ? _quickActions(mesh) : null,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _header() {
    final d = widget.device;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            MeshTokens.elevated(),
            MeshTokens.surface(),
          ],
        ),
        border: Border(bottom: MeshTokens.hairlineBorder()),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: MeshTokens.accentMuted(),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(d.typeIcon, color: MeshTokens.accent(), size: 22),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  d.name,
                  style: TextStyle(
                    color: MeshTokens.textPrimary(),
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '${d.protocolLabel} · ${d.address}',
                  style: TextStyle(
                    color: MeshTokens.textSecondary(),
                    fontSize: 11,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Close deck',
            onPressed: widget.onClose,
            icon: Icon(Icons.close, color: MeshTokens.textSecondary()),
          ),
        ],
      ),
    );
  }

  Widget _quickActions(MeshEngine meshEngine) {
    switch (widget.device.type) {
      case DeviceType.drone:
        return _DroneQuickStrip(meshEngine: meshEngine, device: widget.device);
      case DeviceType.camera:
        return _CameraQuickStrip(meshEngine: meshEngine, device: widget.device);
      case DeviceType.sensor:
        return _SensorQuickStrip(meshEngine: meshEngine, device: widget.device);
      default:
        return _GenericQuickStrip(device: widget.device);
    }
  }
}

class _SurfacePane extends StatelessWidget {
  const _SurfacePane({
    required this.surface,
    required this.device,
    required this.meshEngine,
    this.quickActionsSlot,
  });

  final ControlSurfaceDef surface;
  final MeshDevice device;
  final MeshEngine meshEngine;
  final Widget? quickActionsSlot;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: MeshTokens.screenPadding(),
      children: [
        if (quickActionsSlot != null) ...[
          quickActionsSlot!,
          const SizedBox(height: 16),
        ],
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: MeshTokens.elevated(),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: MeshTokens.border()),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(surface.icon, size: 20, color: MeshTokens.accent()),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      surface.label,
                      style: TextStyle(
                        color: MeshTokens.textPrimary(),
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                surface.description,
                style: TextStyle(
                  color: MeshTokens.textSecondary(),
                  fontSize: 12,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 14),
              _DaemonStub(surfaceId: surface.id, deviceId: device.id),
            ],
          ),
        ),
      ],
    );
  }
}

class _DaemonStub extends StatelessWidget {
  const _DaemonStub({
    required this.surfaceId,
    required this.deviceId,
  });

  final String surfaceId;
  final String deviceId;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: MeshTokens.surface(),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: MeshTokens.border().withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Icon(Icons.extension, size: 16, color: MeshTokens.warning()),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Daemon hook `$surfaceId` ? device `$deviceId` (bind serial / socket from host OS)',
              style: TextStyle(
                fontSize: 11,
                color: MeshTokens.textSecondary(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DroneQuickStrip extends StatelessWidget {
  const _DroneQuickStrip({
    required this.meshEngine,
    required this.device,
  });

  final MeshEngine meshEngine;
  final MeshDevice device;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        meshQuickPill(context, Icons.flight_takeoff, 'Takeoff', () {
          meshEngine.quickCommand(device.id, 'takeoff', {'altitude': '60'});
          _meshToast(context, 'takeoff queued');
        }),
        meshQuickPill(context, Icons.flight_land, 'Land', () {
          meshEngine.quickCommand(device.id, 'land', {});
          _meshToast(context, 'land queued');
        }),
        meshQuickPill(context, Icons.pause_circle_filled_outlined, 'Hover', () {
          meshEngine.quickCommand(device.id, 'hover', {'duration': '30'});
          _meshToast(context, 'hover queued');
        }),
        meshQuickPill(context, Icons.videocam_outlined, 'Record', () {
          meshEngine.quickCommand(device.id, 'record', {'action': 'on'});
          _meshToast(context, 'record');
        }),
      ],
    );
  }
}

class _CameraQuickStrip extends StatelessWidget {
  const _CameraQuickStrip({
    required this.meshEngine,
    required this.device,
  });

  final MeshEngine meshEngine;
  final MeshDevice device;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        meshQuickPill(context, Icons.play_circle_outline, 'Rec on', () {
          meshEngine.quickCommand(device.id, 'record', {'action': 'on'});
          _meshToast(context, 'recording on');
        }),
        meshQuickPill(context, Icons.photo_camera_outlined, 'Still', () {
          meshEngine.quickCommand(device.id, 'photo', {});
          _meshToast(context, 'still capture');
        }),
      ],
    );
  }
}

class _SensorQuickStrip extends StatelessWidget {
  const _SensorQuickStrip({
    required this.meshEngine,
    required this.device,
  });

  final MeshEngine meshEngine;
  final MeshDevice device;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        meshQuickPill(context, Icons.thermostat, 'Temp', () {
          meshEngine.quickCommand(device.id, 'read_temp', {});
          _meshToast(context, 'temperature read');
        }),
        meshQuickPill(context, Icons.water_drop_outlined, 'Humidity', () {
          meshEngine.quickCommand(device.id, 'read_humidity', {});
          _meshToast(context, 'humidity read');
        }),
      ],
    );
  }
}

class _GenericQuickStrip extends StatelessWidget {
  const _GenericQuickStrip({
    required this.device,
  });

  final MeshDevice device;

  @override
  Widget build(BuildContext context) {
    return Text(
      'Node `${device.name}` (${device.type.name}) exposes gateway-style surfaces. Bind daemons under each tab header for full operator control.',
      style: TextStyle(color: MeshTokens.textSecondary(), fontSize: 11),
    );
  }
}

Widget meshQuickPill(BuildContext context, IconData icon, String label, VoidCallback onTap) {
  return FilledButton.tonal(
    style: FilledButton.styleFrom(
      backgroundColor: MeshTokens.accentMuted(),
      foregroundColor: MeshTokens.accent(),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    ),
    onPressed: onTap,
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16),
        const SizedBox(width: 6),
        Text(label),
      ],
    ),
  );
}

void _meshToast(BuildContext ctx, String m) {
  ScaffoldMessenger.maybeOf(ctx)?.showSnackBar(
    SnackBar(content: Text(m), duration: const Duration(seconds: 1)),
  );
}
