import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:http/http.dart' as http;
import '../models/app_user.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_storage/firebase_storage.dart';

class UserService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFunctions _functions = FirebaseFunctions.instance;
  
  // Token costs
  static const int VIDEO_GENERATION_COST = 250;
  static const int INITIAL_TOKEN_BALANCE = 1000;

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
          'tokens': INITIAL_TOKEN_BALANCE, // Initial tokens
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
          'generatedVideoIds': [], // Initialize empty list
        });
        print('Created new user with $INITIAL_TOKEN_BALANCE initial tokens'); // Debug print
      } else {
        // Update existing user but preserve tokens and generatedVideoIds
        final data = doc.data()!;
        await docRef.update({
          'uid': user.id,  // Ensure uid is set
          'id': user.id,   // Ensure id is set
          'displayName': user.displayName,
          'email': user.email,
          'photoUrl': user.photoUrl,
          'isAuthenticated': user.isAuthenticated,
          'updatedAt': FieldValue.serverTimestamp(),
          // Ensure tokens exist, set to initial balance if they don't
          'tokens': data['tokens'] ?? INITIAL_TOKEN_BALANCE,
          // Ensure generatedVideoIds exist
          'generatedVideoIds': data['generatedVideoIds'] ?? [],
        });
      }
      print('Successfully updated user in Firestore'); // Debug print
    } catch (e) {
      print('Error creating/updating user: $e'); // Debug print
      rethrow;
    }
  }

  // Track generated video
  Future<void> addGeneratedVideo(String userId, String videoId) async {
    try {
      print('Adding generated video $videoId to user $userId'); // Debug log
      await _firestore.collection('users').doc(userId).update({
        'generatedVideoIds': FieldValue.arrayUnion([videoId]),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      print('Successfully added video to user\'s generated videos'); // Debug log
    } catch (e) {
      print('Error adding generated video: $e');
      throw e;
    }
  }

  // Get user's generated videos
  Future<List<String>> getUserGeneratedVideos(String userId) async {
    try {
      print('Getting generated videos for user: $userId'); // Debug log
      final doc = await _firestore.collection('users').doc(userId).get();
      if (!doc.exists) {
        print('User document not found'); // Debug log
        return [];
      }
      
      final data = doc.data()!;
      if (!data.containsKey('generatedVideoIds')) {
        print('No generatedVideoIds field found'); // Debug log
        return [];
      }
      
      final List<dynamic> videoIds = data['generatedVideoIds'] ?? [];
      print('Found ${videoIds.length} generated videos'); // Debug log
      return videoIds.cast<String>().toList();
    } catch (e) {
      print('Error getting user generated videos: $e');
      return [];
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

  // Check if user has enough tokens for video generation
  Future<bool> hasEnoughTokens(String userId) async {
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
      print('Current tokens: $currentTokens'); // Debug log
      print('Required tokens: $VIDEO_GENERATION_COST'); // Debug log
      
      final hasEnough = currentTokens >= VIDEO_GENERATION_COST;
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
      print('Attempting to deduct $tokensToDeduct tokens from user $userId'); // Debug log
      
      final doc = await _firestore.collection('users').doc(userId).get();
      if (!doc.exists) {
        print('User document not found for $userId'); // Debug log
        return false;
      }
      
      final currentTokens = doc.data()?['tokens'] as int? ?? 0;
      print('Current token balance: $currentTokens'); // Debug log
      
      if (currentTokens < tokensToDeduct) {
        print('Insufficient tokens: $currentTokens < $tokensToDeduct'); // Debug log
        return false;
      }
      
      final newBalance = currentTokens - tokensToDeduct;
      print('New token balance will be: $newBalance'); // Debug log
      
      await updateUserTokens(userId, newBalance);
      print('Successfully updated token balance to $newBalance'); // Debug log
      return true;
    } catch (e) {
      print('Error deducting user tokens: $e');
      return false;
    }
  }

  // Update user profile
  Future<void> updateProfile({
    required String displayName,
    String? bio,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw FirebaseException(
          plugin: 'user_service',
          message: 'Must be authenticated to update profile',
        );
      }

      // Update Firebase Auth display name
      await user.updateDisplayName(displayName);

      // Update Firestore document
      await _firestore.collection('users').doc(user.uid).update({
        'displayName': displayName,
        'bio': bio,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error updating profile: $e');
      rethrow;
    }
  }

  // Update profile photo
  Future<void> updateProfilePhoto(File photoFile) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      // Upload photo to Firebase Storage
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('user_photos')
          .child('${user.uid}.jpg');

      // Add required metadata
      final metadata = SettableMetadata(
        contentType: 'image/jpeg',
      );

      // Upload the file with metadata
      await storageRef.putFile(photoFile, metadata);

      // Get the download URL
      final photoUrl = await storageRef.getDownloadURL();

      // Update Firebase Auth photo URL
      await user.updatePhotoURL(photoUrl);

      // Update Firestore document
      await _firestore.collection('users').doc(user.uid).update({
        'photoUrl': photoUrl,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error updating profile photo: $e');
      rethrow;
    }
  }
} 