import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  final _auth = FirebaseAuth.instance;

  Stream<User?> get authChanges => _auth.authStateChanges();
  User? get currentUser => _auth.currentUser;

  Future<User> signInAnonymously() async {
    if (_auth.currentUser != null) return _auth.currentUser!;
    final cred = await _auth.signInAnonymously();
    return cred.user!;
  }

  Future<void> logout() async {
    await _auth.signOut();
  }
}