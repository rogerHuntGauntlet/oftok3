import 'package:cloud_firestore/cloud_firestore.dart';

class Project {
  final String id;
  final String name;
  final String? description;
  final String userId;
  final DateTime createdAt;
  final List<String> videoIds;
  final bool isPublic;
  final List<String> collaboratorIds;
  final List<String> favoritedBy;
  final int score;

  Project({
    required this.id,
    required this.name,
    this.description,
    required this.userId,
    required this.createdAt,
    List<String>? videoIds,
    bool? isPublic,
    List<String>? collaboratorIds,
    List<String>? favoritedBy,
    int? score,
  })  : videoIds = videoIds ?? [],
        isPublic = isPublic ?? false,
        collaboratorIds = collaboratorIds ?? [],
        favoritedBy = favoritedBy ?? [],
        score = score ?? 0;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'userId': userId,
      'createdAt': createdAt.toIso8601String(),
      'videoIds': videoIds,
      'isPublic': isPublic,
      'collaboratorIds': collaboratorIds,
      'favoritedBy': favoritedBy,
      'score': score,
    };
  }

  factory Project.fromJson(Map<String, dynamic> json) {
    return Project(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      userId: json['userId'] as String,
      createdAt: json['createdAt'] is Timestamp
          ? (json['createdAt'] as Timestamp).toDate()
          : DateTime.parse(json['createdAt'] as String),
      videoIds: List<String>.from(json['videoIds'] ?? []),
      isPublic: json['isPublic'] as bool? ?? false,
      collaboratorIds: List<String>.from(json['collaboratorIds'] ?? []),
      favoritedBy: List<String>.from(json['favoritedBy'] ?? []),
      score: json['score'] as int? ?? 0,
    );
  }

  Project copyWith({
    String? id,
    String? name,
    String? description,
    String? userId,
    DateTime? createdAt,
    List<String>? videoIds,
    bool? isPublic,
    List<String>? collaboratorIds,
    List<String>? favoritedBy,
    int? score,
  }) {
    return Project(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      userId: userId ?? this.userId,
      createdAt: createdAt ?? this.createdAt,
      videoIds: videoIds ?? this.videoIds,
      isPublic: isPublic ?? this.isPublic,
      collaboratorIds: collaboratorIds ?? this.collaboratorIds,
      favoritedBy: favoritedBy ?? this.favoritedBy,
      score: score ?? this.score,
    );
  }

  bool canEdit(String userId) {
    return this.userId == userId || collaboratorIds.contains(userId);
  }

  bool isFavoritedBy(String userId) {
    return favoritedBy.contains(userId);
  }
} 