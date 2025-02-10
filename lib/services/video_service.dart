import 'dart:io';
import 'dart:async';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import 'package:ffmpeg_kit_flutter/ffmpeg_kit.dart';
import '../models/video.dart';
import '../services/ai_caption_service.dart';

class VideoService {
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final _uuid = Uuid();
  final _aiCaptionService = AICaptionService();

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

  // Generate AI caption and thumbnail for a video
  Future<Video> generateAICaption(String videoId) async {
    File? tempFile;
    String? thumbnailUrl;
    String? caption;
    
    try {
      // Get the video details
      final video = await getVideo(videoId);
      if (video == null) throw Exception('Video not found');

      // Try to generate thumbnail
      try {
        print('Attempting to generate thumbnail...');
        
        // Create temporary file path for the thumbnail
        final tempDir = await getTemporaryDirectory();
        final thumbnailPath = '${tempDir.path}/${videoId}_thumb.jpg';
        
        // Use FFmpeg to extract a frame at 1 second mark
        final result = await FFmpegKit.execute(
          '-y -i "${video.url}" -ss 00:00:01.000 -vframes 1 -vf "scale=720:-1" -q:v 2 "$thumbnailPath"'
        );

        if (result.getReturnCode() == 0) {
          tempFile = File(thumbnailPath);
          if (await tempFile.exists()) {
            print('Thumbnail generated at: $thumbnailPath');

            // Upload thumbnail to Firebase Storage
            print('Uploading thumbnail to Firebase Storage...');
            final thumbnailRef = _storage.ref().child('thumbnails/$videoId.jpg');
            await thumbnailRef.putFile(
              tempFile,
              SettableMetadata(contentType: 'image/jpeg'),
            );
            thumbnailUrl = await thumbnailRef.getDownloadURL();
            print('Thumbnail uploaded successfully: $thumbnailUrl');
          }
        }
      } catch (e) {
        print('Error generating/uploading thumbnail: $e');
        // Continue with caption generation even if thumbnail fails
      }

      // Generate caption using AI
      try {
        print('Generating AI caption...');
        final prompt = 'Generate a creative caption for a video titled: ${video.title}';
        caption = await _aiCaptionService.generateAICaption(prompt);
        print('Caption generated: $caption');
      } catch (e) {
        print('Error generating caption: $e');
        throw Exception('Failed to generate caption: $e');
      }

      // Update video document with whatever we have (caption and/or thumbnail)
      print('Updating video document...');
      final updates = <String, dynamic>{};
      if (caption != null) updates['caption'] = caption;
      if (thumbnailUrl != null) updates['thumbnailUrl'] = thumbnailUrl;
      
      await _firestore
          .collection('videos')
          .doc(videoId)
          .update(updates);

      // Return updated video object
      return Video(
        id: video.id,
        title: video.title,
        url: video.url,
        userId: video.userId,
        uploadedAt: video.uploadedAt,
        thumbnailUrl: thumbnailUrl ?? video.thumbnailUrl,
        duration: video.duration,
        caption: caption ?? video.caption,
      );
    } catch (e) {
      print('Error in generateAICaption: $e');
      throw Exception('Failed to generate caption and thumbnail: $e');
    } finally {
      // Clean up resources
      try {
        if (tempFile != null && await tempFile.exists()) {
          await tempFile.delete();
        }
      } catch (e) {
        print('Error cleaning up temp file: $e');
      }
    }
  }

  // Update video caption
  Future<void> updateVideoCaption(String videoId, String caption) async {
    try {
      await _firestore
          .collection('videos')
          .doc(videoId)
          .update({'caption': caption});
    } catch (e) {
      throw Exception('Failed to update video caption: $e');
    }
  }
} 