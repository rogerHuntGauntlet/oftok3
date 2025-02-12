import 'dart:io';
import 'dart:async';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import 'package:ffmpeg_kit_flutter/ffmpeg_kit.dart';
import 'package:http/http.dart' as http;
import '../models/video.dart';
import '../services/ai_caption_service.dart';
import './video_generation_service.dart';

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

  // Get all videos with validation
  Future<List<Video>> getAllVideos() async {
    try {
      print('\n=== Fetching All Videos ===');
      final snapshot = await _firestore
          .collection('videos')
          .orderBy('uploadedAt', descending: true)
          .get();
          
      print('Found ${snapshot.docs.length} video documents');
      
      final videos = snapshot.docs
          .map((doc) {
            try {
              print('\nProcessing video document: ${doc.id}');
              final data = doc.data();
              data['id'] = doc.id;
              
              // Log raw data for debugging
              print('Raw video data:');
              print(data);
              
              // Validate required fields
              if (data['url']?.toString().isEmpty ?? true) {
                print('❌ Skipping video ${doc.id}: Missing URL');
                print('URL value: ${data['url']}');
                return null;
              }
              if (data['userId']?.toString().isEmpty ?? true) {
                print('❌ Skipping video ${doc.id}: Missing userId');
                print('userId value: ${data['userId']}');
                return null;
              }
              
              final video = Video.fromJson(data);
              print('✓ Successfully parsed video:');
              print('Title: ${video.title}');
              print('URL: ${video.url}');
              print('User ID: ${video.userId}');
              print('Duration: ${video.duration}');
              print('Upload time: ${video.uploadedAt}');
              print('Tags: ${video.tags}');
              return video;
            } catch (e, stackTrace) {
              print('❌ Error parsing video ${doc.id}:');
              print('Error: $e');
              print('Stack trace: $stackTrace');
              return null;
            }
          })
          .where((video) => video != null)
          .cast<Video>()
          .toList();
      
      print('\n=== Video Loading Summary ===');
      print('Total documents: ${snapshot.docs.length}');
      print('Successfully loaded: ${videos.length}');
      print('Failed to load: ${snapshot.docs.length - videos.length}');
      print('===========================\n');
      
      return videos;
    } catch (e, stackTrace) {
      print('❌ Error in getAllVideos:');
      print('Error: $e');
      print('Stack trace: $stackTrace');
      throw Exception('Failed to load videos: $e');
    }
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

      // Log detailed file info
      final metadata = await snapshot.ref.getMetadata();
      print('=== Video Upload Complete ===');
      print('File name: ${metadata.name}');
      print('Full path: ${metadata.fullPath}');
      print('Size: ${metadata.size} bytes');
      print('Content type: ${metadata.contentType}');
      print('Created time: ${metadata.timeCreated}');
      print('Updated time: ${metadata.updated}');
      print('MD5 hash: ${metadata.md5Hash}');
      print('Download URL: $videoUrl');
      print('========================');

      // Generate AI metadata
      print('Generating AI metadata...');
      final aiResponse = await _aiCaptionService.generateProjectDetails(title);
      final String finalTitle = aiResponse['title'] ?? title;
      final String? finalDescription = aiResponse['description'];
      final List<String> finalTags = (aiResponse['tags'] as List<dynamic>?)?.cast<String>() ?? [];

      // Create video document in Firestore with a placeholder thumbnail
      // The actual thumbnail will be generated by the server
      final videoData = Video(
        id: videoId,
        title: finalTitle,
        description: finalDescription,
        url: videoUrl,
        userId: userId,
        uploadedAt: DateTime.now(),
        thumbnailUrl: null, // Will be updated by the server
        duration: duration,
        tags: finalTags,
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
    try {
      print('\n=== Fetching Video: $videoId ===');
      final doc = await _firestore.collection('videos').doc(videoId).get();
      
      if (!doc.exists) {
        print('❌ No video found with ID: $videoId');
        return null;
      }

      print('✓ Document found');
      final data = doc.data()!;
      data['id'] = doc.id;

      // Log raw data
      print('\nRaw video data:');
      print(data);

      // Validate required fields
      if (data['url']?.toString().isEmpty ?? true) {
        print('❌ Video $videoId is missing URL');
        print('URL value: ${data['url']}');
        return null;
      }
      if (data['userId']?.toString().isEmpty ?? true) {
        print('❌ Video $videoId is missing userId');
        print('userId value: ${data['userId']}');
        return null;
      }

      final video = Video.fromJson(data);
      print('\n✓ Successfully parsed video:');
      print('Title: ${video.title}');
      print('URL: ${video.url}');
      print('User ID: ${video.userId}');
      print('Duration: ${video.duration}');
      print('Upload time: ${video.uploadedAt}');
      print('Tags: ${video.tags}');
      print('===========================\n');
      
      return video;
    } catch (e, stackTrace) {
      print('❌ Error fetching video $videoId:');
      print('Error: $e');
      print('Stack trace: $stackTrace');
      return null;
    }
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

  // Create a video from URL
  Future<Video> createVideoFromUrl({
    required String url,
    required String userId,
    required String title,
    required int duration,
    Function(String status, double? progress)? onProgress,
  }) async {
    final String videoId = _uuid.v4();
    final String videoFileName = '$videoId.mp4';
    
    try {
      // Update status: Starting
      onProgress?.call('Starting video creation...', 0);
      print('Creating video from URL for user $userId'); // Debug log
      
      // Download video from URL
      onProgress?.call('Downloading video...', 0.1);
      print('Downloading video from URL: $url'); // Debug log
      final response = await http.get(Uri.parse(url));
      if (response.statusCode != 200) {
        throw Exception('Failed to download video: ${response.statusCode}');
      }

      // Upload to Firebase Storage
      onProgress?.call('Uploading to storage...', 0.2);
      print('Uploading video to Firebase Storage'); // Debug log
      final videoRef = _storage.ref().child('videos/$videoFileName');
      final uploadTask = videoRef.putData(
        response.bodyBytes,
        SettableMetadata(contentType: 'video/mp4'),
      );

      // Monitor upload progress
      uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
        final uploadProgress = snapshot.bytesTransferred / snapshot.totalBytes;
        // Map upload progress to 20-70% of total progress
        final totalProgress = 0.2 + (uploadProgress * 0.5);
        onProgress?.call('Uploading video: ${(uploadProgress * 100).toInt()}%', totalProgress);
      });

      // Wait for upload to complete
      final snapshot = await uploadTask.whenComplete(() {});
      final String firebaseUrl = await snapshot.ref.getDownloadURL();
      
      // Log detailed file info
      final metadata = await snapshot.ref.getMetadata();
      print('=== Video Upload Complete ===');
      print('File name: ${metadata.name}');
      print('Full path: ${metadata.fullPath}');
      print('Size: ${metadata.size} bytes');
      print('Content type: ${metadata.contentType}');
      print('Created time: ${metadata.timeCreated}');
      print('Updated time: ${metadata.updated}');
      print('MD5 hash: ${metadata.md5Hash}');
      print('Download URL: $firebaseUrl');
      print('========================');
      
      // Initialize variables with defaults
      String finalTitle = title;
      String? finalDescription;
      List<String> finalTags = [];

      // Try to generate AI content
      onProgress?.call('Generating AI content...', 0.75);
      try {
        print('Generating AI title, caption and tags'); // Debug log
        final projectDetails = await _aiCaptionService.generateProjectDetails(
          videoId,
          isAiGenerated: true  // Explicitly mark as AI-generated
        );
        finalTitle = projectDetails['title'] ?? title;
        finalDescription = projectDetails['description'];
        finalTags = (projectDetails['tags'] as List<dynamic>?)?.map((tag) => tag.toString()).toList() ?? [];
        print('Generated title: $finalTitle');
        print('Generated description: $finalDescription');
        print('Generated tags: $finalTags');
      } catch (e) {
        print('Failed to generate AI content: $e');
        // Continue with defaults
      }

      // Create video document in Firestore
      onProgress?.call('Saving video details...', 0.95);
      print('Creating video document in Firestore');
      final videoData = Video(
        id: videoId,
        title: finalTitle,
        description: finalDescription,
        url: firebaseUrl,
        userId: userId,
        uploadedAt: DateTime.now(),
        thumbnailUrl: null, // Will be generated by server
        duration: duration,
        tags: finalTags,
        isAiGenerated: true,
      );

      await _firestore
          .collection('videos')
          .doc(videoId)
          .set(videoData.toJson());
      
      print('=== Video Creation Complete ===');
      print('Video ID: $videoId');
      print('Title: $finalTitle');
      print('Description: $finalDescription');
      print('Tags: $finalTags');
      print('Video URL: $firebaseUrl');
      print('========================');
      
      // Final completion status
      onProgress?.call('Video ready!', 1.0);
      
      return videoData;
    } catch (e) {
      print('Error creating video from URL: $e'); // Debug log
      // Clean up the uploaded file if operation fails
      try {
        await _storage.ref().child('videos/$videoFileName').delete();
      } catch (_) {
        // Ignore cleanup errors
      }
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
              // Skip if video already has all metadata
              if (video.description != null && 
                  video.description!.isNotEmpty && 
                  video.tags.isNotEmpty) {
                onProgress?.call(i + 1, total);
                return;
              }

              // Generate AI content
              final aiResponse = await _aiCaptionService.generateProjectDetails(
                video.title,
                isAiGenerated: true  // Explicitly mark as AI-generated
              );

              // Update video with new metadata
              await updateVideoMetadata(
                videoId: video.id,
                title: aiResponse['title'],
                description: aiResponse['description'],
                tags: (aiResponse['tags'] as List<dynamic>?)?.cast<String>(),
              );

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

  // Create a video document from URL
  Future<Video> createVideo({
    required String url,
    required String userId,
    required String projectId,
  }) async {
    final String videoId = _uuid.v4();
    
    try {
      // Generate AI metadata
      print('Generating AI metadata...');
      final aiResponse = await _aiCaptionService.generateProjectDetails(
        'Video for project $projectId',
        isAiGenerated: true,
      );

      // Create video document
      final videoData = Video(
        id: videoId,
        title: aiResponse['title'] ?? 'Generated Video',
        description: aiResponse['description'],
        url: url,
        userId: userId,
        uploadedAt: DateTime.now(),
        thumbnailUrl: null, // Will be generated by server
        duration: 0,  // Will be updated when video is processed
        tags: (aiResponse['tags'] as List<dynamic>?)?.cast<String>() ?? [],
        isAiGenerated: true,
      );

      // Save to Firestore
      await _firestore
          .collection('videos')
          .doc(videoId)
          .set(videoData.toJson());

      return videoData;
    } catch (e) {
      print('Error creating video: $e');
      throw Exception('Failed to create video: $e');
    }
  }

  Future<Video> generateAndSaveVideo({
    required String prompt,
    required String projectId,
    required String userId,
    void Function(VideoGenerationStatus status, double progress)? onProgress,
    void Function(String message)? onError,
  }) async {
    final videoGenerationService = VideoGenerationService();
    String? videoUrl;
    int? generationTime;
    
    try {
      // Generate the video
      onProgress?.call(VideoGenerationStatus.starting, 0.1);
      final result = await videoGenerationService.generateVideo(
        prompt,
        onProgress: onProgress,
        onError: onError,
      );

      if (!result['success']) {
        throw Exception('Failed to generate video: ${result['error']}');
      }

      videoUrl = result['videoUrl'] as String;
      // Clamp generation time between 55-110 seconds
      generationTime = (result['generationTime'] as int).clamp(55, 110);
      
      // Create a video document
      final videoId = _uuid.v4();
      String finalTitle = prompt;
      String? finalDescription;
      List<String> finalTags = [];
      
      // Step 1: Generate AI metadata
      try {
        onProgress?.call(VideoGenerationStatus.processing, 0.8);
        onError?.call('Generating AI content...');
        
        final aiResponse = await _aiCaptionService.generateProjectDetails(
          prompt,
          isAiGenerated: true
        );
        finalTitle = aiResponse['title'] ?? prompt;
        finalDescription = aiResponse['description'];
        finalTags = (aiResponse['tags'] as List<dynamic>?)?.cast<String>() ?? [];
        
        print('Generated AI content:');
        print('Title: $finalTitle');
        print('Description: $finalDescription');
        print('Tags: $finalTags');
      } catch (e) {
        print('Warning: AI content generation failed: $e');
        onError?.call('Warning: Using default content due to AI generation failure');
        // Continue with defaults
      }

      // Step 2: Create and save video document
      onProgress?.call(VideoGenerationStatus.processing, 0.95);
      onError?.call('Saving video details...');
      
      final video = Video(
        id: videoId,
        url: videoUrl,
        title: finalTitle,
        description: finalDescription,
        duration: generationTime,
        uploadedAt: DateTime.now(),
        userId: userId,
        thumbnailUrl: null, // Will be generated by server
        tags: finalTags,
        isAiGenerated: true,
      );

      await _firestore.collection('videos').doc(videoId).set(video.toJson());
      
      onProgress?.call(VideoGenerationStatus.succeeded, 1.0);
      onError?.call('Video created successfully!');
      
      return video;
    } catch (e) {
      print('Error in generateAndSaveVideo: $e');
      onProgress?.call(VideoGenerationStatus.failed, 0);
      onError?.call('Error: ${e.toString()}');
      throw Exception('Failed to generate and save video: $e');
    }
  }
} 