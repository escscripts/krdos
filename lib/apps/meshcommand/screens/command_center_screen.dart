import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/device_command_registry.dart';
import '../core/mesh_engine.dart';
import '../models/device_model.dart';
import '../ui/mesh_tokens.dart';

class CommandCenterScreen extends StatefulWidget {
  const CommandCenterScreen({super.key});

  @override
  State<CommandCenterScreen> createState() => _CommandCenterScreenState();
}

class _CommandCenterScreenState extends State<CommandCenterScreen> {
  MeshDevice? _selectedDevice;
  DeviceCommand? _selectedCommand;
  final Map<String, TextEditingController> _parameterControllers = {};

  @override
  void dispose() {
    for (final controller in _parameterControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<MeshEngine>(
      builder: (context, meshEngine, child) {
        return Scaffold(
          backgroundColor: MeshTokens.bg(),
          body: Row(
            children: [
              _buildDevicePanel(meshEngine),
              Expanded(
                child: _selectedDevice == null
                    ? _buildEmptyState()
                    : _buildCommandPanel(meshEngine),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDevicePanel(MeshEngine meshEngine) {
    final onlineDevices = meshEngine.devices.values
        .where((d) => d.status == DeviceStatus.online)
        .toList();

    return Container(
      width: 320,
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        border: Border(right: BorderSide(color: Colors.white.withOpacity(0.08))),
      ),
      child: Column(
        children: [
          const SizedBox(height: 16),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Devices',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: ListView.builder(
              itemCount: onlineDevices.length,
              itemBuilder: (context, index) {
                final device = onlineDevices[index];
                final selected = _selectedDevice?.id == device.id;
                return ListTile(
                  selected: selected,
                  selectedTileColor: const Color(0xFF7B68FF).withOpacity(0.2),
                  leading: Icon(device.typeIcon, color: device.statusColor),
                  title: Text(
                    device.name,
                    style: const TextStyle(color: Colors.white),
                  ),
                  subtitle: Text(
                    '${device.protocolLabel}  ${device.signalStrength.toStringAsFixed(0)} dBm',
                    style: TextStyle(color: Colors.white.withOpacity(0.7)),
                  ),
                  onTap: () {
                    setState(() {
                      _selectedDevice = device;
                      _selectedCommand = null;
                      _parameterControllers.clear();
                    });
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Text(
        'Select a device to send commands',
        style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 16),
      ),
    );
  }

  Widget _buildCommandPanel(MeshEngine meshEngine) {
    final commandsByCategory = DeviceCommandRegistry.getCommandsByCategory(
      _selectedDevice!.type,
    );
    return Column(
      children: [
        ListTile(
          leading: Icon(_selectedDevice!.typeIcon, color: _selectedDevice!.statusColor),
          title: Text(_selectedDevice!.name, style: const TextStyle(color: Colors.white)),
          subtitle: Text(
            _selectedDevice!.address,
            style: TextStyle(color: Colors.white.withOpacity(0.7)),
          ),
          trailing: _selectedCommand != null
              ? IconButton(
                  onPressed: () => setState(() {
                    _selectedCommand = null;
                    _parameterControllers.clear();
                  }),
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                )
              : null,
        ),
        const Divider(height: 1, color: Colors.white12),
        Expanded(
          child: _selectedCommand == null
              ? _buildCommandList(commandsByCategory)
              : _buildCommandExecutor(meshEngine, _selectedCommand!),
        ),
      ],
    );
  }

  Widget _buildCommandList(Map<String, List<DeviceCommand>> commandsByCategory) {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: commandsByCategory.entries.map((entry) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              entry.key,
              style: TextStyle(
                color: Colors.white.withOpacity(0.8),
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            ...entry.value.map(
              (command) => Card(
                color: const Color(0xFF1A1A1A),
                child: ListTile(
                  title: Text(command.name, style: const TextStyle(color: Colors.white)),
                  subtitle: Text(
                    command.description,
                    style: TextStyle(color: Colors.white.withOpacity(0.7)),
                  ),
                  trailing: command.requiresConfirmation
                      ? const Icon(Icons.warning_amber_rounded, color: Colors.orange)
                      : null,
                  onTap: () => setState(() => _selectedCommand = command),
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
        );
      }).toList(),
    );
  }

  Widget _buildCommandExecutor(MeshEngine meshEngine, DeviceCommand command) {
    for (final param in command.parameters) {
      _parameterControllers.putIfAbsent(param, TextEditingController.new);
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(command.name, style: const TextStyle(color: Colors.white, fontSize: 20)),
        const SizedBox(height: 8),
        Text(command.description, style: TextStyle(color: Colors.white.withOpacity(0.75))),
        const SizedBox(height: 16),
        ...command.parameters.map(
          (param) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: TextField(
              controller: _parameterControllers[param],
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: param,
                labelStyle: TextStyle(color: Colors.white.withOpacity(0.75)),
                enabledBorder: const OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.white24),
                ),
                focusedBorder: const OutlineInputBorder(
                  borderSide: BorderSide(color: Color(0xFF7B68FF)),
                ),
              ),
            ),
          ),
        ),
        ElevatedButton(
          onPressed: () => _executeCommand(meshEngine, command),
          child: const Text('Execute'),
        ),
      ],
    );
  }

  Future<void> _executeCommand(MeshEngine meshEngine, DeviceCommand command) async {
    if (_selectedDevice == null) return;
    final params = <String, dynamic>{};
    for (final param in command.parameters) {
      params[param] = _parameterControllers[param]?.text ?? '';
    }

    try {
      if (command.requiresConfirmation) {
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Confirm'),
            content: Text('Execute "${command.name}" on ${_selectedDevice!.name}?'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
              TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Confirm')),
            ],
          ),
        );
        if (confirmed != true) return;
      }

      await meshEngine.executeDeviceCommand(_selectedDevice!.id, command.id, params);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Sent ${command.name} to ${_selectedDevice!.name}')),
      );
      setState(() {
        _selectedCommand = null;
        _parameterControllers.clear();
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Command failed: $e')),
      );
    }
  }
}
