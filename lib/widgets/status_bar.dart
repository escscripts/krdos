import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../core/os_state.dart';
import '../core/device_role.dart';
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

  @override
  void initState() {
    super.initState();
    _updateTime();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _updateTime());
  }

  void _updateTime() {
    final now = DateTime.now();
    setState(() {
      _time = DateFormat('HH:mm:ss').format(now);
      _date = DateFormat('EEE dd MMM').format(now);
    });
  }

  @override
  void dispose() { _timer.cancel(); super.dispose(); }

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
