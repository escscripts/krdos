import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/vpn_state.dart';
import '../../theme/app_theme.dart';

class MultiHopVPNScreen extends StatefulWidget {
  const MultiHopVPNScreen({super.key});

  @override
  State<MultiHopVPNScreen> createState() => _MultiHopVPNScreenState();
}

class _MultiHopVPNScreenState extends State<MultiHopVPNScreen> {
  @override
  Widget build(BuildContext context) {
    return Consumer<VPNState>(
      builder: (context, vpn, _) {
        return ListView(
          padding: const EdgeInsets.all(24),
          children: [
            _buildHeader(vpn),
            const SizedBox(height: 24),
            _buildConnectionStatus(vpn),
            const SizedBox(height: 20),
            _buildHopChain(vpn),
            const SizedBox(height: 20),
            _buildAvailableServers(vpn),
            const SizedBox(height: 20),
            _buildAdvancedSettings(vpn),
          ],
        );
      },
    );
  }

  Widget _buildHeader(VPNState vpn) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [AppTheme.accent, AppTheme.accent.withValues(alpha: 0.7)],
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.security_rounded, color: Colors.black, size: 24),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Multi-Hop VPN',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Route through ${vpn.hopChain.length} server${vpn.hopChain.length != 1 ? 's' : ''} for maximum privacy',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildConnectionStatus(VPNState vpn) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: vpn.isConnected
              ? [AppTheme.success.withValues(alpha: 0.15), AppTheme.success.withValues(alpha: 0.05)]
              : [AppTheme.surface, AppTheme.surfaceAlt],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: vpn.isConnected ? AppTheme.success : AppTheme.border,
          width: vpn.isConnected ? 2 : 1,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: vpn.isConnected
                      ? AppTheme.success.withValues(alpha: 0.2)
                      : AppTheme.surfaceAlt,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  vpn.isConnected ? Icons.shield_rounded : Icons.shield_outlined,
                  color: vpn.isConnected ? AppTheme.success : AppTheme.textSecondary,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      vpn.isConnected ? 'Protected' : 'Disconnected',
                      style: TextStyle(
                        color: vpn.isConnected ? AppTheme.success : AppTheme.textSecondary,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      vpn.isConnected
                          ? 'Traffic encrypted through ${vpn.hopChain.length} hops'
                          : 'Your connection is not protected',
                      style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                    ),
                  ],
                ),
              ),
              _buildConnectButton(vpn),
            ],
          ),
          if (vpn.isConnected) ...[
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(child: _buildStat('Latency', '${vpn.totalLatency}ms', Icons.speed_rounded)),
                const SizedBox(width: 12),
                Expanded(child: _buildStat('Hops', '${vpn.hopChain.length}', Icons.route_rounded)),
                const SizedBox(width: 12),
                Expanded(child: _buildStat('Data', vpn.dataTransferred, Icons.swap_vert_rounded)),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildConnectButton(VPNState vpn) {
    return GestureDetector(
      onTap: () {
        if (vpn.hopChain.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Add at least one server to the hop chain')),
          );
          return;
        }
        vpn.isConnected ? vpn.disconnect() : vpn.connect();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        decoration: BoxDecoration(
          color: vpn.isConnected ? AppTheme.danger : AppTheme.accent,
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: (vpn.isConnected ? AppTheme.danger : AppTheme.accent).withValues(alpha: 0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Text(
          vpn.isConnected ? 'Disconnect' : 'Connect',
          style: const TextStyle(
            color: Colors.black,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildStat(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceAlt,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.border.withValues(alpha: 0.5)),
      ),
      child: Column(
        children: [
          Icon(icon, color: AppTheme.accent, size: 18),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 10),
          ),
        ],
      ),
    );
  }

  Widget _buildHopChain(VPNState vpn) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Hop Chain',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              if (vpn.hopChain.isNotEmpty)
                TextButton.icon(
                  onPressed: vpn.clearHopChain,
                  icon: const Icon(Icons.clear_all_rounded, size: 16),
                  label: const Text('Clear'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppTheme.danger,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          if (vpn.hopChain.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Icon(Icons.add_circle_outline_rounded, color: AppTheme.textSecondary, size: 48),
                    const SizedBox(height: 12),
                    Text(
                      'No servers in chain',
                      style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Add servers from the list below',
                      style: TextStyle(color: AppTheme.textSecondary.withValues(alpha: 0.7), fontSize: 12),
                    ),
                  ],
                ),
              ),
            )
          else
            ReorderableListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: vpn.hopChain.length,
              onReorder: (oldIndex, newIndex) => vpn.reorderHop(oldIndex, newIndex),
              itemBuilder: (context, index) {
                final server = vpn.hopChain[index];
                return _buildHopCard(server, index, vpn);
              },
            ),
        ],
      ),
    );
  }

  Widget _buildHopCard(VPNServer server, int index, VPNState vpn) {
    return Container(
      key: ValueKey(server.id),
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceAlt,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.accent.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.accent.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '${index + 1}',
              style: TextStyle(
                color: AppTheme.accent,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            server.flag,
            style: const TextStyle(fontSize: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  server.name,
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${server.location} ? ${server.ping}ms',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => vpn.removeFromHopChain(server.id),
            icon: const Icon(Icons.close_rounded, color: AppTheme.danger, size: 20),
            tooltip: 'Remove',
          ),
          const Icon(Icons.drag_handle_rounded, color: AppTheme.textSecondary, size: 20),
        ],
      ),
    );
  }

  Widget _buildAvailableServers(VPNState vpn) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Available Servers',
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          ...vpn.availableServers.map((server) => _buildServerCard(server, vpn)),
        ],
      ),
    );
  }

  Widget _buildServerCard(VPNServer server, VPNState vpn) {
    final isInChain = vpn.hopChain.any((s) => s.id == server.id);
    
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isInChain ? AppTheme.accent.withValues(alpha: 0.08) : AppTheme.surfaceAlt,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isInChain ? AppTheme.accent.withValues(alpha: 0.4) : AppTheme.border.withValues(alpha: 0.5),
        ),
      ),
      child: Row(
        children: [
          Text(
            server.flag,
            style: const TextStyle(fontSize: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  server.name,
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  server.location,
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                ),
              ],
            ),
          ),
          _buildServerMetric('${server.ping}ms', server.ping < 100 ? AppTheme.success : AppTheme.warning),
          const SizedBox(width: 12),
          _buildServerMetric('${server.load}%', server.load < 50 ? AppTheme.success : AppTheme.warning),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: () {
              if (isInChain) {
                vpn.removeFromHopChain(server.id);
              } else {
                vpn.addToHopChain(server);
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: isInChain ? AppTheme.danger : AppTheme.accent,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                isInChain ? 'Remove' : 'Add',
                style: const TextStyle(
                  color: Colors.black,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildServerMetric(String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        value,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildAdvancedSettings(VPNState vpn) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Advanced Settings',
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          _buildToggle(
            'Kill Switch',
            'Block all traffic if VPN disconnects',
            vpn.killSwitchEnabled,
            (_) => vpn.toggleKillSwitch(),
          ),
          const SizedBox(height: 12),
          _buildToggle(
            'DNS Leak Protection',
            'Force all DNS through VPN tunnel',
            vpn.dnsLeakProtection,
            (_) => vpn.toggleDNSLeakProtection(),
          ),
          const SizedBox(height: 12),
          _buildToggle(
            'Auto-Reconnect',
            'Automatically reconnect on disconnect',
            vpn.autoReconnect,
            (_) => vpn.toggleAutoReconnect(),
          ),
          const SizedBox(height: 12),
          _buildToggle(
            'IPv6 Leak Protection',
            'Disable IPv6 to prevent leaks',
            vpn.ipv6LeakProtection,
            (_) => vpn.toggleIPv6LeakProtection(),
          ),
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
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 11),
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
}
