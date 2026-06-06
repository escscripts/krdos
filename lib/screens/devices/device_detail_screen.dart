import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../../core/devices/device_model.dart';
import '../../core/devices/device_registry.dart';
import '../../core/os_state.dart';
import '../../theme/app_theme.dart';
import '../../theme/grid_painter.dart';
import '../../widgets/status_bar.dart';
import 'drone_control_screen.dart';

class DeviceDetailScreen extends StatelessWidget {
  final String deviceId;
  const DeviceDetailScreen({super.key, required this.deviceId});

  @override
  Widget build(BuildContext context) {
    final registry = context.watch<DeviceRegistry>();
    final os       = context.watch<OsState>();
    final device   = registry.getById(deviceId);
    final isAdmin  = os.role == UserRole.admin;

    if (device == null) {
      return const Scaffold(
        body: Center(child: Text('Device not found', style: TextStyle(color: AppTheme.textSecondary))),
      );
    }

    return Scaffold(
      body: Stack(
        children: [
          CustomPaint(painter: GridPainter(), child: const SizedBox.expand()),
          Column(
            children: [
              const StatusBar(),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Icon(Icons.arrow_back_ios, color: AppTheme.accent, size: 16),
                    ),
                    const SizedBox(width: 12),
                    Text(device.name.toUpperCase(),
                      style: TextStyle(color: AppTheme.accent, fontSize: 14,
                        fontWeight: FontWeight.bold, letterSpacing: 2),
                    ),
                    const Spacer(),
                    _statusBadge(device.status),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _buildInfoCard(device),
                    const SizedBox(height: 12),
                    _buildCapabilities(device),
                    const SizedBox(height: 12),
  // Control buttons always visible if device is trusted and has capabilities
                    if (device.trusted) _buildDeviceControls(context, device),
                    if (device.trusted) const SizedBox(height: 12),
                    if (isAdmin) _buildAdminControls(context, device, registry),
                    if (!device.trusted && isAdmin) _buildTrustPanel(context, device, registry),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statusBadge(DeviceStatus status) {
    Color c;
    String label;
    switch (status) {
      case DeviceStatus.online:     c = AppTheme.accent;   label = 'ONLINE';     break;
      case DeviceStatus.offline:    c = AppTheme.textSecondary; label = 'OFFLINE'; break;
      case DeviceStatus.connecting: c = AppTheme.warning;  label = 'CONNECTING'; break;
      case DeviceStatus.pairing:    c = AppTheme.warning;  label = 'PAIRING';    break;
      case DeviceStatus.error:      c = AppTheme.danger;   label = 'ERROR';      break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: c.withOpacity(0.1),
        border: Border.all(color: c),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Text(label, style: TextStyle(color: c, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 1)),
    );
  }

  Widget _buildInfoCard(ConnectedDevice d) {
    return _Card(
      title: 'DEVICE INFO',
      child: Column(
        children: [
          _infoRow('ID',         d.id),
          _infoRow('Category',   d.categoryLabel),
          _infoRow('Connection', d.connectionLabel),
          if (d.ipAddress != null)  _infoRow('IP Address', d.ipAddress!),
          if (d.macAddress != null) _infoRow('MAC',        d.macAddress!),
          _infoRow('Signal',     '${d.signalStrength}%'),
          _infoRow('First Seen', _formatDate(d.firstSeen)),
          _infoRow('Last Seen',  _formatDate(d.lastSeen)),
          _infoRow('Access',     d.accessLevel.name.toUpperCase()),
          _infoRow('Trusted',    d.trusted ? 'YES' : 'NO',
            valueColor: d.trusted ? AppTheme.accent : AppTheme.warning),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms);
  }

  Widget _buildCapabilities(ConnectedDevice d) {
    if (d.capabilities.isEmpty) return const SizedBox.shrink();
    return _Card(
      title: 'CAPABILITIES',
      child: Wrap(
        spacing: 8, runSpacing: 8,
        children: d.capabilities.entries.map((e) {
          final active = e.value == true;
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: active ? AppTheme.accentDim : AppTheme.surfaceAlt,
              border: Border.all(color: active ? AppTheme.accent : AppTheme.border),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(e.key.toUpperCase(),
              style: TextStyle(
                color: active ? AppTheme.accent : AppTheme.textSecondary,
                fontSize: 10, fontWeight: FontWeight.bold,
              ),
            ),
          );
        }).toList(),
      ),
    ).animate().fadeIn(delay: 100.ms, duration: 300.ms);
  }

  Widget _buildAdminControls(BuildContext context, ConnectedDevice d, DeviceRegistry registry) {
    return _Card(
      title: 'ADMIN CONTROLS',
      child: Column(
        children: [
  // Access level selector
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                Text('Access Level',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                const Spacer(),
                _AccessDropdown(
                  current: d.accessLevel,
                  onChanged: (level) => registry.setAccessLevel(d.id, level),
                ),
              ],
            ),
          ),
          const Divider(color: AppTheme.border, height: 1),
          const SizedBox(height: 12),
  // Token
          if (d.accessToken != null) ...[
            Row(
              children: [
                Text('Access Token',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                const Spacer(),
                GestureDetector(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: d.accessToken!));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Token copied'),
                        backgroundColor: AppTheme.surfaceAlt,
                        duration: 1500.ms,
                      ),
                    );
                  },
                  child: Icon(Icons.copy, color: AppTheme.accent, size: 14),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                border: Border.all(color: AppTheme.border),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(d.accessToken!,
                style: TextStyle(color: AppTheme.accent, fontSize: 12, letterSpacing: 2),
              ),
            ),
            const SizedBox(height: 12),
          ],
  // Action buttons
          Row(
            children: [
              Expanded(
                child: _ActionButton(
                  label: 'REVOKE ACCESS',
                  color: AppTheme.danger,
                  icon: Icons.block,
                  onTap: () {
                    registry.revokeDevice(d.id);
                    Navigator.pop(context);
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _ActionButton(
                  label: 'REMOVE DEVICE',
                  color: AppTheme.textSecondary,
                  icon: Icons.delete_outline,
                  onTap: () {
                    registry.removeDevice(d.id);
                    Navigator.pop(context);
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(delay: 200.ms, duration: 300.ms);
  }

  Widget _buildDeviceControls(BuildContext context, ConnectedDevice d) {
    return _Card(
      title: 'DEVICE CONTROL',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (d.capabilities['camera'] == true || d.capabilities['control'] == true)
            _ActionButton(
              label: d.category == DeviceCategory.drone ? 'OPEN DRONE CONTROL' : 'VIEW CAMERA FEED',
              color: AppTheme.accent,
              icon: d.category == DeviceCategory.drone ? Icons.flight : Icons.videocam,
              onTap: () => Navigator.push(context, PageRouteBuilder(
                pageBuilder: (_, __, ___) => DroneControlScreen(deviceId: d.id),
                transitionsBuilder: (_, anim, __, child) => FadeTransition(opacity: anim, child: child),
                transitionDuration: 250.ms,
              )),
            ),
          if (d.capabilities['location'] == true) ...[
            const SizedBox(height: 8),
            _ActionButton(
              label: 'VIEW LOCATION',
              color: AppTheme.accent,
              icon: Icons.gps_fixed,
              onTap: () {},
            ),
          ],
          if (d.capabilities['telemetry'] == true) ...[
            const SizedBox(height: 8),
            _ActionButton(
              label: 'VIEW TELEMETRY',
              color: AppTheme.accent,
              icon: Icons.analytics,
              onTap: () {},
            ),
          ],
        ],
      ),
    ).animate().fadeIn(delay: 200.ms, duration: 300.ms);
  }

  Widget _buildTrustPanel(BuildContext context, ConnectedDevice d, DeviceRegistry registry) {
    return _Card(
      title: 'TRUST THIS DEVICE',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'This device is not trusted. Approve it to allow connection and generate an access token.',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _ActionButton(
                  label: 'APPROVE & TRUST',
                  color: AppTheme.accent,
                  icon: Icons.verified_user,
                  onTap: () {
                    final token = registry.trustDevice(d.id);
                    showDialog(
                      context: context,
                      builder: (_) => _TokenDialog(token: token, deviceName: d.name),
                    );
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _ActionButton(
                  label: 'REJECT',
                  color: AppTheme.danger,
                  icon: Icons.block,
                  onTap: () {
                    registry.removeDevice(d.id);
                    Navigator.pop(context);
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(delay: 200.ms, duration: 300.ms);
  }

  Widget _infoRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Text(label, style: TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
          const Spacer(),
          Text(value, style: TextStyle(
            color: valueColor ?? AppTheme.textPrimary, fontSize: 11,
          )),
        ],
      ),
    );
  }

  String _formatDate(DateTime d) =>
    '${d.day.toString().padLeft(2,'0')}/${d.month.toString().padLeft(2,'0')}/${d.year} '
    '${d.hour.toString().padLeft(2,'0')}:${d.minute.toString().padLeft(2,'0')}';
}

class _Card extends StatelessWidget {
  final String title;
  final Widget child;
  const _Card({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceAlt,
        border: Border.all(color: AppTheme.border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: AppTheme.border)),
            ),
            child: Text(title,
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 10,
                letterSpacing: 2, fontWeight: FontWeight.bold),
            ),
          ),
          Padding(padding: const EdgeInsets.all(14), child: child),
        ],
      ),
    );
  }
}

class _ActionButton extends StatefulWidget {
  final String label;
  final Color color;
  final IconData icon;
  final VoidCallback onTap;
  const _ActionButton({required this.label, required this.color, required this.icon, required this.onTap});
  @override
  State<_ActionButton> createState() => _ActionButtonState();
}

class _ActionButtonState extends State<_ActionButton> {
  bool _hovered = false;
  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit:  (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: 120.ms,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: _hovered ? widget.color.withOpacity(0.15) : AppTheme.surface,
            border: Border.all(color: _hovered ? widget.color : AppTheme.border),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(widget.icon, color: widget.color, size: 14),
              const SizedBox(width: 8),
              Text(widget.label,
                style: TextStyle(color: widget.color, fontSize: 11,
                  fontWeight: FontWeight.bold, letterSpacing: 1),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AccessDropdown extends StatelessWidget {
  final AccessLevel current;
  final ValueChanged<AccessLevel> onChanged;
  const _AccessDropdown({required this.current, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        border: Border.all(color: AppTheme.border),
        borderRadius: BorderRadius.circular(4),
      ),
      child: DropdownButton<AccessLevel>(
        value: current,
        dropdownColor: AppTheme.surfaceAlt,
        underline: const SizedBox.shrink(),
        style: TextStyle(color: AppTheme.accent, fontSize: 11),
        items: AccessLevel.values.map((l) => DropdownMenuItem(
          value: l,
          child: Text(l.name.toUpperCase(),
            style: TextStyle(color: AppTheme.textPrimary, fontSize: 11)),
        )).toList(),
        onChanged: (v) { if (v != null) onChanged(v); },
      ),
    );
  }
}

class _TokenDialog extends StatelessWidget {
  final String token;
  final String deviceName;
  const _TokenDialog({required this.token, required this.deviceName});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppTheme.surfaceAlt,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: AppTheme.accent),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.verified_user, color: AppTheme.accent, size: 32),
            const SizedBox(height: 12),
            Text('$deviceName TRUSTED',
              style: TextStyle(color: AppTheme.accent, fontSize: 13,
                fontWeight: FontWeight.bold, letterSpacing: 2),
            ),
            const SizedBox(height: 8),
            Text('Share this token with the device operator:',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 11),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                border: Border.all(color: AppTheme.accent),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(token,
                style: TextStyle(color: AppTheme.accent, fontSize: 14,
                  letterSpacing: 3, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => Clipboard.setData(ClipboardData(text: token)),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        border: Border.all(color: AppTheme.border),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.copy, color: AppTheme.textSecondary, size: 14),
                          SizedBox(width: 6),
                          Text('COPY', style: TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: AppTheme.accentDim,
                        border: Border.all(color: AppTheme.accent),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text('DONE',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppTheme.accent, fontSize: 11,
                          fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
