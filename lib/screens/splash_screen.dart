import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../theme/app_transitions.dart';
import 'dc_name_screen.dart';
import 'home_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  bool _exiting = false;

  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<void> _run() async {
    await Future.delayed(const Duration(milliseconds: 2500));
    if (!mounted) return;
    setState(() => _exiting = true);
    await Future.delayed(const Duration(milliseconds: 200));
    if (!mounted) return;

    final user = FirebaseAuth.instance.currentUser;
    final hasProfile = (user?.displayName ?? '').trim().isNotEmpty;
    Navigator.of(context).pushReplacement(
      AppTransitions.fadeThrough(hasProfile ? const HomeScreen() : const DcNameScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: Colors.transparent, // let the app gradient show
      body: Center(
        child: AnimatedOpacity(
          opacity: _exiting ? 0 : 1,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          child: AnimatedScale(
            scale: _exiting ? 0.92 : 1,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                    color: scheme.primary,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [BoxShadow(color: scheme.primary.withOpacity(0.35), blurRadius: 28, offset: const Offset(0, 12))],
                  ),
                  child: Icon(Icons.auto_graph_rounded, color: scheme.onPrimary, size: 42),
                )
                    .animate()
                    .scale(begin: const Offset(0.6, 0.6), end: const Offset(1, 1), duration: 480.ms, curve: Curves.easeOutBack)
                    .fadeIn(duration: 350.ms),
                const SizedBox(height: 28),
                Text(
                  "Welcome to Folk's",
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(color: scheme.onSurfaceVariant),
                ).animate().fadeIn(delay: 250.ms, duration: 2.seconds).slideY(begin: 0.3, end: 0, delay: 220.ms, duration: 500.ms),
                const SizedBox(height: 4),
                Text(
                  'Study Progress Tracker',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700, color: scheme.onSurface),
                ).animate().fadeIn(delay: 350.ms, duration: 2.seconds).slideY(begin: 0.3, end: 0, delay: 340.ms, duration: 500.ms),
              ],
            ),
          ),
        ),
      ),
    );
  }
}