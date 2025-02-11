import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SocialService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Like/unlike a project
  Future<void> toggleLike(String projectId) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;

    final likeRef = _firestore
        .collection('projects')
        .doc(projectId)
        .collection('likes')
        .doc(userId);

    final likeDoc = await likeRef.get();
    
    if (likeDoc.exists) {
      await likeRef.delete();
      await _firestore.collection('projects').doc(projectId).update({
        'likeCount': FieldValue.increment(-1),
      });
    } else {
      await likeRef.set({
        'userId': userId,
        'timestamp': FieldValue.serverTimestamp(),
      });
      await _firestore.collection('projects').doc(projectId).update({
        'likeCount': FieldValue.increment(1),
      });
    }
  }

  // Add a comment to a project
  Future<void> addComment(String projectId, String comment) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;

    await _firestore
        .collection('projects')
        .doc(projectId)
        .collection('comments')
        .add({
      'userId': userId,
      'comment': comment,
      'timestamp': FieldValue.serverTimestamp(),
    });

    await _firestore.collection('projects').doc(projectId).update({
      'commentCount': FieldValue.increment(1),
    });
  }

  // Get comments for a project
  Stream<QuerySnapshot> getComments(String projectId) {
    return _firestore
        .collection('projects')
        .doc(projectId)
        .collection('comments')
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  // Check if user has liked a project
  Future<bool> hasUserLiked(String projectId) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return false;

    final likeDoc = await _firestore
        .collection('projects')
        .doc(projectId)
        .collection('likes')
        .doc(userId)
        .get();

    return likeDoc.exists;
  }

  // Share project (returns share URL)
  Future<String> generateShareUrl(String projectId) async {
    // TODO: Implement dynamic links or custom share URL generation
    return 'https://ohftok.app/project/$projectId';
  }
} 