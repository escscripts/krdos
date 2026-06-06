import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/mesh_engine.dart';
import '../models/device_model.dart';
import '../ui/mesh_tokens.dart';

class CameraOperatorDeck extends StatefulWidget {
  const CameraOperatorDeck({super.key, required this.device});

  final MeshDevice device;

  @override
  State<CameraOperatorDeck> createState() => _CameraOperatorDeckState();
}

class _CameraOperatorDeckState extends State<CameraOperatorDeck> {
  double _zoom = 1;
  double _pan = 0;
  double _tilt = 0;
  String _feed = '';
  bool _recording = false;

  void _pushPanTilt(MeshEngine mesh) {
    mesh.quickCommand(widget.device.id, 'pan_tilt', {
      'pan': _pan.toStringAsFixed(1),
      'tilt': _tilt.toStringAsFixed(1),
    });
  }

  @override
  Widget build(BuildContext context) {
    final mesh = context.watch<MeshEngine>();

    return ListView(
      padding: MeshTokens.screenPadding(),
      children: [
        TextField(
          onChanged: (v) => setState(() => _feed = v.trim()),
          style: TextStyle(color: MeshTokens.textPrimary(), fontSize: 12),
          decoration: InputDecoration(
            labelText: 'Ingress URL (MJPEG / snapshot)',
            labelStyle: TextStyle(color: MeshTokens.textSecondary()),
            enabledBorder:
                OutlineInputBorder(borderSide: BorderSide(color: MeshTokens.border())),
            focusedBorder:
                OutlineInputBorder(borderSide: BorderSide(color: MeshTokens.accent())),
          ),
        ),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: AspectRatio(
            aspectRatio: 16 / 9,
            child: _feed.startsWith('http')
                ? Image.network(
                    _feed,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) =>
                        _fallback(),
                  )
                : _fallback(),
          ),
        ),
        const SizedBox(height: 12),
        _zoomSlider(mesh),
        _axisSlider(mesh, title: 'Pan', value: _pan, min: -180, max: 180,
            valueLabel: '${_pan.toStringAsFixed(0)}°', onChanged: (v) => setState(() => _pan = v),
            onPanTiltCommit: (_) => _pushPanTilt(mesh)),
        _axisSlider(mesh, title: 'Tilt', value: _tilt, min: -45, max: 45,
            valueLabel: '${_tilt.toStringAsFixed(0)}°', onChanged: (v) => setState(() => _tilt = v),
            onPanTiltCommit: (_) => _pushPanTilt(mesh)),
        Row(
          children: [
            Expanded(
              child: FilledButton.tonalIcon(
                onPressed: () {
                  setState(() => _recording = !_recording);
                  mesh.quickCommand(
                    widget.device.id,
                    'record',
                    {'action': _recording ? 'on' : 'off'},
                  );
                },
                icon: Icon(Icons.fiber_smart_record_outlined, color: MeshTokens.danger()),
                label: Text(_recording ? 'Recording?' : 'Record'),
                style: FilledButton.styleFrom(backgroundColor: MeshTokens.accentMuted()),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: FilledButton.tonalIcon(
                onPressed: () =>
                    mesh.quickCommand(widget.device.id, 'photo', {}),
                icon: Icon(Icons.photo_camera_rounded, color: MeshTokens.accent()),
                label: const Text('Still capture'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _zoomSlider(MeshEngine mesh) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Zoom level', style: TextStyle(color: MeshTokens.textPrimary(), fontSize: 11)),
        Row(
          children: [
            Expanded(
              child: Slider(
                value: _zoom.clamp(1, 30),
                min: 1,
                max: 30,
                onChanged: (v) => setState(() => _zoom = v),
                onChangeEnd: (v) => mesh.quickCommand(
                  widget.device.id,
                  'zoom',
                  {'level': v.toStringAsFixed(1)},
                ),
                activeColor: MeshTokens.accent(),
              ),
            ),
            SizedBox(
              width: 40,
              child: Text(_zoom.toStringAsFixed(0),
                  style: TextStyle(color: MeshTokens.accent())),
            ),
          ],
        ),
      ],
    );
  }

  Widget _axisSlider(
    MeshEngine mesh, {
    required String title,
    required double value,
    required double min,
    required double max,
    required String valueLabel,
    required ValueChanged<double> onChanged,
    required ValueChanged<double> onPanTiltCommit,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: TextStyle(color: MeshTokens.textPrimary(), fontSize: 11)),
        Row(
          children: [
            Expanded(
              child: Slider(
                value: value.clamp(min, max),
                min: min,
                max: max,
                onChanged: onChanged,
                onChangeEnd: onPanTiltCommit,
                activeColor: MeshTokens.accent(),
              ),
            ),
            SizedBox(
              width: 40,
              child: Text(valueLabel,
                  style: TextStyle(color: MeshTokens.accent())),
            ),
          ],
        ),
      ],
    );
  }

  Widget _fallback() {
    return Container(
      color: MeshTokens.elevated(),
      child: Center(
        child: Text(
          'Bind your camera ingest server',
          style: TextStyle(color: MeshTokens.textSecondary(), fontSize: 11),
        ),
      ),
    );
  }
}
