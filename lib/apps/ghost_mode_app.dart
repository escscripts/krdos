import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/ghost_mode_service.dart';
import '../core/map/fullscreen_map_picker.dart';
import '../theme/app_theme.dart';

class GhostModeApp extends StatelessWidget {
  const GhostModeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => GhostModeService(),
      child: const GhostModeScreen(),
    );
  }
}

class GhostModeScreen extends StatefulWidget {
  const GhostModeScreen({super.key});

  @override
  State<GhostModeScreen> createState() => _GhostModeScreenState();
}

class _GhostModeScreenState extends State<GhostModeScreen> {
  int _selectedTab = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Consumer<GhostModeService>(
        builder: (context, ghost, _) {
          return Column(
            children: [
              _buildHeader(ghost),
              _buildTabBar(),
              Expanded(
                child: _buildTabContent(ghost),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildHeader(GhostModeService ghost) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        border: Border(bottom: BorderSide(color: AppTheme.border)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: ghost.isGhostModeActive
                  ? AppTheme.accent.withValues(alpha: 0.15)
                  : AppTheme.surfaceAlt,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: ghost.isGhostModeActive ? AppTheme.accent : AppTheme.border,
              ),
            ),
            child: Icon(
              Icons.visibility_off_rounded,
              color: ghost.isGhostModeActive ? AppTheme.accent : AppTheme.textSecondary,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Ghost Mode',
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  ghost.isGhostModeActive
                      ? 'Identity hidden · All protections active'
                      : 'Identity exposed · Protections disabled',
                  style: TextStyle(
                    color: ghost.isGhostModeActive
                        ? AppTheme.accent
                        : AppTheme.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          _buildMasterSwitch(ghost),
        ],
      ),
    );
  }

  Widget _buildMasterSwitch(GhostModeService ghost) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: ghost.isGhostModeActive
            ? AppTheme.accent.withValues(alpha: 0.15)
            : AppTheme.surfaceAlt,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: ghost.isGhostModeActive ? AppTheme.accent : AppTheme.border,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            ghost.isGhostModeActive ? 'ACTIVE' : 'INACTIVE',
            style: TextStyle(
              color: ghost.isGhostModeActive ? AppTheme.accent : AppTheme.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(width: 8),
          Switch(
            value: ghost.isGhostModeActive,
            onChanged: (_) {
              if (ghost.isGhostModeActive) {
                ghost.disableAllProtections();
              } else {
                ghost.enableAllProtections();
              }
            },
            activeColor: AppTheme.accent,
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    final tabs = [
      {'icon': Icons.shield_outlined, 'label': 'Protection'},
      {'icon': Icons.location_on_outlined, 'label': 'Location'},
      {'icon': Icons.fingerprint, 'label': 'Identity'},
      {'icon': Icons.settings_outlined, 'label': 'Advanced'},
    ];

    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: AppTheme.surface,
        border: Border(bottom: BorderSide(color: AppTheme.border)),
      ),
      child: Row(
        children: List.generate(tabs.length, (index) {
          final tab = tabs[index];
          final isSelected = _selectedTab == index;
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selectedTab = index),
              child: Container(
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: isSelected ? AppTheme.accent : Colors.transparent,
                      width: 2,
                    ),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      tab['icon'] as IconData,
                      size: 16,
                      color: isSelected ? AppTheme.accent : AppTheme.textSecondary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      tab['label'] as String,
                      style: TextStyle(
                        color: isSelected ? AppTheme.accent : AppTheme.textSecondary,
                        fontSize: 12,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildTabContent(GhostModeService ghost) {
    switch (_selectedTab) {
      case 0:
        return _buildProtectionTab(ghost);
      case 1:
        return _buildLocationTab(ghost);
      case 2:
        return _buildIdentityTab(ghost);
      case 3:
        return _buildAdvancedTab(ghost);
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildProtectionTab(GhostModeService ghost) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('Network Protection'),
          const SizedBox(height: 12),
          _buildProtectionCard(
            icon: Icons.swap_horiz_rounded,
            title: 'IP Rotation',
            subtitle: ghost.currentIP,
            isActive: ghost.ipRotationEnabled,
            onToggle: ghost.toggleIPRotation,
            child: Column(
              children: [
                const SizedBox(height: 12),
                _buildInfoRow('IP Address', ghost.currentIP),
                const SizedBox(height: 8),
                _buildInfoRow('MAC Address', ghost.currentMAC),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Text(
                      'Rotation Interval',
                      style: TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                    ),
                    const Spacer(),
                    Text(
                      '${ghost.ipRotationInterval}s',
                      style: TextStyle(
                        color: AppTheme.accent,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                Slider(
                  value: ghost.ipRotationInterval.toDouble(),
                  min: 1,
                  max: 60,
                  divisions: 59,
                  activeColor: AppTheme.accent,
                  inactiveColor: AppTheme.border,
                  onChanged: (v) => ghost.setIPRotationInterval(v.toInt()),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _buildProtectionCard(
            icon: Icons.dns_rounded,
            title: 'DNS Rotation',
            subtitle: ghost.currentDNS,
            isActive: ghost.dnsRotationEnabled,
            onToggle: ghost.toggleDNSRotation,
            child: Padding(
              padding: const EdgeInsets.only(top: 12),
              child: _buildInfoRow('DNS Server', ghost.currentDNS),
            ),
          ),
          const SizedBox(height: 24),
          _buildSectionTitle('Quick Actions'),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildActionButton(
                  'Enable All',
                  Icons.shield_rounded,
                  AppTheme.accent,
                  ghost.enableAllProtections,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildActionButton(
                  'Disable All',
                  Icons.shield_outlined,
                  AppTheme.danger,
                  ghost.disableAllProtections,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLocationTab(GhostModeService ghost) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildProtectionCard(
            icon: Icons.location_on_rounded,
            title: 'GPS Spoofing',
            subtitle: ghost.locationName,
            isActive: ghost.locationSpoofEnabled,
            onToggle: ghost.toggleLocationSpoof,
            child: Column(
              children: [
                const SizedBox(height: 12),
                _buildInfoRow('Latitude', ghost.latitude.toStringAsFixed(6)),
                const SizedBox(height: 8),
                _buildInfoRow('Longitude', ghost.longitude.toStringAsFixed(6)),
                const SizedBox(height: 8),
                _buildInfoRow('Timezone', ghost.timezone),
                const SizedBox(height: 16),
                _buildMapPreview(ghost),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildActionButton(
                        'Random Location',
                        Icons.shuffle_rounded,
                        AppTheme.accent,
                        ghost.randomLocation,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildActionButton(
                        'Pick on Map',
                        Icons.map_outlined,
                        AppTheme.accent,
                        () => _showMapPicker(ghost),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _buildSectionTitle('Quick Locations'),
          const SizedBox(height: 12),
          _buildQuickLocationGrid(ghost),
        ],
      ),
    );
  }

  Widget _buildMapPreview(GhostModeService ghost) {
    return Container(
      height: 200,
      decoration: BoxDecoration(
        color: AppTheme.surfaceAlt,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.border),
      ),
      child: Stack(
        children: [
          Center(
            child: Icon(
              Icons.map_outlined,
              size: 48,
              color: AppTheme.textSecondary.withValues(alpha: 0.3),
            ),
          ),
          Positioned(
            bottom: 12,
            left: 12,
            right: 12,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.surface.withValues(alpha: 0.95),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppTheme.border),
              ),
              child: Row(
                children: [
                  Icon(Icons.location_on, size: 16, color: AppTheme.accent),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      ghost.locationName,
                      style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
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

  Widget _buildQuickLocationGrid(GhostModeService ghost) {
    final locations = [
      {'name': 'New York, USA', 'lat': 40.7128, 'lon': -74.0060, 'tz': 'America/New_York'},
      {'name': 'London, UK', 'lat': 51.5074, 'lon': -0.1278, 'tz': 'Europe/London'},
      {'name': 'Tokyo, Japan', 'lat': 35.6762, 'lon': 139.6503, 'tz': 'Asia/Tokyo'},
      {'name': 'Paris, France', 'lat': 48.8566, 'lon': 2.3522, 'tz': 'Europe/Paris'},
      {'name': 'Sydney, Australia', 'lat': -33.8688, 'lon': 151.2093, 'tz': 'Australia/Sydney'},
      {'name': 'Dubai, UAE', 'lat': 25.2048, 'lon': 55.2708, 'tz': 'Asia/Dubai'},
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 2.5,
      ),
      itemCount: locations.length,
      itemBuilder: (context, index) {
        final loc = locations[index];
        return GestureDetector(
          onTap: () {
            ghost.setCustomLocation(
              loc['lat'] as double,
              loc['lon'] as double,
              loc['name'] as String,
              loc['tz'] as String,
            );
          },
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.surfaceAlt,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.border),
            ),
            child: Row(
              children: [
                Icon(Icons.public, size: 16, color: AppTheme.accent),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    loc['name'] as String,
                    style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showMapPicker(GhostModeService ghost) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FullscreenMapPicker(
          initialLat: ghost.latitude,
          initialLon: ghost.longitude,
          onLocationPicked: (lat, lon) {
            ghost.setCustomLocation(lat, lon, 'Custom Location', 'UTC');
          },
        ),
        fullscreenDialog: true,
      ),
    );
  }

  Widget _buildIdentityTab(GhostModeService ghost) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildProtectionCard(
            icon: Icons.fingerprint_rounded,
            title: 'Fingerprint Rotation',
            subtitle: '${ghost.browser} on ${ghost.os}',
            isActive: ghost.fingerprintRotationEnabled,
            onToggle: ghost.toggleFingerprintRotation,
            child: Column(
              children: [
                const SizedBox(height: 12),
                _buildInfoRow('Browser', ghost.browser),
                const SizedBox(height: 8),
                _buildInfoRow('OS', ghost.os),
                const SizedBox(height: 8),
                _buildInfoRow('Language', ghost.language),
                const SizedBox(height: 8),
                _buildInfoRow('Resolution', ghost.screenResolution),
                const SizedBox(height: 8),
                _buildInfoRow('CPU Cores', '${ghost.hardwareConcurrency}'),
                const SizedBox(height: 8),
                _buildInfoRow('Memory', '${ghost.deviceMemory} GB'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdvancedTab(GhostModeService ghost) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('Advanced Protection'),
          const SizedBox(height: 12),
          _buildToggleRow(
            'WebRTC Leak Protection',
            'Prevent IP leaks through WebRTC',
            ghost.webrtcProtection,
            ghost.toggleWebRTCProtection,
          ),
          const SizedBox(height: 8),
          _buildToggleRow(
            'Canvas Fingerprint Noise',
            'Randomize canvas fingerprinting',
            ghost.canvasNoiseEnabled,
            ghost.toggleCanvasNoise,
          ),
          const SizedBox(height: 8),
          _buildToggleRow(
            'Audio Fingerprint Noise',
            'Randomize audio fingerprinting',
            ghost.audioNoiseEnabled,
            ghost.toggleAudioNoise,
          ),
          const SizedBox(height: 8),
          _buildToggleRow(
            'Battery Status Spoofing',
            'Hide real battery information',
            ghost.batterySpoofEnabled,
            ghost.toggleBatterySpoof,
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: TextStyle(
        color: AppTheme.textSecondary,
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.5,
      ),
    );
  }

  Widget _buildProtectionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isActive,
    required VoidCallback onToggle,
    Widget? child,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isActive ? AppTheme.accent : AppTheme.border,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isActive
                      ? AppTheme.accent.withValues(alpha: 0.15)
                      : AppTheme.surfaceAlt,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  color: isActive ? AppTheme.accent : AppTheme.textSecondary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 11,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Switch(
                value: isActive,
                onChanged: (_) => onToggle(),
                activeColor: AppTheme.accent,
              ),
            ],
          ),
          if (child != null) child,
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppTheme.surfaceAlt,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        children: [
          Text(
            label,
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 11,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              color: AppTheme.accent,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(
    String label,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToggleRow(
    String title,
    String subtitle,
    bool value,
    VoidCallback onToggle,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: (_) => onToggle(),
            activeColor: AppTheme.accent,
          ),
        ],
      ),
    );
  }
}

class _MapPickerDialog extends StatefulWidget {
  final GhostModeService ghost;
  const _MapPickerDialog({required this.ghost});

  @override
  State<_MapPickerDialog> createState() => _MapPickerDialogState();
}

class _MapPickerDialogState extends State<_MapPickerDialog> {
  late double _selectedLat;
  late double _selectedLon;
  final TextEditingController _latController = TextEditingController();
  final TextEditingController _lonController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _selectedLat = widget.ghost.latitude;
    _selectedLon = widget.ghost.longitude;
    _latController.text = _selectedLat.toStringAsFixed(6);
    _lonController.text = _selectedLon.toStringAsFixed(6);
    _nameController.text = 'Custom Location';
  }

  @override
  void dispose() {
    _latController.dispose();
    _lonController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppTheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: AppTheme.border),
      ),
      child: Container(
        width: 600,
        height: 500,
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.map_outlined, color: AppTheme.accent, size: 24),
                const SizedBox(width: 12),
                Text(
                  'Pick Location on Map',
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(Icons.close, color: AppTheme.textSecondary),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: GestureDetector(
                onTapDown: (details) {
                  final box = context.findRenderObject() as RenderBox;
                  final localPos = box.globalToLocal(details.globalPosition);
                  final mapWidth = box.size.width;
                  final mapHeight = box.size.height - 200;

                  setState(() {
                    _selectedLon = ((localPos.dx / mapWidth) * 360) - 180;
                    _selectedLat = 90 - ((localPos.dy / mapHeight) * 180);
                    _latController.text = _selectedLat.toStringAsFixed(6);
                    _lonController.text = _selectedLon.toStringAsFixed(6);
                  });
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceAlt,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: Stack(
                    children: [
                      Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.public,
                              size: 64,
                              color: AppTheme.textSecondary.withValues(alpha: 0.3),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Click anywhere to set location',
                              style: TextStyle(
                                color: AppTheme.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Positioned(
                        left: ((_selectedLon + 180) / 360) * MediaQuery.of(context).size.width,
                        top: ((90 - _selectedLat) / 180) * 300,
                        child: Icon(
                          Icons.location_on,
                          color: AppTheme.accent,
                          size: 32,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _latController,
                    style: TextStyle(color: AppTheme.textPrimary, fontSize: 12),
                    decoration: InputDecoration(
                      labelText: 'Latitude',
                      labelStyle: TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                        borderSide: BorderSide(color: AppTheme.border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                        borderSide: BorderSide(color: AppTheme.accent),
                      ),
                      isDense: true,
                    ),
                    onChanged: (v) {
                      final val = double.tryParse(v);
                      if (val != null) setState(() => _selectedLat = val);
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _lonController,
                    style: TextStyle(color: AppTheme.textPrimary, fontSize: 12),
                    decoration: InputDecoration(
                      labelText: 'Longitude',
                      labelStyle: TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                        borderSide: BorderSide(color: AppTheme.border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                        borderSide: BorderSide(color: AppTheme.accent),
                      ),
                      isDense: true,
                    ),
                    onChanged: (v) {
                      final val = double.tryParse(v);
                      if (val != null) setState(() => _selectedLon = val);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _nameController,
              style: TextStyle(color: AppTheme.textPrimary, fontSize: 12),
              decoration: InputDecoration(
                labelText: 'Location Name',
                labelStyle: TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: BorderSide(color: AppTheme.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: BorderSide(color: AppTheme.accent),
                ),
                isDense: true,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      'Cancel',
                      style: TextStyle(color: AppTheme.textSecondary),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      widget.ghost.setCustomLocation(
                        _selectedLat,
                        _selectedLon,
                        _nameController.text,
                        'UTC',
                      );
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.accent,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    child: const Text('Set Location'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}


