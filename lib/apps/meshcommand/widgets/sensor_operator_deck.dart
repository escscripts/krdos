import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/mesh_engine.dart';
import '../models/device_model.dart';
import '../ui/mesh_tokens.dart';

class SensorOperatorDeck extends StatelessWidget {
  const SensorOperatorDeck({super.key, required this.device});

  final MeshDevice device;

  @override
  Widget build(BuildContext context) {
    final mesh = context.watch<MeshEngine>();

    return ListView(
      padding: MeshTokens.screenPadding(),
      children: [
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _readTile(mesh, Icons.thermostat, 'Temperature',
                () => mesh.quickCommand(device.id, 'read_temp', {})),
            _readTile(mesh, Icons.water_drop_outlined, 'Humidity',
                () => mesh.quickCommand(device.id, 'read_humidity', {})),
            _readTile(mesh, Icons.speed_outlined, 'Pressure',
                () => mesh.quickCommand(device.id, 'read_pressure', {})),
          ],
        ),
        const SizedBox(height: 14),
        FilledButton.tonalIcon(
          onPressed: () => mesh.quickCommand(device.id, 'calibrate', {}),
          icon: Icon(Icons.architecture_rounded, color: MeshTokens.warning()),
          label: const Text('Run calibration ladder'),
          style: FilledButton.styleFrom(backgroundColor: MeshTokens.accentMuted()),
        ),
        const SizedBox(height: 8),
        FilledButton.tonalIcon(
          onPressed: () => mesh.quickCommand(device.id, 'reset', {}),
          icon: Icon(Icons.restart_alt, color: MeshTokens.textSecondary()),
          label: const Text('Factory-ish reset · confirm on device'),
        ),
      ],
    );
  }

  Widget _readTile(MeshEngine mesh, IconData icon, String label, VoidCallback onTap) {
    return ActionChip(
      avatar: Icon(icon, color: MeshTokens.accent()),
      label: Text(label),
      onPressed: onTap,
      backgroundColor: MeshTokens.elevated(),
      shape: StadiumBorder(side: BorderSide(color: MeshTokens.border())),
      labelStyle: TextStyle(color: MeshTokens.textPrimary(), fontSize: 11),
    );
  }
}
