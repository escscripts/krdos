import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/platform/system_bridge.dart';
import '../../theme/app_theme.dart';

class AudioControlScreen extends StatefulWidget {
  const AudioControlScreen({super.key});
  @override
  State<AudioControlScreen> createState() => _AudioControlScreenState();
}

class _AudioControlScreenState extends State<AudioControlScreen> {
  double _masterVolume = 70;
  double _micVolume    = 80;
  bool   _muted        = false;
  bool   _micMuted     = false;
  bool   _loading      = true;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final v = await SystemBridge.audioGetVolume();
    final m = await SystemBridge.micGetVolume();
    if (mounted) {
      setState(() {
        _masterVolume = v.toDouble().clamp(0, 150);
        _micVolume    = m.toDouble().clamp(0, 150);
        _loading = false;
      });
    }
  }

  void _setVolume(double v) {
    setState(() => _masterVolume = v);
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 200), () {
      SystemBridge.audioSetVolume(v.round());
    });
  }

  void _setMicVolume(double v) {
    setState(() => _micVolume = v);
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 200), () {
      SystemBridge.micSetVolume(v.round());
    });
  }

  Future<void> _toggleMute() async {
    setState(() => _muted = !_muted);
    await SystemBridge.audioSetVolume(_muted ? 0 : _masterVolume.round());
  }

  Future<void> _toggleMicMute() async {
    setState(() => _micMuted = !_micMuted);
    if (_micMuted) {
      await SystemBridge.micMute();
    } else {
      await SystemBridge.micUnmute();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Container(
        color: AppTheme.background,
        child: Center(child: CircularProgressIndicator(color: AppTheme.accent)),
      );
    }
    return Container(
      color: AppTheme.background,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _sectionTitle('Output'),
          const SizedBox(height: 12),
          _volumeCard(
            label: 'Master Volume',
            icon: _muted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
            value: _masterVolume,
            max: 150,
            color: AppTheme.accent,
            muted: _muted,
            onChanged: _muted ? null : _setVolume,
            onMute: _toggleMute,
          ),
          const SizedBox(height: 16),
          _appVolumeCard('System Sounds',       Icons.notifications_rounded,  85),
          const SizedBox(height: 8),
          _appVolumeCard('Media Player',        Icons.music_note_rounded,     100),
          const SizedBox(height: 8),
          _appVolumeCard('Notifications',       Icons.chat_bubble_rounded,    60),
          const SizedBox(height: 24),

          _sectionTitle('Input'),
          const SizedBox(height: 12),
          _volumeCard(
            label: 'Microphone',
            icon: _micMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
            value: _micVolume,
            max: 150,
            color: AppTheme.success,
            muted: _micMuted,
            onChanged: _micMuted ? null : _setMicVolume,
            onMute: _toggleMicMute,
          ),
          const SizedBox(height: 24),

          _sectionTitle('Audio Output Device'),
          const SizedBox(height: 12),
          _deviceTile('Built-in Speakers',    Icons.speaker_rounded,    true),
          const SizedBox(height: 8),
          _deviceTile('HDMI Audio',           Icons.tv_rounded,         false),
          const SizedBox(height: 8),
          _deviceTile('Bluetooth Headphones', Icons.headset_rounded,     false),
          const SizedBox(height: 24),

          _sectionTitle('Advanced'),
          const SizedBox(height: 12),
          _settingRow('Audio profile',       'High Fidelity Playback'),
          _settingRow('Equalizer',           'Flat'),
          _settingRow('Noise suppression',   'Enabled'),
          _settingRow('Echo cancellation',   'Enabled'),
        ]),
      ),
    );
  }

  Widget _sectionTitle(String t) => Text(t, style: TextStyle(
    color: AppTheme.accent, fontSize: 12, fontWeight: FontWeight.w600,
    letterSpacing: 1.2,
  ));

  Widget _volumeCard({
    required String label,
    required IconData icon,
    required double value,
    required double max,
    required Color color,
    required bool muted,
    required ValueChanged<double>? onChanged,
    required VoidCallback onMute,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border.withValues(alpha: 0.5)),
      ),
      child: Column(children: [
        Row(children: [
          GestureDetector(
            onTap: onMute,
            child: Icon(icon, color: muted ? AppTheme.danger : color, size: 22),
          ),
          const SizedBox(width: 12),
          Text(label, style: TextStyle(color: AppTheme.textPrimary, fontSize: 15, fontWeight: FontWeight.w500)),
          const Spacer(),
          Text('${value.round()}%', style: TextStyle(color: AppTheme.textSecondary, fontSize: 14)),
        ]),
        const SizedBox(height: 8),
        SliderTheme(
          data: SliderThemeData(
            activeTrackColor: muted ? AppTheme.textSecondary : color,
            inactiveTrackColor: AppTheme.surfaceAlt,
            thumbColor: muted ? AppTheme.textSecondary : color,
            overlayColor: color.withValues(alpha: 0.2),
            trackHeight: 3,
          ),
          child: Slider(
            value: value.clamp(0, max),
            min: 0, max: max,
            onChanged: onChanged,
          ),
        ),
      ]),
    );
  }

  Widget _appVolumeCard(String name, IconData icon, int vol) {
    double v = vol.toDouble();
    return StatefulBuilder(builder: (_, set) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.border.withValues(alpha: 0.4)),
      ),
      child: Row(children: [
        Icon(icon, color: AppTheme.textSecondary, size: 18),
        const SizedBox(width: 10),
        SizedBox(width: 120, child: Text(name, style: TextStyle(color: AppTheme.textPrimary, fontSize: 13))),
        Expanded(
          child: SliderTheme(
            data: SliderThemeData(
              activeTrackColor: AppTheme.accent,
              inactiveTrackColor: AppTheme.surfaceAlt,
              thumbColor: AppTheme.accent,
              trackHeight: 2,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
            ),
            child: Slider(value: v, min: 0, max: 150, onChanged: (nv) => set(() => v = nv)),
          ),
        ),
        SizedBox(width: 36, child: Text('${v.round()}%',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 12))),
      ]),
    ));
  }

  Widget _deviceTile(String name, IconData icon, bool selected) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: selected ? AppTheme.accentDim : AppTheme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: selected ? AppTheme.accent.withValues(alpha: 0.6) : AppTheme.border.withValues(alpha: 0.4)),
      ),
      child: Row(children: [
        Icon(icon, color: selected ? AppTheme.accent : AppTheme.textSecondary, size: 20),
        const SizedBox(width: 12),
        Text(name, style: TextStyle(color: AppTheme.textPrimary, fontSize: 14)),
        const Spacer(),
        if (selected) Icon(Icons.check_circle, color: AppTheme.accent, size: 18),
      ]),
    );
  }

  Widget _settingRow(String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.border.withValues(alpha: 0.3)),
      ),
      child: Row(children: [
        Text(label, style: TextStyle(color: AppTheme.textPrimary, fontSize: 14)),
        const Spacer(),
        Text(value, style: TextStyle(color: AppTheme.textSecondary, fontSize: 14)),
        const SizedBox(width: 8),
        Icon(Icons.chevron_right, color: AppTheme.textSecondary, size: 16),
      ]),
    ),
  );
}
