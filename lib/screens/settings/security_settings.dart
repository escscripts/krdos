import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../theme/app_theme.dart';

class SecuritySettingsScreen extends StatefulWidget {
  final int initialTab;

  const SecuritySettingsScreen({super.key, this.initialTab = 0});

  @override
  State<SecuritySettingsScreen> createState() => _SecuritySettingsScreenState();
}

class _SecuritySettingsScreenState extends State<SecuritySettingsScreen> {
  late int _tab = widget.initialTab.clamp(0, 3);

  bool _telemetry = false;
  bool _diagnostics = true;
  bool _location = false;
  bool _adId = false;
  bool _clipboardSync = true;
  bool _cameraGlobal = true;
  bool _micGlobal = true;

  final List<Map<String, dynamic>> _appPerms = [
    {'app': 'Browser', 'camera': 'Ask', 'mic': 'Off', 'files': 'Full'},
    {'app': 'Terminal', 'camera': 'Off', 'mic': 'Off', 'files': 'Downloads'},
    {'app': 'Files', 'camera': 'Off', 'mic': 'Off', 'files': 'Full'},
    {'app': 'Settings', 'camera': 'Off', 'mic': 'Off', 'files': 'System'},
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final p = await SharedPreferences.getInstance();
    setState(() {
      _telemetry = p.getBool('sec_telemetry') ?? false;
      _diagnostics = p.getBool('sec_diagnostics') ?? true;
      _location = p.getBool('sec_location') ?? false;
      _adId = p.getBool('sec_adId') ?? false;
      _clipboardSync = p.getBool('sec_clipboard') ?? true;
      _cameraGlobal = p.getBool('sec_camera_global') ?? true;
      _micGlobal = p.getBool('sec_mic_global') ?? true;
    });
  }

