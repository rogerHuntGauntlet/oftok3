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
        .map((doc) {
          try {
            final data = doc.data();
            data['id'] = doc.id; // Ensure ID is included
            return Video.fromJson(data);
          } catch (e) {
            print('Error parsing video document ${doc.id}: $e');
            return null;
          }
        })
        .where((video) => video != null)
        .cast<Video>()
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

      // Generate AI caption and tags
      final aiResponse = await _aiCaptionService.generateAICaption(title);

      // Create video document in Firestore
      final videoData = Video(
        id: videoId,
        title: title,
        description: aiResponse['caption'],
        url: videoUrl,
        userId: userId,
        uploadedAt: DateTime.now(),
        thumbnailUrl: '', // Empty for now
        duration: duration,
        tags: aiResponse['tags'],
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

  // Update video metadata
  Future<Video> updateVideoMetadata({
    required String videoId,
    String? title,
    String? description,
    String? thumbnailUrl,
    List<String>? tags,
  }) async {
    final videoDoc = await _firestore.collection('videos').doc(videoId).get();
    if (!videoDoc.exists) {
      throw Exception('Video not found');
    }

    final video = Video.fromJson(videoDoc.data()!);
    final updatedVideo = video.copyWith(
      title: title,
      description: description,
      thumbnailUrl: thumbnailUrl,
      tags: tags,
    );

    await _firestore
        .collection('videos')
        .doc(videoId)
        .update(updatedVideo.toJson());

    return updatedVideo;
  }

  // Generate AI caption for a video
  Future<Video> generateAICaption(String videoId) async {
    final video = await getVideo(videoId);
    if (video == null) {
      throw Exception('Video not found');
    }

    try {
      // Generate caption and tags using AI
      final aiResponse = await _aiCaptionService.generateAICaption(video.title);
      
      // Update video with new caption and tags
      return await updateVideoMetadata(
        videoId: videoId,
        description: aiResponse['caption'],
        tags: aiResponse['tags'],
      );
    } catch (e) {
      print('Error generating AI caption: $e');
      throw Exception('Failed to generate AI caption: $e');
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

  Future<Video> createVideoFromUrl({
    required String url,
    required String userId,
    required String title,
    required int duration,
  }) async {
    try {
      // Generate AI caption and tags
      final aiResponse = await _aiCaptionService.generateAICaption(title);

      final videoDoc = await _firestore.collection('videos').add({
        'url': url,
        'userId': userId,
        'title': title,
        'description': aiResponse['caption'],
        'duration': duration,
        'thumbnailUrl': '', // AI videos might not have thumbnails
        'uploadedAt': FieldValue.serverTimestamp(),
        'tags': aiResponse['tags'],
        'views': 0,
        'likedBy': [],
        'isAiGenerated': true,
      });

      return Video(
        id: videoDoc.id,
        url: url,
        userId: userId,
        title: title,
        description: aiResponse['caption'],
        duration: duration,
        thumbnailUrl: '',
        uploadedAt: DateTime.now(),
        tags: aiResponse['tags'],
        views: 0,
        likedBy: [],
      );
    } catch (e) {
      throw Exception('Failed to create video from URL: $e');
    }
  }

  // Batch update all existing videos with AI captions and tags
  Future<void> batchUpdateAllVideosWithAI({
    Function(int total)? onTotalVideos,
    Function(int current, int total)? onProgress,
    Function(String videoId, dynamic error)? onError,
  }) async {
    try {
      // Get all videos
      final videos = await getAllVideos();
      final total = videos.length;
      onTotalVideos?.call(total);

      // Process videos in batches to avoid rate limiting
      const batchSize = 5;
      for (var i = 0; i < videos.length; i += batchSize) {
        final batch = videos.skip(i).take(batchSize);
        
        // Process batch concurrently
        await Future.wait(
          batch.map((video) async {
            try {
              // Skip if video already has both description and tags
              if (video.description != null && 
                  video.description!.isNotEmpty && 
                  video.tags.isNotEmpty) {
                onProgress?.call(i + 1, total);
                return;
              }

              // Generate new caption and tags
              await generateAICaption(video.id);
              onProgress?.call(i + 1, total);
            } catch (e) {
              print('Error processing video ${video.id}: $e');
              onError?.call(video.id, e);
            }
          }),
        );

        // Add a small delay between batches to avoid rate limiting
        if (i + batchSize < videos.length) {
          await Future.delayed(const Duration(seconds: 2));
        }
      }
    } catch (e) {
      print('Error in batch update: $e');
      throw Exception('Failed to batch update videos: $e');
    }
  }
} 