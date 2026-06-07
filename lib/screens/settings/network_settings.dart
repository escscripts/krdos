import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/settings_state.dart';
import '../../core/os_state.dart';
import '../../core/platform/system_bridge.dart';
import '../../theme/app_theme.dart';
import 'multihop_vpn_screen.dart';

class NetworkSettingsScreen extends StatefulWidget {
  final int initialTab;

  const NetworkSettingsScreen({super.key, this.initialTab = 0});

  @override
  State<NetworkSettingsScreen> createState() => _NetworkSettingsScreenState();
}

class _NetworkSettingsScreenState extends State<NetworkSettingsScreen> {
  late int _selectedTab = widget.initialTab.clamp(0, 4);
  final TextEditingController _primaryDNSController = TextEditingController();
  final TextEditingController _secondaryDNSController = TextEditingController();
  final TextEditingController _proxyAddressController = TextEditingController();
  final TextEditingController _proxyPortController = TextEditingController();

  @override
  void dispose() {
    _primaryDNSController.dispose();
    _secondaryDNSController.dispose();
    _proxyAddressController.dispose();
    _proxyPortController.dispose();
    super.dispose();
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
                    _buildSidebarChip(0, Icons.wifi_rounded, 'Wi-Fi'),
                    _buildSidebarChip(4, Icons.settings_ethernet_rounded, 'Ethernet'),
                    _buildSidebarChip(1, Icons.security_rounded, 'Firewall'),
                    _buildSidebarChip(2, Icons.dns_rounded, 'DNS'),
                    _buildSidebarChip(3, Icons.lan_rounded, 'Proxy'),
                  ],
                ),
              ),
              Container(height: 1, color: AppTheme.border.withValues(alpha: 0.45)),
              Expanded(child: _buildContent()),
            ],
          );
        }
        return Row(
          children: [
            _buildSidebar(),
            Expanded(child: _buildContent()),
          ],
        );
      },
    );
  }

  Widget _buildSidebarChip(int index, IconData icon, String label) {
    final isSelected = _selectedTab == index;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Material(
        color: isSelected ? AppTheme.accent.withValues(alpha: 0.12) : AppTheme.surfaceAlt,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => setState(() => _selectedTab = index),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                Icon(icon, size: 16, color: isSelected ? AppTheme.accent : AppTheme.textSecondary),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    color: isSelected ? AppTheme.accent : AppTheme.textPrimary,
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSidebar() {
    return Container(
      width: 220,
      decoration: BoxDecoration(
        color: AppTheme.surface,
        border: Border(right: BorderSide(color: AppTheme.border.withValues(alpha: 0.5))),
      ),
      child: Column(
        children: [
          _buildSidebarItem(0, Icons.wifi_rounded, 'Wi-Fi'),
          _buildSidebarItem(4, Icons.settings_ethernet_rounded, 'Ethernet'),
          _buildSidebarItem(1, Icons.security_rounded, 'Firewall'),
          _buildSidebarItem(2, Icons.dns_rounded, 'DNS'),
          _buildSidebarItem(3, Icons.lan_rounded, 'Proxy'),
        ],
      ),
    );
  }

  Widget _buildSidebarItem(int index, IconData icon, String label) {
    final isSelected = _selectedTab == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedTab = index),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.accent.withValues(alpha: 0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? AppTheme.accent : Colors.transparent,
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: isSelected ? AppTheme.accent : AppTheme.textSecondary, size: 20),
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? AppTheme.accent : AppTheme.textPrimary,
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    switch (_selectedTab) {
      case 0:
        return _buildWiFiTab();
      case 1:
        return _buildFirewallTab();
      case 2:
        return _buildDNSTab();
      case 3:
        return _buildProxyTab();
      case 4:
        return const _EthernetTab();
      default:
        return const SizedBox();
    }
  }

  Widget _buildWiFiTab() {
    return Consumer<OsState>(
      builder: (context, os, _) {
        return ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Row(
              children: [
                Text(
                  'Wi-Fi Networks',
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () => os.scanWifi(),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppTheme.accent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          os.scanningWifi ? Icons.refresh_rounded : Icons.search_rounded,
                          color: Colors.black,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          os.scanningWifi ? 'Scanning...' : 'Scan',
                          style: TextStyle(
                            color: Colors.black,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Available networks in your area',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 24),
            _buildCard(
              'Wi-Fi',
              Column(
                children: [
                  _buildToggle(
                    'Wi-Fi',
                    os.wifiEnabled ? 'Connected to ${os.connectedWifi}' : 'Disabled',
                    os.wifiEnabled,
                    (_) => os.toggleWifi(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            ...os.wifiNetworks.map((network) => _buildWiFiNetworkCard(network, os)),
          ],
        );
      },
    );
  }

  Widget _buildWiFiNetworkCard(Map<String, dynamic> network, OsState os) {
    final isConnected = network['connected'] as bool;
    final signal = network['signal'] as int;
    final secured = network['secured'] as bool;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isConnected ? AppTheme.accent.withOpacity(0.1) : AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isConnected ? AppTheme.accent : AppTheme.border,
          width: isConnected ? 2 : 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            _getWiFiIcon(signal),
            color: isConnected ? AppTheme.accent : AppTheme.textSecondary,
            size: 24,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      network['ssid'],
                      style: TextStyle(
                        color: isConnected ? AppTheme.accent : AppTheme.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (secured) ...[
                      const SizedBox(width: 8),
                      const Icon(Icons.lock_rounded, color: AppTheme.textSecondary, size: 14),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  isConnected ? 'Connected' : 'Signal: $signal%',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                ),
              ],
            ),
          ),
          if (!isConnected)
            GestureDetector(
              onTap: () => os.connectWifi(network['ssid']),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: AppTheme.accent,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'Connect',
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          if (isConnected)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppTheme.accent,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                'Connected',
                style: TextStyle(
                  color: Colors.black,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }

  IconData _getWiFiIcon(int signal) {
    if (signal >= 80) return Icons.wifi_rounded;
    if (signal >= 60) return Icons.wifi_2_bar_rounded;
    if (signal >= 40) return Icons.wifi_1_bar_rounded;
    return Icons.wifi_off_rounded;
  }

  Widget _buildFirewallTab() {
    return Consumer2<SettingsState, OsState>(
      builder: (context, settings, os, _) {
        return ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(
              'Firewall',
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Manage firewall rules and network security',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 24),
            _buildCard(
              'Firewall Status',
              _buildToggle(
                'Firewall',
                os.firewallEnabled ? 'Active - Blocking threats' : 'Disabled',
                os.firewallEnabled,
                (_) => os.toggleFirewall(),
              ),
            ),
            const SizedBox(height: 16),
            _buildCard(
              'Firewall Rules',
              Column(
                children: [
                  ...settings.firewallRules.asMap().entries.map((entry) {
                    final index = entry.key;
                    final rule = entry.value;
                    return _buildFirewallRuleCard(rule, index, settings);
                  }),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildFirewallRuleCard(Map<String, dynamic> rule, int index, SettingsState settings) {
    final enabled = rule['enabled'] as bool;
    final action = rule['action'] as String;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: enabled ? AppTheme.surfaceAlt : AppTheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: action == 'Block' 
                  ? AppTheme.danger.withOpacity(0.15)
                  : AppTheme.success.withOpacity(0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(
              action == 'Block' ? Icons.block_rounded : Icons.check_circle_rounded,
              color: action == 'Block' ? AppTheme.danger : AppTheme.success,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  rule['name'],
                  style: TextStyle(
                    color: enabled ? AppTheme.textPrimary : AppTheme.textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${rule['type']} ‚¬¢ ${rule['action']}',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                ),
              ],
            ),
          ),
          Switch(
            value: enabled,
            onChanged: (_) => settings.toggleFirewallRule(index),
            activeColor: AppTheme.accent,
          ),
        ],
      ),
    );
  }

  Widget _buildDNSTab() {
    return Consumer<SettingsState>(
      builder: (context, settings, _) {
        _primaryDNSController.text = settings.primaryDNS;
        _secondaryDNSController.text = settings.secondaryDNS;
        
        return ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(
              'DNS Settings',
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Configure Domain Name System servers',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 24),
            _buildCard(
              'DNS Configuration',
              Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _buildDNSModeButton('Automatic', 'automatic', settings),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildDNSModeButton('Custom', 'custom', settings),
                      ),
                    ],
                  ),
                  if (settings.dnsMode == 'custom') ...[
                    const SizedBox(height: 20),
                    _buildTextField(
                      'Primary DNS',
                      _primaryDNSController,
                      (value) => settings.setPrimaryDNS(value),
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      'Secondary DNS',
                      _secondaryDNSController,
                      (value) => settings.setSecondaryDNS(value),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
            _buildCard(
              'Popular DNS Servers',
              Column(
                children: [
                  _buildDNSPreset('Google DNS', '8.8.8.8', '8.8.4.4', settings),
                  const SizedBox(height: 8),
                  _buildDNSPreset('Cloudflare DNS', '1.1.1.1', '1.0.0.1', settings),
                  const SizedBox(height: 8),
                  _buildDNSPreset('OpenDNS', '208.67.222.222', '208.67.220.220', settings),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildDNSModeButton(String label, String mode, SettingsState settings) {
    final isSelected = settings.dnsMode == mode;
    return GestureDetector(
      onTap: () => settings.setDNSMode(mode),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.accent.withOpacity(0.15) : AppTheme.surfaceAlt,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? AppTheme.accent : AppTheme.border,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? AppTheme.accent : AppTheme.textPrimary,
              fontSize: 13,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDNSPreset(String name, String primary, String secondary, SettingsState settings) {
    return GestureDetector(
      onTap: () {
        settings.setDNSMode('custom');
        settings.setPrimaryDNS(primary);
        settings.setSecondaryDNS(secondary);
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.surfaceAlt,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppTheme.border),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$primary, $secondary',
                    style: TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_rounded, color: AppTheme.textSecondary, size: 18),
          ],
        ),
      ),
    );
  }

  Widget _buildProxyTab() {
    return Consumer<SettingsState>(
      builder: (context, settings, _) {
        _proxyAddressController.text = settings.proxyAddress;
        _proxyPortController.text = settings.proxyPort;
        
        return ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(
              'Proxy Settings',
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Configure proxy server for network connections',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 24),
            _buildCard(
              'Proxy Configuration',
              Column(
                children: [
                  _buildToggle(
                    'Use Proxy Server',
                    settings.proxyEnabled ? 'Enabled' : 'Disabled',
                    settings.proxyEnabled,
                    (_) => settings.toggleProxy(),
                  ),
                  if (settings.proxyEnabled) ...[
                    const SizedBox(height: 20),
                    _buildTextField(
                      'Proxy Address',
                      _proxyAddressController,
                      (value) => settings.setProxyAddress(value),
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      'Port',
                      _proxyPortController,
                      (value) => settings.setProxyPort(value),
                    ),
                  ],
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildCard(String title, Widget child) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  Widget _buildToggle(String title, String subtitle, bool value, Function(bool) onChanged) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
              ),
            ],
          ),
        ),
        Switch(
          value: value,
          onChanged: onChanged,
          activeColor: AppTheme.accent,
        ),
      ],
    );
  }

  Widget _buildTextField(String label, TextEditingController controller, Function(String) onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          style: TextStyle(color: AppTheme.textPrimary, fontSize: 13),
          decoration: InputDecoration(
            filled: true,
            fillColor: AppTheme.surfaceAlt,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: AppTheme.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: AppTheme.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: AppTheme.accent, width: 2),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
          onChanged: onChanged,
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Ethernet Tab — detects wired interfaces via platform channel
// ─────────────────────────────────────────────────────────────────────────────
class _EthernetTab extends StatefulWidget {
  const _EthernetTab();

  @override
  State<_EthernetTab> createState() => _EthernetTabState();
}

class _EthernetTabState extends State<_EthernetTab> {
  List<Map<String, dynamic>> _ifaces = [];
  bool _loading = true;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _refresh();
    // Auto-refresh every 5 s so plug/unplug events show immediately
    _refreshTimer = Timer.periodic(const Duration(seconds: 5), (_) => _refresh());
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
    final list = await SystemBridge.ethernetList();
    if (!mounted) return;
    setState(() {
      _ifaces = list;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Row(
          children: [
            Text(
              'Ethernet',
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Spacer(),
            GestureDetector(
              onTap: () { setState(() => _loading = true); _refresh(); },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: AppTheme.accent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(children: [
                  Icon(_loading ? Icons.refresh_rounded : Icons.refresh_rounded,
                      color: Colors.black, size: 18),
                  const SizedBox(width: 8),
                  Text(_loading ? 'Scanning...' : 'Refresh',
                      style: const TextStyle(color: Colors.black, fontSize: 13, fontWeight: FontWeight.w600)),
                ]),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Wired network interfaces detected on this device',
          style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
        ),
        const SizedBox(height: 24),

        if (_loading)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(48),
              child: CircularProgressIndicator(color: AppTheme.accent),
            ),
          )
        else if (_ifaces.isEmpty)
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.border),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.settings_ethernet_rounded,
                    size: 48, color: AppTheme.textSecondary.withValues(alpha: 0.4)),
                const SizedBox(height: 16),
                Text('No Ethernet Adapters Found',
                    style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Text(
                  'Plug in an Ethernet cable or check that the\n'
                  'adapter is recognized by the kernel.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                ),
              ],
            ),
          )
        else
          ..._ifaces.map((iface) => _buildIfaceCard(iface)),
      ],
    );
  }

  Widget _buildIfaceCard(Map<String, dynamic> iface) {
    final name = iface['iface'] as String? ?? '';
    final connected = iface['connected'] as bool? ?? false;
    final ip = iface['ip'] as String? ?? '';
    final speed = iface['speed'] as int? ?? 0;
    final mac = iface['mac'] as String? ?? '';

    final speedLabel = speed > 0
        ? (speed >= 1000 ? '${speed ~/ 1000} Gbps' : '$speed Mbps')
        : 'Speed unknown';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: connected
            ? AppTheme.accent.withValues(alpha: 0.08)
            : AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: connected ? AppTheme.accent : AppTheme.border,
          width: connected ? 2 : 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: (connected ? AppTheme.accent : AppTheme.textSecondary)
                  .withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.settings_ethernet_rounded,
              color: connected ? AppTheme.accent : AppTheme.textSecondary,
              size: 26,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Text(name,
                      style: TextStyle(
                          color: connected ? AppTheme.accent : AppTheme.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: (connected
                              ? const Color(0xFF3FB950)
                              : AppTheme.textSecondary)
                          .withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      connected ? 'Connected' : 'Disconnected',
                      style: TextStyle(
                          color: connected
                              ? const Color(0xFF3FB950)
                              : AppTheme.textSecondary,
                          fontSize: 11,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                ]),
                const SizedBox(height: 4),
                if (ip.isNotEmpty)
                  Text('IP: $ip',
                      style: TextStyle(
                          color: AppTheme.textSecondary, fontSize: 12)),
                if (mac.isNotEmpty)
                  Text('MAC: $mac  •  $speedLabel',
                      style: TextStyle(
                          color: AppTheme.textSecondary, fontSize: 12)),
                if (ip.isEmpty && mac.isEmpty)
                  Text('No cable connected',
                      style: TextStyle(
                          color: AppTheme.textSecondary, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

