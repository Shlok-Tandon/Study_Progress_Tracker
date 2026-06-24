import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../theme/app_transitions.dart';
import 'home_screen.dart';

class DcNameScreen extends StatefulWidget {
  const DcNameScreen({super.key});

  @override
  State<DcNameScreen> createState() => _DcNameScreenState();
}

class _DcNameScreenState extends State<DcNameScreen> {
  final _nameController = TextEditingController();
  final _auth = AuthService();
  final _fs = FirestoreService();
  bool _loading = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _continue() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    setState(() => _loading = true);
    try {
      await _auth.signInAnonymously(name);
      await _fs.claimProfile(name);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(AppTransitions.fadeThrough(const HomeScreen()));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(28, 40, 28, 28),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: MediaQuery.of(context).size.height * 0.75),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(color: scheme.primaryContainer, borderRadius: BorderRadius.circular(18)),
                  child: Icon(Icons.self_improvement, size: 32, color: scheme.onPrimaryContainer),
                ).animate().fadeIn(duration: 350.ms).slideY(begin: 0.2, end: 0),
                const SizedBox(height: 28),
                Text(
                  'Enter your DC name\nto get started.',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w700, height: 1.2),
                ).animate().fadeIn(delay: 100.ms, duration: 350.ms).slideY(begin: 0.2, end: 0, delay: 100.ms),
                const SizedBox(height: 10),
                Text(
                  'Your name keeps your tasks and streak linked across sessions — '
                      'use the same one each time you sign in.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
                ).animate().fadeIn(delay: 180.ms, duration: 350.ms).slideY(begin: 0.2, end: 0, delay: 180.ms),
                const SizedBox(height: 36),
                TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: 'DC Name', prefixIcon: Icon(Icons.person_outline)),
                  textCapitalization: TextCapitalization.words,
                  onChanged: (_) => setState(() {}),
                  onSubmitted: (_) => _continue(),
                ).animate().fadeIn(delay: 260.ms, duration: 350.ms).slideY(begin: 0.2, end: 0, delay: 260.ms),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton(
                    onPressed: (_loading || _nameController.text.trim().isEmpty) ? null : _continue,
                    child: _loading
                        ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                        : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [Text('Continue'), SizedBox(width: 8), Icon(Icons.arrow_forward_rounded, size: 18)],
                    ),
                  ),
                ).animate().fadeIn(delay: 340.ms, duration: 350.ms).slideY(begin: 0.2, end: 0, delay: 340.ms),
              ],
            ),
          ),
        ),
      ),
    );
  }
}