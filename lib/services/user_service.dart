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

  // Static list of fake users for testing
  static final List<AppUser> _fakeUsers = [
    AppUser(
      id: 'user1',
      displayName: 'John Doe',
      email: 'john.doe@example.com',
      photoUrl: 'https://ui-avatars.com/api/?name=John+Doe',
    ),
    AppUser(
      id: 'user2',
      displayName: 'Jane Smith',
      email: 'jane.smith@example.com',
      photoUrl: 'https://ui-avatars.com/api/?name=Jane+Smith',
    ),
    AppUser(
      id: 'user3',
      displayName: 'Bob Johnson',
      email: 'bob.johnson@example.com',
      photoUrl: 'https://ui-avatars.com/api/?name=Bob+Johnson',
    ),
    AppUser(
      id: 'user4',
      displayName: 'Alice Brown',
      email: 'alice.brown@example.com',
      photoUrl: 'https://ui-avatars.com/api/?name=Alice+Brown',
    ),
    AppUser(
      id: 'user5',
      displayName: 'Charlie Wilson',
      email: 'charlie.wilson@example.com',
      photoUrl: 'https://ui-avatars.com/api/?name=Charlie+Wilson',
    ),
  ];

  // Get initial list of users (excluding current user)
  Future<List<AppUser>> getInitialUsers() async {
    print('Getting initial fake users'); // Debug print
    final currentUserId = _auth.currentUser?.uid;
    return _fakeUsers.where((user) => user.id != currentUserId).toList();
  }

  // Search authenticated users
  Future<List<AppUser>> searchUsers(String query) async {
    print('Searching fake users with query: $query'); // Debug print
    final currentUserId = _auth.currentUser?.uid;
    final lowercaseQuery = query.toLowerCase();
    
    return _fakeUsers.where((user) {
      if (user.id == currentUserId) return false;
      return user.displayName.toLowerCase().contains(lowercaseQuery) ||
             user.email.toLowerCase().contains(lowercaseQuery);
    }).toList();
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