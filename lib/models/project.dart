import 'package:cloud_firestore/cloud_firestore.dart';

class Project {
  final String id;
  final String name;
  final String description;
  final String userId;
  final DateTime createdAt;
  final List<String> videoIds; // References to videos in the videos collection
  final bool isPublic;
  final List<String> collaboratorIds;

  Project({
    required this.id,
    required this.name,
    required this.description,
    required this.userId,
    required this.createdAt,
    required this.videoIds,
    this.isPublic = false,
    List<String>? collaboratorIds,
  }) : collaboratorIds = collaboratorIds ?? [];

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'userId': userId,
      'createdAt': Timestamp.fromDate(createdAt),
      'videoIds': videoIds,
      'isPublic': isPublic,
      'collaboratorIds': collaboratorIds,
    };
  }

  factory Project.fromJson(Map<String, dynamic> json) {
    try {
      return Project(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? 'Untitled Project',
        description: json['description'] as String? ?? '',
        userId: json['userId'] as String? ?? '',
        createdAt: json['createdAt'] != null
            ? (json['createdAt'] is Timestamp)
                ? (json['createdAt'] as Timestamp).toDate()
                : DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now()
            : DateTime.now(),
        videoIds: (json['videoIds'] is List)
            ? List<String>.from(json['videoIds'])
            : [],
        isPublic: json['isPublic'] as bool? ?? false,
        collaboratorIds: (json['collaboratorIds'] is List)
            ? List<String>.from(json['collaboratorIds'])
            : [],
      );
    } catch (e) {
      print('Error creating Project from JSON: $e');
      print('Problematic JSON: $json');
      rethrow;
    }
  }

  Project copyWith({
    String? name,
    String? description,
    List<String>? videoIds,
    bool? isPublic,
    List<String>? collaboratorIds,
  }) {
    return Project(
      id: id,
      name: name ?? this.name,
      description: description ?? this.description,
      userId: userId,
      createdAt: createdAt,
      videoIds: videoIds ?? this.videoIds,
      isPublic: isPublic ?? this.isPublic,
      collaboratorIds: collaboratorIds ?? this.collaboratorIds,
    );
  }

  bool canEdit(String userId) {
    return this.userId == userId || collaboratorIds.contains(userId);
  }
} 