import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../firebase_options.dart';
import '../services/video_service.dart';

void main() async {
  try {
    // Initialize Flutter bindings
    WidgetsFlutterBinding.ensureInitialized();
    
    // Load environment variables
    await dotenv.load();
    
    // Initialize Firebase
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    
    final videoService = VideoService();
    
    print('Starting batch update of videos...');
    
    await videoService.batchUpdateAllVideosWithAI(
      onTotalVideos: (total) {
        print('Found $total videos to process');
      },
      onProgress: (current, total) {
        final percentage = ((current / total) * 100).toStringAsFixed(1);
        print('Progress: $current/$total ($percentage%)');
      },
      onError: (videoId, error) {
        print('Error processing video $videoId: $error');
      },
    );
    
    print('Finished processing all videos');
  } catch (e) {
    print('Error: $e');
  } finally {
    // Exit the application
    WidgetsBinding.instance.handleRequestAppExit();
  }
} 