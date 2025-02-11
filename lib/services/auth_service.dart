import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import './user_service.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
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

  // Email & Password Sign In
  Future<UserCredential> signInWithEmailPassword(String email, String password) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );
      return credential;
    } catch (e) {
      rethrow;
    }
  }

  // Google Sign In
  Future<UserCredential> signInWithGoogle() async {
    try {
      // Trigger the authentication flow
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      
      if (googleUser == null) {
        throw FirebaseAuthException(
          code: 'ERROR_ABORTED_BY_USER',
          message: 'Sign in aborted by user',
        );
      }

      // Obtain the auth details from the request
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      // Create a new credential
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Sign in to Firebase with the Google credential
      final userCredential = await _auth.signInWithCredential(credential);
      
      // Create or update user in Firestore
      if (userCredential.user != null) {
        await _userService.createOrUpdateUser(userCredential.user!);
      }

      return userCredential;
    } catch (e) {
      rethrow;
    }
  }

  // Password Reset
  Future<void> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
    } catch (e) {
      rethrow;
    }
  }

  // Sign Out
  Future<void> signOut() async {
    try {
      await Future.wait([
        _auth.signOut(),
        _googleSignIn.signOut(),
      ]);
    } catch (e) {
      rethrow;
    }
  }

  // Register with Email & Password
  Future<UserCredential> registerWithEmailPassword(
    String email,
    String password,
    String displayName,
  ) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );

      // Update the user's display name
      await credential.user?.updateDisplayName(displayName.trim());

      // Create the user document in Firestore
      if (credential.user != null) {
        await _userService.createOrUpdateUser(credential.user!);
      }

      return credential;
    } catch (e) {
      rethrow;
    }
  }
} 