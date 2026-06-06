import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/mesh_engine.dart';
import '../ui/mesh_tokens.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool enableEncryption = true;
  bool autoReconnect = true;
  int alertThreshold = -95;

  @override
  Widget build(BuildContext context) {
    return Consumer<MeshEngine>(
      builder: (context, meshEngine, child) {
        return Scaffold(
          backgroundColor: MeshTokens.bg(),
          body: SingleChildScrollView(
            child: Column(
              children: [
                Align(
                  alignment: Alignment.centerRight,
                  child: IconButton(
                    icon: Icon(Icons.help_outline, color: MeshTokens.textSecondary()),
                    onPressed: _showSettingsHelp,
                    tooltip: 'Help',
                  ),
                ),
  // Encryption settings
                _buildSection('Encryption & Security', [
                  _buildToggleSetting(
                    'Enable Encryption',
                    'AES-256-GCM end-to-end encryption',
                    enableEncryption,
                    (value) => setState(() => enableEncryption = value),
                  ),
                  if (enableEncryption)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                      child: ElevatedButton(
                        onPressed: _showEncryptionKeyManager,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                        ),
                        child: const Text('Manage Encryption Keys'),
                      ),
                    ),
                  _buildToggleSetting(
                    'Ghost Mode',
                    'Anonymize mesh traffic patterns',
                    meshEngine.anonymizeTraffic,
                    meshEngine.setGhostMode,
                  ),
                ]),

  // Emergency settings
                _buildSection('Emergency Features', [
                  _buildToggleSetting(
                    'Emergency Broadcast',
                    'Enable emergency message relay',
                    meshEngine.useEmergencyBroadcast,
                    meshEngine.setEmergencyBroadcastEnabled,
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: ElevatedButton(
                      onPressed: () => _showBroadcastTest(meshEngine),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                      ),
                      child: const Text('Send Test Broadcast'),
                    ),
                  ),
                ]),

  // Connection settings
                _buildSection('Connection', [
                  _buildToggleSetting(
                    'Auto Reconnect',
                    'Automatically reconnect to devices',
                    autoReconnect,
                    (value) => setState(() => autoReconnect = value),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Signal Alert Threshold',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              '$alertThreshold dBm',
                              style: const TextStyle(
                                color: Colors.cyan,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Slider(
                          value: alertThreshold.toDouble(),
                          min: -120,
                          max: -30,
                          divisions: 18,
                          label: '$alertThreshold dBm',
                          onChanged: (value) {
                            setState(() => alertThreshold = value.toInt());
                          },
                        ),
                        Text(
                          'Alerts when signal drops below this level',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ]),

  // Whitelist management
                _buildSection('Device Whitelist', [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Whitelisted Devices',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              '${meshEngine.whitelist.length}',
                              style: const TextStyle(
                                color: Colors.cyan,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        if (meshEngine.whitelist.isEmpty)
                          Text(
                            'All devices allowed (whitelist empty)',
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 11,
                            ),
                          )
                        else
                          ...meshEngine.whitelist
                              .map(
                                (id) => Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 4,
                                  ),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        id,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 11,
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.close, size: 16),
                                        onPressed: () {
                                          meshEngine.whitelist.remove(id);
                                          setState(() {});
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                              )
                              .toList(),
                        const SizedBox(height: 8),
                        ElevatedButton(
                          onPressed: _showAddToWhitelist,
                          child: const Text('Add Device to Whitelist'),
                        ),
                      ],
                    ),
                  ),
                ]),

  // System info
                _buildSection('System Information', [
                  _buildInfoRow('Mesh Engine Version', '1.0.0'),
                  _buildInfoRow(
                    'Protocol Layers',
                    '4 (LoRa, WiFi, Sub-GHz, BLE)',
                  ),
                  _buildInfoRow('Encryption Standard', 'AES-256-GCM'),
                  _buildInfoRow('Noise Protocol', 'NN (no authentication)'),
                ]),

  // About
                _buildSection('About', [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'MeshCommand',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'A universal mesh communication hub for heterogeneous devices across multiple radio protocols.',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Features: Multi-hop VPN, End-to-end encryption, Offline routing, Auto protocol selection, Emergency broadcast',
                          style: TextStyle(color: Colors.grey, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ]),

                const SizedBox(height: 24),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            title,
            style: TextStyle(
              color: Colors.grey.shade400,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
        ),
        ...children,
        Container(
          height: 1,
          margin: const EdgeInsets.only(top: 12),
          color: Colors.white.withValues(alpha: 0.05),
        ),
      ],
    );
  }

  Widget _buildToggleSetting(
    String label,
    String description,
    bool value,
    ValueChanged<bool> onChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 11),
                ),
              ],
            ),
          ),
          Switch(value: value, onChanged: onChanged, activeColor: Colors.cyan),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(color: Colors.white, fontSize: 12),
          ),
          Text(
            value,
            style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
          ),
        ],
      ),
    );
  }

  void _showEncryptionKeyManager() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Encryption Key Manager'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Active Encryption Keys',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'Key rotation: Every 7 days\nForward secrecy: Enabled\nKey storage: Encrypted\n\nAll keys are AES-256 format',
                  style: TextStyle(fontSize: 10),
                ),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Rotate Keys Now'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showBroadcastTest(MeshEngine meshEngine) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Send Test Broadcast'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'This will send a test emergency broadcast to all devices.',
            ),
            const SizedBox(height: 12),
            TextField(
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Enter test message...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              meshEngine.sendEmergencyBroadcast('Test emergency broadcast');
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Test broadcast sent')),
              );
            },
            child: const Text('Send'),
          ),
        ],
      ),
    );
  }

  void _showAddToWhitelist() {
    showDialog(
      context: context,
      builder: (context) {
        final controller = TextEditingController();
        return AlertDialog(
          title: const Text('Add Device to Whitelist'),
          content: TextField(
            controller: controller,
            decoration: InputDecoration(
              hintText: 'Device ID',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                if (controller.text.isNotEmpty) {
                  context.read<MeshEngine>().whitelist.add(controller.text);
                  Navigator.pop(context);
                  setState(() {});
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Device added to whitelist')),
                  );
                }
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
  }

  void _showSettingsHelp() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Settings Help'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _helpSection('Encryption', [
                '? AES-256-GCM provides military-grade protection',
                '? Keys rotate automatically every 7 days',
                '? Ghost Mode masks traffic patterns',
              ]),
              const SizedBox(height: 12),
              _helpSection('Emergency Features', [
                '? Broadcasts reach all devices in mesh',
                '? Messages repeat every 30 seconds',
                '? Can bypass signal thresholds',
              ]),
              const SizedBox(height: 12),
              _helpSection('Whitelist', [
                '? Empty whitelist = all devices allowed',
                '? Add device IDs to restrict access',
                '? Applies to incoming connections only',
              ]),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _helpSection(String title, List<String> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
        ),
        const SizedBox(height: 6),
        ...items
            .map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(item, style: const TextStyle(fontSize: 11)),
              ),
            )
            .toList(),
      ],
    );
  }
}