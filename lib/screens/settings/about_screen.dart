import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(28, 24, 28, 40),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                gradient: const LinearGradient(
                  colors: [Color(0xFF00FFD1), Color(0xFF0078FF)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.accent.withValues(alpha: 0.35),
                    blurRadius: 28,
                    offset: const Offset(0, 14),
                  ),
                ],
              ),
              child: const Icon(Icons.layers_rounded, color: Colors.black, size: 36),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'KrdOS',
                    style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.4,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Nebula build 1.0.0 (26A512)',
                    style: TextStyle(
                      color: AppTheme.textSecondary.withValues(alpha: 0.95),
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _pill('Edition', 'Developer Preview'),
                      _pill('Channel', 'Stable'),
                      _pill('Kernel', '6.8-custom'),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppTheme.surfaceAlt,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.info_outline_rounded, color: AppTheme.accent, size: 22),
                  const SizedBox(width: 10),
                  Text(
                    'Simulation & device truth',
                    style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                'This build is a Flutter desktop shell. The virtual file system can persist to disk; most '
                'network, radio, VPN, firewall, Wi\u2011Fi, Bluetooth, IP masking, and hardware metrics below are '
                'simulated for UI demonstration only\u2014they do not control your real machine.',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 12, height: 1.45),
              ),
              const SizedBox(height: 12),
              _simChip('Wi\u2011Fi / Bluetooth lists'),
              _simChip('VPN / firewall / IP mask toggles'),
              _simChip('Processor / RAM / GPU / storage cards'),
              _simChip('Volume and memory pressure meters'),
            ],
          ),
        ),
        const SizedBox(height: 28),
        Text(
          'This device',
          style: TextStyle(color: AppTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 10),
        LayoutBuilder(
          builder: (context, c) {
            final w = c.maxWidth;
            final cols = w > 820 ? 2 : 1;
            return GridView.count(
              crossAxisCount: cols,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 14,
              mainAxisSpacing: 14,
              childAspectRatio: cols == 2 ? 1.55 : 1.35,
              children: [
                _hardwareCard(
                  title: 'Processor',
                  value: 'QuantumCore Ultra 9',
                  detail: '16 cores (8P + 8E) - 5.2 GHz boost (demo)',
                  icon: Icons.memory_rounded,
                ),
                _hardwareCard(
                  title: 'Memory',
                  value: '32 GB LPDDR5X',
                  detail: '6400 MT/s - Hardware ECC (demo)',
                  icon: Icons.sd_storage_rounded,
                ),
                _hardwareCard(
                  title: 'Graphics',
                  value: 'Aurora GPU 16-core',
                  detail: 'Ray tracing - AV1 encode/decode (demo)',
                  icon: Icons.developer_board_rounded,
                ),
                _hardwareCard(
                  title: 'Storage',
                  value: '2 TB NVMe Gen4',
                  detail: 'Encrypted volume - 78% used (demo)',
                  icon: Icons.storage_rounded,
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 22),
        _meterCard(
          label: 'System volume (simulated)',
          used: 0.78,
          caption: '1.56 TB used - 440 GB free',
        ),
        const SizedBox(height: 14),
        _meterCard(
          label: 'Memory pressure (simulated)',
          used: 0.42,
          caption: '13.4 GB active - compression on',
          color: AppTheme.accent,
        ),
        const SizedBox(height: 26),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Legal & notices',
                style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600),
              ),
              SizedBox(height: 8),
              Text(
                'KrdOS includes open-source components. Licenses ship with the system image. '
                'No warranty: this is a UI simulation for demonstration.',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 12, height: 1.4),
              ),
            ],
          ),
        ),
      ],
    );
  }

  static Widget _simChip(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.sim_card_outlined, size: 14, color: AppTheme.warning.withValues(alpha: 0.9)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 11, height: 1.35),
            ),
          ),
        ],
      ),
    );
  }

  static Widget _pill(String k, String v) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.surfaceAlt,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.border),
      ),
      child: Text(
        '$k · $v',
        style: TextStyle(color: AppTheme.textSecondary, fontSize: 11, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _hardwareCard({
    required String title,
    required String value,
    required String detail,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.surface,
            AppTheme.surfaceAlt.withValues(alpha: 0.85),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppTheme.accent, size: 24),
          const Spacer(),
          Text(title, style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(color: AppTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(detail, style: TextStyle(color: AppTheme.textSecondary, fontSize: 11, height: 1.3)),
        ],
      ),
    );
  }

  Widget _meterCard({
    required String label,
    required double used,
    required String caption,
    Color? color,
  }) {
    final c = color ?? AppTheme.warning;
    final safe = used.clamp(0.0, 1.0);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(label, style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600)),
              const Spacer(),
              Text('${(safe * 100).round()}%', style: TextStyle(color: c, fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: safe,
              minHeight: 10,
              backgroundColor: AppTheme.surfaceAlt,
              color: c,
            ),
          ),
          const SizedBox(height: 8),
          Text(caption, style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
        ],
      ),
    );
  }
}
