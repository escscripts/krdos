import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import 'core/mesh_engine.dart';
import 'models/device_model.dart';
import 'models/hardware_tool_profile.dart';
import 'screens/command_center_screen.dart';
import 'screens/device_detail_screen.dart';
import 'screens/mesh_view_screen.dart';
import 'screens/protocol_manager_screen.dart';
import 'screens/radar_screen.dart';
import 'screens/signal_lab_screen.dart';
import 'screens/settings_screen.dart';
import 'ui/mesh_tokens.dart';
import 'widgets/mesh_device_command_deck.dart';

/// MeshCommand ? universal mesh hub shell aligned with host OS chrome.
class MeshCommandApp extends StatefulWidget {
  const MeshCommandApp({super.key});

  @override
  State<MeshCommandApp> createState() => _MeshCommandAppState();
}

class _MeshCommandAppState extends State<MeshCommandApp>
    with TickerProviderStateMixin {
  static final List<_MeshSection> _sections = [
    _MeshSection(
      title: 'Radar',
      subtitle: 'Circular sweep & proximity',
      icon: Icons.radar,
      screen: const RadarScreen(),
    ),
    _MeshSection(
      title: 'Mesh view',
      subtitle: 'Node graph',
      icon: Icons.hub_outlined,
      screen: const MeshViewScreen(),
    ),
    _MeshSection(
      title: 'Device detail',
      subtitle: 'Per-node dashboard',
      icon: Icons.devices_rounded,
      screen: const DeviceDetailScreen(),
    ),
    _MeshSection(
      title: 'Command center',
      subtitle: 'Execute mesh commands',
      icon: Icons.terminal_rounded,
      screen: const CommandCenterScreen(),
    ),
    _MeshSection(
      title: 'Signal lab',
      subtitle: 'Traces · codec pad · sandbox replay',
      icon: Icons.biotech_rounded,
      screen: const SignalLabScreen(),
    ),
    _MeshSection(
      title: 'Protocol manager',
      subtitle: 'Multi-radio stacks',
      icon: Icons.settings_input_antenna,
      screen: const ProtocolManagerScreen(),
    ),
    _MeshSection(
      title: 'Settings',
      subtitle: 'Keys · whitelist · alerts',
      icon: Icons.tune_rounded,
      screen: const SettingsScreen(),
    ),
  ];

  int _selectedIndex = 0;
  bool _panelOpen = false;
  MeshDevice? _panelDevice;

  @override
  Widget build(BuildContext context) {
    final mesh = context.watch<MeshEngine>();
    final section = _sections[_selectedIndex];
    final online = mesh.devices.values.where((d) => d.status == DeviceStatus.online).length;
    final encPct = mesh.totalPacketsProcessed == 0
        ? 0.0
        : (mesh.totalEncryptedPackets / mesh.totalPacketsProcessed * 100);

    return Scaffold(
      backgroundColor: MeshTokens.bg(),
      body: Row(
        children: [
          _MeshSidebar(
            sections: _sections,
            selectedIndex: _selectedIndex,
            onSelect: (i) => setState(() => _selectedIndex = i),
            mesh: mesh,
            onOpenDevice: (d) => setState(() {
              _panelDevice = d;
              _panelOpen = true;
            }),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _MeshTopChrome(
                  section: section,
                  online: online,
                  total: mesh.devices.length,
                  encPct: encPct,
                  mesh: mesh,
                  onGhost: (v) => mesh.setGhostMode(v),
                  onEmergencyTap: () => _emergencySheet(context, mesh),
                ),
                Expanded(
                  child: ClipRect(
                    child: IndexedStack(
                      index: _selectedIndex,
                      children: _sections.map((s) => s.screen).toList(),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (_panelOpen && _panelDevice != null)
            SizedBox(
              width: 456,
              child: Material(
                elevation: 8,
                color: MeshTokens.surface(),
                shadowColor: Colors.black54,
                child: MeshDeviceCommandDeck(
                  device: _panelDevice!,
                  onClose: () => setState(() {
                    _panelOpen = false;
                    _panelDevice = null;
                  }),
                ),
              ),
            ).animate().slideX(begin: 1, end: 0, duration: 280.ms, curve: Curves.easeOutCubic),
        ],
      ),
    );
  }

  Future<void> _emergencySheet(BuildContext context, MeshEngine mesh) async {
    if (!mesh.useEmergencyBroadcast) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Arm emergency relay in Protocol / Settings before broadcasting.',
          ),
          backgroundColor: MeshTokens.warning().withValues(alpha: 0.85),
        ),
      );
      return;
    }
    final controller = TextEditingController(text: 'MESH_ALERT');
    final sent = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: MeshTokens.surface(),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Emergency broadcast',
                style: TextStyle(
                  color: MeshTokens.textPrimary(),
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                style: TextStyle(color: MeshTokens.textPrimary()),
                decoration: InputDecoration(
                  labelText: 'Payload',
                  labelStyle: TextStyle(color: MeshTokens.textSecondary()),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: MeshTokens.border()),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: MeshTokens.accent(), width: 1.4),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: MeshTokens.danger(),
                  foregroundColor: Colors.white,
                ),
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Transmit'),
              ),
            ],
          ),
        );
      },
    );
    if (sent == true) {
      await mesh.sendEmergencyBroadcast(controller.text);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Emergency frame staged to mesh'),
            backgroundColor: MeshTokens.danger().withValues(alpha: 0.9),
          ),
        );
      }
    }
    controller.dispose();
  }
}

