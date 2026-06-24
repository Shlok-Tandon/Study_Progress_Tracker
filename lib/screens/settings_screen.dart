import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../theme/app_theme.dart';
import '../theme/theme_provider.dart';
import '../widgets/segmented_control.dart';
import 'dc_name_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _fs = FirestoreService();
  final _auth = AuthService();
  late final Stream<DocumentSnapshot> _profileStream = _fs.streamMyProfile(); // cached

  String _studyRank(int streak) {
    if (streak >= 30) return 'Legend';
    if (streak >= 14) return 'Champion';
    if (streak >= 7) return 'Rising Star';
    if (streak >= 1) return 'Getting Started';
    return 'Newcomer';
  }

  Future<void> _confirmLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Switch DC name?'),
        content: const Text(
          'Logging out starts a fresh anonymous session. Your streak and tasks '
              'are tied to your DC name — sign back in with the same name later to '
              'pick up right where you left off.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Logout')),
        ],
      ),
    );
    if (confirmed != true) return;
    await _auth.logout();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const DcNameScreen()), (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    final tp = context.watch<ThemeProvider>();
    final scheme = Theme.of(context).colorScheme;
    final name = FirebaseAuth.instance.currentUser?.displayName ?? 'DC';
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          StreamBuilder<DocumentSnapshot>(
            stream: _profileStream,
            builder: (context, snap) {
              final data = snap.data?.data() as Map<String, dynamic>?;
              final streak = (data?['streak'] as num?)?.toInt() ?? 0;
              final freezes = (data?['freezeCount'] as num?)?.toInt() ?? 0;
              final kudos = (data?['kudosReceived'] as num?)?.toInt() ?? 0;
              final rank = _studyRank(streak);

              return Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [scheme.primary, scheme.primary.withOpacity(0.75)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white.withOpacity(0.6), width: 2.5)),
                      child: CircleAvatar(backgroundColor: Colors.white, child: Text(initial, style: AppTheme.display(size: 24, color: scheme.primary))),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(name, style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.white, fontWeight: FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                            decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(12)),
                            child: Text('🏅 $rank', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 12)),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 12,
                            runSpacing: 4,
                            children: [
                              Text('🛡️ $freezes freezes', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                              Text('👏 $kudos kudos', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text('APPEARANCE', style: Theme.of(context).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.bold, letterSpacing: 0.6, color: scheme.onSurfaceVariant)),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: scheme.surfaceContainerHigh, borderRadius: BorderRadius.circular(20)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Theme mode', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 12),
                SegmentedControl<ThemeMode>(
                  values: const [ThemeMode.system, ThemeMode.light, ThemeMode.dark],
                  labels: const ['System', 'Light', 'Dark'],
                  selected: tp.themeMode,
                  onChanged: tp.setThemeMode,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text('ACCOUNT', style: Theme.of(context).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.bold, letterSpacing: 0.6, color: scheme.onSurfaceVariant)),
          ),
          Container(
            decoration: BoxDecoration(color: scheme.errorContainer.withOpacity(0.35), borderRadius: BorderRadius.circular(20)),
            child: ListTile(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              leading: Icon(Icons.logout_rounded, color: scheme.error),
              title: Text('Logout', style: TextStyle(color: scheme.error, fontWeight: FontWeight.w600)),
              onTap: _confirmLogout,
            ),
          ),
        ],
      ),
    );
  }
}