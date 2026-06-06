import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/platform/system_bridge.dart';
import '../../theme/app_theme.dart';

class ScreenshotScreen extends StatefulWidget {
  const ScreenshotScreen({super.key});
  @override
  State<ScreenshotScreen> createState() => _ScreenshotScreenState();
}

class _ScreenshotScreenState extends State<ScreenshotScreen> {
  int _delay = 0;         // seconds before capture
  bool _wholeScreen = true;
  bool _capturing = false;
  bool _success = false;
  String _lastPath = '';
  String _savePath = '/home/admin/Pictures';
  String _format = 'PNG';
  int _countdown = 0;
  Timer? _countdownTimer;

  Future<void> _capture() async {
    if (_capturing) return;
    setState(() { _capturing = true; _success = false; _countdown = _delay; });

    if (_delay > 0) {
      _countdownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
        setState(() => _countdown--);
        if (_countdown <= 0) t.cancel();
      });
      await Future.delayed(Duration(seconds: _delay));
    }

    final ts = DateTime.now().millisecondsSinceEpoch;
    final path = '$_savePath/screenshot_$ts.${_format.toLowerCase()}';
    final result = await SystemBridge.screenshot(outputPath: path);

    setState(() {
      _capturing = false;
      _success = result.isNotEmpty;
      _lastPath = result.isNotEmpty ? result : path;
      _countdown = 0;
    });

    if (_success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Saved: $_lastPath'),
        backgroundColor: AppTheme.success,
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppTheme.background,
      child: Column(children: [
  // Preview area
        Expanded(
          child: Center(
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              if (_capturing && _countdown > 0) ...[
                Text('$_countdown', style: TextStyle(
                  color: AppTheme.accent, fontSize: 96, fontWeight: FontWeight.w100,
                )),
                Text('seconds', style: TextStyle(color: AppTheme.textSecondary, fontSize: 18)),
              ] else if (_capturing) ...[
                CircularProgressIndicator(color: AppTheme.accent),
                const SizedBox(height: 16),
                Text('Capturing...', style: TextStyle(color: AppTheme.textSecondary)),
              ] else if (_success) ...[
                Container(
                  width: 200, height: 140,
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.accent.withValues(alpha: 0.5)),
                  ),
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(Icons.check_circle, color: AppTheme.success, size: 48),
                    const SizedBox(height: 8),
                    Text('Saved!', style: TextStyle(color: AppTheme.success, fontSize: 18)),
                    const SizedBox(height: 4),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text(_lastPath, style: TextStyle(
                        color: AppTheme.textSecondary, fontSize: 11,
                      ), textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis),
                    ),
                  ]),
                ),
              ] else ...[
                Container(
                  width: 200, height: 140,
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(Icons.screenshot_monitor, color: AppTheme.textSecondary, size: 48),
                    const SizedBox(height: 8),
                    Text('Screenshot preview', style: TextStyle(
                      color: AppTheme.textSecondary, fontSize: 13,
                    )),
                  ]),
                ),
              ],
            ]),
          ),
        ),
  // Controls
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            border: Border(top: BorderSide(color: AppTheme.border)),
          ),
          child: Column(children: [
  // Mode
            Row(children: [
              _modeBtn('Full Screen', Icons.monitor, _wholeScreen, () => setState(() => _wholeScreen = true)),
              const SizedBox(width: 10),
              _modeBtn('Window', Icons.web_asset, !_wholeScreen, () => setState(() => _wholeScreen = false)),
            ]),
            const SizedBox(height: 16),
  // Delay
            Row(children: [
              Text('Delay:', style: TextStyle(color: AppTheme.textSecondary, fontSize: 14)),
              const SizedBox(width: 12),
              ...([0, 3, 5, 10]).map((d) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GestureDetector(
                  onTap: () => setState(() => _delay = d),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: _delay == d ? AppTheme.accentDim : AppTheme.surfaceAlt,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: _delay == d ? AppTheme.accent.withValues(alpha: 0.6) : AppTheme.border),
                    ),
                    child: Text(d == 0 ? 'Now' : '${d}s',
                      style: TextStyle(
                        color: _delay == d ? AppTheme.accent : AppTheme.textSecondary,
                        fontSize: 13,
                      )),
                  ),
                ),
              )),
              const Spacer(),
  // Format
              Text('Format:', style: TextStyle(color: AppTheme.textSecondary, fontSize: 14)),
              const SizedBox(width: 8),
              ...(['PNG', 'JPG']).map((f) => Padding(
                padding: const EdgeInsets.only(left: 8),
                child: GestureDetector(
                  onTap: () => setState(() => _format = f),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: _format == f ? AppTheme.accentDim : AppTheme.surfaceAlt,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: _format == f ? AppTheme.accent.withValues(alpha: 0.6) : AppTheme.border),
                    ),
                    child: Text(f, style: TextStyle(
                      color: _format == f ? AppTheme.accent : AppTheme.textSecondary,
                      fontSize: 13,
                    )),
                  ),
                ),
              )),
            ]),
            const SizedBox(height: 16),
  // Save path
            Row(children: [
              Icon(Icons.folder_open, color: AppTheme.textSecondary, size: 16),
              const SizedBox(width: 8),
              Text(_savePath, style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
            ]),
            const SizedBox(height: 16),
  // Capture button
            GestureDetector(
              onTap: _capturing ? null : _capture,
              child: Container(
                width: double.infinity, height: 48,
                decoration: BoxDecoration(
                  color: _capturing ? AppTheme.surfaceAlt : AppTheme.accent,
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: _capturing
                    ? Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        SizedBox(width: 18, height: 18, child: CircularProgressIndicator(
                          strokeWidth: 2, color: AppTheme.textPrimary)),
                        const SizedBox(width: 10),
                        Text('Capturing...', style: TextStyle(color: AppTheme.textPrimary)),
                      ])
                    : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        const Icon(Icons.camera_alt, color: Colors.white, size: 20),
                        const SizedBox(width: 8),
                        const Text('Take Screenshot',
                          style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
                      ]),
              ),
            ),
          ]),
        ),
      ]),
    );
  }

  Widget _modeBtn(String label, IconData icon, bool selected, VoidCallback onTap) => Expanded(
    child: GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: selected ? AppTheme.accentDim : AppTheme.surfaceAlt,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? AppTheme.accent.withValues(alpha: 0.6) : AppTheme.border),
        ),
        child: Column(children: [
          Icon(icon, color: selected ? AppTheme.accent : AppTheme.textSecondary, size: 24),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(
            color: selected ? AppTheme.accent : AppTheme.textSecondary, fontSize: 12)),
        ]),
      ),
    ),
  );
}