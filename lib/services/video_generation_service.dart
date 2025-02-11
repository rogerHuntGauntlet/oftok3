import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import './user_service.dart';
import './app_check_service.dart';

class VideoGenerationService {
  static const int tokensPerGeneration = 250;
  static const int _maxRetryAttempts = 3;
  static const Duration _initialRetryDelay = Duration(seconds: 2);
  
  final UserService _userService = UserService();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFunctions _functions = FirebaseFunctions.instance;
  final AppCheckService _appCheckService = AppCheckService();

  Future<Map<String, dynamic>> generateVideo(String prompt) async {
    final user = _auth.currentUser;

    if (user == null) {
      throw Exception('User must be authenticated to generate videos');
    }

    try {
      // First ensure user exists in database with tokens
      final currentUser = await _userService.getCurrentUser();
      if (currentUser == null) {
        // Create user if they don't exist
        await _userService.createOrUpdateUser(user);
        print('Created new user with initial tokens');
      }

      // Now check if user has enough tokens
      final hasTokens = await _userService.hasEnoughTokens(user.uid, tokensPerGeneration);
      if (!hasTokens) {
        throw Exception('Insufficient tokens. You need $tokensPerGeneration tokens to generate a video.');
      }

      print('Starting video generation with prompt: $prompt');
      
      // Implement retry logic for token refresh and function call
      int retryCount = 0;
      Exception? lastError;

      while (retryCount < _maxRetryAttempts) {
        try {
          // Get fresh ID token
          final idToken = await user.getIdToken(true);
          print('Got fresh ID token'); // Debug print

          // Get fresh App Check token
          final appCheckToken = await _appCheckService.getToken(forceRefresh: retryCount > 0);
          if (appCheckToken == null) {
            throw Exception('Failed to obtain App Check token');
          }
          print('Got fresh App Check token'); // Debug print
          
          // Call the Cloud Function with a longer timeout
          final HttpsCallable callable = _functions.httpsCallable(
            'generateVideo',
            options: HttpsCallableOptions(
              timeout: const Duration(minutes: 5),
            ),
          );
          final result = await callable.call({
            'prompt': prompt
          });

          final data = result.data as Map<String, dynamic>;
          
          if (!data['success']) {
            throw Exception('Video generation failed: ${data['error']}');
          }

          return {
            'success': true,
            'videoUrl': data['videoUrl'],
            'tokensDeducted': data['tokensDeducted'],
            'remainingTokens': data['remainingTokens']
          };
        } catch (e) {
          lastError = e is Exception ? e : Exception(e.toString());
          print('Attempt ${retryCount + 1} failed: $e');
          
          // Check if we should retry
          if (e.toString().contains('App Check') || 
              e.toString().contains('Authentication required') ||
              e.toString().contains('Too many attempts')) {
            retryCount++;
            if (retryCount < _maxRetryAttempts) {
              final delay = _initialRetryDelay * (1 << retryCount);
              print('Retrying in ${delay.inSeconds} seconds...');
              await Future.delayed(delay);
              continue;
            }
          } else {
            // For other errors, don't retry
            rethrow;
          }
        }
      }
      
      // If we get here, all retries failed
      throw lastError ?? Exception('Failed to generate video after $_maxRetryAttempts attempts');
    } catch (e) {
      print('Error in video generation: $e');
      throw Exception('Error generating video: $e');
    }
  }
} 