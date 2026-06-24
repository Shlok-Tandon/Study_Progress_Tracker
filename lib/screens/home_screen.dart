import 'package:flutter/material.dart';
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: index, children: _pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (v) => setState(() => index = v),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.groups_outlined), selectedIcon: Icon(Icons.groups), label: 'Team'),
          NavigationDestination(icon: Icon(Icons.task_alt_outlined), selectedIcon: Icon(Icons.task_alt), label: 'My Tasks'),
          NavigationDestination(icon: Icon(Icons.emoji_events_outlined), selectedIcon: Icon(Icons.emoji_events), label: 'Leaderboard'),
          NavigationDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings), label: 'Settings'),
        ],
      ),
    );
  }
}