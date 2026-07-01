import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  final _pinController = TextEditingController();
  final _auth = AuthService();
  final _fs = FirestoreService();
  bool _loading = false;
  String? _error;

  bool get _canSubmit =>
      !_loading && _nameController.text.trim().isNotEmpty && _fs.isValidPin(_pinController.text.trim());

  @override
  void dispose() {
    _nameController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  Future<void> _continue() async {
    final name = _nameController.text.trim();
    final pin = _pinController.text.trim();
    if (name.isEmpty || !_fs.isValidPin(pin)) return;

    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await _auth.signInAnonymously(name);
      await _fs.claimProfile(name, pin);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(AppTransitions.fadeThrough(const HomeScreen()));
      return;
    } on WrongPinException {
      setState(() => _error = 'Incorrect PIN for "$name". If this is your first time, try a different name.');
    } on ArgumentError catch (e) {
      setState(() => _error = e.message?.toString() ?? 'Invalid PIN.');
    } catch (e) {
      setState(() => _error = '$e');
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
                  'Enter your DC name\nand PIN to get started.',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w700, height: 1.2),
                ).animate().fadeIn(delay: 100.ms, duration: 350.ms).slideY(begin: 0.2, end: 0, delay: 100.ms),
                const SizedBox(height: 10),
                Text(
                  'New name? Pick any 4-6 digit PIN — it becomes this profile\'s '
                      'password. Returning? Enter the same name and PIN you used '
                      'last time to pick up right where you left off.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
                ).animate().fadeIn(delay: 180.ms, duration: 350.ms).slideY(begin: 0.2, end: 0, delay: 180.ms),
                const SizedBox(height: 36),
                TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: 'DC Name', prefixIcon: Icon(Icons.person_outline)),
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                  onChanged: (_) => setState(() => _error = null),
                ).animate().fadeIn(delay: 260.ms, duration: 350.ms).slideY(begin: 0.2, end: 0, delay: 260.ms),
                const SizedBox(height: 16),
                TextField(
                  controller: _pinController,
                  decoration: const InputDecoration(
                    labelText: 'PIN (4-6 digits)',
                    prefixIcon: Icon(Icons.lock_outline),
                  ),
                  keyboardType: TextInputType.number,
                  obscureText: true,
                  maxLength: 6,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  onChanged: (_) => setState(() => _error = null),
                  onSubmitted: (_) => _continue(),
                ).animate().fadeIn(delay: 300.ms, duration: 350.ms).slideY(begin: 0.2, end: 0, delay: 300.ms),
                if (_error != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    _error!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.error),
                  ).animate().fadeIn(duration: 200.ms),
                ],
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton(
                    onPressed: _canSubmit ? _continue : null,
                    child: _loading
                        ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [Text('Continue'), SizedBox(width: 8), Icon(Icons.arrow_forward_rounded, size: 18)],
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