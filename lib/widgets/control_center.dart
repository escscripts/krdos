import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../core/os_state.dart';
import '../core/platform/system_bridge.dart';
import '../core/settings_state.dart';
import '../core/vpn_state.dart';
import '../theme/app_theme.dart';

class ControlCenter extends StatefulWidget {
  final VoidCallback onClose;
  final bool isLaptop;
  const ControlCenter({super.key, required this.onClose, this.isLaptop = false});
  @override
  State<ControlCenter> createState() => _ControlCenterState();
}

class _ControlCenterState extends State<ControlCenter> {
  int _tab = 0; // 0=main 1=wifi 2=bluetooth
  int _quickSettingsPage = 0; // 0=page1, 1=page2

  @override
  Widget build(BuildContext context) {
    final os = context.watch<OsState>();
    return GestureDetector(
      onTap: () {},
      child: ClipRRect(
        borderRadius: widget.isLaptop
          ? BorderRadius.circular(16)
          : const BorderRadius.only(bottomLeft: Radius.circular(16), bottomRight: Radius.circular(16)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
          child: Container(
            width: widget.isLaptop ? 340 : double.infinity,
            constraints: BoxConstraints(maxHeight: widget.isLaptop ? 560 : 500),
            decoration: BoxDecoration(
              color: const Color(0xFF0D1117).withValues(alpha: 0.92),
              borderRadius: widget.isLaptop
                ? BorderRadius.circular(16)
                : const BorderRadius.only(bottomLeft: Radius.circular(16), bottomRight: Radius.circular(16)),
              border: Border.all(color: AppTheme.border.withValues(alpha: 0.6)),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.5), blurRadius: 40)],
            ),
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                _buildHeader(os),
                if (_tab == 0) _buildMain(os),
                if (_tab == 1) _buildWifi(os),
                if (_tab == 2) _buildBluetooth(os),
                const SizedBox(height: 8),
              ]),
            ),
          ),
        ),
      ),
    ).animate().fadeIn(duration: 150.ms).scale(
      begin: const Offset(0.95, 0.95), end: const Offset(1, 1),
      duration: 180.ms, curve: Curves.easeOutBack,
    );
  }

  Widget _buildHeader(OsState os) {
    if (_tab != 0) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: AppTheme.border.withValues(alpha: 0.4))),
      ),
      child: Row(children: [
        Container(
          width: 32, height: 32,
          decoration: BoxDecoration(
            color: AppTheme.accentDim,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(Icons.tune_rounded, color: AppTheme.accent, size: 16),
        ),
        const SizedBox(width: 10),
        Text('Control Center',
          style: TextStyle(color: AppTheme.textPrimary, fontSize: 14, fontWeight: FontWeight.w600)),
        const Spacer(),
        GestureDetector(
          onTap: widget.onClose,
          child: Container(
            width: 24, height: 24,
            decoration: BoxDecoration(
              color: AppTheme.surfaceAlt,
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Icon(Icons.close, color: AppTheme.textSecondary, size: 14),
          ),
        ),
      ]),
    );
  }

  Widget _buildMain(OsState os) {
    return Padding(
      padding: const EdgeInsets.all(14),
      child: Column(children: [
  // Row 1: WiFi + Bluetooth (large tiles)
        Row(children: [
          Expanded(child: _BigTile(
            icon: Icons.wifi_rounded,
            label: 'Wi-Fi',
            sublabel: os.wifiEnabled ? os.connectedWifi : 'Off',
            active: os.wifiEnabled,
            onTap: () => setState(() => _tab = 1),
            onLongPress: os.toggleWifi,
          )),
          const SizedBox(width: 10),
          Expanded(child: _BigTile(
            icon: Icons.bluetooth_rounded,
            label: 'Bluetooth',
            sublabel: os.bluetoothEnabled ? 'On' : 'Off',
            active: os.bluetoothEnabled,
            onTap: () => setState(() => _tab = 2),
            onLongPress: os.toggleBluetooth,
          )),
        ]),
        const SizedBox(height: 10),
  // Brightness & Volume - Compact
        Row(children: [
          Expanded(child: _CompactSlider(
            icon: Icons.brightness_6_rounded,
            value: os.brightness,
            color: AppTheme.warning,
            onChanged: os.setBrightness,
          )),
          const SizedBox(width: 8),
          Expanded(child: _CompactSlider(
            icon: Icons.volume_up_rounded,
            value: os.volume,
            color: AppTheme.accent,
            onChanged: os.setVolume,
          )),
        ]),
        const SizedBox(height: 10),
  // Quick Settings with Pagination
        _buildQuickSettings(os),
        const SizedBox(height: 10),
  // User / admin card
        _UserCard(os: os, onAdminTap: () => _showAdminDialog(context)),
      ]),
    );
  }

  Widget _buildQuickSettings(OsState os) {
    return Container(
      height: 140,
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border.withValues(alpha: 0.5)),
      ),
      child: Column(children: [
        Expanded(
          child: PageView(
            onPageChanged: (page) => setState(() => _quickSettingsPage = page),
            children: [
              _buildQuickSettingsPage1(os),
              _buildQuickSettingsPage2(os),
            ],
          ),
        ),
  // Page Indicators
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _PageDot(active: _quickSettingsPage == 0),
              const SizedBox(width: 6),
              _PageDot(active: _quickSettingsPage == 1),
            ],
          ),
        ),
      ]),
    );
  }

  Widget _buildQuickSettingsPage1(OsState os) {
    return Consumer<VPNState>(
      builder: (context, vpn, _) {
        return Padding(
          padding: const EdgeInsets.all(10),
          child: Column(children: [
            Row(children: [
              Expanded(child: _SmallTile(
                icon: Icons.vpn_lock_rounded,
                label: vpn.isConnected ? '${vpn.hopChain.length}H VPN' : 'VPN',
                active: vpn.isConnected,
                onTap: () => vpn.isConnected ? vpn.disconnect() : (vpn.hopChain.isNotEmpty ? vpn.connect() : null),
                danger: !vpn.isConnected,
              )),
              const SizedBox(width: 8),
              Expanded(child: _SmallTile(icon: Icons.shield_rounded, label: 'Firewall', active: os.firewallEnabled, onTap: os.toggleFirewall, danger: !os.firewallEnabled)),
              const SizedBox(width: 8),
              Expanded(child: _SmallTile(icon: Icons.visibility_off, label: 'IP Mask', active: os.ipMasked, onTap: os.toggleIpMask, danger: !os.ipMasked)),
              const SizedBox(width: 8),
              Expanded(
                child: _SmallTile(
                  icon: Icons.dark_mode_rounded,
                  label: 'Dark',
                  active: context.watch<SettingsState>().isEffectivelyDark(
                        MediaQuery.platformBrightnessOf(context),
                      ),
                  onTap: () => context.read<SettingsState>().toggleLightDarkTheme(
                        MediaQuery.platformBrightnessOf(context),
                      ),
                ),
              ),
            ]),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: _SmallTile(
                icon: Icons.airplanemode_active,
                label: 'Airplane',
                active: !os.wifiEnabled && !os.bluetoothEnabled,
                onTap: () {
  // Toggle airplane: disable both wifi and BT
                  final on = os.wifiEnabled || os.bluetoothEnabled;
                  if (on) { os.toggleWifi(); os.toggleBluetooth(); }
                  else    { os.toggleWifi(); os.toggleBluetooth(); }
                },
              )),
              const SizedBox(width: 8),
              Expanded(child: _SmallTile(icon: Icons.do_not_disturb_rounded, label: 'DND', active: os.doNotDisturb, onTap: os.toggleDoNotDisturb)),
              const SizedBox(width: 8),
              Expanded(child: _SmallTile(
                icon: Icons.battery_saver,
                label: 'Power Save',
                active: false,
                onTap: () => SystemBridge.setBrightness(40),
              )),
              const SizedBox(width: 8),
              Expanded(child: _SmallTile(
                icon: Icons.screenshot_rounded,
                label: 'Screenshot',
                active: false,
                onTap: () => SystemBridge.screenshot(),
              )),
            ]),
          ]),
        );
      },
    );
  }

  Widget _buildQuickSettingsPage2(OsState os) {
    return Padding(
      padding: const EdgeInsets.all(10),
      child: Column(children: [
  // Hardware kill switches ? these call real Linux commands via SystemBridge
        Row(children: [
          Expanded(child: _SmallTile(
            icon: os.micEnabled ? Icons.mic_rounded : Icons.mic_off_rounded,
            label: 'Mic',
            active: os.micEnabled,
            onTap: os.toggleMic,
            danger: !os.micEnabled,
          )),
          const SizedBox(width: 8),
          Expanded(child: _SmallTile(
            icon: os.cameraEnabled ? Icons.videocam_rounded : Icons.videocam_off_rounded,
            label: 'Camera',
            active: os.cameraEnabled,
            onTap: os.toggleCamera,
            danger: !os.cameraEnabled,
          )),
          const SizedBox(width: 8),
          Expanded(child: _SmallTile(
            icon: Icons.location_on_rounded,
            label: 'Location',
            active: false,
            onTap: () {},
          )),
          const SizedBox(width: 8),
          Expanded(child: _SmallTile(
            icon: Icons.wifi_tethering_rounded,
            label: 'Hotspot',
            active: false,
            onTap: () {},
          )),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          Consumer<SettingsState>(
            builder: (context, settings, _) => Expanded(child: _SmallTile(
              icon: Icons.nightlight_rounded,
              label: 'Night',
              active: settings.nightLightEnabled,
              onTap: settings.toggleNightLight,
            )),
          ),
          const SizedBox(width: 8),
          Expanded(child: _SmallTile(icon: Icons.nfc_rounded, label: 'NFC', active: false, onTap: () {})),
          const SizedBox(width: 8),
          Expanded(child: _SmallTile(icon: Icons.flashlight_on_rounded, label: 'Flash', active: false, onTap: () {})),
          const SizedBox(width: 8),
          Expanded(child: _SmallTile(icon: Icons.power_settings_new, label: 'Power', active: false, onTap: () {})),
        ]),
      ]),
    );
  }

  Widget _buildWifi(OsState os) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
      child: Column(children: [
        Row(children: [
          GestureDetector(
            onTap: () => setState(() => _tab = 0),
            child: Icon(Icons.arrow_back_ios_rounded, color: AppTheme.accent, size: 14),
          ),
          const SizedBox(width: 8),
          Text('Wi-Fi', style: TextStyle(color: AppTheme.textPrimary, fontSize: 14, fontWeight: FontWeight.w600)),
          const Spacer(),
          GestureDetector(
            onTap: () => _showWifiSettings(context),
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppTheme.surfaceAlt,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(Icons.settings_rounded, color: AppTheme.accent, size: 14),
            ),
          ),
          const SizedBox(width: 8),
          _OsSwitch(value: os.wifiEnabled, onChanged: (_) => os.toggleWifi()),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: os.scanWifi,
            child: os.scanningWifi
              ? SizedBox(width: 14, height: 14,
                  child: CircularProgressIndicator(strokeWidth: 1.5, color: AppTheme.accent))
              : Icon(Icons.refresh_rounded, color: AppTheme.accent, size: 16),
          ),
        ]),
        const SizedBox(height: 12),
        if (!os.wifiEnabled)
          Padding(padding: EdgeInsets.all(20),
            child: Text('Wi-Fi is off', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)))
        else
          ...os.wifiNetworks.map((n) => _WifiTile(
            ssid: n['ssid'], signal: n['signal'],
            secured: n['secured'], connected: n['connected'],
            onTap: () => _connectToWifi(context, os, n),
          )),
      ]),
    );
  }

  Widget _buildBluetooth(OsState os) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
      child: Column(children: [
        Row(children: [
          GestureDetector(
            onTap: () => setState(() => _tab = 0),
            child: Icon(Icons.arrow_back_ios_rounded, color: AppTheme.accent, size: 14),
          ),
          const SizedBox(width: 8),
          Text('Bluetooth', style: TextStyle(color: AppTheme.textPrimary, fontSize: 14, fontWeight: FontWeight.w600)),
          const Spacer(),
          GestureDetector(
            onTap: () => _showBluetoothSettings(context),
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppTheme.surfaceAlt,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(Icons.settings_rounded, color: AppTheme.accent, size: 14),
            ),
          ),
          const SizedBox(width: 8),
          _OsSwitch(value: os.bluetoothEnabled, onChanged: (_) => os.toggleBluetooth()),
        ]),
        const SizedBox(height: 12),
        if (!os.bluetoothEnabled)
          Padding(padding: EdgeInsets.all(20),
            child: Text('Bluetooth is off', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)))
        else
          ...os.btDevices.map((d) => _BtTile(
            name: d['name'], type: d['type'],
            paired: d['paired'], connected: d['connected'],
            onTap: () {
              final mac = (d['mac'] as String?) ?? (d['name'] as String);
              if (d['connected'] == true) {
                os.disconnectBluetooth(mac);
              } else {
                os.connectBluetooth(mac);
              }
            },
          )),
      ]),
    );
  }

  void _showAdminDialog(BuildContext context) {
    final os = context.read<OsState>();
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: AppTheme.surfaceAlt,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: AppTheme.accent),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.usb_rounded, color: AppTheme.accent, size: 32),
            const SizedBox(height: 12),
            Text('Admin Connection',
              style: TextStyle(color: AppTheme.accent, fontSize: 14, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(
              'Connect via USB to the admin device.\nThe admin device will push an auth token.',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            GestureDetector(
              onTap: () { os.connectWiredAdmin('ADMIN-WIRE-AUTH'); Navigator.pop(context); },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: AppTheme.accentDim,
                  border: Border.all(color: AppTheme.accent),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text('[DEV] Simulate Admin Connection',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppTheme.accent, fontSize: 12, fontWeight: FontWeight.bold)),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  void _connectToWifi(BuildContext context, OsState os, Map<String, dynamic> network) {
    if (network['connected']) return;
    if (!network['secured']) {
      os.connectWifi(network['ssid']);
      return;
    }

    final passwordController = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => _WifiPasswordDialog(
        network: network,
        controller: passwordController,
        onConnect: () {
          if (passwordController.text.isNotEmpty) {
            os.connectWifi(network['ssid'], password: passwordController.text);
            Navigator.pop(context);
          }
        },
      ),
    );
  }

  void _showWifiSettings(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: AppTheme.border.withValues(alpha: 0.6)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Row(children: [
              Icon(Icons.wifi_rounded, color: AppTheme.accent, size: 24),
              const SizedBox(width: 12),
              Text('Advanced Wi-Fi Settings',
                style: TextStyle(color: AppTheme.textPrimary, fontSize: 14, fontWeight: FontWeight.bold)),
              const Spacer(),
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: const Icon(Icons.close, color: AppTheme.textSecondary, size: 18),
              ),
            ]),
            const SizedBox(height: 20),
            _SettingRow(icon: Icons.network_check, label: 'Network Preferences', onTap: () {}),
            _SettingRow(icon: Icons.dns_rounded, label: 'DNS Settings', onTap: () {}),
            _SettingRow(icon: Icons.vpn_key_rounded, label: 'Saved Networks', onTap: () {}),
            _SettingRow(icon: Icons.speed_rounded, label: 'Network Speed Test', onTap: () {}),
            _SettingRow(icon: Icons.info_outline_rounded, label: 'Connection Info', onTap: () {}),
          ]),
        ),
      ),
    );
  }

  void _showBluetoothSettings(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: AppTheme.border.withValues(alpha: 0.6)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Row(children: [
              Icon(Icons.bluetooth_rounded, color: AppTheme.accent, size: 24),
              const SizedBox(width: 12),
              Text('Advanced Bluetooth Settings',
                style: TextStyle(color: AppTheme.textPrimary, fontSize: 14, fontWeight: FontWeight.bold)),
              const Spacer(),
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: const Icon(Icons.close, color: AppTheme.textSecondary, size: 18),
              ),
            ]),
            const SizedBox(height: 20),
            _SettingRow(icon: Icons.devices_rounded, label: 'Paired Devices', onTap: () {}),
            _SettingRow(icon: Icons.visibility_rounded, label: 'Visibility Settings', onTap: () {}),
            _SettingRow(icon: Icons.file_download_rounded, label: 'File Transfer', onTap: () {}),
            _SettingRow(icon: Icons.headphones_rounded, label: 'Audio Settings', onTap: () {}),
            _SettingRow(icon: Icons.info_outline_rounded, label: 'Device Info', onTap: () {}),
          ]),
        ),
      ),
    );
  }
}

