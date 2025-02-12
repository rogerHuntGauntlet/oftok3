import 'package:firebase_core/firebase_core.dart';
import '../lib/services/video_service.dart';
import '../lib/firebase_options.dart';

void main() async {
  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  final videoService = VideoService();
  int totalVideos = 0;
  int processedVideos = 0;
  final List<String> errors = [];

  print('Starting batch update of video metadata...\n');

  try {
    await videoService.batchUpdateAllVideosWithAI(
      onTotalVideos: (total) {
        totalVideos = total;
        print('Found $total videos to process\n');
      },
      onProgress: (current, total) {
        processedVideos = current;
        final percentage = (current / total * 100).toStringAsFixed(1);
        print('Progress: $current/$total ($percentage%)\n');
      },
      onError: (videoId, error) {
        final errorMessage = 'Error processing video $videoId: $error';
        errors.add(errorMessage);
        print('\n$errorMessage\n');
      },
    );

    print('\nBatch update completed!');
    print('Processed $processedVideos out of $totalVideos videos');
    
    if (errors.isNotEmpty) {
      print('\nErrors encountered:');
      errors.forEach((error) => print('- $error'));
    }
  } catch (e) {
    print('\nFatal error: $e');
  }
} 