import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../services/firestore_service.dart';

class TeamProgressScreen extends StatelessWidget {
  const TeamProgressScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final fs = FirestoreService();

    return Scaffold(
      appBar: AppBar(title: const Text('Team Progress')),
      body: StreamBuilder<QuerySnapshot>(
        stream: fs.streamAllTasks(),
        builder: (context, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final docs = snap.data!.docs;
          if (docs.isEmpty) return const Center(child: Text('No shared tasks'));

          final pending = docs.where((d) => !(d['completed'] as bool? ?? false)).length;
          final completed = docs.length - pending;

          return Column(
            children: [
              const SizedBox(height: 8),
              ListTile(
                title: Text('Completed: $completed'),
                subtitle: Text('Pending: $pending'),
                trailing: const Icon(Icons.insights),
              ),
              const Divider(),
              Expanded(
                child: ListView.builder(
                  itemCount: docs.length,
                  itemBuilder: (_, i) {
                    final d = docs[i].data() as Map<String, dynamic>;
                    final done = d['completed'] as bool? ?? false;
                    return ListTile(
                      title: Text(d['title'] ?? ''),
                      subtitle: Text('${d['subject']} • ${done ? "Done ✅" : "Pending ⏳"}'),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}