//  Big toggle tile (WiFi / BT) - Windows 11 Style  
class _BigTile extends StatelessWidget {
  final IconData icon;
  final String label, sublabel;
  final bool active;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  const _BigTile({required this.icon, required this.label, required this.sublabel,
    required this.active, required this.onTap, this.onLongPress});

  @override
  Widget build(BuildContext context) {
    final color = active ? AppTheme.accent : AppTheme.textSecondary;
    return AnimatedContainer(
      duration: 200.ms,
      height: 64,
      decoration: BoxDecoration(
        color: active ? AppTheme.accentDim : AppTheme.surfaceAlt,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: active ? AppTheme.accent.withValues(alpha: 0.5) : AppTheme.border),
      ),
      child: Row(children: [
  // Left side: Toggle on/off
        Expanded(
          child: GestureDetector(
            onTap: onLongPress,
            child: Container(
              padding: const EdgeInsets.all(12),
              child: Row(children: [
                Container(
                  width: 32, height: 32,
                  decoration: BoxDecoration(
                    color: active ? AppTheme.accent.withValues(alpha: 0.2) : AppTheme.surface,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: color, size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
                    Text(sublabel,
                      style: TextStyle(color: AppTheme.textSecondary, fontSize: 10),
                      overflow: TextOverflow.ellipsis),
                  ],
                )),
              ]),
            ),
          ),
        ),
  // Right side: Arrow to open settings
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: 40,
            decoration: BoxDecoration(
              border: Border(left: BorderSide(color: AppTheme.border.withValues(alpha: 0.5))),
            ),
            child: Icon(Icons.chevron_right_rounded, color: AppTheme.textSecondary, size: 20),
          ),
        ),
      ]),
    );
  }
}

