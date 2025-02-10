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
    final now = DateTime.now();
    
    try {
      final docRef = _firestore.collection('users').doc(user.id);
      final doc = await docRef.get();
      
      if (!doc.exists) {
        // Create new user
        await docRef.set({
          ...user.toJson(),
          'createdAt': now.toIso8601String(),
          'updatedAt': now.toIso8601String(),
        });
      } else {
        // Update existing user
        await docRef.update({
          ...user.toJson(),
          'updatedAt': now.toIso8601String(),
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
    final firebaseUser = _auth.currentUser;
    if (firebaseUser == null) return null;
    
    try {
      final doc = await _firestore.collection('users').doc(firebaseUser.uid).get();
      if (doc.exists) {
        return AppUser.fromJson(doc.data()!);
      } else {
        // Create user document if it doesn't exist
        final user = AppUser.fromFirebaseUser(firebaseUser);
        await createOrUpdateUser(firebaseUser);
        return user;
      }
    } catch (e) {
      print('Error getting current user: $e');
      return AppUser.fromFirebaseUser(firebaseUser);
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
} 