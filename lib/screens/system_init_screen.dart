import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/auth/auth_manager.dart';
import '../theme/app_theme.dart';
import 'advanced_welcome_setup.dart';
import 'advanced_lock_screen.dart';

class SystemInitScreen extends StatefulWidget {
  const SystemInitScreen({super.key});

  @override
  State<SystemInitScreen> createState() => _SystemInitScreenState();
}

class _SystemInitScreenState extends State<SystemInitScreen> {
  int _progress = 0;
  String _currentTask = 'Initializing system...';
  bool _isComplete = false;

  final List<Map<String, dynamic>> _tasks = [
    {'label': 'Loading kernel modules', 'duration': 800},
    {'label': 'Initializing hardware drivers', 'duration': 600},
    {'label': 'Starting system services', 'duration': 700},
    {'label': 'Mounting file systems', 'duration': 500},
    {'label': 'Loading network stack', 'duration': 600},
    {'label': 'Initializing security modules', 'duration': 700},
    {'label': 'Starting display server', 'duration': 500},
    {'label': 'Loading user interface', 'duration': 600},
  ];

  @override
  void initState() {
    super.initState();
    _startInitialization();
  }

  Future<void> _startInitialization() async {
  // Wait for AuthManager to initialize
    final authManager = context.read<AuthManager>();
    while (!authManager.initialized) {
      await Future.delayed(const Duration(milliseconds: 100));
    }
    
    for (int i = 0; i < _tasks.length; i++) {
      await Future.delayed(Duration(milliseconds: _tasks[i]['duration']));
      if (!mounted) return;
      setState(() {
        _currentTask = _tasks[i]['label'];
        _progress = ((i + 1) / _tasks.length * 100).round();
      });
    }

    await Future.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;
    
    setState(() => _isComplete = true);
    
    await Future.delayed(const Duration(milliseconds: 800));
    if (!mounted) return;

    final hasAccounts = authManager.accounts.isNotEmpty;

    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => hasAccounts ? const AdvancedLockScreen() : const AdvancedWelcomeSetup(),
        transitionsBuilder: (_, anim, __, child) => FadeTransition(opacity: anim, child: child),
        transitionDuration: const Duration(milliseconds: 800),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withValues(alpha: 0.1), width: 1),
              ),
              child: Center(
                child: Icon(
                  Icons.computer,
                  size: 40,
                  color: Colors.white.withValues(alpha: 0.8),
                ),
              ),
            ),
            const SizedBox(height: 40),
            Text(
              'KrdOS',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.9),
                fontSize: 28,
                fontWeight: FontWeight.w300,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 60),
            SizedBox(
              width: 300,
              child: Column(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: _progress / 100,
                      backgroundColor: Colors.white.withValues(alpha: 0.1),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Colors.white.withValues(alpha: 0.8),
                      ),
                      minHeight: 3,
                    ),
                  ),
                  const SizedBox(height: 16),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: Text(
                      _isComplete ? 'Ready' : _currentTask,
                      key: ValueKey(_currentTask),
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.5),
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}