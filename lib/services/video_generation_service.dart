import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import './user_service.dart';
import './app_check_service.dart';

// Define generation status for better type safety
enum VideoGenerationStatus {
  starting,
  processing,
  failed,
  succeeded
}

// Custom exception types for better error handling
class VideoGenerationException implements Exception {
  final String message;
  final String? code;
  final dynamic details;

  VideoGenerationException(this.message, {this.code, this.details});

  @override
  String toString() => 'VideoGenerationException: $message${code != null ? ' (Code: $code)' : ''}';
}

class VideoGenerationService {
  static const String _baseUrl = 'https://ohftokv3-1mjlzvcdb-rogerhuntgauntlets-projects.vercel.app/api/render';
  static const int _maxRetryAttempts = 3;
  static const Duration _initialRetryDelay = Duration(seconds: 2);
  static const Duration _pollInterval = Duration(seconds: 2);
  static const Duration _maxGenerationTime = Duration(minutes: 5);
  
  final UserService? _userService;
  final AppCheckService? _appCheckService;

  VideoGenerationService({UserService? userService, AppCheckService? appCheckService})
      : _userService = userService,
        _appCheckService = appCheckService;

  // Test server connection with retry logic
  Future<bool> testConnection() async {
    int attempts = 0;
    while (attempts < _maxRetryAttempts) {
      try {
        print('Testing connection to $_baseUrl (Attempt ${attempts + 1})');
        final response = await http.get(Uri.parse(_baseUrl))
            .timeout(const Duration(seconds: 10));
        
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          print('Server response: $data');
          return true;
        }
        
        print('Server returned status code: ${response.statusCode}');
        attempts++;
        if (attempts < _maxRetryAttempts) {
          await Future.delayed(_initialRetryDelay * (1 << attempts));
        }
      } catch (e) {
        print('Connection test failed: $e');
        attempts++;
        if (attempts < _maxRetryAttempts) {
          await Future.delayed(_initialRetryDelay * (1 << attempts));
        }
      }
    }
    return false;
  }

  Future<Map<String, dynamic>> generateVideo(
    String prompt, {
    void Function(VideoGenerationStatus status, double progress)? onProgress,
    void Function(String message)? onError,
  }) async {
    try {
      print('Starting video generation with prompt: $prompt');
      onProgress?.call(VideoGenerationStatus.starting, 0.0);
      
      // Step 1: Start the video generation with retry logic
      String? predictionId;
      int attempts = 0;
      
      while (attempts < _maxRetryAttempts && predictionId == null) {
        try {
          final response = await http.post(
            Uri.parse(_baseUrl),
            headers: {
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'prompt': prompt,
            }),
          ).timeout(const Duration(seconds: 30));

          if (response.statusCode == 200) {
            final data = jsonDecode(response.body) as Map<String, dynamic>;
            
            if (!data['success']) {
              throw VideoGenerationException(
                'Failed to start video generation',
                code: 'START_FAILED',
                details: data['error']
              );
            }

            predictionId = data['id'];
          } else {
            throw VideoGenerationException(
              'Server error',
              code: 'HTTP_ERROR',
              details: response.statusCode
            );
          }
        } catch (e) {
          attempts++;
          if (attempts < _maxRetryAttempts) {
            onError?.call('Generation attempt failed, retrying...');
            await Future.delayed(_initialRetryDelay * (1 << attempts));
          } else {
            rethrow;
          }
        }
      }

      if (predictionId == null) {
        throw VideoGenerationException(
          'Failed to start video generation after $_maxRetryAttempts attempts',
          code: 'MAX_RETRIES_EXCEEDED'
        );
      }
      
      // Step 2: Poll for completion with timeout
      onProgress?.call(VideoGenerationStatus.processing, 0.1);
      final stopwatch = Stopwatch()..start();
      int pollCount = 0;
      
      while (stopwatch.elapsed < _maxGenerationTime) {
        try {
          final statusResponse = await http.get(
            Uri.parse('$_baseUrl?id=$predictionId'),
          ).timeout(const Duration(seconds: 10));

          if (statusResponse.statusCode != 200) {
            throw VideoGenerationException(
              'Failed to check video status',
              code: 'STATUS_CHECK_FAILED',
              details: statusResponse.statusCode
            );
          }

          final statusData = jsonDecode(statusResponse.body) as Map<String, dynamic>;
          
          if (!statusData['success']) {
            throw VideoGenerationException(
              'Video generation failed',
              code: 'GENERATION_FAILED',
              details: statusData['error']
            );
          }

          final status = statusData['status'];
          
          // Update progress based on status and time elapsed
          pollCount++;
          final timeProgress = stopwatch.elapsed.inMilliseconds / _maxGenerationTime.inMilliseconds;
          final progress = 0.1 + (timeProgress * 0.9); // Scale from 10% to 100%
          onProgress?.call(
            VideoGenerationStatus.values.firstWhere(
              (s) => s.toString().split('.').last == status,
              orElse: () => VideoGenerationStatus.processing
            ),
            progress.clamp(0.0, 1.0)
          );
          
          if (status == 'succeeded') {
            onProgress?.call(VideoGenerationStatus.succeeded, 1.0);
            return {
              'success': true,
              'videoUrl': statusData['output'],
              'generationTime': stopwatch.elapsed.inSeconds,
              'pollCount': pollCount,
            };
          } else if (status == 'failed') {
            throw VideoGenerationException(
              'Video generation failed',
              code: 'GENERATION_FAILED',
              details: statusData['error']
            );
          }
        } catch (e) {
          // Only retry on network errors, not on generation failures
          if (e is! VideoGenerationException) {
            onError?.call('Status check failed, retrying...');
            await Future.delayed(const Duration(seconds: 1));
            continue;
          }
          rethrow;
        }

        // Wait before polling again
        await Future.delayed(_pollInterval);
      }
      
      throw VideoGenerationException(
        'Video generation timed out',
        code: 'TIMEOUT',
        details: 'Generation exceeded $_maxGenerationTime'
      );
    } catch (e) {
      onProgress?.call(VideoGenerationStatus.failed, 0.0);
      print('Error in video generation: $e');
      if (e is VideoGenerationException) {
        rethrow;
      }
      throw VideoGenerationException(
        'Error generating video',
        code: 'UNKNOWN_ERROR',
        details: e.toString()
      );
    }
  }
} 