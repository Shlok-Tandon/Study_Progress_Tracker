import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../theme/theme_provider.dart';
import 'dc_name_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  Future<void> _confirmLogout(BuildContext context, AuthService auth) async {
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
    await auth.logout();
    if (!context.mounted) return;
    Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const DcNameScreen()), (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    final tp = context.watch<ThemeProvider>();
    final auth = AuthService();
    final scheme = Theme.of(context).colorScheme;
    final name = FirebaseAuth.instance.currentUser?.displayName ?? 'DC';
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: scheme.primaryContainer, borderRadius: BorderRadius.circular(20)),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: scheme.primary,
                  child: Text(initial, style: TextStyle(color: scheme.onPrimary, fontSize: 22, fontWeight: FontWeight.w700)),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: Theme.of(context).textTheme.titleLarge?.copyWith(color: scheme.onPrimaryContainer, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 2),
                      Text('Signed in as this DC name', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onPrimaryContainer.withOpacity(0.75))),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text('APPEARANCE', style: Theme.of(context).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.bold, letterSpacing: 0.6, color: scheme.onSurfaceVariant)),
          ),
          Card(
            margin: EdgeInsets.zero,
            child: ListTile(
              title: const Text('Theme mode'),
              subtitle: const Text('Choose light, dark, or system'),
              trailing: DropdownButton<ThemeMode>(
                value: tp.themeMode,
                underline: const SizedBox.shrink(),
                items: const [
                  DropdownMenuItem(value: ThemeMode.system, child: Text('System')),
                  DropdownMenuItem(value: ThemeMode.light, child: Text('Light')),
                  DropdownMenuItem(value: ThemeMode.dark, child: Text('Dark')),
                ],
                onChanged: (v) {
                  if (v != null) tp.setThemeMode(v);
                },
              ),
            ),
          ),
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text('ACCOUNT', style: Theme.of(context).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.bold, letterSpacing: 0.6, color: scheme.onSurfaceVariant)),
          ),
          Card(
            margin: EdgeInsets.zero,
            child: ListTile(
              leading: Icon(Icons.logout, color: scheme.error),
              title: Text('Logout', style: TextStyle(color: scheme.error)),
              onTap: () => _confirmLogout(context, auth),
            ),
          ),
        ],
      ),
    );
  }
}