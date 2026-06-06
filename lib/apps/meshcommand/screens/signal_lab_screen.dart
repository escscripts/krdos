import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../core/mesh_engine.dart';
import '../models/device_model.dart';
import '../models/rf_lab_capture.dart';
import '../ui/mesh_tokens.dart';
import '../widgets/lab_ethics_banner.dart';

/// Capture / annotate / clipboard / sandbox replay routing for traces from YOUR hardware dongle daemon.
class SignalLabScreen extends StatefulWidget {
  const SignalLabScreen({super.key});

  @override
  State<SignalLabScreen> createState() => _SignalLabScreenState();
}

class _SignalLabScreenState extends State<SignalLabScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  final _ascii = TextEditingController();
  final _b64decode = TextEditingController();
  final _b64encode = TextEditingController();
  String _hexScratch = '';

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this)
      ..addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tabs.dispose();
    _ascii.dispose();
    _b64decode.dispose();
    _b64encode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mesh = context.watch<MeshEngine>();

    return Scaffold(
      backgroundColor: MeshTokens.bg(),
      floatingActionButton: _tabs.index == 0
          ? FloatingActionButton.extended(
              onPressed: () => _addSample(mesh),
              backgroundColor: MeshTokens.accent(),
              foregroundColor: MeshTokens.bg(),
              icon: const Icon(Icons.biotech_rounded),
              label: const Text('New trace'),
            )
          : null,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: MeshTokens.screenPadding(),
            child: const LabEthicsBanner(),
          ),
          TabBar(
            controller: _tabs,
            labelColor: MeshTokens.accent(),
            unselectedLabelColor: MeshTokens.textSecondary(),
            indicatorColor: MeshTokens.accent(),
            dividerColor: MeshTokens.border(),
            tabs: const [
              Tab(text: 'Trace vault'),
              Tab(text: 'Codec scratchpad'),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: [_vault(mesh), _scratchpad()],
            ),
          ),
        ],
      ),
    );
  }

  Widget _vault(MeshEngine mesh) {
    final items = mesh.rfLabCaptures;

    if (items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.scatter_plot_outlined, size: 48, color: MeshTokens.accent()),
              const SizedBox(height: 16),
              Text(
                'No traces yet · import from clipboard or forge a sandbox sample',
                textAlign: TextAlign.center,
                style: TextStyle(color: MeshTokens.textSecondary()),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: () => _addSample(mesh),
                icon: const Icon(Icons.add),
                label: const Text('Seed demo trace'),
                style: FilledButton.styleFrom(
                  backgroundColor: MeshTokens.accent(),
                  foregroundColor: MeshTokens.bg(),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: MeshTokens.screenPadding(),
      itemCount: items.length,
      itemBuilder: (ctx, i) {
        final c = items[i];
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: MeshTokens.border()),
              color: MeshTokens.elevated(),
            ),
            child: ExpansionTile(
              iconColor: MeshTokens.accent(),
              collapsedIconColor: MeshTokens.accent(),
              title: Text(
                c.title,
                style:
                    TextStyle(color: MeshTokens.textPrimary(), fontWeight: FontWeight.w700),
              ),
              subtitle: Text(
                '${c.normalizedHex.length ~/ 2} bytes · ${_shortTs(c.capturedAt)}',
                style: TextStyle(color: MeshTokens.textSecondary(), fontSize: 11),
              ),
              children: [
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: SelectableText(
                    c.hexPayload,
                    style: TextStyle(
                      fontFamily: 'monospace',
                      color: MeshTokens.textPrimary(),
                      fontSize: 11,
                    ),
                  ),
                ),
                Divider(height: 1, color: MeshTokens.border()),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () =>
                            Clipboard.setData(ClipboardData(text: c.normalizedHex)),
                        icon: const Icon(Icons.copy_rounded),
                        label: const Text('Copy hex'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => Clipboard.setData(
                          ClipboardData(text: c.toExportJsonPretty()),
                        ),
                        icon: const Icon(Icons.data_object_rounded),
                        label: const Text('Copy JSON bundle'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () =>
                            ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Saved to MeshCommand vault (export JSON to disk from your host OS tooling when ready).',
                            ),
                            duration: const Duration(seconds: 2),
                          ),
                        ),
                        icon: Icon(Icons.archive_outlined,
                            color: MeshTokens.warning()),
                        label: const Text('Persist hook'),
                      ),
                      FilledButton.icon(
                        onPressed: mesh.devices.keys.isEmpty ? null : () => _replaySheet(context, mesh, c.id),
                        icon: Icon(Icons.play_circle_outline_rounded,
                            color: MeshTokens.bg()),
                        label: Text('Sandbox replay ? node',
                            style: TextStyle(color: MeshTokens.bg())),
                        style:
                            FilledButton.styleFrom(backgroundColor: MeshTokens.accent()),
                      ),
                      IconButton(
                        tooltip: 'Delete',
                        onPressed: () => mesh.removeRfLabCapture(c.id),
                        icon:
                            Icon(Icons.delete_outline_rounded, color: MeshTokens.danger()),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _scratchpad() {
    return SingleChildScrollView(
      padding: MeshTokens.screenPadding(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Local-only transforms for debugging payloads you already control.',
            style: TextStyle(color: MeshTokens.textSecondary(), fontSize: 11),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _ascii,
            decoration: _fieldDeco('ASCII / plaintext'),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: MeshTokens.accent()),
                onPressed: () {
                  setState(() {
                    _hexScratch = (_ascii.text.codeUnits.map((v) =>
                        v.toRadixString(16).padLeft(2, '0').toUpperCase())).join('');
                  });
                },
                child: Text('To hex', style: TextStyle(color: MeshTokens.bg())),
              ),
              const SizedBox(width: 8),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: MeshTokens.surface()),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: _hexScratch));
                  ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Hex copied')));
                },
                child: Text('Copy hex column', style: TextStyle(color: MeshTokens.bg())),
              ),
            ],
          ),
          if (_hexScratch.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: SelectableText(
                _hexScratch,
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 11,
                  color: MeshTokens.textPrimary(),
                ),
              ),
            ),
          const Divider(height: 32),
          TextField(
            controller: _b64encode,
            decoration: _fieldDeco('Encode string ? Base64'),
          ),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: () {
              final encoded = base64Encode(utf8.encode(_b64encode.text));
              Clipboard.setData(ClipboardData(text: encoded));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    encoded.length <= 52
                        ? 'Base64 copied: $encoded'
                        : 'Base64 copied (${encoded.length} chars): ${encoded.substring(0, 48)}?',
                  ),
                ),
              );
            },
            icon: Icon(Icons.compress_rounded,
                color: MeshTokens.bg(), size: 18),
            label:
                Text('Encode + copy', style: TextStyle(color: MeshTokens.bg())),
            style: FilledButton.styleFrom(backgroundColor: MeshTokens.success()),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _b64decode,
            decoration: _fieldDeco('Decode Base64 ? UTF-8 (safe view)'),
          ),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: () {
              try {
                final bytes = base64Decode(_b64decode.text.trim());
                final s = utf8.decode(bytes);
                Clipboard.setData(ClipboardData(text: s));
                final preview =
                    s.length <= 140 ? s : '${s.substring(0, 120)}?';
                ScaffoldMessenger.of(context)
                    .showSnackBar(SnackBar(content: Text('Decoded: $preview')));
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Decode failed ? $e')),
                );
              }
            },
            icon: Icon(Icons.expand_rounded,
                color: MeshTokens.bg(), size: 18),
            label:
                Text('Decode + copy', style: TextStyle(color: MeshTokens.bg())),
            style: FilledButton.styleFrom(backgroundColor: MeshTokens.warning()),
          ),
          const Divider(height: 32),
          OutlinedButton.icon(
            onPressed: () async {
              final data = await Clipboard.getData('text/plain');
              final clip = data?.text?.trim();
              if (clip == null || clip.isEmpty) return;
              if (!mounted) return;
              final mesh =
                  Provider.of<MeshEngine>(context, listen: false);
              final ok = mesh.importRfLabFromJsonClipboard(clip);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(ok
                      ? 'Imported RFC lab JSON from clipboard'
                      : 'Clipboard is not RFC lab schema JSON'),
                ),
              );
            },
            icon: Icon(Icons.upload_file_rounded, color: MeshTokens.accent()),
            label:
                Text('Paste schema JSON bundle from clipboard'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () =>
                ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Forge new trace from editor ? use Add from Command Center future hook',
                ),
              ),
            ),
            icon: Icon(Icons.edit_note_rounded, color: MeshTokens.textSecondary()),
            label: Text('Manual entry (shortcut: seed demo)',
                style: TextStyle(color: MeshTokens.textSecondary())),
          ),
          const SizedBox(height: 20),
          const LabEthicsBanner(dense: true),
        ],
      ),
    );
  }

  InputDecoration _fieldDeco(String label) => InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: MeshTokens.textSecondary()),
        enabledBorder:
            OutlineInputBorder(borderSide: BorderSide(color: MeshTokens.border())),
        focusedBorder:
            OutlineInputBorder(borderSide: BorderSide(color: MeshTokens.accent())),
      );

  static String _shortTs(DateTime t) =>
      '${t.year}-${t.month.toString().padLeft(2, '0')}-${t.day.toString().padLeft(2, '0')} '
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  void _addSample(MeshEngine mesh) {
    mesh.addRfLabCapture(
      RfLabCapture.placeholder(
        title: 'Sandbox car-key practice frame (logical)',
        hexPayload:
            'A0 B1 C2 ' * 12 + 'FF',
      ),
    );
  }

  Future<void> _replaySheet(BuildContext context, MeshEngine mesh, String capId) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: MeshTokens.surface(),
      builder: (ctx) {
        MeshDevice? picked;
        return StatefulBuilder(
          builder: (ctx2, setSheet) => Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Target sandbox node',
                  style: TextStyle(
                    color: MeshTokens.textPrimary(),
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 12),
                ...mesh.devices.values.map(
                  (d) => RadioListTile<MeshDevice>(
                    value: d,
                    groupValue: picked,
                    onChanged: (v) => setSheet(() => picked = v),
                    title:
                        Text(d.name, style: TextStyle(color: MeshTokens.textPrimary())),
                    subtitle: Text(
                      d.type.name,
                      style: TextStyle(color: MeshTokens.textSecondary(), fontSize: 11),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton(
                  style:
                      FilledButton.styleFrom(backgroundColor: MeshTokens.accent()),
                  onPressed: picked == null
                      ? null
                      : () async {
                          final sel = picked!;
                          await mesh.simulateReplayLabCapture(
                            targetDeviceId: sel.id,
                            captureId: capId,
                          );
                          if (!context.mounted) return;
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Replay frame sent to ${sel.name} (simulator)'),
                            ),
                          );
                        },
                  child: Text('Commit replay', style: TextStyle(color: MeshTokens.bg())),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