class _MeshSection {
  const _MeshSection({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.screen,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Widget screen;
}

class _MeshSidebar extends StatelessWidget {
  const _MeshSidebar({
    required this.sections,
    required this.selectedIndex,
    required this.onSelect,
    required this.mesh,
    required this.onOpenDevice,
  });

  final List<_MeshSection> sections;
  final int selectedIndex;
  final ValueChanged<int> onSelect;
  final MeshEngine mesh;
  final ValueChanged<MeshDevice> onOpenDevice;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 268,
      decoration: BoxDecoration(
        color: MeshTokens.surface(),
        border: Border(right: MeshTokens.hairlineBorder()),
        boxShadow: MeshTokens.panelShadow(),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: MeshTokens.accentMuted(),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.hub, color: MeshTokens.accent(), size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'MeshCommand',
                        style: TextStyle(
                          color: MeshTokens.textPrimary(),
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                          letterSpacing: 0.3,
                        ),
                      ),
                      Text(
                        'Mesh · multi-radio · host OS',
                        style: TextStyle(
                          color: MeshTokens.textSecondary(),
                          fontSize: 10,
                          height: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              itemCount: sections.length,
              itemBuilder: (context, index) {
                final s = sections[index];
                final sel = index == selectedIndex;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Material(
                    color: sel ? MeshTokens.accentMuted() : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: () => onSelect(index),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                        child: Row(
                          children: [
                            Icon(
                              s.icon,
                              size: 20,
                              color: sel ? MeshTokens.accent() : MeshTokens.textSecondary(),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    s.title,
                                    style: TextStyle(
                                      color: MeshTokens.textPrimary(),
                                      fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
                                      fontSize: 13,
                                    ),
                                  ),
                                  Text(
                                    s.subtitle,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: MeshTokens.textSecondary(),
                                      fontSize: 10,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (sel)
                              Icon(Icons.chevron_right, size: 18, color: MeshTokens.accent()),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          Divider(height: 1, color: MeshTokens.border().withValues(alpha: 0.35)),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
            child: Text(
              'Hardware roadmap',
              style: TextStyle(
                color: MeshTokens.textSecondary(),
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.6,
              ),
            ),
          ),
          SizedBox(
            height: 108,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
              children: MeshHardwareProfiles.toolkitRoadmap()
                  .map(
                    (e) => ListTile(
                      dense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                      leading: Icon(e.$3, size: 16, color: MeshTokens.accent()),
                      title: Text(
                        e.$2,
                        maxLines: 2,
                        style: TextStyle(color: MeshTokens.textSecondary(), fontSize: 10, height: 1.2),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
          if (mesh.devices.isNotEmpty) ...[
            Divider(height: 1, color: MeshTokens.border().withValues(alpha: 0.35)),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
              child: Text(
                'Quick access',
                style: TextStyle(
                  color: MeshTokens.textSecondary(),
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            ...mesh.devices.values.take(4).map(
                  (d) => ListTile(
                    dense: true,
                    onTap: () => onOpenDevice(d),
                    leading: Icon(d.typeIcon, color: d.statusColor, size: 20),
                    title: Text(
                      d.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: MeshTokens.textPrimary(), fontSize: 12),
                    ),
                    trailing: Icon(Icons.open_in_new, size: 14, color: MeshTokens.accent()),
                  ),
                ),
          ],
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _MeshTopChrome extends StatelessWidget {
  const _MeshTopChrome({
    required this.section,
    required this.online,
    required this.total,
    required this.encPct,
    required this.mesh,
    required this.onGhost,
    required this.onEmergencyTap,
  });

  final _MeshSection section;
  final int online;
  final int total;
  final double encPct;
  final MeshEngine mesh;
  final ValueChanged<bool> onGhost;
  final VoidCallback onEmergencyTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: MeshTokens.elevated(),
        border: Border(bottom: MeshTokens.hairlineBorder()),
      ),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                section.title,
                style: TextStyle(
                  color: MeshTokens.textPrimary(),
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                ),
              ),
              Text(
                section.subtitle,
                style: TextStyle(color: MeshTokens.textSecondary(), fontSize: 11),
              ),
            ],
          ),
          const Spacer(),
          _chip(Icons.wifi_tethering, '$online / $total online', MeshTokens.success()),
          const SizedBox(width: 8),
          _chip(Icons.lock_outline, '${encPct.toStringAsFixed(0)}% enc', MeshTokens.accent()),
          const SizedBox(width: 8),
          _chip(
            mesh.anonymizeTraffic ? Icons.visibility_off_outlined : Icons.visibility_outlined,
            'Ghost',
            mesh.anonymizeTraffic ? MeshTokens.warning() : MeshTokens.textSecondary(),
            onTap: () => onGhost(!mesh.anonymizeTraffic),
          ),
          const SizedBox(width: 8),
          Tooltip(
            message: 'Emergency mesh broadcast',
            child: FilledButton.tonal(
              style: FilledButton.styleFrom(
                backgroundColor: mesh.useEmergencyBroadcast
                    ? MeshTokens.danger().withValues(alpha: 0.2)
                    : MeshTokens.surface(),
                foregroundColor: mesh.useEmergencyBroadcast
                    ? MeshTokens.danger()
                    : MeshTokens.textSecondary(),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              onPressed: onEmergencyTap,
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.campaign_outlined, size: 18),
                  SizedBox(width: 6),
                  Text('PANIC'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(IconData icon, String label, Color tone, {VoidCallback? onTap}) {
    final child = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: MeshTokens.surface(),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: MeshTokens.border().withValues(alpha: 0.45)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: tone),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(color: MeshTokens.textPrimary(), fontSize: 11),
          ),
        ],
      ),
    );
    if (onTap == null) return child;
    return InkWell(onTap: onTap, borderRadius: BorderRadius.circular(999), child: child);
  }
}
