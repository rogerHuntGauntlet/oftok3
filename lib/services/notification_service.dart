import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import '../models/notification.dart';
import 'auth_service.dart';

class NotificationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AuthService _authService = AuthService();
  final _uuid = Uuid();

  // Get notifications for current user
  Stream<List<Notification>> getNotifications() {
    final userId = _authService.currentUserId;
    if (userId == null) return Stream.value([]);

    return _firestore
        .collection('notifications')
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Notification.fromJson({...doc.data(), 'id': doc.id}))
            .toList());
  }

  // Create a new notification
  Future<void> createNotification({
    required String userId,
    required String title,
    required String message,
    String? projectId,
    String? videoId,
  }) async {
    final notification = Notification(
      id: _uuid.v4(),
      userId: userId,
      title: title,
      message: message,
      projectId: projectId,
      videoId: videoId,
      createdAt: DateTime.now(),
    );

    await _firestore
        .collection('notifications')
        .doc(notification.id)
        .set(notification.toJson());
  }

  // Mark a notification as read
  Future<void> markAsRead(String notificationId) async {
    await _firestore
        .collection('notifications')
        .doc(notificationId)
        .update({'isRead': true});
  }

  // Mark all notifications as read
  Future<void> markAllAsRead() async {
    final userId = _authService.currentUserId;
    if (userId == null) return;

    final batch = _firestore.batch();
    final notifications = await _firestore
        .collection('notifications')
        .where('userId', isEqualTo: userId)
        .where('isRead', isEqualTo: false)
        .get();

    for (var doc in notifications.docs) {
      batch.update(doc.reference, {'isRead': true});
    }

    await batch.commit();
  }

  // Delete a notification
  Future<void> deleteNotification(String notificationId) async {
    await _firestore.collection('notifications').doc(notificationId).delete();
  }

  // Create a video added notification
  Future<void> notifyVideoAdded({
    required String userId,
    required String projectName,
    required String projectId,
    required String videoId,
  }) async {
    await createNotification(
      userId: userId,
      title: 'New Video Added',
      message: 'A new video has been added to your project: $projectName',
      projectId: projectId,
      videoId: videoId,
    );
  }
} 