//  Small toggle tile  
class _SmallTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final bool danger;
  final VoidCallback onTap;
  const _SmallTile({required this.icon, required this.label,
    required this.active, required this.onTap, this.danger = false});

  @override
  Widget build(BuildContext context) {
    final color = danger && !active ? AppTheme.danger : active ? AppTheme.accent : AppTheme.textSecondary;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: 200.ms,
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: active ? AppTheme.accentDim : AppTheme.surfaceAlt,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: active ? AppTheme.accent.withValues(alpha: 0.4) : AppTheme.border),
        ),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.w600),
            textAlign: TextAlign.center),
        ]),
      ),
    );
  }
}

//  Slider tile  
class _SliderTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final double value;
  final Color color;
  final ValueChanged<double> onChanged;
  const _SliderTile({required this.icon, required this.label,
    required this.value, required this.color, required this.onChanged});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(
      color: AppTheme.surfaceAlt,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: AppTheme.border),
    ),
    child: Row(children: [
      Icon(icon, color: color, size: 16),
      const SizedBox(width: 8),
      Expanded(
        child: SliderTheme(
          data: SliderThemeData(
            activeTrackColor: color,
            inactiveTrackColor: AppTheme.border,
            thumbColor: color,
            overlayColor: color.withValues(alpha: 0.15),
            trackHeight: 3,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
          ),
          child: Slider(value: value, onChanged: onChanged),
        ),
      ),
      Text('${(value * 100).round()}%',
        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w600)),
    ]),
  );
}

