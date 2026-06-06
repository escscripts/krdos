import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

class FullscreenMapPicker extends StatefulWidget {
  final double initialLat;
  final double initialLon;
  final Function(double lat, double lon) onLocationPicked;

  const FullscreenMapPicker({
    super.key,
    required this.initialLat,
    required this.initialLon,
    required this.onLocationPicked,
  });

  @override
  State<FullscreenMapPicker> createState() => _FullscreenMapPickerState();
}

class _FullscreenMapPickerState extends State<FullscreenMapPicker> {
  late double _selectedLat;
  late double _selectedLon;
  double _zoom = 2.0;
  Offset _offset = Offset.zero;

  @override
  void initState() {
    super.initState();
    _selectedLat = widget.initialLat;
    _selectedLon = widget.initialLon;
  }

  math.Point<double> _latLonToTile(double lat, double lon, int zoom) {
    final n = math.pow(2, zoom);
    final x = ((lon + 180) / 360 * n);
    final latRad = lat * math.pi / 180;
    final y =
        ((1 - math.log(math.tan(latRad) + 1 / math.cos(latRad)) / math.pi) /
        2 *
        n);
    return math.Point(x, y);
  }

  double _sinh(double value) => (math.exp(value) - math.exp(-value)) / 2;

  math.Point<double> _tileToLatLon(double x, double y, int zoom) {
    final n = math.pow(2, zoom);
    final lon = x / n * 360 - 180;
    final latRad = math.atan(_sinh(math.pi * (1 - 2 * y / n)));
    final lat = latRad * 180 / math.pi;
    return math.Point(lat, lon);
  }

  void _handleTap(TapDownDetails details) {
    final size = MediaQuery.of(context).size;
    final z = _zoom.floor();
    final center = _latLonToTile(_selectedLat, _selectedLon, z);

    final dx = (details.localPosition.dx - size.width / 2) / 256;
    final dy = (details.localPosition.dy - size.height / 2) / 256;

    final tileX = center.x + dx;
    final tileY = center.y + dy;

    final latLon = _tileToLatLon(tileX, tileY, z);

    setState(() {
      _selectedLat = latLon.x.clamp(-85.0, 85.0);
      _selectedLon = latLon.y;
    });
  }

  void _zoomIn() {
    setState(() {
      _zoom = (_zoom + 1).clamp(0.0, 18.0);
    });
  }

  void _zoomOut() {
    setState(() {
      _zoom = (_zoom - 1).clamp(0.0, 18.0);
    });
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final z = _zoom.floor().clamp(0, 18); // Allow higher zoom for OSM
    final centerTile = _latLonToTile(_selectedLat, _selectedLon, z);

    final centerX = size.width / 2;
    final centerY = size.height / 2;

    final tileSize = 256.0;
    final startTileX = ((centerTile.x - centerX / tileSize)).floor() - 1;
    final startTileY = ((centerTile.y - centerY / tileSize)).floor() - 1;
    final endTileX = ((centerTile.x + centerX / tileSize)).ceil() + 1;
    final endTileY = ((centerTile.y + centerY / tileSize)).ceil() + 1;

    final maxTile = math.pow(2, z).toInt();

    final tileWidgets = <Widget>[];

    for (int x = startTileX; x <= endTileX; x++) {
      for (int y = startTileY; y <= endTileY; y++) {
        if (x < 0 || x >= maxTile || y < 0 || y >= maxTile) continue;

        final tileX = centerX + (x - centerTile.x) * tileSize + _offset.dx;
        final tileY = centerY + (y - centerTile.y) * tileSize + _offset.dy;

        final url = 'https://tile.openstreetmap.org/$z/$x/$y.png';

        tileWidgets.add(
          Positioned(
            left: tileX,
            top: tileY,
            width: tileSize,
            height: tileSize,
            child: Image.network(
              url,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Container(
                color: const Color(0xFF1A1A1A),
                child: const Center(
                  child: Icon(Icons.error, color: Colors.white24),
                ),
              ),
            ),
          ),
        );
      }
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      body: Stack(
        children: [
          GestureDetector(
            onTapDown: _handleTap,
            onPanUpdate: (details) {
              setState(() {
                _offset += details.delta;
              });
            },
            child: Stack(children: tileWidgets),
          ),
          Center(
            child: Icon(
              Icons.location_on,
              color: AppTheme.accent,
              size: 48,
              shadows: [
                Shadow(
                  color: Colors.black.withValues(alpha: 0.8),
                  blurRadius: 12,
                ),
              ],
            ),
          ),
          _buildTopBar(),
          _buildBottomBar(),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppTheme.surface.withValues(alpha: 0.95),
              AppTheme.surface.withValues(alpha: 0.0),
            ],
          ),
        ),
        child: Row(
          children: [
            IconButton(
              onPressed: () => Navigator.pop(context),
              icon: Icon(Icons.arrow_back, color: AppTheme.textPrimary),
              style: IconButton.styleFrom(
                backgroundColor: AppTheme.surface,
                side: BorderSide(color: AppTheme.border),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Pick Location',
                      style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Lat: ${_selectedLat.toStringAsFixed(6)}, Lon: ${_selectedLon.toStringAsFixed(6)}',
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 11,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [
              AppTheme.surface.withValues(alpha: 0.95),
              AppTheme.surface.withValues(alpha: 0.0),
            ],
          ),
        ),
        child: Row(
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  onPressed: _zoomIn,
                  icon: Icon(Icons.add, color: AppTheme.textPrimary),
                  style: IconButton.styleFrom(
                    backgroundColor: AppTheme.surface,
                    side: BorderSide(color: AppTheme.border),
                  ),
                ),
                const SizedBox(height: 8),
                IconButton(
                  onPressed: _zoomOut,
                  icon: Icon(Icons.remove, color: AppTheme.textPrimary),
                  style: IconButton.styleFrom(
                    backgroundColor: AppTheme.surface,
                    side: BorderSide(color: AppTheme.border),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: () {
                  widget.onLocationPicked(_selectedLat, _selectedLon);
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accent,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  'Confirm Location',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
