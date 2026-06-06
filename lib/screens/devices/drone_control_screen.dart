import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../../core/devices/device_model.dart';
import '../../core/devices/device_registry.dart';
import '../../theme/app_theme.dart';
import '../../theme/grid_painter.dart';
import '../../widgets/status_bar.dart';

class DroneControlScreen extends StatefulWidget {
  final String deviceId;
  const DroneControlScreen({super.key, required this.deviceId});
  @override
  State<DroneControlScreen> createState() => _DroneControlScreenState();
}

class _DroneControlScreenState extends State<DroneControlScreen>
    with TickerProviderStateMixin {
  bool _armed = false;
  bool _recording = false;
  double _altitude = 0;
  double _battery = 87;
  double _speed = 0;
  double _heading = 0;
  Offset _leftStick = Offset.zero;
  Offset _rightStick = Offset.zero;
  late Timer _telemetryTimer;

  // Simulated GPS
  double _lat = 25.2048;
  double _lng = 55.2708;

  @override
  void initState() {
    super.initState();
    _telemetryTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      if (!_armed) return;
      setState(() {
        _altitude += (_leftStick.dy * -0.5);
        _altitude = _altitude.clamp(0, 400);
        _speed = (_rightStick.distance * 20).clamp(0, 120);
        _heading = (_heading + _leftStick.dx * 3) % 360;
        _battery -= 0.01;
        _lat += _rightStick.dy * -0.0001;
        _lng += _rightStick.dx * 0.0001;
      });
    });
  }

  @override
  void dispose() {
    _telemetryTimer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final registry = context.watch<DeviceRegistry>();
    final device = registry.getById(widget.deviceId);

    return Scaffold(
      body: Stack(
        children: [
          CustomPaint(painter: GridPainter(), child: const SizedBox.expand()),
          Column(
            children: [
              const StatusBar(),
              _buildHeader(device),
              Expanded(
                child: Row(
                  children: [
  // Left panel  telemetry
                    SizedBox(width: 220, child: _buildTelemetry()),
                    Container(width: 1, color: AppTheme.border),
  // Center  camera + controls
                    Expanded(
                      child: Column(
                        children: [
                          Expanded(child: _buildCameraFeed()),
                          _buildControlBar(),
                          _buildJoysticks(),
                        ],
                      ),
                    ),
                    Container(width: 1, color: AppTheme.border),
  // Right panel  map
                    SizedBox(width: 220, child: _buildMap()),
                  ],
                ),
              ),
            ],
          ),
  // Battery warning
          if (_battery < 20)
            Positioned(
              top: 60,
              left: 0,
              right: 0,
              child:
                  Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.danger.withOpacity(0.9),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'Å¡  LOW BATTERY ‚¬ RETURN TO HOME',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      )
                      .animate(onPlay: (c) => c.repeat(reverse: true))
                      .fadeIn(duration: 500.ms),
            ),
        ],
      ),
    );
  }

  Widget _buildHeader(ConnectedDevice? device) {
    return Container(
      color: AppTheme.surface,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Icon(Icons.arrow_back_ios, color: AppTheme.accent, size: 14),
          ),
          const SizedBox(width: 8),
          Text(
            device?.name.toUpperCase() ?? 'DRONE',
            style: TextStyle(
              color: AppTheme.accent,
              fontSize: 13,
              fontWeight: FontWeight.bold,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: (_armed ? AppTheme.danger : AppTheme.textSecondary)
                  .withOpacity(0.15),
              border: Border.all(
                color: _armed ? AppTheme.danger : AppTheme.textSecondary,
              ),
              borderRadius: BorderRadius.circular(3),
            ),
            child: Text(
              _armed ? 'ARMED' : 'DISARMED',
              style: TextStyle(
                color: _armed ? AppTheme.danger : AppTheme.textSecondary,
                fontSize: 9,
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
              ),
            ),
          ),
          const Spacer(),
          _batteryIndicator(),
        ],
      ),
    );
  }

  Widget _batteryIndicator() {
    final color = _battery > 50
        ? AppTheme.accent
        : _battery > 20
        ? AppTheme.warning
        : AppTheme.danger;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.battery_full, color: color, size: 16),
        const SizedBox(width: 4),
        Text(
          '${_battery.toStringAsFixed(0)}%',
          style: TextStyle(
            color: color,
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildTelemetry() {
    return Container(
      color: AppTheme.surface,
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'TELEMETRY',
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 9,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 12),
          _telRow('ALT', '${_altitude.toStringAsFixed(1)} m'),
          _telRow('SPEED', '${_speed.toStringAsFixed(1)} km/h'),
          _telRow('HEADING', '${_heading.toStringAsFixed(0)}Ã‚°'),
          _telRow('BATTERY', '${_battery.toStringAsFixed(1)}%'),
          _telRow(
            'GPS',
            '${_lat.toStringAsFixed(4)}, ${_lng.toStringAsFixed(4)}',
          ),
          _telRow('SIGNAL', '87%'),
          _telRow('MODE', _armed ? 'MANUAL' : 'STANDBY'),
          const SizedBox(height: 16),
          Text(
            'ATTITUDE',
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 9,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 12),
          _buildAttitudeIndicator(),
          const SizedBox(height: 16),
          Text(
            'FLIGHT LOG',
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 9,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 8),
          ...[
            'System initialized',
            if (_armed) 'Motors armed',
            if (_altitude > 0) 'Altitude: ${_altitude.toStringAsFixed(0)}m',
            if (_recording) 'Recording started',
          ].map(
            (l) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  Container(
                    width: 4,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppTheme.accent,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    l,
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _telRow(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      children: [
        Text(
          '$label ',
          style: TextStyle(color: AppTheme.textSecondary, fontSize: 11),
        ),
        const Spacer(),
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

  Widget _buildAttitudeIndicator() {
    return Center(
      child: SizedBox(
        width: 100,
        height: 100,
        child: CustomPaint(
          painter: _AttitudePainter(
            pitch: _leftStick.dy * 30,
            roll: _rightStick.dx * 30,
          ),
        ),
      ),
    );
  }

  Widget _buildCameraFeed() {
    return Container(
      color: Colors.black,
      child: Stack(
        children: [
  // Simulated camera feed
          CustomPaint(
            painter: _CameraFeedPainter(),
            child: const SizedBox.expand(),
          ),
  // HUD overlay
          Positioned(
            top: 8,
            left: 8,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'REC ${_recording ? "-" : "- - ¹"}',
                  style: TextStyle(
                    color: _recording
                        ? AppTheme.danger
                        : AppTheme.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'ALT ${_altitude.toStringAsFixed(0)}m',
                  style: TextStyle(color: Colors.white, fontSize: 10),
                ),
                Text(
                  'SPD ${_speed.toStringAsFixed(0)}km/h',
                  style: TextStyle(color: Colors.white, fontSize: 10),
                ),
              ],
            ),
          ),
  // Crosshair
          Center(
            child: CustomPaint(
              painter: _CrosshairPainter(),
              child: const SizedBox(width: 60, height: 60),
            ),
          ),
  // Heading compass
          Positioned(top: 8, right: 8, child: _buildCompass()),
        ],
      ),
    );
  }

  Widget _buildCompass() {
    return SizedBox(
      width: 50,
      height: 50,
      child: CustomPaint(painter: _CompassPainter(heading: _heading)),
    );
  }

  Widget _buildControlBar() {
    return Container(
      color: AppTheme.surface,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _ctrlBtn(
            'ARM',
            _armed ? AppTheme.danger : AppTheme.accent,
            Icons.power_settings_new,
            () {
              setState(() => _armed = !_armed);
            },
          ),
          _ctrlBtn('RTH', AppTheme.warning, Icons.home, () {}),
          _ctrlBtn(
            _recording ? 'STOP' : 'REC',
            _recording ? AppTheme.danger : AppTheme.textSecondary,
            _recording ? Icons.stop : Icons.fiber_manual_record,
            () {
              setState(() => _recording = !_recording);
            },
          ),
          _ctrlBtn('PHOTO', AppTheme.accent, Icons.camera_alt, () {}),
          _ctrlBtn('HOLD', AppTheme.warning, Icons.pause, () {}),
          _ctrlBtn('LAND', AppTheme.accent, Icons.flight_land, () {
            setState(() {
              _altitude = 0;
              _armed = false;
            });
          }),
        ],
      ),
    );
  }

  Widget _ctrlBtn(
    String label,
    Color color,
    IconData icon,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              border: Border.all(color: color),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 9,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildJoysticks() {
    return Container(
      color: AppTheme.surface,
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            children: [
              Text(
                'THROTTLE / YAW',
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 9,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 8),
              _Joystick(
                onChanged: (v) => setState(() => _leftStick = v),
                enabled: _armed,
              ),
            ],
          ),
          Column(
            children: [
              Text(
                'PITCH / ROLL',
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 9,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 8),
              _Joystick(
                onChanged: (v) => setState(() => _rightStick = v),
                enabled: _armed,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMap() {
    return Container(
      color: AppTheme.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.all(12),
            child: Text(
              'GPS MAP',
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 9,
                letterSpacing: 2,
              ),
            ),
          ),
          Expanded(
            child: CustomPaint(
              painter: _MapPainter(lat: _lat, lng: _lng, heading: _heading),
              child: const SizedBox.expand(),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'LAT: ${_lat.toStringAsFixed(6)}',
                  style: TextStyle(color: AppTheme.accent, fontSize: 10),
                ),
                Text(
                  'LNG: ${_lng.toStringAsFixed(6)}',
                  style: TextStyle(color: AppTheme.accent, fontSize: 10),
                ),
                Text(
                  'ALT: ${_altitude.toStringAsFixed(1)}m',
                  style: TextStyle(color: AppTheme.accent, fontSize: 10),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

//  Joystick Widget  
class _Joystick extends StatefulWidget {
  final ValueChanged<Offset> onChanged;
  final bool enabled;
  const _Joystick({required this.onChanged, required this.enabled});
  @override
  State<_Joystick> createState() => _JoystickState();
}

class _JoystickState extends State<_Joystick> {
  Offset _pos = Offset.zero;
  static const _size = 100.0;
  static const _knob = 24.0;

  void _update(Offset local) {
    final center = const Offset(_size / 2, _size / 2);
    var delta = local - center;
    final maxR = (_size / 2) - (_knob / 2);
    if (delta.distance > maxR) delta = delta / delta.distance * maxR;
    setState(() => _pos = delta);
    widget.onChanged(Offset(delta.dx / maxR, delta.dy / maxR));
  }

  void _reset() {
    setState(() => _pos = Offset.zero);
    widget.onChanged(Offset.zero);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanUpdate: widget.enabled ? (d) => _update(d.localPosition) : null,
      onPanEnd: widget.enabled ? (_) => _reset() : null,
      child: SizedBox(
        width: _size,
        height: _size,
        child: CustomPaint(
          painter: _JoystickPainter(pos: _pos, enabled: widget.enabled),
        ),
      ),
    );
  }
}

class _JoystickPainter extends CustomPainter {
  final Offset pos;
  final bool enabled;
  const _JoystickPainter({required this.pos, required this.enabled});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final color = enabled ? AppTheme.accent : AppTheme.textSecondary;

  // Base circle
    canvas.drawCircle(
      center,
      size.width / 2 - 2,
      Paint()
        ..color = color.withOpacity(0.05)
        ..style = PaintingStyle.fill,
    );
    canvas.drawCircle(
      center,
      size.width / 2 - 2,
      Paint()
        ..color = color.withOpacity(0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );

  // Crosshair
    final cp = Paint()
      ..color = color.withOpacity(0.2)
      ..strokeWidth = 0.5;
    canvas.drawLine(
      Offset(center.dx, 4),
      Offset(center.dx, size.height - 4),
      cp,
    );
    canvas.drawLine(
      Offset(4, center.dy),
      Offset(size.width - 4, center.dy),
      cp,
    );

  // Knob
    final knobCenter = center + pos;
    canvas.drawCircle(
      knobCenter,
      12,
      Paint()
        ..color = color.withOpacity(0.2)
        ..style = PaintingStyle.fill,
    );
    canvas.drawCircle(
      knobCenter,
      12,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
    canvas.drawCircle(
      knobCenter,
      4,
      Paint()
        ..color = color
        ..style = PaintingStyle.fill,
    );
  }

  @override
  bool shouldRepaint(_JoystickPainter old) =>
      old.pos != pos || old.enabled != enabled;
}

//  Custom Painters  
class _AttitudePainter extends CustomPainter {
  final double pitch, roll;
  const _AttitudePainter({required this.pitch, required this.roll});

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2 - 4;
    canvas.drawCircle(c, r, Paint()..color = AppTheme.surfaceAlt);
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..color = AppTheme.border
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
  // Horizon line
    final p = Paint()
      ..color = AppTheme.accent
      ..strokeWidth = 2;
    final angle = roll * pi / 180;
    final dx = cos(angle) * r * 0.7;
    final dy = sin(angle) * r * 0.7;
    canvas.drawLine(
      c + Offset(-dx, -dy + pitch),
      c + Offset(dx, dy + pitch),
      p,
    );
  // Center dot
    canvas.drawCircle(c, 3, Paint()..color = AppTheme.accent);
  }

  @override
  bool shouldRepaint(_) => true;
}

class _CameraFeedPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rng = Random(42);
  // Simulated terrain
    final paint = Paint()..color = const Color(0xFF0A1A0A);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint);
  // Grid lines (ground)
    final gp = Paint()
      ..color = const Color(0xFF00FF0020)
      ..strokeWidth = 0.5;
    for (double x = 0; x < size.width; x += 40) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gp);
    }
    for (double y = 0; y < size.height; y += 40) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gp);
    }
  }

  @override
  bool shouldRepaint(_) => false;
}

class _CrosshairPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = AppTheme.accent
      ..strokeWidth = 1;
    final c = Offset(size.width / 2, size.height / 2);
    canvas.drawLine(Offset(c.dx - 20, c.dy), Offset(c.dx - 8, c.dy), p);
    canvas.drawLine(Offset(c.dx + 8, c.dy), Offset(c.dx + 20, c.dy), p);
    canvas.drawLine(Offset(c.dx, c.dy - 20), Offset(c.dx, c.dy - 8), p);
    canvas.drawLine(Offset(c.dx, c.dy + 8), Offset(c.dx, c.dy + 20), p);
    canvas.drawCircle(
      c,
      4,
      Paint()
        ..color = AppTheme.accent
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
  }

  @override
  bool shouldRepaint(_) => false;
}

class _CompassPainter extends CustomPainter {
  final double heading;
  const _CompassPainter({required this.heading});

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2 - 2;
    canvas.drawCircle(c, r, Paint()..color = Colors.black.withOpacity(0.6));
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..color = AppTheme.border
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(-heading * pi / 180);
    final np = Paint()
      ..color = AppTheme.danger
      ..strokeWidth = 2;
    canvas.drawLine(Offset.zero, Offset(0, -r + 4), np);
    final sp = Paint()
      ..color = AppTheme.textSecondary
      ..strokeWidth = 1;
    canvas.drawLine(Offset.zero, Offset(0, r - 4), sp);
    canvas.restore();
  // N label
    final tp = TextPainter(
      text: const TextSpan(
        text: 'N',
        style: TextStyle(color: AppTheme.danger, fontSize: 8),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(c.dx - tp.width / 2, 2));
  }

  @override
  bool shouldRepaint(_CompassPainter old) => old.heading != heading;
}

class _MapPainter extends CustomPainter {
  final double lat, lng, heading;
  const _MapPainter({
    required this.lat,
    required this.lng,
    required this.heading,
  });

  @override
  void paint(Canvas canvas, Size size) {
  // Dark map background
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = const Color(0xFF0A0F0A),
    );
  // Grid
    final gp = Paint()
      ..color = const Color(0xFF00FF0015)
      ..strokeWidth = 0.5;
    for (double x = 0; x < size.width; x += 20) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gp);
    }
    for (double y = 0; y < size.height; y += 20) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gp);
    }
  // Drone position (center)
    final c = Offset(size.width / 2, size.height / 2);
    canvas.drawCircle(c, 20, Paint()..color = AppTheme.accent.withOpacity(0.1));
    canvas.drawCircle(
      c,
      20,
      Paint()
        ..color = AppTheme.accent.withOpacity(0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
  // Drone icon
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(heading * pi / 180);
    final dp = Paint()
      ..color = AppTheme.accent
      ..strokeWidth = 2;
    canvas.drawLine(const Offset(0, -12), const Offset(0, 12), dp);
    canvas.drawLine(const Offset(-12, 0), const Offset(12, 0), dp);
    canvas.drawCircle(Offset.zero, 4, Paint()..color = AppTheme.accent);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_MapPainter old) =>
      old.lat != lat || old.lng != lng || old.heading != heading;
}