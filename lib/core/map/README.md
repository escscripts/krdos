# Map Module

Fullscreen dark mode map picker with offline tile support for Ghost Mode location spoofing.

## Files

### `fullscreen_map_picker.dart`
Fullscreen map widget with Mapbox integration.

**Usage:**
```dart
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (context) => FullscreenMapPicker(
      initialLat: 40.7128,
      initialLon: -74.0060,
      onLocationPicked: (lat, lon) {
        print('Picked: $lat, $lon');
      },
    ),
    fullscreenDialog: true,
  ),
);
```

**Features:**
- Dark mode theme
- Click to pick location
- Zoom controls
- Real-time coordinates
- Visual marker

### `offline_map_manager.dart`
Manages offline tile downloads and caching.

**Usage:**
```dart
final manager = OfflineMapManager('/path/to/tiles');

// Download tiles
await manager.downloadWorldTiles(
  onProgress: (progress, downloaded, total) {
    print('$downloaded / $total');
  },
);

// Check size
final size = await manager.getCacheSize();

// Clear cache
await manager.clearCache();
```

**Features:**
- Download zoom 0-8 (~500MB)
- Progress tracking
- Cache management
- Size calculation

## Setup

1. Get Mapbox token from https://account.mapbox.com/
2. Add token to `offline_map_manager.dart` line 8
3. Run `flutter pub get`
4. Use in Ghost Mode app

## Documentation

- **Quick Start**: `../../MAPBOX_QUICKSTART.md`
- **Full Setup**: `../../MAPBOX_SETUP.md`
- **Implementation**: `../../MAPBOX_IMPLEMENTATION.md`
