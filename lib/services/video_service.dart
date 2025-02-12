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

  // Convert video to HLS format
  Future<String> convertVideoToHLS(File videoFile, String videoId) async {
    try {
      // Create temporary directory for HLS files
      final tempDir = await getTemporaryDirectory();
      final hlsDir = Directory('${tempDir.path}/hls_$videoId');
      await hlsDir.create(recursive: true);

      final outputPath = '${hlsDir.path}/playlist.m3u8';
      
      // FFmpeg command for HLS conversion with multiple quality levels
      final command = '-i ${videoFile.path} '
          '-filter_complex "[0:v]split=3[v1][v2][v3]; '
          '[v1]scale=w=640:h=360[v1out]; [v2]scale=w=842:h=480[v2out]; [v3]scale=w=1280:h=720[v3out]" '
          '-map "[v1out]" -map "[v2out]" -map "[v3out]" -map 0:a -map 0:a -map 0:a '
          '-c:v libx264 -crf 22 -c:a aac -ar 48000 '
          '-var_stream_map "v:0,a:0,name:360p v:1,a:1,name:480p v:2,a:2,name:720p" '
          '-master_pl_name master.m3u8 '
          '-f hls -hls_time 6 -hls_list_size 0 '
          '-hls_segment_filename "${hlsDir.path}/%v_segment%d.ts" '
          '$outputPath';

      // Execute FFmpeg command
      final session = await FFmpegKit.execute(command);
      final returnCode = await session.getReturnCode();

      if (returnCode?.isValueSuccess() ?? false) {
        return hlsDir.path;
      } else {
        final logs = await session.getLogs();
        throw Exception('FFmpeg conversion failed: ${logs.join("\n")}');
      }
    } catch (e) {
      throw Exception('Failed to convert video to HLS: $e');
    }
  }

  // Upload HLS files to Firebase Storage
  Future<String> uploadHLSFiles(String hlsDirPath, String videoId) async {
    try {
      final hlsDir = Directory(hlsDirPath);
      final List<FileSystemEntity> files = await hlsDir.list().toList();
      
      // Upload each file
      for (var file in files) {
        if (file is File) {
          final fileName = file.path.split('/').last;
          final ref = _storage.ref().child('videos/$videoId/hls/$fileName');
          
          // Set appropriate content type
          String contentType = 'application/octet-stream';
          if (fileName.endsWith('.m3u8')) {
            contentType = 'application/x-mpegURL';
          } else if (fileName.endsWith('.ts')) {
            contentType = 'video/MP2T';
          }
          
          await ref.putFile(
            file,
            SettableMetadata(contentType: contentType),
          );
        }
      }
      
      // Get the master playlist URL
      final masterUrl = await _storage
          .ref()
          .child('videos/$videoId/hls/master.m3u8')
          .getDownloadURL();
          
      return masterUrl;
    } catch (e) {
      throw Exception('Failed to upload HLS files: $e');
    } finally {
      // Cleanup temporary directory
      try {
        await Directory(hlsDirPath).delete(recursive: true);
      } catch (e) {
        print('Warning: Failed to cleanup temporary HLS directory: $e');
      }
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
    String? hlsUrl;
    String? thumbnailUrl;
    
    try {
      // Upload original video to Firebase Storage with progress monitoring
      final videoRef = _storage.ref().child('videos/$videoFileName');
      final uploadTask = videoRef.putFile(
        videoFile,
        SettableMetadata(contentType: 'video/mp4'),
      );

      // Monitor upload progress
      uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
        final progress = snapshot.bytesTransferred / snapshot.totalBytes;
        onProgress?.call(progress * 0.3); // 30% progress for initial upload
      });

      // Get video URL
      final snapshot = await uploadTask.whenComplete(() {});
      final String videoUrl = await snapshot.ref.getDownloadURL();

      // Generate thumbnail
      onProgress?.call(0.4); // 40% progress
      thumbnailUrl = await generateAndUploadThumbnail(videoFile, videoId);

      // Convert video to HLS
      onProgress?.call(0.5); // 50% progress after thumbnail
      final hlsDirPath = await convertVideoToHLS(videoFile, videoId);
      
      // Upload HLS files
      onProgress?.call(0.7); // 70% progress after conversion
      hlsUrl = await uploadHLSFiles(hlsDirPath, videoId);
      onProgress?.call(0.9); // 90% progress after HLS upload

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
      print('HLS URL: $hlsUrl');
      print('Thumbnail URL: $thumbnailUrl');
      print('========================');

      // Generate AI metadata
      print('Generating AI metadata...');
      final aiResponse = await _aiCaptionService.generateProjectDetails(title);
      final String finalTitle = aiResponse['title'] ?? title;
      final String? finalDescription = aiResponse['description'];
      final List<String> finalTags = (aiResponse['tags'] as List<dynamic>?)?.cast<String>() ?? [];

      onProgress?.call(1.0); // 100% progress

      // Create video document in Firestore
      final videoData = Video(
        id: videoId,
        title: finalTitle,
        description: finalDescription,
        url: videoUrl,
        hlsUrl: hlsUrl,
        thumbnailUrl: thumbnailUrl,
        userId: userId,
        uploadedAt: DateTime.now(),
        duration: duration,
        tags: finalTags,
      );

      await _firestore
          .collection('videos')
          .doc(videoId)
          .set(videoData.toJson());

      return videoData;
    } catch (e) {
      // Clean up the uploaded files if operation fails
      try {
        await _storage.ref().child('videos/$videoFileName').delete();
        await _storage.ref().child('videos/$videoId/hls').delete();
        if (thumbnailUrl != null) {
          await _storage.ref().child('thumbnails/$videoId.jpg').delete();
        }
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
    String? hlsUrl;
    
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

      // Create a temporary file for the downloaded video
      final tempDir = await getTemporaryDirectory();
      final tempFile = File('${tempDir.path}/$videoFileName');
      await tempFile.writeAsBytes(response.bodyBytes);

      // Upload to Firebase Storage
      onProgress?.call('Uploading to storage...', 0.2);
      print('Uploading video to Firebase Storage'); // Debug log
      final videoRef = _storage.ref().child('videos/$videoFileName');
      final uploadTask = videoRef.putFile(
        tempFile,
        SettableMetadata(contentType: 'video/mp4'),
      );

      // Monitor upload progress
      uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
        final uploadProgress = snapshot.bytesTransferred / snapshot.totalBytes;
        // Map upload progress to 20-40% of total progress
        final totalProgress = 0.2 + (uploadProgress * 0.2);
        onProgress?.call('Uploading video: ${(uploadProgress * 100).toInt()}%', totalProgress);
      });

      // Wait for upload to complete
      final snapshot = await uploadTask.whenComplete(() {});
      final String firebaseUrl = await snapshot.ref.getDownloadURL();

      // Convert to HLS
      onProgress?.call('Converting to HLS format...', 0.5);
      final hlsDirPath = await convertVideoToHLS(tempFile, videoId);
      
      // Upload HLS files
      onProgress?.call('Uploading HLS files...', 0.7);
      hlsUrl = await uploadHLSFiles(hlsDirPath, videoId);
      
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
      print('HLS URL: $hlsUrl');
      print('========================');
      
      // Initialize variables with defaults
      String finalTitle = title;
      String? finalDescription;
      List<String> finalTags = [];

      // Try to generate AI content
      onProgress?.call('Generating AI content...', 0.8);
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
        hlsUrl: hlsUrl,
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
      print('HLS URL: $hlsUrl');
      print('========================');
      
      // Cleanup temporary file
      try {
        await tempFile.delete();
      } catch (e) {
        print('Warning: Failed to delete temporary file: $e');
      }
      
      // Final completion status
      onProgress?.call('Video ready!', 1.0);
      
      return videoData;
    } catch (e) {
      print('Error creating video from URL: $e'); // Debug log
      // Clean up the uploaded files if operation fails
      try {
        await _storage.ref().child('videos/$videoFileName').delete();
        await _storage.ref().child('videos/$videoId/hls').delete();
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
    String? hlsUrl;
    String? thumbnailUrl;
    int? generationTime;
    File? tempFile;
    
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

      // Download the generated video to a temporary file
      final tempDir = await getTemporaryDirectory();
      final videoId = _uuid.v4();
      tempFile = File('${tempDir.path}/$videoId.mp4');
      
      onProgress?.call(VideoGenerationStatus.processing, 0.3);
      onError?.call('Downloading generated video...');
      
      final response = await http.get(Uri.parse(result['videoUrl']));
      await tempFile.writeAsBytes(response.bodyBytes);
      
      // Generate thumbnail
      onProgress?.call(VideoGenerationStatus.processing, 0.4);
      onError?.call('Generating thumbnail...');
      thumbnailUrl = await generateAndUploadThumbnail(tempFile, videoId);
      
      // Upload original video to Firebase
      onProgress?.call(VideoGenerationStatus.processing, 0.5);
      onError?.call('Uploading video...');
      
      final videoRef = _storage.ref().child('videos/$videoId.mp4');
      final uploadTask = videoRef.putFile(
        tempFile,
        SettableMetadata(contentType: 'video/mp4'),
      );
      
      // Wait for upload to complete
      final snapshot = await uploadTask.whenComplete(() {});
      videoUrl = await snapshot.ref.getDownloadURL();
      
      // Convert to HLS
      onProgress?.call(VideoGenerationStatus.processing, 0.7);
      onError?.call('Converting to HLS format...');
      final hlsDirPath = await convertVideoToHLS(tempFile, videoId);
      
      // Upload HLS files
      onProgress?.call(VideoGenerationStatus.processing, 0.8);
      onError?.call('Uploading HLS files...');
      hlsUrl = await uploadHLSFiles(hlsDirPath, videoId);

      // Clamp generation time between 55-110 seconds
      generationTime = (result['generationTime'] as int).clamp(55, 110);
      
      // Create a video document
      String finalTitle = prompt;
      String? finalDescription;
      List<String> finalTags = [];
      
      // Generate AI metadata
      try {
        onProgress?.call(VideoGenerationStatus.processing, 0.9);
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

      // Create and save video document
      onProgress?.call(VideoGenerationStatus.processing, 0.95);
      onError?.call('Saving video details...');
      
      final video = Video(
        id: videoId,
        url: videoUrl!,
        hlsUrl: hlsUrl,
        thumbnailUrl: thumbnailUrl,
        title: finalTitle,
        description: finalDescription,
        duration: generationTime,
        uploadedAt: DateTime.now(),
        userId: userId,
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
    } finally {
      // Cleanup temporary file
      try {
        await tempFile?.delete();
      } catch (e) {
        print('Warning: Failed to delete temporary file: $e');
      }
    }
  }

  // Generate thumbnail from video file
  Future<String?> generateAndUploadThumbnail(File videoFile, String videoId) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final thumbnailPath = '${tempDir.path}/${videoId}_thumb.jpg';
      
      // FFmpeg command to extract first frame
      final command = '-i ${videoFile.path} -vframes 1 -an -s 1280x720 -ss 0 $thumbnailPath';
      
      // Execute FFmpeg command
      final session = await FFmpegKit.execute(command);
      final returnCode = await session.getReturnCode();

      if (returnCode?.isValueSuccess() ?? false) {
        // Upload thumbnail to Firebase Storage
        final thumbnailFile = File(thumbnailPath);
        final thumbnailRef = _storage.ref().child('thumbnails/$videoId.jpg');
        
        await thumbnailRef.putFile(
          thumbnailFile,
          SettableMetadata(contentType: 'image/jpeg'),
        );

        // Get thumbnail URL
        final thumbnailUrl = await thumbnailRef.getDownloadURL();
        
        // Cleanup
        try {
          await thumbnailFile.delete();
        } catch (e) {
          print('Warning: Failed to delete temporary thumbnail file: $e');
        }
        
        return thumbnailUrl;
      } else {
        final logs = await session.getLogs();
        throw Exception('FFmpeg thumbnail generation failed: ${logs.join("\n")}');
      }
    } catch (e) {
      print('Error generating thumbnail: $e');
      return null;
    }
  }

  // Batch update existing videos with HLS and metadata
  Future<void> batchUpdateVideosWithHLSAndMetadata({
    Function(int total)? onTotalVideos,
    Function(int current, int total, String status)? onProgress,
    Function(String videoId, String type, dynamic error)? onError,
  }) async {
    try {
      // Get all videos
      final videos = await getAllVideos();
      final total = videos.length;
      onTotalVideos?.call(total);

      // Process videos in batches to avoid overloading
      const batchSize = 3; // Small batch size due to intensive processing
      for (var i = 0; i < videos.length; i += batchSize) {
        final batch = videos.skip(i).take(batchSize);
        
        // Process batch sequentially to avoid memory issues
        for (var video in batch) {
          try {
            final needsHLS = video.hlsUrl == null;
            final needsMetadata = video.description == null || 
                                video.description!.isEmpty || 
                                video.tags.isEmpty;
            final needsThumbnail = video.thumbnailUrl == null;
            
            if (!needsHLS && !needsMetadata && !needsThumbnail) {
              onProgress?.call(i + 1, total, 'Skipping ${video.title} - already up to date');
              continue;
            }

            File? tempFile;
            String? thumbnailUrl;

            // Download the video if we need HLS or thumbnail
            if (needsHLS || needsThumbnail) {
              onProgress?.call(i + 1, total, 'Downloading ${video.title}');
              
              // Create temporary file
              final tempDir = await getTemporaryDirectory();
              tempFile = File('${tempDir.path}/${video.id}.mp4');
              
              try {
                // Download video
                final response = await http.get(Uri.parse(video.url));
                await tempFile.writeAsBytes(response.bodyBytes);

                // Generate thumbnail if needed
                if (needsThumbnail) {
                  onProgress?.call(i + 1, total, 'Generating thumbnail for ${video.title}');
                  thumbnailUrl = await generateAndUploadThumbnail(tempFile, video.id);
                }

                // Convert to HLS if needed
                if (needsHLS) {
                  onProgress?.call(i + 1, total, 'Converting ${video.title} to HLS');
                  final hlsDirPath = await convertVideoToHLS(tempFile, video.id);
                  
                  // Upload HLS files
                  onProgress?.call(i + 1, total, 'Uploading HLS files for ${video.title}');
                  final hlsUrl = await uploadHLSFiles(hlsDirPath, video.id);

                  // Update video with HLS URL
                  await _firestore
                      .collection('videos')
                      .doc(video.id)
                      .update({'hlsUrl': hlsUrl});

                  print('Successfully added HLS for video ${video.id}');
                  print('HLS URL: $hlsUrl');
                }
              } catch (e) {
                onError?.call(video.id, 'processing', e);
                print('Error processing video ${video.id}: $e');
                continue;
              } finally {
                // Cleanup temp file
                try {
                  await tempFile?.delete();
                } catch (e) {
                  print('Warning: Failed to delete temporary file: $e');
                }
              }
            }

            // Update metadata if needed
            if (needsMetadata) {
              onProgress?.call(i + 1, total, 'Generating metadata for ${video.title}');
              
              try {
                final aiResponse = await _aiCaptionService.generateProjectDetails(
                  video.title,
                  isAiGenerated: true
                );

                final updates = {
                  if (video.description == null || video.description!.isEmpty)
                    'description': aiResponse['description'],
                  if (video.tags.isEmpty)
                    'tags': aiResponse['tags'],
                  if (aiResponse['title'] != null)
                    'title': aiResponse['title'],
                };

                if (updates.isNotEmpty) {
                  await _firestore
                      .collection('videos')
                      .doc(video.id)
                      .update(updates);

                  print('Successfully updated metadata for video ${video.id}');
                  print('Updates: $updates');
                }
              } catch (e) {
                onError?.call(video.id, 'metadata', e);
                print('Error updating metadata for video ${video.id}: $e');
              }
            }

            // Update thumbnail URL if we generated one
            if (thumbnailUrl != null) {
              try {
                await _firestore
                    .collection('videos')
                    .doc(video.id)
                    .update({'thumbnailUrl': thumbnailUrl});
                print('Successfully updated thumbnail for video ${video.id}');
              } catch (e) {
                onError?.call(video.id, 'thumbnail_update', e);
                print('Error updating thumbnail URL for video ${video.id}: $e');
              }
            }

            onProgress?.call(i + 1, total, 'Completed processing ${video.title}');
          } catch (e) {
            onError?.call(video.id, 'general', e);
            print('Error processing video ${video.id}: $e');
            // Continue with next video
          }
        }

        // Add a delay between batches to avoid rate limiting
        if (i + batchSize < videos.length) {
          await Future.delayed(const Duration(seconds: 5));
        }
      }
    } catch (e) {
      print('Error in batch update: $e');
      throw Exception('Failed to batch update videos: $e');
    }
  }
} 