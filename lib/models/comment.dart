import 'package:cloud_firestore/cloud_firestore.dart';

class Comment {
  final String id;
  final String? videoId;
  final String? projectId;
  final String text;
  final String authorId;
  final String authorName;
  final DateTime createdAt;
  final DateTime? editedAt;
  final List<String> likedBy;
  final int replyCount;
  final Map<String, List<String>> reactions;
  final String? parentId;

  Comment({
    required this.id,
    this.videoId,
    this.projectId,
    required this.text,
    required this.authorId,
    required this.authorName,
    required this.createdAt,
    this.editedAt,
    required this.likedBy,
    required this.replyCount,
    Map<String, List<String>>? reactions,
    this.parentId,
  }) : reactions = reactions ?? {};

  factory Comment.fromJson(Map<String, dynamic> json) {
    return Comment(
      id: json['id'] as String,
      videoId: json['videoId'] as String?,
      projectId: json['projectId'] as String?,
      text: json['text'] as String,
      authorId: json['authorId'] as String,
      authorName: json['authorName'] as String,
      createdAt: (json['createdAt'] as Timestamp).toDate(),
      editedAt: json['editedAt'] != null
          ? (json['editedAt'] as Timestamp).toDate()
          : null,
      likedBy: List<String>.from(json['likedBy'] ?? []),
      replyCount: json['replyCount'] as int? ?? 0,
      reactions: (json['reactions'] as Map<String, dynamic>?)?.map(
            (key, value) => MapEntry(
              key,
              List<String>.from(value.keys),
            ),
          ) ??
          {},
      parentId: json['parentId'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'videoId': videoId,
      'projectId': projectId,
      'text': text,
      'authorId': authorId,
      'authorName': authorName,
      'createdAt': Timestamp.fromDate(createdAt),
      'editedAt': editedAt != null ? Timestamp.fromDate(editedAt!) : null,
      'likedBy': likedBy,
      'replyCount': replyCount,
      'reactions': reactions,
      'parentId': parentId,
    };
  }

  Comment copyWith({
    String? id,
    String? videoId,
    String? projectId,
    String? text,
    String? authorId,
    String? authorName,
    DateTime? createdAt,
    DateTime? editedAt,
    List<String>? likedBy,
    int? replyCount,
    Map<String, List<String>>? reactions,
    String? parentId,
  }) {
    return Comment(
      id: id ?? this.id,
      videoId: videoId ?? this.videoId,
      projectId: projectId ?? this.projectId,
      text: text ?? this.text,
      authorId: authorId ?? this.authorId,
      authorName: authorName ?? this.authorName,
      createdAt: createdAt ?? this.createdAt,
      editedAt: editedAt ?? this.editedAt,
      likedBy: likedBy ?? this.likedBy,
      replyCount: replyCount ?? this.replyCount,
      reactions: reactions ?? this.reactions,
      parentId: parentId ?? this.parentId,
    );
  }

  bool hasReacted(String emoji, String userId) {
    return reactions[emoji]?.contains(userId) ?? false;
  }

  int getReactionCount(String emoji) {
    return reactions[emoji]?.length ?? 0;
  }

  bool isLikedBy(String userId) {
    return likedBy.contains(userId);
  }
} 