class Notification {
  final String id;
  final String userId;
  final String title;
  final String message;
  final String? projectId;
  final String? videoId;
  final DateTime createdAt;
  final bool isRead;

  Notification({
    required this.id,
    required this.userId,
    required this.title,
    required this.message,
    this.projectId,
    this.videoId,
    required this.createdAt,
    this.isRead = false,
  });

  factory Notification.fromJson(Map<String, dynamic> json) {
    return Notification(
      id: json['id'] as String,
      userId: json['userId'] as String,
      title: json['title'] as String,
      message: json['message'] as String,
      projectId: json['projectId'] as String?,
      videoId: json['videoId'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      isRead: json['isRead'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'title': title,
      'message': message,
      'projectId': projectId,
      'videoId': videoId,
      'createdAt': createdAt.toIso8601String(),
      'isRead': isRead,
    };
  }

  Notification copyWith({
    String? id,
    String? userId,
    String? title,
    String? message,
    String? projectId,
    String? videoId,
    DateTime? createdAt,
    bool? isRead,
  }) {
    return Notification(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      message: message ?? this.message,
      projectId: projectId ?? this.projectId,
      videoId: videoId ?? this.videoId,
      createdAt: createdAt ?? this.createdAt,
      isRead: isRead ?? this.isRead,
    );
  }
} 