import 'package:cloud_firestore/cloud_firestore.dart';

class Video {
  final String id;
  final String title;
  final String? description;
  final String url;
  final String userId;
  final DateTime uploadedAt;
  final String? thumbnailUrl;
  final int duration;
  final List<String> tags;
  final int views;
  final List<String> likedBy;

  Video({
    required this.id,
    required this.title,
    this.description,
    required this.url,
    required this.userId,
    required this.uploadedAt,
    this.thumbnailUrl,
    required this.duration,
    List<String>? tags,
    int? views,
    List<String>? likedBy,
  })  : tags = tags ?? [],
        views = views ?? 0,
        likedBy = likedBy ?? [];

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'url': url,
      'userId': userId,
      'uploadedAt': uploadedAt.toIso8601String(),
      'thumbnailUrl': thumbnailUrl,
      'duration': duration,
      'tags': tags,
      'views': views,
      'likedBy': likedBy,
    };
  }

  factory Video.fromJson(Map<String, dynamic> json) {
    return Video(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      url: json['url'] as String,
      userId: json['userId'] as String,
      uploadedAt: json['uploadedAt'] is Timestamp
          ? (json['uploadedAt'] as Timestamp).toDate()
          : DateTime.parse(json['uploadedAt'] as String),
      thumbnailUrl: json['thumbnailUrl'] as String?,
      duration: json['duration'] as int,
      tags: List<String>.from(json['tags'] ?? []),
      views: json['views'] as int? ?? 0,
      likedBy: List<String>.from(json['likedBy'] ?? []),
    );
  }

  Video copyWith({
    String? id,
    String? title,
    String? description,
    String? url,
    String? userId,
    DateTime? uploadedAt,
    String? thumbnailUrl,
    int? duration,
    List<String>? tags,
    int? views,
    List<String>? likedBy,
  }) {
    return Video(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      url: url ?? this.url,
      userId: userId ?? this.userId,
      uploadedAt: uploadedAt ?? this.uploadedAt,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      duration: duration ?? this.duration,
      tags: tags ?? this.tags,
      views: views ?? this.views,
      likedBy: likedBy ?? this.likedBy,
    );
  }
} 