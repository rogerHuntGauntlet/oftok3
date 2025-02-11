import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:http/http.dart' as http;
import '../models/app_user.dart';

class UserService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFunctions _functions = FirebaseFunctions.instance;

  // Get initial list of users (excluding current user and collaborators)
  Future<List<AppUser>> getInitialUsers({String? searchQuery, List<String>? excludeIds}) async {
    try {
      print('Fetching users from Firebase Auth...'); // Debug print
      
      // Get the current user's ID to exclude them from the list
      final currentUserId = _auth.currentUser?.uid;
      
      // Call the HTTP endpoint
      final response = await http.get(Uri.parse(
        'https://us-central1-ohftok-gauntlet.cloudfunctions.net/listAllUsers'
      ));
      
      if (response.statusCode != 200) {
        print('Error response: ${response.body}'); // Debug print
        return [];
      }
      
      final data = json.decode(response.body) as Map<String, dynamic>;
      if (!data.containsKey('users')) {
        print('Invalid response format'); // Debug print
        return [];
      }
      
      final List<dynamic> usersData = data['users'] as List<dynamic>;
      var users = usersData
          .where((userData) {
            final uid = userData['uid'] as String;
            return uid != currentUserId && !(excludeIds?.contains(uid) ?? false);
          })
          .map((userData) => AppUser(
                id: userData['uid'] as String,
                displayName: userData['displayName'] as String? ?? 'User',
                email: userData['email'] as String? ?? '',
                photoUrl: userData['photoUrl'] as String?,
                isAuthenticated: true,
              ))
          .toList();

      // Filter users if search query is provided
      if (searchQuery != null && searchQuery.isNotEmpty) {
        final query = searchQuery.toLowerCase();
        users = users.where((user) =>
          user.displayName.toLowerCase().contains(query) ||
          user.email.toLowerCase().contains(query)
        ).toList();
      }

      print('Found ${users.length} users'); // Debug print
      return users;
    } catch (e) {
      print('Error fetching users: $e'); // Debug print
      return [];
    }
  }

  // Search users
  Future<List<AppUser>> searchUsers(String query) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        throw FirebaseException(
          plugin: 'user_service',
          message: 'Must be authenticated to search users',
        );
      }

      // Ensure we have a valid ID token
      await currentUser.getIdToken();

      print('Searching users with query: $query'); // Debug print
      final HttpsCallable callable = _functions.httpsCallable('listUsers');
      final result = await callable.call<Map<String, dynamic>>({
        'query': query,
      });
      
      final List<dynamic> usersData = result.data['users'] as List<dynamic>;
      final users = usersData
          .map((userData) => AppUser.fromJson(userData as Map<String, dynamic>))
          .toList();

      print('Found ${users.length} users matching query'); // Debug print
      return users;
    } on FirebaseException catch (e) {
      print('Firebase error searching users: ${e.message}'); // Debug print
      rethrow;
    } catch (e) {
      print('Error searching users: $e'); // Debug print
      rethrow;
    }
  }

  // Create or update user in Firestore
  Future<void> createOrUpdateUser(User firebaseUser) async {
    print('Creating/updating user: ${firebaseUser.uid}'); // Debug print
    final user = AppUser.fromFirebaseUser(firebaseUser);
    
    try {
      final docRef = _firestore.collection('users').doc(user.id);
      final doc = await docRef.get();
      
      if (!doc.exists) {
        // Create new user with initial tokens
        await docRef.set({
          'uid': user.id,  // Add both uid and id for compatibility
          'id': user.id,
          'displayName': user.displayName,
          'email': user.email,
          'photoUrl': user.photoUrl,
          'isAuthenticated': user.isAuthenticated,
          'tokens': 1000, // Initial tokens
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
        print('Created new user with 1000 initial tokens'); // Debug print
      } else {
        // Update existing user but preserve tokens
        final data = doc.data()!;
        await docRef.update({
          'uid': user.id,  // Ensure uid is set
          'id': user.id,   // Ensure id is set
          'displayName': user.displayName,
          'email': user.email,
          'photoUrl': user.photoUrl,
          'isAuthenticated': user.isAuthenticated,
          'updatedAt': FieldValue.serverTimestamp(),
          // Ensure tokens exist, set to 1000 if they don't
          'tokens': data['tokens'] ?? 1000,
        });
      }
      print('Successfully updated user in Firestore'); // Debug print
    } catch (e) {
      print('Error creating/updating user: $e'); // Debug print
      rethrow;
    }
  }

  // Get user by ID
  Future<AppUser?> getUser(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      if (!doc.exists) {
        print('No user found with ID: $userId'); // Debug print
        return null;
      }
      print('Found user: ${doc.data()}'); // Debug print
      return AppUser.fromJson(doc.data()!);
    } catch (e) {
      print('Error getting user: $e'); // Debug print
      rethrow;
    }
  }

  // Get current user
  Future<AppUser?> getCurrentUser() async {
    try {
      final firebaseUser = _auth.currentUser;
      if (firebaseUser == null) return null;

      print('Getting user document for ID: ${firebaseUser.uid}'); // Debug print
      final userDoc = await _firestore.collection('users').doc(firebaseUser.uid).get();
      print('User document exists: ${userDoc.exists}'); // Debug print
      
      if (!userDoc.exists) {
        print('Creating new user document'); // Debug print
        // Create new user if doesn't exist
        final userData = {
          'displayName': firebaseUser.displayName ?? 'User',
          'email': firebaseUser.email ?? '',
          'photoUrl': firebaseUser.photoURL,
          'isAuthenticated': true,
          'tokens': 1000, // Initial tokens
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        };
        print('New user data to be written: $userData'); // Debug print
        
        await _firestore.collection('users').doc(firebaseUser.uid).set(userData);
        
        // Fetch the newly created user
        final newUserDoc = await _firestore.collection('users').doc(firebaseUser.uid).get();
        print('New user data from Firestore: ${newUserDoc.data()}'); // Debug print
        return AppUser.fromJson(newUserDoc.data()!, documentId: newUserDoc.id);
      }

      final userData = userDoc.data()!;
      print('Existing user data from Firestore: $userData'); // Debug print
      
      // Ensure tokens exist
      if (!userData.containsKey('tokens')) {
        print('No tokens field found, adding default 1000 tokens'); // Debug print
        await _firestore.collection('users').doc(firebaseUser.uid).update({
          'tokens': 1000,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        userData['tokens'] = 1000;
      }

      final user = AppUser.fromJson(userData, documentId: userDoc.id);
      print('Final user object tokens: ${user.tokens}'); // Debug print
      return user;
    } catch (e) {
      print('Error getting current user: $e');
      return null;
    }
  }

  // Get multiple users by IDs
  Future<List<AppUser>> getUsers(List<String> userIds) async {
    print('Getting users for IDs: $userIds'); // Debug print
    if (userIds.isEmpty) return [];

    try {
      final response = await http.get(Uri.parse(
        'https://us-central1-ohftok-gauntlet.cloudfunctions.net/listAllUsers'
      ));
      
      if (response.statusCode != 200) {
        print('Error response: ${response.body}'); // Debug print
        return [];
      }
      
      final data = json.decode(response.body) as Map<String, dynamic>;
      if (!data.containsKey('users')) {
        print('Invalid response format'); // Debug print
        return [];
      }
      
      final List<dynamic> usersData = data['users'] as List<dynamic>;
      final users = usersData
          .where((userData) => userIds.contains(userData['uid'] as String))
          .map((userData) => AppUser(
                id: userData['uid'] as String,
                displayName: userData['displayName'] as String? ?? 'User',
                email: userData['email'] as String? ?? '',
                photoUrl: userData['photoUrl'] as String?,
                isAuthenticated: true,
              ))
          .toList();

      print('Found ${users.length} users out of ${userIds.length} requested'); // Debug print
      return users;
    } catch (e) {
      print('Error fetching users: $e'); // Debug print
      return [];
    }
  }

  // Update user tokens
  Future<void> updateUserTokens(String userId, int newTokenCount) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'tokens': newTokenCount,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error updating user tokens: $e');
      throw e;
    }
  }

  // Check if user has enough tokens
  Future<bool> hasEnoughTokens(String userId, int requiredTokens) async {
    try {
      print('Checking tokens for user: $userId'); // Debug log
      final doc = await _firestore.collection('users').doc(userId).get();
      print('User document exists: ${doc.exists}'); // Debug log
      if (!doc.exists) return false;
      
      final data = doc.data();
      print('User data from hasEnoughTokens: $data'); // Debug log
      
      if (!data!.containsKey('tokens')) {
        print('No tokens field found in document!'); // Debug log
        return false;
      }
      
      final rawTokens = data['tokens'];
      print('Raw tokens value type: ${rawTokens.runtimeType}'); // Debug log
      print('Raw tokens value: $rawTokens'); // Debug log
      
      final currentTokens = rawTokens is int ? rawTokens : 0;
      print('Parsed current tokens: $currentTokens'); // Debug log
      print('Required tokens: $requiredTokens'); // Debug log
      
      final hasEnough = currentTokens >= requiredTokens;
      print('Has enough tokens? $hasEnough'); // Debug log
      
      return hasEnough;
    } catch (e) {
      print('Error checking tokens: $e');
      return false;
    }
  }

  // Deduct tokens from user
  Future<bool> deductTokens(String userId, int tokensToDeduct) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      if (!doc.exists) return false;
      
      final currentTokens = doc.data()?['tokens'] as int? ?? 0;
      if (currentTokens < tokensToDeduct) return false;
      
      await updateUserTokens(userId, currentTokens - tokensToDeduct);
      return true;
    } catch (e) {
      print('Error deducting user tokens: $e');
      return false;
    }
  }
} 