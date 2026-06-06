import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../core/first_boot/first_boot_service.dart';
import '../theme/app_theme.dart';
import 'home_screen.dart';

class FirstBootScreen extends StatefulWidget {
  const FirstBootScreen({super.key});
  @override
  State<FirstBootScreen> createState() => _FirstBootScreenState();
}

class _FirstBootScreenState extends State<FirstBootScreen> {
  final List<String> _steps = [];
  String _current = 'Initialising?';
  bool _done = false;
  bool _error = false;
  double _progress = 0;

  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<void> _run() async {
    try {
      await FirstBootService.runSetup(
        onStep: (step) {
          if (!mounted) return;
          setState(() {
            _current = step;
            _steps.add(step);
            _progress = _steps.length / 6.0;
          });
        },
      );
      await Future.delayed(const Duration(milliseconds: 500));
      if (!mounted) return;
      setState(() { _done = true; _progress = 1.0; });
      await Future.delayed(const Duration(seconds: 2));
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = true; _current = 'Setup error: $e'; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
  // Logo
              Container(
                width: 80, height: 80,
                decoration: BoxDecoration(
                  color: AppTheme.accentDim,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppTheme.accent.withValues(alpha: 0.4)),
                ),
                child: Icon(Icons.terminal_rounded, color: AppTheme.accent, size: 40),
              ).animate().scale(duration: 600.ms, curve: Curves.easeOutBack),
              const SizedBox(height: 32),
              Text(
                _done ? 'Welcome to KrdOS' : 'Setting Up Your System',
                style: TextStyle(
                  color: AppTheme.textPrimary, fontSize: 28, fontWeight: FontWeight.w300,
                ),
                textAlign: TextAlign.center,
              ).animate().fadeIn(delay: 300.ms),
              const SizedBox(height: 8),
              Text(
                _done
                    ? 'Your system is ready. Starting now?'
                    : 'This only happens once.',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 15),
              ).animate().fadeIn(delay: 500.ms),
              const SizedBox(height: 48),
  // Progress bar
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: _progress,
                  backgroundColor: AppTheme.surfaceAlt,
                  valueColor: AlwaysStoppedAnimation(
                    _error ? AppTheme.danger : (_done ? AppTheme.success : AppTheme.accent),
                  ),
                  minHeight: 4,
                ),
              ).animate().fadeIn(delay: 400.ms),
              const SizedBox(height: 20),
  // Current step
              Text(_current, style: TextStyle(
                color: _error ? AppTheme.danger : AppTheme.textSecondary, fontSize: 13,
              ), textAlign: TextAlign.center),
              const SizedBox(height: 32),
  // Completed steps
              ..._steps.map((s) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.check, color: AppTheme.success, size: 14),
                  const SizedBox(width: 8),
                  Text(s, style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                ]),
              )),
              if (_error) ...[
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pushReplacement(
                    MaterialPageRoute(builder: (_) => const HomeScreen()),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.accent,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Continue Anyway'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}