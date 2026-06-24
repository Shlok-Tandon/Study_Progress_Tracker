import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../services/firestore_service.dart';

class LeaderboardScreen extends StatelessWidget {
  const LeaderboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final fs = FirestoreService();

    return Scaffold(
      appBar: AppBar(title: const Text('Leaderboard')),
      body: StreamBuilder<QuerySnapshot>(
        stream: fs.streamLeaderboard(),
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(child: Text('Something went wrong: ${snap.error}'));
          }
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final docs = snap.data!.docs;
          if (docs.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.emoji_events_outlined, size: 56, color: Theme.of(context).colorScheme.primary),
                    const SizedBox(height: 12),
                    Text('No leaderboard data yet', style: Theme.of(context).textTheme.titleMedium),
                  ],
                ),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: docs.length,
            itemBuilder: (_, i) {
              final d = docs[i].data() as Map<String, dynamic>;
              final rank = i + 1;
              final medal = switch (rank) { 1 => '🥇', 2 => '🥈', 3 => '🥉', _ => null };

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: ListTile(
                  leading: CircleAvatar(child: medal != null ? Text(medal, style: const TextStyle(fontSize: 18)) : Text('#$rank')),
                  title: Text(d['name'] ?? 'User', style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text('Streak: ${d['streak'] ?? 0} • Badges: ${d['badgeCount'] ?? 0}'),
                ),
              ).animate().fadeIn(delay: (i * 40).ms, duration: 250.ms).slideX(begin: 0.04, end: 0, delay: (i * 40).ms, duration: 250.ms);
            },
          );
        },
      ),
    );
  }
}