//  Compact Slider (Windows 11 Style)  
class _CompactSlider extends StatelessWidget {
  final IconData icon;
  final double value;
  final Color color;
  final ValueChanged<double> onChanged;
  const _CompactSlider({required this.icon, required this.value, required this.color, required this.onChanged});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    decoration: BoxDecoration(
      color: AppTheme.surfaceAlt,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: AppTheme.border),
    ),
    child: Column(children: [
      Row(children: [
        Icon(icon, color: color, size: 14),
        const Spacer(),
        Text('${(value * 100).round()}%',
          style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.w600)),
      ]),
      const SizedBox(height: 6),
      SliderTheme(
        data: SliderThemeData(
          activeTrackColor: color,
          inactiveTrackColor: AppTheme.border,
          thumbColor: color,
          overlayColor: color.withValues(alpha: 0.15),
          trackHeight: 2.5,
          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
        ),
        child: Slider(value: value, onChanged: onChanged),
      ),
    ]),
  );
}

//  User card  
class _UserCard extends StatelessWidget {
  final OsState os;
  final VoidCallback onAdminTap;
  const _UserCard({required this.os, required this.onAdminTap});

  @override
  Widget build(BuildContext context) {
    final isAdmin = os.role == UserRole.admin;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceAlt,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isAdmin ? AppTheme.accent.withValues(alpha: 0.4) : AppTheme.border),
      ),
      child: Row(children: [
        Container(
          width: 36, height: 36,
          decoration: BoxDecoration(
            color: isAdmin ? AppTheme.accentDim : AppTheme.surface,
            shape: BoxShape.circle,
            border: Border.all(color: isAdmin ? AppTheme.accent : AppTheme.border),
          ),
          child: Icon(isAdmin ? Icons.admin_panel_settings_rounded : Icons.person_rounded,
            color: isAdmin ? AppTheme.accent : AppTheme.textSecondary, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(isAdmin ? 'Administrator' : 'Standard User',
            style: TextStyle(
              color: isAdmin ? AppTheme.accent : AppTheme.textPrimary,
              fontSize: 12, fontWeight: FontWeight.w600)),
          Text(isAdmin ? 'Full access via wired connection' : 'Connect USB to get admin access',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 10)),
        ])),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: isAdmin ? os.disconnectAdmin : onAdminTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: isAdmin ? AppTheme.danger.withValues(alpha: 0.1) : AppTheme.accentDim,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: isAdmin ? AppTheme.danger : AppTheme.accent),
            ),
            child: Text(isAdmin ? 'Revoke' : 'Connect',
              style: TextStyle(
                color: isAdmin ? AppTheme.danger : AppTheme.accent,
                fontSize: 10, fontWeight: FontWeight.bold)),
          ),
        ),
      ]),
    );
  }
}

