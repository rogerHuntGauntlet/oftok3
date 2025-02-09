import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import '../models/video.dart';

class VideoService {
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final _uuid = Uuid();

  // Get all videos not in a specific project
  Future<List<Video>> getAvailableVideos(List<String> excludeVideoIds) async {
    try {
      print('Getting available videos, excluding: $excludeVideoIds'); // Debug print
      QuerySnapshot snapshot;
      
      if (excludeVideoIds.isEmpty) {
        print('No videos to exclude, getting all videos'); // Debug print
        snapshot = await _firestore
            .collection('videos')
            .orderBy('uploadedAt', descending: true)
            .get();
      } else {
        // Firestore has a limit of 10 items in a whereNotIn query
        // So we'll get all videos and filter in memory if the list is too long
        if (excludeVideoIds.length > 10) {
          print('More than 10 videos to exclude, filtering in memory'); // Debug print
          snapshot = await _firestore
              .collection('videos')
              .orderBy('uploadedAt', descending: true)
              .get();
              
          final allVideos = snapshot.docs.map((doc) {
            try {
              final data = doc.data() as Map<String, dynamic>;
              data['id'] = doc.id; // Ensure the ID is included
              return Video.fromJson(data);
            } catch (e) {
              print('Error parsing video document ${doc.id}: $e');
              return null;
            }
          })
          .where((video) => video != null)
          .cast<Video>()
          .where((video) => !excludeVideoIds.contains(video.id))
          .toList();
          
          print('Found ${allVideos.length} available videos'); // Debug print
          return allVideos;
        } else {
          print('Using whereNotIn query for ${excludeVideoIds.length} videos'); // Debug print
          snapshot = await _firestore
              .collection('videos')
              .where(FieldPath.documentId, whereNotIn: excludeVideoIds)
              .orderBy('uploadedAt', descending: true)
              .get();
        }
      }
      
      final videos = snapshot.docs.map((doc) {
        try {
          final data = doc.data() as Map<String, dynamic>;
          data['id'] = doc.id; // Ensure the ID is included
          return Video.fromJson(data);
        } catch (e) {
          print('Error parsing video document ${doc.id}: $e');
          return null;
        }
      })
      .where((video) => video != null)
      .cast<Video>()
      .toList();
      
      print('Found ${videos.length} available videos'); // Debug print
      return videos;
    } catch (e) {
      print('Error in getAvailableVideos: $e');
      throw Exception('Failed to load available videos: $e');
    }
  }

  // Get all videos
  Future<List<Video>> getAllVideos() async {
    final snapshot = await _firestore
        .collection('videos')
        .orderBy('uploadedAt', descending: true)
        .get();
        
    return snapshot.docs
        .map((doc) => Video.fromJson(doc.data() as Map<String, dynamic>))
        .where((video) => video != null)
        .toList();
  }

  // Upload a video file and create video document
  Future<Video> uploadVideo({
    required File videoFile,
    required String userId,
    required String title,
    required int duration,
    Function(double)? onProgress,
  }) async {
    final String videoId = _uuid.v4();
    final String videoFileName = '$videoId.mp4';
    
    try {
      // Upload video to Firebase Storage with progress monitoring
      final videoRef = _storage.ref().child('videos/$videoFileName');
      final uploadTask = videoRef.putFile(
        videoFile,
        SettableMetadata(contentType: 'video/mp4'),
      );

      // Monitor upload progress
      uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
        final progress = snapshot.bytesTransferred / snapshot.totalBytes;
        onProgress?.call(progress);
      });

      // Get video URL
      final snapshot = await uploadTask.whenComplete(() {});
      final String videoUrl = await snapshot.ref.getDownloadURL();

      // Create video document in Firestore
      final videoData = Video(
        id: videoId,
        title: title,
        url: videoUrl,
        userId: userId,
        uploadedAt: DateTime.now(),
        thumbnailUrl: '', // Empty for now
        duration: duration,
      );

      await _firestore
          .collection('videos')
          .doc(videoId)
          .set(videoData.toJson());

      return videoData;
    } catch (e) {
      // Clean up the uploaded file if operation fails
      try {
        await _storage.ref().child('videos/$videoFileName').delete();
      } catch (_) {
        // Ignore cleanup errors
      }
      throw Exception('Failed to upload video: $e');
    }
  }

  // Get videos for a project
  Future<List<Video>> getProjectVideos(List<String> videoIds) async {
    if (videoIds.isEmpty) return [];

    try {
      print('Getting videos for IDs: $videoIds'); // Debug print
      final snapshots = await Future.wait(
        videoIds.map((id) => _firestore.collection('videos').doc(id).get()),
      );

      final videos = snapshots
          .where((snap) => snap.exists)
          .map((snap) {
            try {
              final data = snap.data()!;
              data['id'] = snap.id; // Ensure the ID is included
              return Video.fromJson(data);
            } catch (e) {
              print('Error parsing video document ${snap.id}: $e');
              return null;
            }
          })
          .where((video) => video != null)
          .cast<Video>()
          .toList();
          
      print('Found ${videos.length} videos out of ${videoIds.length} requested'); // Debug print
      return videos;
    } catch (e) {
      print('Error in getProjectVideos: $e');
      throw Exception('Failed to load project videos: $e');
    }
  }

  // Delete a video
  Future<void> deleteVideo(String videoId) async {
    // Delete from Storage
    final videoRef = _storage.ref().child('videos/$videoId.mp4');
    await videoRef.delete();

    // Delete from Firestore
    await _firestore.collection('videos').doc(videoId).delete();
  }

  // Get a single video
  Future<Video?> getVideo(String videoId) async {
    final doc = await _firestore.collection('videos').doc(videoId).get();
    if (!doc.exists) return null;
    return Video.fromJson(doc.data()!);
  }
} 