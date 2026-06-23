import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../models/team_member.dart';
import '../services/firestore_service.dart';
import 'home_screen.dart';

class NameClaimScreen extends StatefulWidget {
  const NameClaimScreen({super.key});

  @override
  State<NameClaimScreen> createState() => _NameClaimScreenState();
}

class _NameClaimScreenState extends State<NameClaimScreen> {
  final fs = FirestoreService();
  String? selectedMemberDocId;

  final seedNames = const [
    'Hola',
    'Dora',
    'Talli',
    'Jhaag',
    'Chilka',
    'Magga',
    'Mahila',
    'Gungi',
    'Wangdu',
    'Kamod'
  ];

  @override
  void initState() {
    super.initState();
    fs.seedMembersIfEmpty(seedNames);
  }

  bool isDisabled(TeamMember m, String myUid) {
    if (m.claimedByUid == null) return false;
    return m.claimedByUid != myUid; // claimed by someone else => disabled
  }

  Future<void> claim() async {
    if (selectedMemberDocId == null) return;
    try {
      await fs.claimMemberName(selectedMemberDocId!);
      if (!mounted) return;
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const HomeScreen()));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final myUid = FirebaseAuth.instance.currentUser!.uid;

    return Scaffold(
      appBar: AppBar(title: const Text('Select Your Team Name')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: StreamBuilder<List<TeamMember>>(
          stream: fs.streamTeamMembers(),
          builder: (context, snap) {
            if (!snap.hasData) return const Center(child: CircularProgressIndicator());
            final members = snap.data!;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Choose your name. Claimed names are greyed out for others.',
                  style: TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: selectedMemberDocId,
                  items: members.map((m) {
                    final disabled = isDisabled(m, myUid);
                    return DropdownMenuItem<String>(
                      value: m.id,
                      enabled: !disabled,
                      child: Text(
                        disabled ? '${m.name} (claimed)' : m.name,
                        style: TextStyle(color: disabled ? Colors.grey : null),
                      ),
                    );
                  }).toList(),
                  onChanged: (v) => setState(() => selectedMemberDocId = v),
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    labelText: 'Team member name',
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: selectedMemberDocId == null ? null : claim,
                  child: const Text('Continue'),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}