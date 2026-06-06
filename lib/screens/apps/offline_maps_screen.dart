import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import '../../core/map/offline_map_manager.dart';
import '../../theme/app_theme.dart';

class OfflineMapsScreen extends StatefulWidget {
  const OfflineMapsScreen({super.key});

  @override
  State<OfflineMapsScreen> createState() => _OfflineMapsScreenState();
}

class _OfflineMapsScreenState extends State<OfflineMapsScreen> {
  late OfflineMapManager _mapManager;
  bool _isInitialized = false;
  String _cacheSize = '0 MB';
  bool _isDownloading = false;
  double _progress = 0.0;
  int _downloaded = 0;
  int _total = 0;

  @override
  void initState() {
    super.initState();
    _initializeManager();
  }

  Future<void> _initializeManager() async {
    final appDir = await getApplicationDocumentsDirectory();
    _mapManager = OfflineMapManager('${appDir.path}/map_tiles');
    final size = await _mapManager.getCacheSize();
    setState(() {
      _cacheSize = size;
      _isInitialized = true;
    });
  }

  Future<void> _startDownload() async {
    setState(() => _isDownloading = true);
    
    await _mapManager.downloadWorldTiles(
      onProgress: (progress, downloaded, total) {
        setState(() {
          _progress = progress;
          _downloaded = downloaded;
          _total = total;
        });
      },
    );
    
    final size = await _mapManager.getCacheSize();
    setState(() {
      _isDownloading = false;
      _cacheSize = size;
    });
  }

  Future<void> _clearCache() async {
    await _mapManager.clearCache();
    final size = await _mapManager.getCacheSize();
    setState(() => _cacheSize = size);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: _isInitialized
                ? _buildContent()
                : Center(
                    child: CircularProgressIndicator(color: AppTheme.accent),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
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
              color: AppTheme.accent.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.accent),
            ),
            child: Icon(
              Icons.map_outlined,
              color: AppTheme.accent,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Offline Maps',
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Download maps for offline use',
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInfoCard(),
          const SizedBox(height: 20),
          _buildDownloadCard(),
          const SizedBox(height: 20),
          _buildCacheCard(),
        ],
      ),
    );
  }

  Widget _buildInfoCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, color: AppTheme.accent, size: 20),
              const SizedBox(width: 8),
              Text(
                'About Offline Maps',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildInfoRow('Coverage', 'Full Earth (Zoom 0-8)'),
          const SizedBox(height: 8),
          _buildInfoRow('Size', '~500 MB'),
          const SizedBox(height: 8),
          _buildInfoRow('Includes', 'Cities, major roads, borders'),
          const SizedBox(height: 8),
          _buildInfoRow('Style', 'Dark mode optimized'),
        ],
      ),
    );
  }

  Widget _buildDownloadCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.download_outlined, color: AppTheme.accent, size: 20),
              const SizedBox(width: 8),
              Text(
                'Download Maps',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_isDownloading) ...[
            LinearProgressIndicator(
              value: _progress,
              backgroundColor: AppTheme.border,
              color: AppTheme.accent,
            ),
            const SizedBox(height: 12),
            Text(
              'Downloading: $_downloaded / $_total tiles (${(_progress * 100).toStringAsFixed(1)}%)',
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 12,
              ),
            ),
          ] else ...[
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _startDownload,
                icon: const Icon(Icons.download),
                label: const Text('Download Full Earth Maps'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accent,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCacheCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.storage_outlined, color: AppTheme.accent, size: 20),
              const SizedBox(width: 8),
              Text(
                'Storage',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildInfoRow('Cache Size', _cacheSize),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _clearCache,
              icon: const Icon(Icons.delete_outline),
              label: const Text('Clear Cache'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.danger,
                side: BorderSide(color: AppTheme.danger),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      children: [
        Text(
          label,
          style: TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 12,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: TextStyle(
            color: AppTheme.accent,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
