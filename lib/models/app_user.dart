import 'package:firebase_auth/firebase_auth.dart';

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
      id: json['uid'] as String? ?? json['id'] as String, // Support both uid and id
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