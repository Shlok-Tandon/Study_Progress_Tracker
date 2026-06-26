import 'package:flutter/material.dart';
import '../widgets/tactile_nav_bar.dart';
import 'leaderboard_screen.dart';
import 'my_tasks_screen.dart';
import 'settings_screen.dart';
import 'team_progress_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int index = 0;

  // RepaintBoundary isolates each tab's painting, so an infinite animation
  // on one tab can't dirty the paint region of another. IndexedStack keeps
  // all four alive (state + Firestore listeners preserved across switches).
  static const _pages = [
    RepaintBoundary(child: TeamProgressScreen()),
    RepaintBoundary(child: MyTasksScreen()),
    RepaintBoundary(child: LeaderboardScreen()),
    RepaintBoundary(child: SettingsScreen()),
  ];

  static const _items = [
    TactileNavItem(icon: Icons.groups_outlined, activeIcon: Icons.groups, label: 'Team'),
    TactileNavItem(icon: Icons.task_alt_outlined, activeIcon: Icons.task_alt, label: 'My Tasks'),
    TactileNavItem(icon: Icons.emoji_events_outlined, activeIcon: Icons.emoji_events, label: 'Leaderboard'),
    TactileNavItem(icon: Icons.settings_outlined, activeIcon: Icons.settings, label: 'Settings'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: IndexedStack(index: index, children: _pages),
      bottomNavigationBar: TactileNavBar(
        selectedIndex: index,
        onSelected: (v) => setState(() => index = v),
        items: _items,
      ),
    );
  }
}