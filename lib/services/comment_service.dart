import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import '../models/comment.dart';

class CommentService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final _uuid = Uuid();

  // Common emojis for reactions
  static const defaultEmojis = ['❤️', '😂', '😮', '😢', '😡', '👍'];

  // Get top-level comments for a video
  Stream<List<Comment>> getVideoComments(String videoId) {
    return _firestore
        .collection('comments')
        .where('videoId', isEqualTo: videoId)
        .where('parentId', isNull: true)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => Comment.fromJson(doc.data())).toList());
  }

  // Get replies for a comment
  Stream<List<Comment>> getCommentReplies(String commentId) {
    return _firestore
        .collection('comments')
        .where('parentId', isEqualTo: commentId)
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => Comment.fromJson(doc.data())).toList());
  }

  // Add a new comment
  Future<Comment> addComment({
    required String videoId,
    required String userId,
    required String text,
    String? parentId,
  }) async {
    final commentId = _uuid.v4();
    final comment = Comment(
      id: commentId,
      videoId: videoId,
      userId: userId,
      text: text,
      createdAt: DateTime.now(),
      likedBy: [],
      parentId: parentId,
    );

    await _firestore
        .collection('comments')
        .doc(commentId)
        .set(comment.toJson());

    // If this is a reply, increment the parent comment's reply count
    if (parentId != null) {
      await _firestore.collection('comments').doc(parentId).update({
        'replyCount': FieldValue.increment(1),
      });
    }

    return comment;
  }

  // Edit a comment
  Future<void> editComment(String commentId, String newText) async {
    await _firestore.collection('comments').doc(commentId).update({
      'text': newText,
      'editedAt': FieldValue.serverTimestamp(),
    });
  }

  // Toggle reaction on a comment
  Future<void> toggleReaction(String commentId, String emoji, String userId) async {
    final docRef = _firestore.collection('comments').doc(commentId);
    
    await _firestore.runTransaction((transaction) async {
      final doc = await transaction.get(docRef);
      if (!doc.exists) return;

      final comment = Comment.fromJson(doc.data()!);
      final reactions = Map<String, List<String>>.from(comment.reactions);
      
      if (!reactions.containsKey(emoji)) {
        reactions[emoji] = [];
      }

      final userReactions = reactions[emoji]!;
      if (userReactions.contains(userId)) {
        userReactions.remove(userId);
        if (userReactions.isEmpty) {
          reactions.remove(emoji);
        }
      } else {
        userReactions.add(userId);
      }

      transaction.update(docRef, {'reactions': reactions});
    });
  }

  // Toggle like on a comment
  Future<void> toggleLike(String commentId, String userId) async {
    final docRef = _firestore.collection('comments').doc(commentId);
    
    await _firestore.runTransaction((transaction) async {
      final doc = await transaction.get(docRef);
      if (!doc.exists) return;

      final comment = Comment.fromJson(doc.data()!);
      final likedBy = List<String>.from(comment.likedBy);

      if (likedBy.contains(userId)) {
        likedBy.remove(userId);
      } else {
        likedBy.add(userId);
      }

      transaction.update(docRef, {'likedBy': likedBy});
    });
  }

  // Delete a comment
  Future<void> deleteComment(String commentId) async {
    final commentDoc = await _firestore.collection('comments').doc(commentId).get();
    if (!commentDoc.exists) return;

    final comment = Comment.fromJson(commentDoc.data()!);

    // If this is a reply, decrement the parent's reply count
    if (comment.parentId != null) {
      await _firestore.collection('comments').doc(comment.parentId).update({
        'replyCount': FieldValue.increment(-1),
      });
    }

    // Delete the comment
    await _firestore.collection('comments').doc(commentId).delete();

    // If this is a parent comment, delete all replies
    if (comment.parentId == null) {
      final replies = await _firestore
          .collection('comments')
          .where('parentId', isEqualTo: commentId)
          .get();

      for (final reply in replies.docs) {
        await reply.reference.delete();
      }
    }
  }
} 