import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../models/team.dart';
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
  final _codeController = TextEditingController();
  final _auth = AuthService();
  final _fs = FirestoreService();

  TeamRole _role = TeamRole.member;
  String? _teamId;
  bool _loading = false;
  String? _error;

  // Name + PIN are all a RETURNING user needs, so the button unlocks on
  // those two. Team + code are only required to CREATE a new profile — if
  // they're missing on a first-time claim, claimProfile throws a friendly
  // MissingTeamException that we surface inline, rather than blocking the
  // button for people who are just signing back in.
  bool get _canSubmit =>
      !_loading && _nameController.text.trim().isNotEmpty && _fs.isValidPin(_pinController.text.trim());

  @override
  void dispose() {
    _nameController.dispose();
    _pinController.dispose();
    _codeController.dispose();
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
      await _fs.claimProfile(
        name,
        pin,
        teamId: _teamId,
        role: _role,
        teamCode: _codeController.text.trim(),
      );
      if (!mounted) return;
      Navigator.of(context).pushReplacement(AppTransitions.fadeThrough(const HomeScreen()));
      return;
    } on WrongPinException {
      setState(() => _error = 'Incorrect PIN for "$name". If this is your first time, try a different name.');
    } on WrongTeamCodeException catch (e) {
      setState(() => _error = '$e Double-check the code your team leader gave you.');
    } on MissingTeamException {
      setState(() => _error = 'First time here? Pick your team and enter your team code below.');
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
    final isLeader = _role == TeamRole.leader;

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
                  'New here? Pick your team + role and enter the code your team '
                      'leader gave you. Returning? Just your name and PIN pick up '
                      'right where you left off.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
                ).animate().fadeIn(delay: 180.ms, duration: 350.ms).slideY(begin: 0.2, end: 0, delay: 180.ms),
                const SizedBox(height: 28),

                // ---- Name ----
                TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: 'DC Name', prefixIcon: Icon(Icons.person_outline)),
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                  onChanged: (_) => setState(() => _error = null),
                ).animate().fadeIn(delay: 240.ms, duration: 350.ms).slideY(begin: 0.2, end: 0, delay: 240.ms),
                const SizedBox(height: 16),

                // ---- PIN ----
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
                ).animate().fadeIn(delay: 280.ms, duration: 350.ms).slideY(begin: 0.2, end: 0, delay: 280.ms),

                const SizedBox(height: 8),
                Divider(color: scheme.outlineVariant.withOpacity(0.5)),
                const SizedBox(height: 8),
                Text(
                  'FIRST TIME HERE?',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 12),

                // ---- Role ----
                DropdownButtonFormField<TeamRole>(
                  value: _role,
                  decoration: const InputDecoration(
                    labelText: 'I am a',
                    prefixIcon: Icon(Icons.badge_outlined),
                  ),
                  items: const [
                    DropdownMenuItem(value: TeamRole.member, child: Text('Team member')),
                    DropdownMenuItem(value: TeamRole.leader, child: Text('Team leader')),
                  ],
                  onChanged: (v) => setState(() {
                    _role = v ?? TeamRole.member;
                    _error = null;
                  }),
                ).animate().fadeIn(delay: 320.ms, duration: 350.ms).slideY(begin: 0.2, end: 0, delay: 320.ms),
                const SizedBox(height: 16),

                // ---- Team ----
                DropdownButtonFormField<String>(
                  value: _teamId,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Team',
                    prefixIcon: Icon(Icons.groups_outlined),
                  ),
                  hint: const Text('Select your team'),
                  items: [
                    for (final t in kTeams) DropdownMenuItem(value: t.id, child: Text(t.label)),
                  ],
                  onChanged: (v) => setState(() {
                    _teamId = v;
                    _error = null;
                  }),
                ).animate().fadeIn(delay: 350.ms, duration: 350.ms).slideY(begin: 0.2, end: 0, delay: 350.ms),
                const SizedBox(height: 16),

                // ---- Code (label switches with role) ----
                TextField(
                  controller: _codeController,
                  decoration: InputDecoration(
                    labelText: isLeader ? 'Team leader code' : 'Team member code',
                    prefixIcon: Icon(isLeader ? Icons.vpn_key_outlined : Icons.tag_rounded),
                    helperText: isLeader
                        ? 'The leader code for the team you lead.'
                        : 'The code your team leader shared with the team.',
                  ),
                  obscureText: true,
                  onChanged: (_) => setState(() => _error = null),
                  onSubmitted: (_) => _continue(),
                ).animate().fadeIn(delay: 380.ms, duration: 350.ms).slideY(begin: 0.2, end: 0, delay: 380.ms),

                if (_error != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    _error!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.error),
                  ).animate().fadeIn(duration: 200.ms),
                ],
                const SizedBox(height: 24),
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
                ).animate().fadeIn(delay: 420.ms, duration: 350.ms).slideY(begin: 0.2, end: 0, delay: 420.ms),
              ],
            ),
          ),
        ),
      ),
    );
  }
}