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
  final double score;
  final int likeCount;
  final int commentCount;
  final int shareCount;
  final Duration totalSessionDuration;
  final int sessionCount;
  final Map<String, double> videoCompletionRates;
  final DateTime lastEngagement;

  Project({
    required this.id,
    required this.name,
    this.description,
    required this.userId,
    required this.createdAt,
    List<String>? videoIds,
    bool? isPublic,
    List<String>? collaboratorIds,
    double? score,
    int? likeCount,
    int? commentCount,
    int? shareCount,
    Duration? totalSessionDuration,
    int? sessionCount,
    Map<String, double>? videoCompletionRates,
    DateTime? lastEngagement,
  })  : videoIds = videoIds ?? [],
        isPublic = isPublic ?? false,
        collaboratorIds = collaboratorIds ?? [],
        score = score ?? 0.0,
        likeCount = likeCount ?? 0,
        commentCount = commentCount ?? 0,
        shareCount = shareCount ?? 0,
        totalSessionDuration = totalSessionDuration ?? Duration.zero,
        sessionCount = sessionCount ?? 0,
        videoCompletionRates = videoCompletionRates ?? {},
        lastEngagement = lastEngagement ?? DateTime.now();

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
      'score': score,
      'likeCount': likeCount,
      'commentCount': commentCount,
      'shareCount': shareCount,
      'totalSessionDuration': totalSessionDuration.inMilliseconds,
      'sessionCount': sessionCount,
      'videoCompletionRates': videoCompletionRates,
      'lastEngagement': Timestamp.fromDate(lastEngagement),
    };
  }

  factory Project.fromJson(Map<String, dynamic> json, {String? id}) {
    return Project(
      id: id ?? json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      userId: json['userId'] as String,
      isPublic: json['isPublic'] as bool? ?? false,
      videoIds: List<String>.from(json['videoIds'] ?? []),
      collaboratorIds: List<String>.from(json['collaboratorIds'] ?? []),
      createdAt: (json['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      lastEngagement: (json['lastEngagement'] as Timestamp?)?.toDate() ?? DateTime.now(),
      score: (json['score'] as num?)?.toDouble() ?? 0.0,
      likeCount: (json['likeCount'] as num?)?.toInt() ?? 0,
      commentCount: (json['commentCount'] as num?)?.toInt() ?? 0,
      shareCount: (json['shareCount'] as num?)?.toInt() ?? 0,
      totalSessionDuration: Duration(milliseconds: (json['totalSessionDuration'] as num?)?.toInt() ?? 0),
      sessionCount: (json['sessionCount'] as num?)?.toInt() ?? 0,
      videoCompletionRates: (json['videoCompletionRates'] as Map<String, dynamic>?)?.map(
        (key, value) => MapEntry(key, (value as num).toDouble()),
      ) ?? {},
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
    double? score,
    int? likeCount,
    int? commentCount,
    int? shareCount,
    Duration? totalSessionDuration,
    int? sessionCount,
    Map<String, double>? videoCompletionRates,
    DateTime? lastEngagement,
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
      score: score ?? this.score,
      likeCount: likeCount ?? this.likeCount,
      commentCount: commentCount ?? this.commentCount,
      shareCount: shareCount ?? this.shareCount,
      totalSessionDuration: totalSessionDuration ?? this.totalSessionDuration,
      sessionCount: sessionCount ?? this.sessionCount,
      videoCompletionRates: videoCompletionRates ?? this.videoCompletionRates,
      lastEngagement: lastEngagement ?? this.lastEngagement,
    );
  }

  bool canEdit(String userId) {
    return this.userId == userId || collaboratorIds.contains(userId);
  }

  // Analytics helper methods
  double get averageSessionDuration {
    if (sessionCount == 0) return 0;
    return totalSessionDuration.inMilliseconds / sessionCount;
  }

  double get averageVideoCompletionRate {
    if (videoCompletionRates.isEmpty) return 0;
    return videoCompletionRates.values.reduce((a, b) => a + b) / videoCompletionRates.length;
  }

  int get totalEngagements => likeCount + commentCount + shareCount;
} 