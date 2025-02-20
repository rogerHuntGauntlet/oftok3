import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/comment.dart';

class SocialService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Like/unlike a project
  Future<void> toggleLike(String projectId) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Must be signed in to like');

    final projectRef = _firestore.collection('projects').doc(projectId);

    return _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(projectRef);
      if (!snapshot.exists) throw Exception('Project not found');

      final likedBy = List<String>.from(snapshot.data()?['likedBy'] ?? []);
      final isLiked = likedBy.contains(user.uid);

      if (isLiked) {
        likedBy.remove(user.uid);
        transaction.update(projectRef, {
          'likedBy': likedBy,
          'likeCount': FieldValue.increment(-1),
        });
      } else {
        likedBy.add(user.uid);
        transaction.update(projectRef, {
          'likedBy': likedBy,
          'likeCount': FieldValue.increment(1),
        });
      }
    });
  }

  // Get like status stream for a project
  Stream<bool> getLikeStatus(String projectId) {
    final user = _auth.currentUser;
    if (user == null) return Stream.value(false);

    return _firestore
        .collection('projects')
        .doc(projectId)
        .snapshots()
        .map((doc) {
          if (!doc.exists) return false;
          final likedBy = List<String>.from(doc.data()?['likedBy'] ?? []);
          return likedBy.contains(user.uid);
        });
  }

  // Add a comment to a project
  Future<void> addComment({
    required String projectId,
    required String text,
    required String authorId,
    required String authorName,
  }) async {
    final comment = Comment(
      id: '', // Will be set by Firestore
      projectId: projectId,
      text: text,
      authorId: authorId,
      authorName: authorName,
      createdAt: DateTime.now(),
      editedAt: null,
      likedBy: [],
      replyCount: 0,
    );

    await _firestore
        .collection('projects')
        .doc(projectId)
        .collection('comments')
        .add(comment.toJson());
  }

  // Get comments for a project
  Stream<List<Comment>> getComments(String projectId) {
    return _firestore
        .collection('projects')
        .doc(projectId)
        .collection('comments')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Comment.fromJson({...doc.data(), 'id': doc.id}))
            .toList());
  }

  // Check if user has liked a project
  Future<bool> hasUserLiked(String projectId) async {
    final user = _auth.currentUser;
    if (user == null) return false;

    final doc = await _firestore.collection('projects').doc(projectId).get();
    if (!doc.exists) return false;

    final likedBy = List<String>.from(doc.data()?['likedBy'] ?? []);
    return likedBy.contains(user.uid);
  }

  // Share project (returns share URL)
  Future<String> generateShareUrl(String projectId) async {
    // TODO: Implement dynamic links or custom share URL generation
    return 'https://ohftok.app/project/$projectId';
  }

  // Get comment like status
  Stream<bool> getCommentLikeStatus(String projectId, String commentId) {
    final user = _auth.currentUser;
    if (user == null) return Stream.value(false);

    return _firestore
        .collection('projects')
        .doc(projectId)
        .collection('comments')
        .doc(commentId)
        .snapshots()
        .map((snapshot) {
      if (!snapshot.exists) return false;
      final comment = Comment.fromJson({...snapshot.data()!, 'id': snapshot.id});
      return comment.likedBy.contains(user.uid);
    });
  }

  // Toggle comment like
  Future<void> toggleCommentLike(String projectId, String commentId) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final docRef = _firestore
        .collection('projects')
        .doc(projectId)
        .collection('comments')
        .doc(commentId);

    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(docRef);
      if (!snapshot.exists) return;

      final comment = Comment.fromJson({...snapshot.data()!, 'id': snapshot.id});
      final userId = user.uid;
      final likedBy = List<String>.from(comment.likedBy);

      if (likedBy.contains(userId)) {
        likedBy.remove(userId);
      } else {
        likedBy.add(userId);
      }

      transaction.update(docRef, {'likedBy': likedBy});
    });
  }

  // Add a reply to a comment
  Future<void> addReply(String projectId, String commentId, String text) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Must be signed in to reply');

    await _firestore
        .collection('projects')
        .doc(projectId)
        .collection('comments')
        .doc(commentId)
        .collection('replies')
        .add({
          'text': text,
          'userId': user.uid,
          'userName': user.displayName ?? 'Anonymous',
          'userPhoto': user.photoURL,
          'timestamp': FieldValue.serverTimestamp(),
        });
  }

  // Get replies for a comment
  Stream<QuerySnapshot> getReplies(String projectId, String commentId) {
    return _firestore
        .collection('projects')
        .doc(projectId)
        .collection('comments')
        .doc(commentId)
        .collection('replies')
        .orderBy('timestamp', descending: false)
        .snapshots();
  }

  // Add a reaction to a comment
  Future<void> addReaction(String projectId, String commentId, String emoji) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Must be signed in to react');

    final commentRef = _firestore
        .collection('projects')
        .doc(projectId)
        .collection('comments')
        .doc(commentId);

    return _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(commentRef);
      if (!snapshot.exists) throw Exception('Comment not found');

      final reactions = Map<String, dynamic>.from(snapshot.data()?['reactions'] ?? {});
      
      // If user already reacted with this emoji, remove it
      if (reactions[emoji]?[user.uid] == true) {
        reactions[emoji].remove(user.uid);
        if (reactions[emoji].isEmpty) {
          reactions.remove(emoji);
        }
      } else {
        // Add new reaction
        if (!reactions.containsKey(emoji)) {
          reactions[emoji] = {user.uid: true};
        } else {
          reactions[emoji][user.uid] = true;
        }
      }

      transaction.update(commentRef, {'reactions': reactions});
    });
  }

  Future<void> deleteComment(String projectId, String commentId) async {
    await _firestore
        .collection('projects')
        .doc(projectId)
        .collection('comments')
        .doc(commentId)
        .delete();
  }
} 