/// The fixed set of dance teams. [id] is the stable key used everywhere
/// (the `/teams/{id}` doc, and the `teamId` field on users and tasks);
/// [label] is what's shown in the UI. To add or rename a team, edit this
/// list AND create/rename the matching `/teams/{id}` doc in the Firebase
/// console (with its hidden `/private/codes`). Nothing else references team
/// names by hand.
class TeamOption {
  final String id;
  final String label;
  const TeamOption(this.id, this.label);
}

const List<TeamOption> kTeams = [
  TeamOption('folk', 'Folk'),
  TeamOption('western', 'Western'),
  TeamOption('semi_western', 'Semi-Western'),
  TeamOption('contemp', 'Contemp'),
];

/// UI label for a stored teamId (falls back to the raw id, then a dash).
String teamLabel(String? id) {
  for (final t in kTeams) {
    if (t.id == id) return t.label;
  }
  return (id == null || id.isEmpty) ? '—' : id;
}

/// A member's role within their team. Stored as the string on the user
/// doc's `role` field, and mirrored onto the join proof at signup so the
/// security rules can check the right code (member vs leader).
enum TeamRole { member, leader }

String roleToString(TeamRole r) => r == TeamRole.leader ? 'leader' : 'member';

TeamRole roleFromString(String? s) =>
    s == 'leader' ? TeamRole.leader : TeamRole.member;

/// A lightweight view of one teammate — used by the leader's "assign to"
/// picker and the team roster. Not persisted; built from user docs.
class TeamMember {
  final String id; // profileId (slugified name)
  final String name; // display name
  final TeamRole role;
  const TeamMember({required this.id, required this.name, required this.role});

  bool get isLeader => role == TeamRole.leader;
}