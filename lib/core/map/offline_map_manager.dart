import 'dart:io';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;

class OfflineMapManager {
  // Using OpenStreetMap tiles (free, no token required)
  static const String tileServer = 'https://tile.openstreetmap.org';
  static const int maxZoom = 8;
  static const int minZoom = 0;
  
  final String tilesDirectory;
  bool _isDownloading = false;
  double _downloadProgress = 0.0;
  int _downloadedCount = 0;
  int _totalCount = 0;
  
  OfflineMapManager(this.tilesDirectory);
  
  bool get isDownloading => _isDownloading;
  double get downloadProgress => _downloadProgress;
  int get downloadedCount => _downloadedCount;
  int get totalCount => _totalCount;
  
  String getTilePath(int z, int x, int y) {
    return path.join(tilesDirectory, '$z', '$x', '$y.png');
  }
  
  Future<bool> tileExists(int z, int x, int y) async {
    final tilePath = getTilePath(z, x, y);
    return await File(tilePath).exists();
  }
  
  Future<File?> getTile(int z, int x, int y) async {
    final tilePath = getTilePath(z, x, y);
    final file = File(tilePath);
    if (await file.exists()) {
      return file;
    }
    return null;
  }
  
  Future<void> downloadTile(int z, int x, int y) async {
    if (await tileExists(z, x, y)) {
      _downloadedCount++;
      return;
    }
    
    final url = '$tileServer/$z/$x/$y.png';
    try {
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'User-Agent': 'KrdOS/1.0',
        },
      );
      if (response.statusCode == 200) {
        final tilePath = getTilePath(z, x, y);
        final file = File(tilePath);
        await file.parent.create(recursive: true);
        await file.writeAsBytes(response.bodyBytes);
        _downloadedCount++;
        
  // Rate limiting for OSM (max 2 requests/second)
        await Future.delayed(const Duration(milliseconds: 500));
      }
    } catch (e) {
      debugPrint('Failed to download tile $z/$x/$y: $e');
    }
  }
  
  Future<void> downloadWorldTiles({
    Function(double, int, int)? onProgress,
  }) async {
    if (_isDownloading) return;
    
    _isDownloading = true;
    _downloadProgress = 0.0;
    _downloadedCount = 0;
    _totalCount = 0;
    
    for (int z = minZoom; z <= maxZoom; z++) {
      final tilesAtZoom = (1 << z) * (1 << z);
      _totalCount += tilesAtZoom;
    }
    
    debugPrint('Total tiles to download (zoom 0-8): $_totalCount (~500MB)');
    
    for (int z = minZoom; z <= maxZoom; z++) {
      final maxTile = 1 << z;
      for (int x = 0; x < maxTile; x++) {
        for (int y = 0; y < maxTile; y++) {
          await downloadTile(z, x, y);
          _downloadProgress = _downloadedCount / _totalCount;
          onProgress?.call(_downloadProgress, _downloadedCount, _totalCount);
          
          if (_downloadedCount % 50 == 0) {
            await Future.delayed(const Duration(milliseconds: 50));
          }
        }
      }
      debugPrint('Completed zoom level $z');
    }
    
    _isDownloading = false;
    _downloadProgress = 1.0;
    debugPrint('Download complete! Total tiles: $_downloadedCount');
  }
  

  Future<String> getCacheSize() async {
    final dir = Directory(tilesDirectory);
    if (!await dir.exists()) return '0 MB';
    
    int totalBytes = 0;
    await for (final entity in dir.list(recursive: true)) {
      if (entity is File) {
        totalBytes += await entity.length();
      }
    }
    
    final mb = totalBytes / (1024 * 1024);
    return '${mb.toStringAsFixed(2)} MB';
  }
  
  Future<void> clearCache() async {
    final dir = Directory(tilesDirectory);
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
    _downloadedCount = 0;
    _totalCount = 0;
  }
}