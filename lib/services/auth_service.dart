import 'package:firebase_auth/firebase_auth.dart';
import 'user_service.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final UserService _userService = UserService();

  // Get current user ID
  String? get currentUserId => _auth.currentUser?.uid;

  // Stream of auth state changes
  Stream<User?> get authStateChanges => _auth.authStateChanges()..listen(_handleAuthStateChange);

  // Check if user is signed in
  bool get isSignedIn => _auth.currentUser != null;

  // Get current user
  User? get currentUser => _auth.currentUser;

  // Handle auth state changes
  void _handleAuthStateChange(User? user) {
    if (user != null) {
      _userService.createOrUpdateUser(user);
    }
  }

  // Sign out
  Future<void> signOut() async {
    await _auth.signOut();
  }
} 