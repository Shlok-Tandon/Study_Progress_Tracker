import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  final _auth = FirebaseAuth.instance;

  Stream<User?> get authChanges => _auth.authStateChanges();
  User? get currentUser => _auth.currentUser;

  /// Signs in anonymously (or reuses the existing session) and stores
  /// [name] as the Auth display name — so it's available instantly
  /// anywhere via `currentUser?.displayName`, with no extra Firestore read.
  Future<User> signInAnonymously(String name) async {
    final user = _auth.currentUser ?? (await _auth.signInAnonymously()).user!;
    await user.updateDisplayName(name);
    return user;
  }

  Future<void> logout() async {
    await _auth.signOut();
  }
}