//  WiFi tile  
class _WifiTile extends StatelessWidget {
  final String ssid;
  final int signal;
  final bool secured, connected;
  final VoidCallback onTap;
  const _WifiTile({required this.ssid, required this.signal,
    required this.secured, required this.connected, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: connected ? AppTheme.accentDim : AppTheme.surfaceAlt,
        border: Border.all(color: connected ? AppTheme.accent : AppTheme.border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(children: [
        Icon(Icons.wifi_rounded, color: connected ? AppTheme.accent : AppTheme.textSecondary, size: 16),
        const SizedBox(width: 10),
        Expanded(child: Text(ssid, style: TextStyle(
          color: connected ? AppTheme.accent : AppTheme.textPrimary,
          fontSize: 12, fontWeight: connected ? FontWeight.bold : FontWeight.normal))),
        if (secured) const Icon(Icons.lock_rounded, color: AppTheme.textSecondary, size: 11),
        const SizedBox(width: 6),
        Text('$signal%', style: TextStyle(color: AppTheme.textSecondary, fontSize: 10)),
        if (connected) ...[
          const SizedBox(width: 6),
          Text('\u2713', style: TextStyle(color: AppTheme.accent, fontSize: 12, fontWeight: FontWeight.bold)),
        ],
      ]),
    ),
  );
}

// Bluetooth tile
class _BtTile extends StatelessWidget {
  final String name, type;
  final bool paired, connected;
  final VoidCallback onTap;
  const _BtTile({required this.name, required this.type,
    required this.paired, required this.connected, required this.onTap});

