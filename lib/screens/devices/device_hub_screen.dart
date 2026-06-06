import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../../core/devices/device_model.dart';
import '../../core/devices/device_registry.dart';
import '../../core/os_state.dart';
import '../../theme/app_theme.dart';
import '../../theme/grid_painter.dart';
import '../../widgets/status_bar.dart';
import 'device_detail_screen.dart';

class DeviceHubScreen extends StatefulWidget {
  const DeviceHubScreen({super.key});
  @override
  State<DeviceHubScreen> createState() => _DeviceHubScreenState();
}

class _DeviceHubScreenState extends State<DeviceHubScreen> {
  DeviceCategory? _filter;

  static const _categories = [
    null,
    DeviceCategory.drone,
    DeviceCategory.camera,
    DeviceCategory.robot,
    DeviceCategory.gps,
    DeviceCategory.smartHome,
    DeviceCategory.sensor,
  ];

  static const _catLabels = ['ALL', 'DRONE', 'CAMERA', 'ROBOT', 'GPS', 'HOME', 'SENSOR'];

  @override
  Widget build(BuildContext context) {
    final registry = context.watch<DeviceRegistry>();
    final os       = context.watch<OsState>();
    final isAdmin  = os.role == UserRole.admin;

    final filtered = _filter == null
      ? registry.devices
      : registry.devices.where((d) => d.category == _filter).toList();

    return Scaffold(
      body: Stack(
        children: [
          CustomPaint(painter: GridPainter(), child: const SizedBox.expand()),
          Column(
            children: [
              const StatusBar(),
              _buildHeader(registry, isAdmin),
              _buildCategoryFilter(),
              _buildStats(registry),
              Expanded(
                child: filtered.isEmpty
                  ? _buildEmpty()
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                      itemCount: filtered.length,
                      itemBuilder: (_, i) => _DeviceCard(
                        device: filtered[i],
                        isAdmin: isAdmin,
                        onTap: () => Navigator.push(context, _route(
                          DeviceDetailScreen(deviceId: filtered[i].id),
                        )),
                      ).animate(delay: Duration(milliseconds: i * 50))
                        .fadeIn(duration: 200.ms)
                        .slideY(begin: 0.05, end: 0),
                    ),
              ),
            ],
          ),
  // Pending devices badge
          if (registry.pendingDevices.isNotEmpty)
            Positioned(
              bottom: 24, right: 24,
              child: _PendingBadge(count: registry.pendingDevices.length),
            ),
        ],
      ),
    );
  }

  Widget _buildHeader(DeviceRegistry registry, bool isAdmin) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Icon(Icons.arrow_back_ios, color: AppTheme.accent, size: 16),
          ),
          const SizedBox(width: 12),
          Text('DEVICE HUB',
            style: TextStyle(color: AppTheme.accent, fontSize: 14,
              fontWeight: FontWeight.bold, letterSpacing: 3),
          ),
          const Spacer(),
          if (isAdmin)
            GestureDetector(
              onTap: () => registry.startScan(),
              child: AnimatedContainer(
                duration: 300.ms,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: registry.scanning ? AppTheme.accentDim : AppTheme.surfaceAlt,
                  border: Border.all(color: registry.scanning ? AppTheme.accent : AppTheme.border),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (registry.scanning)
                      SizedBox(
                        width: 10, height: 10,
                        child: CircularProgressIndicator(
                          strokeWidth: 1.5,
                          color: AppTheme.accent,
                        ),
                      )
                    else
                      Icon(Icons.radar, color: AppTheme.accent, size: 14),
                    const SizedBox(width: 6),
                    Text(
                      registry.scanning ? 'SCANNING...' : 'SCAN',
                      style: TextStyle(color: AppTheme.accent, fontSize: 10,
                        fontWeight: FontWeight.bold, letterSpacing: 1),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCategoryFilter() {
    return SizedBox(
      height: 36,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _categories.length,
        itemBuilder: (_, i) {
          final selected = _filter == _categories[i];
          return GestureDetector(
            onTap: () => setState(() => _filter = _categories[i]),
            child: AnimatedContainer(
              duration: 150.ms,
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: selected ? AppTheme.accentDim : AppTheme.surfaceAlt,
                border: Border.all(color: selected ? AppTheme.accent : AppTheme.border),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(_catLabels[i],
                style: TextStyle(
                  color: selected ? AppTheme.accent : AppTheme.textSecondary,
                  fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildStats(DeviceRegistry registry) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Row(
        children: [
          _stat('TOTAL',   '${registry.devices.length}',      AppTheme.textSecondary),
          const SizedBox(width: 10),
          _stat('ONLINE',  '${registry.onlineDevices.length}', AppTheme.accent),
          const SizedBox(width: 10),
          _stat('TRUSTED', '${registry.trustedDevices.length}', AppTheme.accent),
          const SizedBox(width: 10),
          if (registry.pendingDevices.isNotEmpty)
            _stat('PENDING', '${registry.pendingDevices.length}', AppTheme.warning),
        ],
      ),
    );
  }

  Widget _stat(String label, String value, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: AppTheme.surfaceAlt,
      border: Border.all(color: AppTheme.border),
      borderRadius: BorderRadius.circular(4),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Text('$label ', style: TextStyle(color: AppTheme.textSecondary, fontSize: 10)),
      Text(value, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
    ]),
  );

  Widget _buildEmpty() => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.devices_other, color: AppTheme.textSecondary, size: 48),
        const SizedBox(height: 12),
        Text('No devices found', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
        const SizedBox(height: 6),
        Text('Tap SCAN to discover nearby devices',
          style: TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
      ],
    ),
  );

  PageRoute _route(Widget page) => PageRouteBuilder(
    pageBuilder: (_, __, ___) => page,
    transitionsBuilder: (_, anim, __, child) =>
      FadeTransition(opacity: anim, child: child),
    transitionDuration: 250.ms,
  );
}

class _DeviceCard extends StatefulWidget {
  final ConnectedDevice device;
  final bool isAdmin;
  final VoidCallback onTap;
  const _DeviceCard({required this.device, required this.isAdmin, required this.onTap});
  @override
  State<_DeviceCard> createState() => _DeviceCardState();
}

class _DeviceCardState extends State<_DeviceCard> {
  bool _hovered = false;

  Color get _statusColor {
    switch (widget.device.status) {
      case DeviceStatus.online:     return AppTheme.accent;
      case DeviceStatus.offline:    return AppTheme.textSecondary;
      case DeviceStatus.connecting: return AppTheme.warning;
      case DeviceStatus.pairing:    return AppTheme.warning;
      case DeviceStatus.error:      return AppTheme.danger;
    }
  }

  IconData get _categoryIcon {
    switch (widget.device.category) {
      case DeviceCategory.drone:     return Icons.flight;
      case DeviceCategory.camera:    return Icons.videocam;
      case DeviceCategory.robot:     return Icons.smart_toy;
      case DeviceCategory.gps:       return Icons.gps_fixed;
      case DeviceCategory.smartHome: return Icons.home;
      case DeviceCategory.sensor:    return Icons.sensors;
      case DeviceCategory.unknown:   return Icons.device_unknown;
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.device;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit:  (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: 150.ms,
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: _hovered ? AppTheme.surfaceAlt : AppTheme.surface,
            border: Border.all(
              color: _hovered ? _statusColor.withOpacity(0.5) : AppTheme.border,
            ),
            borderRadius: BorderRadius.circular(8),
            boxShadow: _hovered
              ? [BoxShadow(color: _statusColor.withOpacity(0.1), blurRadius: 12)]
              : [],
          ),
          child: Row(
            children: [
  // Icon + status dot
              Stack(
                children: [
                  Container(
                    width: 44, height: 44,
                    decoration: BoxDecoration(
                      color: _statusColor.withOpacity(0.1),
                      border: Border.all(color: _statusColor.withOpacity(0.3)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(_categoryIcon, color: _statusColor, size: 22),
                  ),
                  Positioned(
                    bottom: 0, right: 0,
                    child: Container(
                      width: 10, height: 10,
                      decoration: BoxDecoration(
                        color: _statusColor,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppTheme.surface, width: 1.5),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 12),
  // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(d.name,
                          style: TextStyle(color: AppTheme.textPrimary,
                            fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(width: 8),
                        if (!d.trusted)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                              color: AppTheme.warning.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(3),
                            ),
                            child: Text('UNTRUSTED',
                              style: TextStyle(color: AppTheme.warning, fontSize: 8,
                                fontWeight: FontWeight.bold),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Text(d.categoryLabel,
                          style: TextStyle(color: AppTheme.textSecondary, fontSize: 10)),
                        Text(' Ãƒ - šÃ‚ |  ', style: TextStyle(color: AppTheme.border, fontSize: 10)),
                        Text(d.connectionLabel,
                          style: TextStyle(color: AppTheme.textSecondary, fontSize: 10)),
                        if (d.ipAddress != null) ...[
                          Text(' Ãƒ - šÃ‚ |  ', style: TextStyle(color: AppTheme.border, fontSize: 10)),
                          Text(d.ipAddress!,
                            style: TextStyle(color: AppTheme.textSecondary, fontSize: 10)),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
  // Signal + arrow
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _SignalBar(strength: d.signalStrength, color: _statusColor),
                  const SizedBox(height: 4),
                  Text('${d.signalStrength}%',
                    style: TextStyle(color: _statusColor, fontSize: 9)),
                ],
              ),
              const SizedBox(width: 8),
              Icon(Icons.chevron_right,
                color: _hovered ? _statusColor : AppTheme.textSecondary, size: 16),
            ],
          ),
        ),
      ),
    );
  }
}

class _SignalBar extends StatelessWidget {
  final int strength;
  final Color color;
  const _SignalBar({required this.strength, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: List.generate(4, (i) {
        final filled = strength > i * 25;
        return Container(
          margin: const EdgeInsets.only(left: 2),
          width: 4,
          height: 6.0 + i * 3,
          decoration: BoxDecoration(
            color: filled ? color : AppTheme.border,
            borderRadius: BorderRadius.circular(1),
          ),
        );
      }),
    );
  }
}

class _PendingBadge extends StatelessWidget {
  final int count;
  const _PendingBadge({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.warning.withOpacity(0.15),
        border: Border.all(color: AppTheme.warning),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.device_unknown, color: AppTheme.warning, size: 16),
          const SizedBox(width: 8),
          Text('$count device${count > 1 ? 's' : ''} waiting approval',
            style: TextStyle(color: AppTheme.warning, fontSize: 11)),
        ],
      ),
    ).animate(onPlay: (c) => c.repeat(reverse: true))
      .fadeIn(duration: 1000.ms);
  }
}
