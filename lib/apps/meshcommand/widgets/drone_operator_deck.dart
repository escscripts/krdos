import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../core/mesh_engine.dart';
import '../models/device_model.dart';
import '../models/packet_model.dart';
import '../ui/mesh_tokens.dart';

/// RC-style surface: WASD + drift-correct sliders, optional MJPEG/HTTP preview URL.
class DroneOperatorDeck extends StatefulWidget {
  const DroneOperatorDeck({super.key, required this.device});

  final MeshDevice device;

  @override
  State<DroneOperatorDeck> createState() => _DroneOperatorDeckState();
}

class _DroneOperatorDeckState extends State<DroneOperatorDeck> {
  final FocusNode _focus = FocusNode();
  double _pitch = 0;
  double _roll = 0;
  double _yawRate = 0;
  double _throttleHold = 0.35;

  Timer? _rcTimer;
  String _streamUrl = '';
  bool _recording = false;

  @override
  void dispose() {
    _rcTimer?.cancel();
    _focus.dispose();
    super.dispose();
  }

  void _pulseRc(MeshEngine mesh) {
    if (widget.device.status != DeviceStatus.online) return;
    final payload = jsonEncode({
      'rc': {'p': _pitch, 'r': _roll, 'y': _yawRate, 't': _throttleHold},
      'ts': DateTime.now().millisecondsSinceEpoch,
    });
    unawaited(
      mesh.sendPacket(widget.device.id, payload, PacketType.command).catchError((_) => false),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mesh = context.watch<MeshEngine>();

    return Focus(
      focusNode: _focus,
      onKeyEvent: (node, event) {
        if (event is! KeyDownEvent) return KeyEventResult.ignored;
        const step = 0.08;
        const yawStep = 0.12;

        KeyEventResult apply(VoidCallback fn) {
          setState(fn);
          return KeyEventResult.handled;
        }

        switch (event.logicalKey) {
          case LogicalKeyboardKey.keyW:
            return apply(() => _pitch = (_pitch + step).clamp(-1.0, 1.0));
          case LogicalKeyboardKey.keyS:
            return apply(() => _pitch = (_pitch - step).clamp(-1.0, 1.0));
          case LogicalKeyboardKey.keyA:
            return apply(() => _roll = (_roll - step).clamp(-1.0, 1.0));
          case LogicalKeyboardKey.keyD:
            return apply(() => _roll = (_roll + step).clamp(-1.0, 1.0));
          case LogicalKeyboardKey.keyQ:
            return apply(() => _yawRate = (_yawRate - yawStep).clamp(-1.0, 1.0));
          case LogicalKeyboardKey.keyE:
            return apply(() => _yawRate = (_yawRate + yawStep).clamp(-1.0, 1.0));
          case LogicalKeyboardKey.space:
            return apply(() =>
                _throttleHold = (_throttleHold + 0.05).clamp(0.0, 1.0));
          case LogicalKeyboardKey.shiftLeft:
          case LogicalKeyboardKey.shiftRight:
            return apply(() =>
                _throttleHold = (_throttleHold - 0.05).clamp(0.0, 1.0));
          case LogicalKeyboardKey.keyX:
            return apply(() {
              _pitch = 0;
              _roll = 0;
              _yawRate = 0;
            });
          default:
            return KeyEventResult.ignored;
        }
      },
      child: ListView(
        padding: MeshTokens.screenPadding(),
        children: [
          Text(
            'Focus this panel · WASD horizon · Q/E yaw · Space / Shift thrust · X zero stick',
            style: TextStyle(color: MeshTokens.textSecondary(), fontSize: 11),
          ),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () => _focus.requestFocus(),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: MeshTokens.border()),
                color: MeshTokens.elevated(),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Simulated MAVLink-ish RC telemetry ? mesh command packets',
                    style: TextStyle(color: MeshTokens.accent(), fontSize: 11),
                  ),
                  const SizedBox(height: 12),
                  _meter('Pitch', _pitch),
                  _meter('Roll', _roll),
                  _meter('Yaw rate', _yawRate),
                  _meter('Throttle hold', _throttleHold),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.tonalIcon(
                          onPressed: mesh.devices.containsKey(widget.device.id)
                              ? () {
                                  if (_rcTimer == null) {
                                    _rcTimer = Timer.periodic(
                                      const Duration(milliseconds: 120),
                                      (_) => _pulseRc(mesh),
                                    );
                                  } else {
                                    _rcTimer!.cancel();
                                    _rcTimer = null;
                                  }
                                  setState(() {});
                                }
                              : null,
                          icon: Icon(
                            _rcTimer != null ? Icons.pause : Icons.play_arrow,
                            color: MeshTokens.accent(),
                          ),
                          label: Text(
                            _rcTimer != null ? 'Stop RC stream' : 'Start RC stream',
                          ),
                          style: FilledButton.styleFrom(
                            backgroundColor: MeshTokens.accentMuted(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: FilledButton.tonalIcon(
                          onPressed: () async {
                            setState(() => _recording = !_recording);
                            await mesh.quickCommand(
                              widget.device.id,
                              'record',
                              {'action': _recording ? 'on' : 'off'},
                            );
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  _recording
                                      ? 'Recorder armed (device-side stub)'
                                      : 'Recorder halted',
                                ),
                              ),
                            );
                          },
                          icon: Icon(
                            _recording ? Icons.stop_circle_outlined : Icons.fiber_smart_record,
                            color: MeshTokens.danger(),
                          ),
                          label: Text(_recording ? 'Stop rec' : 'Record'),
                          style: FilledButton.styleFrom(
                            backgroundColor: MeshTokens.surface(),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Video preview (MJPEG / static snapshot URL)',
            style: TextStyle(
              color: MeshTokens.textPrimary(),
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            onChanged: (v) => setState(() => _streamUrl = v.trim()),
            style: TextStyle(color: MeshTokens.textPrimary(), fontSize: 12),
            decoration: InputDecoration(
              hintText: 'http://192.168.x.x/mjpeg/1 ',
              hintStyle: TextStyle(color: MeshTokens.textSecondary()),
              enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: MeshTokens.border())),
              focusedBorder: OutlineInputBorder(
                borderSide: BorderSide(color: MeshTokens.accent(), width: 1.5),
              ),
            ),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: _streamUrl.startsWith('http')
                  ? Image.network(
                      _streamUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) =>
                          _feedPlaceholder(false),
                      loadingBuilder: (c, child, prog) =>
                          prog == null ? child : _feedPlaceholder(true),
                    )
                  : _feedPlaceholder(false),
            ),
          ),
        ],
      ),
    );
  }

  Widget _meter(String axis, double v) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          SizedBox(width: 88, child: Text(axis, style: TextStyle(color: MeshTokens.textSecondary(), fontSize: 11))),
          Expanded(
            child: LinearProgressIndicator(
              value: (v.abs() / 2) + 0.5,
              color: MeshTokens.accent(),
              backgroundColor: MeshTokens.surface(),
            ),
          ),
          SizedBox(
            width: 48,
            child: Text(v.toStringAsFixed(2), textAlign: TextAlign.end, style: TextStyle(fontSize: 11, color: MeshTokens.textPrimary())),
          ),
        ],
      ),
    );
  }

  Widget _feedPlaceholder(bool loading) {
    return Container(
      color: Colors.black.withValues(alpha: 0.55),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.linked_camera_rounded,
                color: MeshTokens.textSecondary(), size: 36),
            const SizedBox(height: 8),
            Text(
              loading ? 'Receiving?' : 'Paste a MJPEG/stream URL served by YOUR camera bridge',
              textAlign: TextAlign.center,
              style: TextStyle(color: MeshTokens.textSecondary(), fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}
