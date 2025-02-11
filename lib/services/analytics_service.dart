import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/project.dart';

class AnalyticsService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Track video view completion
  Future<void> trackVideoCompletion(String projectId, String videoId, double completionRate) async {
    final analyticsRef = _firestore.collection('projects').doc(projectId)
        .collection('analytics').doc('video_completions');
    
    await analyticsRef.set({
      videoId: {
        'completionRate': completionRate,
        'timestamp': FieldValue.serverTimestamp(),
      }
    }, SetOptions(merge: true));
  }

  // Track session duration
  Future<void> updateSessionDuration(String projectId, Duration duration) async {
    final projectRef = _firestore.collection('projects').doc(projectId);
    
    await projectRef.update({
      'totalSessionDuration': FieldValue.increment(duration.inMilliseconds),
      'sessionCount': FieldValue.increment(1),
    });
  }

  // Track user interaction (like, comment, share)
  Future<void> trackInteraction(String projectId, String type) async {
    final projectRef = _firestore.collection('projects').doc(projectId);
    
    switch (type) {
      case 'like':
        await projectRef.update({'likeCount': FieldValue.increment(1)});
        break;
      case 'comment':
        await projectRef.update({'commentCount': FieldValue.increment(1)});
        break;
      case 'share':
        await projectRef.update({'shareCount': FieldValue.increment(1)});
        break;
    }
  }

  // Get project analytics summary
  Future<Map<String, dynamic>> getProjectAnalytics(String projectId) async {
    final projectDoc = await _firestore.collection('projects').doc(projectId).get();
    final videoCompletions = await _firestore
        .collection('projects')
        .doc(projectId)
        .collection('analytics')
        .doc('video_completions')
        .get();

    if (!projectDoc.exists) {
      throw Exception('Project not found');
    }

    final project = Project.fromJson(projectDoc.data()!);
    final completionData = videoCompletions.data() ?? {};

    return {
      'totalSessions': project.sessionCount,
      'averageSessionDuration': project.sessionCount > 0 
          ? Duration(milliseconds: project.totalSessionDuration.inMilliseconds ~/ project.sessionCount)
          : Duration.zero,
      'totalLikes': project.likeCount,
      'totalComments': project.commentCount,
      'videoCompletions': completionData,
    };
  }

  // Get engagement trends over time
  Stream<List<Map<String, dynamic>>> getEngagementTrends(String projectId) {
    return _firestore
        .collection('projects')
        .doc(projectId)
        .collection('analytics')
        .doc('trends')
        .snapshots()
        .map((snapshot) {
          if (!snapshot.exists) return [];
          
          final data = snapshot.data() as Map<String, dynamic>;
          return List<Map<String, dynamic>>.from(data['trends'] ?? []);
        });
  }
} 