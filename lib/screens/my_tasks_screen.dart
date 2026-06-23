import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../services/firestore_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

class MyTasksScreen extends StatelessWidget {
  const MyTasksScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final fs = FirestoreService();

    return Scaffold(
      appBar: AppBar(title: const Text('My Tasks')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddTaskDialog(context, fs),
        child: const Icon(Icons.add),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: fs.streamMyTasks(),
        builder: (context, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final docs = snap.data!.docs;
          if (docs.isEmpty) return const Center(child: Text('No tasks yet'));

          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (_, i) {
              final d = docs[i].data() as Map<String, dynamic>;
              return CheckboxListTile(
                title: Text(d['title'] ?? ''),
                subtitle: Text('${d['subject']} • Due: ${((d['dueDate'] as Timestamp).toDate()).toString().split(' ').first}'),
                value: d['completed'] ?? false,
                onChanged: (v) => fs.toggleTask(docs[i].id, v ?? false),
              );
            },
          );
        },
      ),
    );
  }

  void _showAddTaskDialog(BuildContext context, FirestoreService fs) {
    final title = TextEditingController();
    final subject = TextEditingController();

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Add Task'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: title, decoration: const InputDecoration(labelText: 'Task title')),
            TextField(controller: subject, decoration: const InputDecoration(labelText: 'Subject')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              await fs.addTask(
                title: title.text.trim(),
                subject: subject.text.trim(),
                dueDate: DateTime.now().add(const Duration(days: 2)),
                assignedToUid: FirebaseAuth.instance.currentUser!.uid,
              );
              Navigator.pop(context);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }
}