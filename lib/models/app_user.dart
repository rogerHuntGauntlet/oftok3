import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AppUser {
  final String id;
  final String displayName;
  final String email;
  final String? photoUrl;
  final String? bio;
  final bool isAuthenticated;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int tokens;
  final List<String> generatedVideoIds;

  AppUser({
    required this.id,
    required this.displayName,
    required this.email,
    this.photoUrl,
    this.bio,
    this.isAuthenticated = true,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.tokens = 1000,
    List<String>? generatedVideoIds,
  }) : 
    this.createdAt = createdAt ?? DateTime.now(),
    this.updatedAt = updatedAt ?? DateTime.now(),
    this.generatedVideoIds = generatedVideoIds ?? [];

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'displayName': displayName,
      'email': email,
      'photoUrl': photoUrl,
      'bio': bio,
      'isAuthenticated': isAuthenticated,
      'tokens': tokens,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'generatedVideoIds': generatedVideoIds,
    };
  }

  factory AppUser.fromJson(Map<String, dynamic> json, {String? documentId}) {
    print('DEBUG: Raw user data from Firestore: $json'); // Debug print
    print('DEBUG: Document ID: $documentId'); // Debug print
    
    // Handle tokens explicitly
    final rawTokens = json['tokens'];
    print('DEBUG: Raw tokens value type: ${rawTokens.runtimeType}'); // Debug print
    print('DEBUG: Raw tokens value: $rawTokens'); // Debug print
    
    int tokenCount;
    if (rawTokens is int) {
      tokenCount = rawTokens;
    } else if (rawTokens is String) {
      tokenCount = int.tryParse(rawTokens) ?? 1000;
    } else {
      tokenCount = 1000;
    }
    print('DEBUG: Final token count: $tokenCount'); // Debug print
    
    // Use document ID if available, otherwise try to find id/uid in the data
    String userId = documentId ?? json['uid'] ?? json['id'] ?? 
      (throw Exception('No id found in user data'));

    // Handle timestamps safely
    DateTime? createdAt;
    if (json['createdAt'] != null) {
      if (json['createdAt'] is Timestamp) {
        createdAt = (json['createdAt'] as Timestamp).toDate();
      } else if (json['createdAt'] is String) {
        createdAt = DateTime.tryParse(json['createdAt'] as String);
      }
    }

    DateTime? updatedAt;
    if (json['updatedAt'] != null) {
      if (json['updatedAt'] is Timestamp) {
        updatedAt = (json['updatedAt'] as Timestamp).toDate();
      } else if (json['updatedAt'] is String) {
        updatedAt = DateTime.tryParse(json['updatedAt'] as String);
      }
    }
    
    return AppUser(
      id: userId,
      displayName: json['displayName'] as String? ?? 'User',
      email: json['email'] as String? ?? '',
      photoUrl: (json['photoURL'] ?? json['photoUrl']) as String?,
      bio: json['bio'] as String?,
      isAuthenticated: json['isAuthenticated'] as bool? ?? true,
      tokens: tokenCount,
      createdAt: createdAt,
      updatedAt: updatedAt,
      generatedVideoIds: List<String>.from(json['generatedVideoIds'] ?? []),
    );
  }

  factory AppUser.fromFirebaseUser(User user) {
    return AppUser(
      id: user.uid,
      displayName: user.displayName ?? 'User',
      email: user.email ?? '',
      photoUrl: user.photoURL,
      isAuthenticated: true,
      tokens: 1000,
      generatedVideoIds: [],
    );
  }
} 