import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../lib/services/video_service.dart';
import '../lib/firebase_options.dart';

void main() async {
  // Load environment variables
  await dotenv.load();

  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  final videoService = VideoService();
  int total = 0;
  int current = 0;
  final errors = <String, List<String>>{};

  try {
    await videoService.batchUpdateVideosWithHLSAndMetadata(
      onTotalVideos: (count) {
        total = count;
        print('\nStarting update of $count videos...\n');
      },
      onProgress: (curr, tot, status) {
        current = curr;
        final percent = (current / total * 100).toStringAsFixed(1);
        print('[$percent%] ($current/$total) $status');
      },
      onError: (videoId, type, error) {
        errors.putIfAbsent(videoId, () => []);
        errors[videoId]!.add('$type: $error');
      },
    );

    // Print summary
    print('\n=== Update Complete ===');
    print('Total videos processed: $current/$total');
    
    if (errors.isEmpty) {
      print('No errors encountered!');
    } else {
      print('\nErrors encountered:');
      errors.forEach((videoId, errorList) {
        print('\nVideo $videoId:');
        errorList.forEach((error) => print('  - $error'));
      });
    }
  } catch (e) {
    print('\nFatal error: $e');
  }
} 