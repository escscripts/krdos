import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../core/os_state.dart';
import '../core/device_role.dart';
import '../core/platform/system_bridge.dart';
import '../theme/app_theme.dart';

class StatusBar extends StatefulWidget {
  final VoidCallback? onNotifTap;
  final VoidCallback? onCCTap;
  final bool showNotif;
  const StatusBar({super.key, this.onNotifTap, this.onCCTap, this.showNotif = false});

  @override
  State<StatusBar> createState() => _StatusBarState();
}

class _StatusBarState extends State<StatusBar> {
  late String _time, _date;
  late Timer _timer;
  Timer? _batteryTimer;
  int _batteryLevel = -1;
  bool _batteryCharging = false;
  bool _hasBattery = false;

  @override
  void initState() {
    super.initState();
    _updateTime();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _updateTime());
    _loadBattery();
    _batteryTimer = Timer.periodic(const Duration(seconds: 60), (_) => _loadBattery());
  }

  void _updateTime() {
    final now = DateTime.now();
    setState(() {
      _time = DateFormat('HH:mm:ss').format(now);
      _date = DateFormat('EEE dd MMM').format(now);
    });
  }

  Future<void> _loadBattery() async {
    final b = await SystemBridge.batteryStatus();
    if (!mounted) return;
    setState(() {
      _hasBattery = b['has_battery'] == true;
      _batteryLevel = (b['level'] as num?)?.toInt() ?? -1;
      _batteryCharging = b['charging'] == true;
    });
  }

  @override
  void dispose() { _timer.cancel(); _batteryTimer?.cancel(); super.dispose(); }

  String _roleLabel(UserRole role) {
    switch (role) {
      case UserRole.admin:     return '[ADMIN]';
      case UserRole.powerUser: return '[POWER]';
      case UserRole.user:      return '[USER]';
    }
  }

  @override
  Widget build(BuildContext context) {
    final os = context.watch<OsState>();
    return Container(
      height: 32,
      color: AppTheme.surface,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Text(_roleLabel(os.role),
            style: TextStyle(
              color: os.role == UserRole.admin ? AppTheme.accent : AppTheme.textSecondary,
              fontSize: 11, fontWeight: FontWeight.bold,
            ),
          ),
          const Spacer(),
          Text(_date, style: TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
          const SizedBox(width: 16),
          Text(_time, style: TextStyle(color: AppTheme.accent, fontSize: 11)),
          const SizedBox(width: 16),
          if (_hasBattery) ...[
            _BatteryIndicator(level: _batteryLevel, charging: _batteryCharging),
            const SizedBox(width: 12),
          ],
          _icon(Icons.vpn_lock, os.vpnEnabled,    false),
          const SizedBox(width: 8),
          _icon(Icons.shield, os.firewallEnabled, !os.firewallEnabled),
          const SizedBox(width: 8),
  // CC tap area
          GestureDetector(
            onTap: widget.onCCTap,
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              _icon(Icons.wifi, os.wifiEnabled, !os.wifiEnabled),
              const SizedBox(width: 8),
              _icon(Icons.bluetooth, os.bluetoothEnabled, !os.bluetoothEnabled),
            ]),
          ),
          const SizedBox(width: 8),
  // Notification bell with badge
          GestureDetector(
            onTap: widget.onNotifTap,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(
                  widget.showNotif ? Icons.notifications : Icons.notifications_outlined,
                  size: 14,
                  color: widget.showNotif ? AppTheme.accent : AppTheme.textSecondary,
                ),
                if (os.unreadCount > 0)
                  Positioned(
                    top: -4, right: -4,
                    child: Container(
                      width: 8, height: 8,
                      decoration: BoxDecoration(
                        color: AppTheme.danger,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _icon(IconData icon, bool active, bool alert) => Icon(
    icon, size: 13,
    color: alert ? AppTheme.danger : active ? AppTheme.accent : AppTheme.textSecondary,
  );
}

class _BatteryIndicator extends StatelessWidget {
  final int level;
  final bool charging;
  const _BatteryIndicator({required this.level, required this.charging});

  IconData get _icon {
    if (charging) return Icons.battery_charging_full_rounded;
    if (level >= 90) return Icons.battery_full_rounded;
    if (level >= 70) return Icons.battery_6_bar_rounded;
    if (level >= 50) return Icons.battery_4_bar_rounded;
    if (level >= 30) return Icons.battery_3_bar_rounded;
    if (level >= 15) return Icons.battery_2_bar_rounded;
    return Icons.battery_1_bar_rounded;
  }

  Color get _color {
    if (charging) return const Color(0xFF00FF88);
    if (level <= 15) return const Color(0xFFFF4B6E);
    if (level <= 30) return const Color(0xFFFFB347);
    return const Color(0xFF9E9EBA);
  }

  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
    Icon(_icon, size: 13, color: _color),
    const SizedBox(width: 3),
    Text('$level%', style: TextStyle(color: _color, fontSize: 10, fontWeight: FontWeight.w600)),
  ]);
}
