import 'package:cloud_firestore/cloud_firestore.dart';

class Video {
  final String id;
  final String title;
  final String url;
  final String userId;
  final DateTime uploadedAt;
  final String thumbnailUrl;
  final int duration; // in seconds

  Video({
    required this.id,
    required this.title,
    required this.url,
    required this.userId,
    required this.uploadedAt,
    required this.thumbnailUrl,
    required this.duration,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'url': url,
      'userId': userId,
      'uploadedAt': uploadedAt,
      'thumbnailUrl': thumbnailUrl,
      'duration': duration,
    };
  }

  factory Video.fromJson(Map<String, dynamic> json) {
    try {
      return Video(
        id: json['id'] as String? ?? '',
        title: json['title'] as String? ?? 'Untitled Video',
        url: json['url'] as String? ?? '',
        userId: json['userId'] as String? ?? '',
        uploadedAt: json['uploadedAt'] != null
            ? (json['uploadedAt'] is Timestamp)
                ? (json['uploadedAt'] as Timestamp).toDate()
                : DateTime.tryParse(json['uploadedAt'].toString()) ?? DateTime.now()
            : DateTime.now(),
        thumbnailUrl: json['thumbnailUrl'] as String? ?? '',
        duration: json['duration'] as int? ?? 0,
      );
    } catch (e) {
      print('Error creating Video from JSON: $e');
      print('Problematic JSON: $json');
      rethrow;
    }
  }
} 