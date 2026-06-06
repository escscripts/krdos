import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../theme/app_theme.dart';
import '../../core/vpn/vpn_engine.dart';
import '../../core/vpn/vpn_hop.dart';
import '../../core/vpn/vpn_server.dart';
import '../../core/vpn/vpn_encryption.dart';

/// Advanced Multi-hop VPN Settings Screen
class VpnSettingsScreen extends StatefulWidget {
  const VpnSettingsScreen({Key? key}) : super(key: key);

  @override
  State<VpnSettingsScreen> createState() => _VpnSettingsScreenState();
}

class _VpnSettingsScreenState extends State<VpnSettingsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late TextEditingController _chainNameController;
  final List<VpnHop> _tempHops = [];
  String? _selectedChainId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _chainNameController = TextEditingController();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _chainNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.surface,
        elevation: 0,
        title: Text(
          'Multi-hop VPN',
          style: TextStyle(color: AppTheme.textPrimary, fontSize: 18),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppTheme.accent,
          unselectedLabelColor: AppTheme.textSecondary,
          indicatorColor: AppTheme.accent,
          tabs: const [
            Tab(icon: Icon(Icons.language), text: 'Connection'),
            Tab(icon: Icon(Icons.settings), text: 'Chains'),
            Tab(icon: Icon(Icons.security), text: 'Advanced'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildConnectionTab(),
          _buildChainsTab(),
          _buildAdvancedTab(),
        ],
      ),
    );
  }

  // ==================== Connection Tab ====================

  Widget _buildConnectionTab() {
    return Consumer<VpnEngine>(
      builder: (context, vpnEngine, child) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
  // Connection Status Card
              _buildStatusCard(vpnEngine),
              const SizedBox(height: 20),

  // Quick Connect
              if (vpnEngine.activeChain == null)
                _buildQuickConnectSection(vpnEngine),

  // Active Connection Details
              if (vpnEngine.isConnected) ...[
                const SizedBox(height: 20),
                _buildActiveConnectionDetails(vpnEngine),
              ],

  // Connection Stats
              if (vpnEngine.isConnected) ...[
                const SizedBox(height: 20),
                _buildConnectionStats(vpnEngine),
              ],

  // Disconnect Button
              if (vpnEngine.isConnected) ...[
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => vpnEngine.disconnect(),
                    icon: const Icon(Icons.power_settings_new),
                    label: const Text('Disconnect'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.danger,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatusCard(VpnEngine vpnEngine) {
    final statusColor = vpnEngine.isConnected
        ? AppTheme.success
        : vpnEngine.isConnecting
        ? AppTheme.warning
        : vpnEngine.state == VpnConnectionState.error
        ? AppTheme.danger
        : AppTheme.textSecondary;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        border: Border.all(color: statusColor.withOpacity(0.5)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: statusColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                vpnEngine.isConnected
                    ? 'Connected'
                    : vpnEngine.isConnecting
                    ? 'Connecting...'
                    : vpnEngine.state == VpnConnectionState.error
                    ? 'Error'
                    : 'Disconnected',
                style: TextStyle(
                  color: statusColor,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          if (vpnEngine.errorMessage != null) ...[
            const SizedBox(height: 8),
            Text(
              vpnEngine.errorMessage!,
              style: TextStyle(color: AppTheme.danger, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildQuickConnectSection(VpnEngine vpnEngine) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Connect',
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        if (vpnEngine.savedChains.isNotEmpty)
          SizedBox(
            height: 50,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: vpnEngine.savedChains.length,
              itemBuilder: (context, index) {
                final chain = vpnEngine.savedChains[index];
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ElevatedButton.icon(
                    onPressed: () => vpnEngine.connect(chain),
                    icon: const Icon(Icons.vpn_lock),
                    label: Text(chain.name),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.accent,
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _buildActiveConnectionDetails(VpnEngine vpnEngine) {
    final chain = vpnEngine.activeChain;
    if (chain == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceAlt,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Connection Details',
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          ..._buildDetailRows(vpnEngine, chain),
        ],
      ),
    );
  }

  List<Widget> _buildDetailRows(VpnEngine vpnEngine, VpnChain chain) {
    return [
      _detailRow('Chain', chain.name),
      _detailRow('Hops', chain.hopCountDisplay),
      _detailRow('Route', chain.routeDisplay),
      _detailRow(
        'Latency',
        '${vpnEngine.currentLatency?.toStringAsFixed(1)}ms',
      ),
      _detailRow('Original IP', vpnEngine.originalIp ?? 'Detecting...'),
      _detailRow('VPN IP', vpnEngine.vpnIp ?? 'Detecting...'),
    ];
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
          ),
          Text(
            value,
            style: TextStyle(color: AppTheme.textPrimary, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildConnectionStats(VpnEngine vpnEngine) {
    final stats = vpnEngine.connectionStats;
    final startTime = stats['startTime'] as DateTime?;
    final elapsed = startTime != null
        ? DateTime.now().difference(startTime).inSeconds
        : 0;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceAlt,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Statistics',
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          _statRow('Connected for', '${elapsed}s'),
          _statRow('Uploaded', '${stats['bytesUp']} B'),
          _statRow('Downloaded', '${stats['bytesDown']} B'),
          _statRow('Packets Up', '${stats['packetsUp']}'),
          _statRow('Packets Down', '${stats['packetsDown']}'),
        ],
      ),
    );
  }

  Widget _statRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 11),
          ),
          Text(
            value,
            style: TextStyle(
              color: AppTheme.accent,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  // ==================== Chains Tab ====================

  Widget _buildChainsTab() {
    return Consumer<VpnEngine>(
      builder: (context, vpnEngine, child) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _showCreateChainDialog(context, vpnEngine),
                  icon: const Icon(Icons.add),
                  label: const Text('Create New Chain'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.accent,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              if (vpnEngine.savedChains.isEmpty)
                Center(
                  child: Text(
                    'No chains saved yet',
                    style: TextStyle(color: AppTheme.textSecondary),
                  ),
                )
              else
                ListView.builder(
                  shrinkWrap: true,
                  itemCount: vpnEngine.savedChains.length,
                  itemBuilder: (context, index) {
                    final chain = vpnEngine.savedChains[index];
                    return _buildChainCard(context, vpnEngine, chain);
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildChainCard(
    BuildContext context,
    VpnEngine vpnEngine,
    VpnChain chain,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        border: Border.all(
          color: chain.isActive ? AppTheme.accent : AppTheme.border,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      chain.name,
                      style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      chain.routeDisplay,
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              if (chain.isActive)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.success.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'Active',
                    style: TextStyle(
                      color: AppTheme.success,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => vpnEngine.connect(chain),
                  icon: const Icon(Icons.power_settings_new, size: 16),
                  label: const Text('Connect'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.accent,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: () => vpnEngine.deleteChain(chain.id),
                icon: const Icon(Icons.delete, size: 16),
                label: const Text('Delete'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.danger.withOpacity(0.2),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ==================== Advanced Tab ====================

  Widget _buildAdvancedTab() {
    return Consumer<VpnEngine>(
      builder: (context, vpnEngine, child) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
  // Kill Switch
              _buildToggleSetting(
                'Kill Switch',
                'Block all internet if VPN disconnects',
                vpnEngine.killSwitchEnabled,
                (value) => vpnEngine.setKillSwitch(value),
              ),
              const SizedBox(height: 16),

  // Auto Reconnect (if active chain)
              if (vpnEngine.activeChain != null)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildToggleSetting(
                      'Auto Reconnect',
                      'Automatically reconnect on failure',
                      vpnEngine.activeChain!.autoReconnect,
                      (value) {
                        vpnEngine.activeChain!.autoReconnect = value;
                        vpnEngine.updateChain(vpnEngine.activeChain!);
                      },
                    ),
                    const SizedBox(height: 16),
                  ],
                ),

  // Protocol Selection
              Text(
                'Protocol',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 8),
              ...[
                ('WireGuard', 'Fast, modern protocol'),
                ('OpenVPN', 'Widely compatible'),
                ('IKEv2', 'Mobile-friendly'),
              ].map((item) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    children: [
                      Radio(
                        value: item,
                        groupValue: null,
                        onChanged: (value) {},
                        activeColor: AppTheme.accent,
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.$1,
                              style: TextStyle(color: AppTheme.textPrimary),
                            ),
                            Text(
                              item.$2,
                              style: TextStyle(
                                color: AppTheme.textSecondary,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }),
              const SizedBox(height: 24),

  // Information
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceAlt,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'About Multi-hop VPN',
                      style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Your traffic is routed through multiple VPN servers sequentially, providing maximum privacy. No single server can see both your real IP and your destination.',
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildToggleSetting(
    String title,
    String subtitle,
    bool value,
    Function(bool) onChanged,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: AppTheme.textPrimary,
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
      ),
    );
  }

  // ==================== Dialog ====================

  void _showCreateChainDialog(BuildContext context, VpnEngine vpnEngine) {
    _chainNameController.clear();
    _tempHops.clear();

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: Text(
          'Create VPN Chain',
          style: TextStyle(color: AppTheme.textPrimary),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _chainNameController,
                decoration: InputDecoration(
                  hintText: 'Chain name',
                  hintStyle: TextStyle(color: AppTheme.textSecondary),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                  filled: true,
                  fillColor: AppTheme.background,
                ),
                style: TextStyle(color: AppTheme.textPrimary),
              ),
              const SizedBox(height: 16),
              Text(
                'Select servers for hops',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              _buildHopSelector(1),
              _buildHopSelector(2),
              _buildHopSelector(3),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text('Cancel', style: TextStyle(color: AppTheme.accent)),
          ),
          ElevatedButton(
            onPressed: () {
              _createAndSaveChain(vpnEngine);
              Navigator.pop(dialogContext);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accent),
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  Widget _buildHopSelector(int hopNum) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Text(
            'Hop $hopNum:',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: DropdownButtonFormField<VpnServer>(
              decoration: InputDecoration(
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(4),
                ),
                filled: true,
                fillColor: AppTheme.background,
              ),
              style: TextStyle(color: AppTheme.textPrimary),
              dropdownColor: AppTheme.surface,
              items: VpnServerRegistry.getAll()
                  .map(
                    (server) => DropdownMenuItem(
                      value: server,
                      child: Text(server.toString()),
                    ),
                  )
                  .toList(),
              onChanged: (server) {
                if (server != null) {
                  if (_tempHops.length < hopNum) {
                    _tempHops.add(
                      VpnHop(
                        id: 'hop_${hopNum}_${DateTime.now().millisecondsSinceEpoch}',
                        server: server,
                        hopNumber: hopNum,
                        encryptionKey: VpnEncryption.generateEncryptionKey(),
                      ),
                    );
                  } else {
                    _tempHops[hopNum - 1] = VpnHop(
                      id: 'hop_${hopNum}_${DateTime.now().millisecondsSinceEpoch}',
                      server: server,
                      hopNumber: hopNum,
                      encryptionKey: VpnEncryption.generateEncryptionKey(),
                    );
                  }
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  void _createAndSaveChain(VpnEngine vpnEngine) {
    if (_chainNameController.text.isEmpty || _tempHops.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please enter a name and select at least 2 hops'),
          backgroundColor: AppTheme.danger,
        ),
      );
      return;
    }

    final chain = VpnChain(
      id: 'chain_${DateTime.now().millisecondsSinceEpoch}',
      name: _chainNameController.text,
      description: 'Multi-hop VPN chain',
      hops: _tempHops,
    );

    vpnEngine.saveChain(chain);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Chain "${chain.name}" created'),
        backgroundColor: AppTheme.success,
      ),
    );
  }
}