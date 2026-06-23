import 'package:cloud_firestore/cloud_firestore.dart';

class TeamMember {
  final String id;
  final String name;
  final String? claimedByUid;
  final String? claimedByEmail;
  final Timestamp? claimedAt;

  TeamMember({
    required this.id,
    required this.name,
    this.claimedByUid,
    this.claimedByEmail,
    this.claimedAt,
  });

  factory TeamMember.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return TeamMember(
      id: doc.id,
      name: data['name'] ?? '',
      claimedByUid: data['claimedByUid'],
      claimedByEmail: data['claimedByEmail'],
      claimedAt: data['claimedAt'],
    );
  }
}