  IconData get _icon {
    switch (type) {
      case 'audio':  return Icons.headphones_rounded;
      case 'input':  return Icons.keyboard_rounded;
      case 'device': return Icons.devices_rounded;
      default:       return Icons.bluetooth_rounded;
    }
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: connected ? AppTheme.accentDim : AppTheme.surfaceAlt,
        border: Border.all(color: connected ? AppTheme.accent : AppTheme.border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(children: [
        Icon(_icon, color: connected ? AppTheme.accent : AppTheme.textSecondary, size: 16),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(name, style: TextStyle(
            color: connected ? AppTheme.accent : AppTheme.textPrimary, fontSize: 12)),
          Text(paired ? 'Paired' : 'Not paired',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 9)),
        ])),
        Text(connected ? 'Disconnect' : 'Connect',
          style: TextStyle(
            color: connected ? AppTheme.danger : AppTheme.accent,
            fontSize: 10, fontWeight: FontWeight.bold)),
      ]),
    ),
  );
}

//  OS Switch  
class _OsSwitch extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  const _OsSwitch({required this.value, required this.onChanged});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: () => onChanged(!value),
    child: AnimatedContainer(
      duration: 200.ms,
      width: 38, height: 22,
      decoration: BoxDecoration(
        color: value ? AppTheme.accentDim : AppTheme.surface,
        border: Border.all(color: value ? AppTheme.accent : AppTheme.border),
        borderRadius: BorderRadius.circular(11),
      ),
      child: AnimatedAlign(
        duration: 200.ms,
        alignment: value ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.all(3),
          width: 14, height: 14,
          decoration: BoxDecoration(
            color: value ? AppTheme.accent : AppTheme.textSecondary,
            shape: BoxShape.circle,
          ),
        ),
      ),
    ),
  );
}

