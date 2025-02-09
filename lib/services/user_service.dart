import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';

class AppUser {
  final String id;
  final String displayName;
  final String email;
  final String? photoUrl;
  final bool isAuthenticated;
  final DateTime createdAt;
  final DateTime updatedAt;

  AppUser({
    required this.id,
    required this.displayName,
    required this.email,
    this.photoUrl,
    this.isAuthenticated = true,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : 
    this.createdAt = createdAt ?? DateTime.now(),
    this.updatedAt = updatedAt ?? DateTime.now();

  Map<String, dynamic> toJson() {
    return {
      'uid': id, // Use uid consistently
      'displayName': displayName,
      'email': email,
      'photoUrl': photoUrl,
      'isAuthenticated': isAuthenticated,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      id: json['uid'] as String, // Use uid consistently
      displayName: json['displayName'] as String? ?? 'User',
      email: json['email'] as String? ?? '',
      photoUrl: json['photoUrl'] as String?,
      isAuthenticated: json['isAuthenticated'] as bool? ?? true,
      createdAt: json['createdAt'] != null 
        ? DateTime.parse(json['createdAt'] as String)
        : null,
      updatedAt: json['updatedAt'] != null
        ? DateTime.parse(json['updatedAt'] as String)
        : null,
    );
  }

  factory AppUser.fromFirebaseUser(User user) {
    return AppUser(
      id: user.uid,
      displayName: user.displayName ?? 'User',
      email: user.email ?? '',
      photoUrl: user.photoURL,
      isAuthenticated: true,
    );
  }
}

class UserService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFunctions _functions = FirebaseFunctions.instance;

  // Get initial list of users (excluding current user)
  Future<List<AppUser>> getInitialUsers() async {
    try {
      print('Fetching initial users...'); // Debug print
      final result = await _functions.httpsCallable('listUsers').call();
      print('Initial users result: ${result.data}'); // Debug print
      final List<dynamic> usersData = (result.data['users'] as List);
      return usersData.map((userData) => AppUser.fromJson(userData)).toList();
    } catch (e) {
      print('Error fetching initial users: $e');
      return [];
    }
  }

  // Search authenticated users
  Future<List<AppUser>> searchUsers(String query) async {
    try {
      print('Searching users with query: $query'); // Debug print
      final result = await _functions
          .httpsCallable('listUsers')
          .call({'query': query});
      print('Search result data: ${result.data}'); // Debug print
      final List<dynamic> usersData = (result.data['users'] as List);
      final users = usersData.map((userData) {
        try {
          return AppUser.fromJson(userData);
        } catch (e) {
          print('Error parsing user data: $e'); // Debug print
          print('Problematic user data: $userData'); // Debug print
          return null;
        }
      })
      .where((user) => user != null)
      .cast<AppUser>()
      .toList();
      
      print('Found ${users.length} users'); // Debug print
      return users;
    } catch (e) {
      print('Error searching users: $e');
      rethrow; // Rethrow to show error in UI
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
    if (userIds.isEmpty) return [];

    try {
      final snapshots = await Future.wait(
        userIds.map((id) => _firestore.collection('users').doc(id).get()),
      );

      return snapshots
          .where((snap) => snap.exists)
          .map((snap) => AppUser.fromJson(snap.data()!))
          .toList();
    } catch (e) {
      print('Error getting multiple users: $e'); // Debug print
      rethrow;
    }
  }
} 