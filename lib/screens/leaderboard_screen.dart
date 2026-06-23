import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
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
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final docs = snap.data!.docs;
          if (docs.isEmpty) return const Center(child: Text('No leaderboard data'));

          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (_, i) {
              final d = docs[i].data() as Map<String, dynamic>;
              return ListTile(
                leading: CircleAvatar(child: Text('#${i + 1}')),
                title: Text(d['email'] ?? 'User'),
                subtitle: Text('Streak: ${d['streak'] ?? 0} • Badges: ${d['badgeCount'] ?? 0}'),
              );
            },
          );
        },
      ),
    );
  }
}