//  Page Dot Indicator  
class _PageDot extends StatelessWidget {
  final bool active;
  const _PageDot({required this.active});
  @override
  Widget build(BuildContext context) => AnimatedContainer(
    duration: 200.ms,
    width: active ? 16 : 6,
    height: 6,
    decoration: BoxDecoration(
      color: active ? AppTheme.accent : AppTheme.border,
      borderRadius: BorderRadius.circular(3),
    ),
  );
}

//  Setting Row  
class _SettingRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _SettingRow({required this.icon, required this.label, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceAlt,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(children: [
        Icon(icon, color: AppTheme.accent, size: 16),
        const SizedBox(width: 12),
        Expanded(
          child: Text(label,
            style: TextStyle(color: AppTheme.textPrimary, fontSize: 12, fontWeight: FontWeight.w500)),
        ),
        const Icon(Icons.chevron_right_rounded, color: AppTheme.textSecondary, size: 18),
      ]),
    ),
  );
}

//  WiFi Password Dialog  
class _WifiPasswordDialog extends StatefulWidget {
  final Map<String, dynamic> network;
  final TextEditingController controller;
  final VoidCallback onConnect;
  const _WifiPasswordDialog({required this.network, required this.controller, required this.onConnect});
  
  @override
  State<_WifiPasswordDialog> createState() => _WifiPasswordDialogState();
}

class _WifiPasswordDialogState extends State<_WifiPasswordDialog> {
  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppTheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: AppTheme.border.withValues(alpha: 0.6)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.accentDim,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.wifi_lock_rounded, color: AppTheme.accent, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(widget.network['ssid'],
                  style: TextStyle(color: AppTheme.textPrimary, fontSize: 14, fontWeight: FontWeight.bold)),
                Text('Enter password',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
              ]),
            ),
          ]),
          const SizedBox(height: 20),
          TextField(
            key: const ValueKey('wifi_password_field'),
            controller: widget.controller,
            obscureText: true,
            autofocus: true,
            style: TextStyle(color: AppTheme.textPrimary, fontSize: 13),
            cursorColor: AppTheme.accent,
            decoration: InputDecoration(
              hintText: 'Password',
              hintStyle: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
              filled: true,
              fillColor: AppTheme.surfaceAlt,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppTheme.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppTheme.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: AppTheme.accent),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
            onSubmitted: (_) => widget.onConnect(),
          ),
          const SizedBox(height: 20),
          Row(children: [
            Expanded(
              child: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceAlt,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: Text('Cancel',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: GestureDetector(
                onTap: widget.onConnect,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: AppTheme.accentDim,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.accent),
                  ),
                  child: Text('Connect',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppTheme.accent, fontSize: 12, fontWeight: FontWeight.bold)),
                ),
              ),
            ),
          ]),
        ]),
      ),
    );
  }
}