  Future<void> _persist(String key, bool v) async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(key, v);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final narrow = c.maxWidth < 720;
        if (narrow) {
          return Column(
            children: [
              SizedBox(
                height: 54,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
                  children: [
                    _topChip(0, Icons.dashboard_rounded, 'Overview'),
                    _topChip(1, Icons.visibility_off_rounded, 'Privacy'),
                    _topChip(2, Icons.app_registration_rounded, 'Perms'),
                    _topChip(3, Icons.verified_user_rounded, 'Device'),
                  ],
                ),
              ),
              Container(height: 1, color: AppTheme.border.withValues(alpha: 0.45)),
              Expanded(child: _content()),
            ],
          );
        }
        return Row(
          children: [
            _sidebar(),
            Expanded(child: _content()),
          ],
        );
      },
    );
  }

  Widget _topChip(int i, IconData icon, String label) {
    final on = _tab == i;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Material(
        color: on ? AppTheme.accent.withValues(alpha: 0.12) : AppTheme.surfaceAlt,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => setState(() => _tab = i),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                Icon(icon, size: 16, color: on ? AppTheme.accent : AppTheme.textSecondary),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    color: on ? AppTheme.accent : AppTheme.textPrimary,
                    fontSize: 12,
                    fontWeight: on ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _sidebar() {
    return Container(
      width: 220,
      decoration: BoxDecoration(
        color: AppTheme.surface,
        border: Border(right: BorderSide(color: AppTheme.border.withValues(alpha: 0.5))),
      ),
      child: Column(
        children: [
          _sideItem(0, Icons.dashboard_rounded, 'Overview'),
          _sideItem(1, Icons.visibility_off_rounded, 'Privacy'),
          _sideItem(2, Icons.app_registration_rounded, 'Permissions'),
          _sideItem(3, Icons.verified_user_rounded, 'Device'),
        ],
      ),
    );
  }

  Widget _sideItem(int i, IconData icon, String label) {
    final on = _tab == i;
    return GestureDetector(
      onTap: () => setState(() => _tab = i),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: on ? AppTheme.accent.withValues(alpha: 0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: on ? AppTheme.accent.withValues(alpha: 0.5) : Colors.transparent),
        ),
        child: Row(
          children: [
            Icon(icon, color: on ? AppTheme.accent : AppTheme.textSecondary, size: 20),
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                color: on ? AppTheme.accent : AppTheme.textPrimary,
                fontSize: 13,
                fontWeight: on ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _content() {
    switch (_tab) {
      case 0:
        return _overview();
      case 1:
        return _privacy();
      case 2:
        return _permissions();
      case 3:
        return _device();
      default:
        return const SizedBox();
    }
  }

  Widget _overview() {
    return ListView(
      padding: const EdgeInsets.all(28),
      children: [
        _header('Security overview', 'Live posture for this device ‚¬ inspired by enterprise dashboards, tuned for everyday use.'),
        const SizedBox(height: 20),
        LayoutBuilder(
          builder: (context, c) {
            final w = c.maxWidth;
            final cols = w > 900 ? 3 : w > 560 ? 2 : 1;
            return GridView.count(
              crossAxisCount: cols,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 14,
              crossAxisSpacing: 14,
              childAspectRatio: 1.45,
              children: [
                _statusCard(
                  title: 'Threat shield',
                  value: 'Active',
                  detail: 'Heuristic monitor + network anomaly hints',
                  icon: Icons.shield_moon_rounded,
                  tone: AppTheme.success,
                ),
                _statusCard(
                  title: 'Disk encryption',
                  value: 'On',
                  detail: 'AES-256 volume encryption',
                  icon: Icons.lock_rounded,
                  tone: AppTheme.accent,
                ),
                _statusCard(
                  title: 'Secure boot',
                  value: 'Verified',
                  detail: 'Firmware chain trusted',
                  icon: Icons.verified_rounded,
                  tone: const Color(0xFF8B5CF6),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 22),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppTheme.surface,
                AppTheme.surfaceAlt,
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.border),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.auto_fix_high_rounded, color: AppTheme.accent),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Smart recommendations',
                      style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _telemetry
                          ? 'Telemetry is on ‚¬ you can turn it off under Privacy for a quieter footprint.'
                          : 'Great ‚¬ minimal telemetry keeps your activity local-first.',
                      style: TextStyle(color: AppTheme.textSecondary, fontSize: 13, height: 1.35),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _privacy() {
    return ListView(
      padding: const EdgeInsets.all(28),
      children: [
        _header('Privacy', 'Decide what leaves this device. Every toggle applies instantly.'),
        const SizedBox(height: 16),
        _toggleCard(
          'Usage & telemetry',
          'Help improve KrdOS with anonymous usage events',
          _telemetry,
          (v) {
            setState(() => _telemetry = v);
            _persist('sec_telemetry', v);
          },
        ),
        _toggleCard(
          'Diagnostic data',
          'Send crash fingerprints for faster fixes',
          _diagnostics,
          (v) {
            setState(() => _diagnostics = v);
            _persist('sec_diagnostics', v);
          },
        ),
        _toggleCard(
          'Location services',
          'Allow system services to approximate your position',
          _location,
          (v) {
            setState(() => _location = v);
            _persist('sec_location', v);
          },
        ),
        _toggleCard(
          'Advertising ID',
          'Allow a resettable ID for suggested content',
          _adId,
          (v) {
            setState(() => _adId = v);
            _persist('sec_adId', v);
          },
        ),
        _toggleCard(
          'Universal clipboard sync',
          'Sync clipboard across your signed-in devices',
          _clipboardSync,
          (v) {
            setState(() => _clipboardSync = v);
            _persist('sec_clipboard', v);
          },
        ),
      ],
    );
  }

  Widget _permissions() {
    return ListView(
      padding: const EdgeInsets.all(28),
      children: [
        _header('App permissions', 'Per-app gates for camera, microphone, and files.'),
        const SizedBox(height: 10),
        _toggleCard(
          'Camera ‚¬ system gate',
          'When off, apps cannot use the camera unless you override per app',
          _cameraGlobal,
          (v) {
            setState(() => _cameraGlobal = v);
            _persist('sec_camera_global', v);
          },
        ),
        _toggleCard(
          'Microphone ‚¬ system gate',
          'When off, dictation and listening features pause globally',
          _micGlobal,
          (v) {
            setState(() => _micGlobal = v);
            _persist('sec_mic_global', v);
          },
        ),
        const SizedBox(height: 12),
        Text('Per application', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
        const SizedBox(height: 10),
        ..._appPerms.map(_permRow),
      ],
    );
  }

  Widget _permRow(Map<String, dynamic> m) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            m['app'] as String,
            style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _chip('Camera', m['camera'] as String),
              _chip('Microphone', m['mic'] as String),
              _chip('Files', m['files'] as String),
            ],
          ),
        ],
      ),
    );
  }

  Widget _chip(String k, String v) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.surfaceAlt,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.border),
      ),
      child: Text('$k: $v', style: TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
    );
  }

  Widget _device() {
    return ListView(
      padding: const EdgeInsets.all(28),
      children: [
        _header('Device security', 'Hardware-backed trust and recovery.'),
        const SizedBox(height: 16),
        _infoTile(Icons.memory_rounded, 'TPM 2.0', 'Attestation ready ‚¬ keys sealed to this chassis'),
        _infoTile(Icons.fingerprint_rounded, 'Biometric unlock', 'Templates stored in secure element'),
        _infoTile(Icons.phonelink_lock_rounded, 'Find device', 'Last known location encrypted end-to-end'),
        _infoTile(Icons.update_rounded, 'Security patches', 'Channel: Stable ‚¬¢ Last check: today'),
      ],
    );
  }

  Widget _header(String title, String sub) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 22,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 6),
        Text(sub, style: TextStyle(color: AppTheme.textSecondary, fontSize: 13, height: 1.35)),
      ],
    );
  }

  Widget _statusCard({
    required String title,
    required String value,
    required String detail,
    required IconData icon,
    required Color tone,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
        boxShadow: [
          BoxShadow(
            color: tone.withValues(alpha: 0.08),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: tone, size: 22),
              const Spacer(),
              Text(
                value,
                style: TextStyle(color: tone, fontWeight: FontWeight.w800, fontSize: 13),
              ),
            ],
          ),
          const Spacer(),
          Text(title, style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(detail, style: TextStyle(color: AppTheme.textSecondary, fontSize: 11, height: 1.3)),
        ],
      ),
    );
  }

  Widget _toggleCard(String title, String sub, bool value, ValueChanged<bool> onChanged) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(sub, style: TextStyle(color: AppTheme.textSecondary, fontSize: 12, height: 1.3)),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: Colors.black,
            activeTrackColor: AppTheme.accent,
          ),
        ],
      ),
    );
  }

  Widget _infoTile(IconData icon, String title, String sub) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.accent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: AppTheme.accent, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(sub, style: TextStyle(color: AppTheme.textSecondary, fontSize: 12, height: 1.3)),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: AppTheme.textSecondary),
        ],
      ),
    );
  }
}

