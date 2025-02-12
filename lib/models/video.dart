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
  final bool isAiGenerated;

  // Add getters for like and comment counts
  int get likeCount => likedBy.length;
  int get commentCount => 0; // This will be updated when we implement comments

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
    this.isAiGenerated = false,
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
      'isAiGenerated': isAiGenerated,
    };
  }

  factory Video.fromJson(Map<String, dynamic> json) {
    try {
      print('Parsing video document with data: $json');
      
      // Handle required fields with strict null checks and defaults
      String id = '';
      String title = 'Untitled Video';
      String url = '';
      String userId = '';
      
      try {
        id = json['id']?.toString() ?? '';
        if (id.isEmpty) {
          print('Warning: Empty video ID');
        }
      } catch (e) {
        print('Error parsing id: $e');
      }
      
      try {
        title = json['title']?.toString() ?? 'Untitled Video';
      } catch (e) {
        print('Error parsing title: $e');
      }
      
      try {
        url = json['url']?.toString() ?? '';
        if (url.isEmpty) {
          print('Warning: Empty video URL');
        }
      } catch (e) {
        print('Error parsing url: $e');
      }
      
      try {
        userId = json['userId']?.toString() ?? '';
        if (userId.isEmpty) {
          print('Warning: Empty userId');
        }
      } catch (e) {
        print('Error parsing userId: $e');
      }
      
      // Handle optional fields with detailed error logging
      String? description;
      try {
        description = json['description']?.toString();
      } catch (e) {
        print('Error parsing description: $e');
      }
      
      String? thumbnailUrl;
      try {
        thumbnailUrl = json['thumbnailUrl']?.toString();
      } catch (e) {
        print('Error parsing thumbnailUrl: $e');
      }
      
      // Handle duration with detailed error logging
      int duration = 0;
      try {
        if (json['duration'] != null) {
          duration = (json['duration'] as num).toInt();
        }
      } catch (e) {
        print('Error parsing duration: $e');
      }
      
      // Handle arrays with detailed error logging
      List<String> tags = [];
      try {
        if (json['tags'] != null) {
          tags = (json['tags'] as List?)?.map((e) => e?.toString() ?? '').where((e) => e.isNotEmpty).toList() ?? [];
        }
      } catch (e) {
        print('Error parsing tags: $e');
      }
      
      List<String> likedBy = [];
      try {
        if (json['likedBy'] != null) {
          likedBy = (json['likedBy'] as List?)?.map((e) => e?.toString() ?? '').where((e) => e.isNotEmpty).toList() ?? [];
        }
      } catch (e) {
        print('Error parsing likedBy: $e');
      }
      
      // Handle timestamp with detailed error logging
      DateTime uploadedAt = DateTime.now();
      try {
        if (json['uploadedAt'] is Timestamp) {
          uploadedAt = (json['uploadedAt'] as Timestamp).toDate();
        } else if (json['uploadedAt'] is String) {
          uploadedAt = DateTime.parse(json['uploadedAt'] as String);
        }
      } catch (e) {
        print('Error parsing uploadedAt: $e');
      }
      
      // Handle views with detailed error logging
      int views = 0;
      try {
        if (json['views'] != null) {
          views = (json['views'] as num).toInt();
        }
      } catch (e) {
        print('Error parsing views: $e');
      }
      
      // Handle isAiGenerated with detailed error logging
      bool isAiGenerated = false;
      try {
        isAiGenerated = json['isAiGenerated'] as bool? ?? false;
      } catch (e) {
        print('Error parsing isAiGenerated: $e');
      }

      return Video(
        id: id,
        title: title,
        description: description,
        url: url,
        userId: userId,
        uploadedAt: uploadedAt,
        thumbnailUrl: thumbnailUrl,
        duration: duration,
        tags: tags,
        views: views,
        likedBy: likedBy,
        isAiGenerated: isAiGenerated,
      );
    } catch (e, stackTrace) {
      print('Error parsing video document: $e');
      print('Stack trace: $stackTrace');
      print('Raw JSON: $json');
      rethrow;
    }
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
    bool? isAiGenerated,
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
      isAiGenerated: isAiGenerated ?? this.isAiGenerated,
    );
  }
} 