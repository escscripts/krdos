import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/mesh_engine.dart';
import '../ui/mesh_tokens.dart';

class ProtocolManagerScreen extends StatefulWidget {
  const ProtocolManagerScreen({Key? key}) : super(key: key);

  @override
  State<ProtocolManagerScreen> createState() => _ProtocolManagerScreenState();
}

class _ProtocolManagerScreenState extends State<ProtocolManagerScreen> {
  final Map<String, bool> protocolStatus = {
    'LoRa': true,
    'WiFi': true,
    'Sub-GHz': false,
    'Bluetooth': true,
  };

  final Map<String, Map<String, dynamic>> protocolSettings = {
    'LoRa': {
      'frequency': '915 MHz',
      'bandwidth': '125 kHz',
      'power': '30 dBm',
      'spreadingFactor': '7',
      'crc': true,
    },
    'WiFi': {
      'band': '2.4 GHz',
      'channel': 'Auto',
      'power': '20 dBm',
      'standard': '802.11n',
    },
    'Sub-GHz': {
      'frequency': '433 MHz',
      'modulation': 'FSK',
      'power': '10 dBm',
      'bandwidth': '50 kHz',
    },
    'Bluetooth': {
      'version': '5.2',
      'mode': 'BLE',
      'power': '0 dBm',
      'range': '~100m',
    },
  };

  @override
  Widget build(BuildContext context) {
    return Consumer<MeshEngine>(
      builder: (context, meshEngine, child) {
        return Scaffold(
          backgroundColor: MeshTokens.bg(),
          body: SingleChildScrollView(
            child: Column(
              children: [
  // Protocol overview
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1A1A),
                    border: Border(
                      bottom: BorderSide(
                        color: Colors.white.withValues(alpha: 0.1),
                      ),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Active Protocols',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        children: protocolStatus.entries
                            .where((e) => e.value)
                            .map((e) => _buildProtocolBadge(e.key))
                            .toList(),
                      ),
                    ],
                  ),
                ),

  // Protocol cards
                ...protocolSettings.entries.map((entry) {
                  final protocol = entry.key;
                  final settings = entry.value;
                  final isActive = protocolStatus[protocol] ?? false;

                  return _buildProtocolCard(
                    protocol,
                    settings,
                    isActive,
                    meshEngine.devicesByProtocol[protocol]?.length ?? 0,
                  );
                }).toList(),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildProtocolBadge(String protocol) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.cyan.withValues(alpha: 0.2),
        border: Border.all(color: Colors.cyan.withValues(alpha: 0.5)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
              color: Colors.cyan,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            protocol,
            style: const TextStyle(
              color: Colors.cyan,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProtocolCard(
    String protocol,
    Map<String, dynamic> settings,
    bool isActive,
    int deviceCount,
  ) {
    return Container(
      margin: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isActive
              ? Colors.cyan.withValues(alpha: 0.3)
              : Colors.grey.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        children: [
  // Header
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        protocol,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$deviceCount device${deviceCount != 1 ? 's' : ''} connected',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: isActive,
                  onChanged: (value) {
                    setState(() {
                      protocolStatus[protocol] = value;
                    });
                  },
                  activeColor: Colors.cyan,
                ),
              ],
            ),
          ),

  // Settings
          if (isActive) ...[
            Container(height: 1, color: Colors.white.withValues(alpha: 0.1)),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ...settings.entries
                      .map((e) => _buildSettingRow(e.key, e.value))
                      .toList(),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => _showAdvancedSettings(protocol),
                          child: const Text('Advanced'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => _resetProtocol(protocol),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                          ),
                          child: const Text('Reset'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSettingRow(String key, dynamic value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            key,
            style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
          ),
          Text(
            value.toString(),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  void _showAdvancedSettings(String protocol) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('$protocol Advanced Settings'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _settingInput('Channel', 'auto'),
              _settingInput('TX Power', '20 dBm'),
              _settingInput('RX Sensitivity', '-110 dBm'),
              _settingInput('Retry Count', '3'),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'Diagnostics',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              _diagnosticRow('Packet Loss', '2.3%', Colors.orange),
              _diagnosticRow('Link Quality', '95%', Colors.green),
              _diagnosticRow('Interference', 'Low', Colors.green),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Apply'),
          ),
        ],
      ),
    );
  }

  Widget _settingInput(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          TextField(
            controller: TextEditingController(text: value),
            decoration: InputDecoration(
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(4),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 6,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _diagnosticRow(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 11)),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(3),
            ),
            child: Text(
              value,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _resetProtocol(String protocol) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Reset $protocol'),
        content: Text('Reset $protocol settings to factory defaults?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('$protocol reset to defaults')),
              );
            },
            child: const Text('Reset'),
          ),
        ],
      ),
    );
  }
}