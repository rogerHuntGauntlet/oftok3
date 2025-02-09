import 'package:cloud_firestore/cloud_firestore.dart';

class Comment {
  final String id;
  final String videoId;
  final String userId;
  final String text;
  final DateTime createdAt;
  final DateTime? editedAt;
  final List<String> likedBy;
  final String? parentId; // null for top-level comments
  final int replyCount;
  final Map<String, List<String>> reactions; // emoji: [userId1, userId2, ...]

  Comment({
    required this.id,
    required this.videoId,
    required this.userId,
    required this.text,
    required this.createdAt,
    this.editedAt,
    required this.likedBy,
    this.parentId,
    this.replyCount = 0,
    Map<String, List<String>>? reactions,
  }) : reactions = reactions ?? {};

  bool isLikedBy(String userId) => likedBy.contains(userId);
  bool hasReacted(String emoji, String userId) => reactions[emoji]?.contains(userId) ?? false;
  int getReactionCount(String emoji) => reactions[emoji]?.length ?? 0;

  Comment copyWith({
    String? text,
    DateTime? editedAt,
    Map<String, List<String>>? reactions,
    List<String>? likedBy,
    int? replyCount,
  }) {
    return Comment(
      id: id,
      videoId: videoId,
      userId: userId,
      text: text ?? this.text,
      createdAt: createdAt,
      editedAt: editedAt ?? this.editedAt,
      likedBy: likedBy ?? this.likedBy,
      parentId: parentId,
      replyCount: replyCount ?? this.replyCount,
      reactions: reactions ?? this.reactions,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'videoId': videoId,
      'userId': userId,
      'text': text,
      'createdAt': createdAt,
      'editedAt': editedAt,
      'likedBy': likedBy,
      'parentId': parentId,
      'replyCount': replyCount,
      'reactions': reactions,
    };
  }

  factory Comment.fromJson(Map<String, dynamic> json) {
    return Comment(
      id: json['id'] as String,
      videoId: json['videoId'] as String,
      userId: json['userId'] as String,
      text: json['text'] as String,
      createdAt: (json['createdAt'] as Timestamp).toDate(),
      editedAt: json['editedAt'] != null ? (json['editedAt'] as Timestamp).toDate() : null,
      likedBy: List<String>.from(json['likedBy'] ?? []),
      parentId: json['parentId'] as String?,
      replyCount: json['replyCount'] as int? ?? 0,
      reactions: (json['reactions'] as Map<String, dynamic>?)?.map(
            (key, value) => MapEntry(key, List<String>.from(value as List)),
          ) ??
          {},
    );
  }
} 