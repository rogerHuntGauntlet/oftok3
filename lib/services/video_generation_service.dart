import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import './user_service.dart';
import './app_check_service.dart';
import './platform_config_service.dart';

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
  final int? statusCode;
  final String? responseBody;

  VideoGenerationException(
    this.message, {
    this.code,
    this.details,
    this.statusCode,
    this.responseBody,
  });

  @override
  String toString() {
    final parts = <String>[
      'VideoGenerationException: $message',
      if (code != null) '(Code: $code)',
      if (statusCode != null) '[Status: $statusCode]',
      if (responseBody != null) '\nResponse: $responseBody',
      if (details != null) '\nDetails: $details',
    ];
    return parts.join(' ');
  }
}

class VideoGenerationService {
  static const String _baseUrl = 'https://vercel-deploy-alpha-five.vercel.app/api';
  static const int _maxRetryAttempts = 3;
  static const Duration _initialRetryDelay = Duration(seconds: 2);
  static const Duration _pollInterval = Duration(seconds: 2);
  static const Duration _maxGenerationTime = Duration(minutes: 5);
  static const String _rickRollUrl = 'https://www.youtube.com/watch?v=dQw4w9WgXcQ';
  
  final UserService? _userService;
  final AppCheckService? _appCheckService;
  final PlatformConfigService _platformConfig;
  final http.Client _client;

  VideoGenerationService({
    UserService? userService, 
    AppCheckService? appCheckService,
    PlatformConfigService? platformConfig,
    http.Client? httpClient,
  })  : _userService = userService,
        _appCheckService = appCheckService,
        _platformConfig = platformConfig ?? PlatformConfigService(),
        _client = httpClient ?? http.Client();

  Future<Map<String, String>> get _headers async {
    final apiSecretKey = dotenv.env['API_SECRET_KEY'];
    if (apiSecretKey == null) {
      throw VideoGenerationException(
        'API_SECRET_KEY not found in environment',
        code: 'CONFIG_ERROR'
      );
    }
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $apiSecretKey',
    };
  }

  // Test server connection with retry logic and detailed error reporting
  Future<bool> testConnection() async {
    int attempts = 0;
    while (attempts < _maxRetryAttempts) {
      try {
        print('Testing connection to $_baseUrl (Attempt ${attempts + 1})');
        
        final response = await _client.get(
          Uri.parse(_baseUrl),
          headers: await _headers,
        ).timeout(const Duration(seconds: 10));
        
        print('Response status code: ${response.statusCode}');
        
        if (response.statusCode == 200) {
          print('Connection test successful');
          return true;
        }
        
        print('Unexpected status code: ${response.statusCode}');
        attempts++;
        if (attempts < _maxRetryAttempts) {
          print('Retrying in ${_initialRetryDelay.inSeconds * (1 << attempts)} seconds...');
          await Future.delayed(_initialRetryDelay * (1 << attempts));
        }
      } catch (e, stackTrace) {
        print('Connection test failed:');
        print('Error: $e');
        print('Stack trace: $stackTrace');
        attempts++;
        if (attempts < _maxRetryAttempts) {
          print('Retrying in ${_initialRetryDelay.inSeconds * (1 << attempts)} seconds...');
          await Future.delayed(_initialRetryDelay * (1 << attempts));
        }
      }
    }
    print('All connection attempts failed');
    return false;
  }

  Future<Map<String, dynamic>> generateVideo(
    String prompt, {
    void Function(VideoGenerationStatus status, double progress)? onProgress,
    void Function(String message)? onError,
  }) async {
    final stopwatch = Stopwatch()..start();
    int pollCount = 0;

    try {
      onProgress?.call(VideoGenerationStatus.starting, 0.1);
      onError?.call('Starting video generation...');

      // Start video generation
      final response = await _client.post(
        Uri.parse(_baseUrl),
        headers: await _headers,
        body: jsonEncode({'prompt': prompt}),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        throw VideoGenerationException(
          'Failed to start video generation',
          code: 'START_FAILED',
          details: response.statusCode,
          statusCode: response.statusCode,
          responseBody: response.body
        );
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (!data['success']) {
        throw VideoGenerationException(
          'Failed to start video generation',
          code: 'START_FAILED',
          details: data['error'],
          statusCode: response.statusCode,
          responseBody: response.body
        );
      }

      final predictionId = data['id'];
      String? videoUrl;
      String? hlsUrl;
      String? thumbnailUrl;
      String? previewUrl;
      bool isModeratedContent = false;

      // Poll for completion
      while (stopwatch.elapsed < _maxGenerationTime) {
        pollCount++;
        await Future.delayed(_pollInterval);

        final pollResponse = await _client.get(
          Uri.parse('$_baseUrl?id=$predictionId'),
          headers: await _headers,
        );

        if (pollResponse.statusCode != 200) {
          onError?.call('Error checking generation status');
          continue;
        }

        final pollData = jsonDecode(pollResponse.body) as Map<String, dynamic>;
        final status = pollData['status'] as String;
        final progress = pollData['progress'] as double? ?? 0.0;

        // Update progress
        if (status == 'processing') {
          onProgress?.call(VideoGenerationStatus.processing, 0.1 + (progress * 0.8));
          onError?.call(pollData['statusMessage'] ?? 'Processing video...');
        }

        if (status == 'failed') {
          throw VideoGenerationException(
            'Video generation failed',
            code: 'GENERATION_FAILED',
            details: pollData['error']
          );
        }

        if (status == 'succeeded') {
          videoUrl = pollData['videoUrl'] as String?;
          hlsUrl = pollData['hlsUrl'] as String?;
          thumbnailUrl = pollData['thumbnailUrl'] as String?;
          previewUrl = pollData['previewUrl'] as String?;
          isModeratedContent = pollData['isModeratedContent'] as bool? ?? false;
          
          if (videoUrl == null && !isModeratedContent) {
            throw VideoGenerationException(
              'Video generation completed but no URL was provided',
              code: 'NO_URL'
            );
          }
          break;
        }
      }

      if (stopwatch.elapsed >= _maxGenerationTime) {
        throw VideoGenerationException(
          'Video generation timed out',
          code: 'TIMEOUT'
        );
      }

      onProgress?.call(VideoGenerationStatus.succeeded, 1.0);
      onError?.call('Video generation complete!');

      return {
        'success': true,
        'videoUrl': videoUrl,
        'hlsUrl': hlsUrl,
        'thumbnailUrl': thumbnailUrl,
        'previewUrl': previewUrl,
        'videoId': predictionId,
        'isModeratedContent': isModeratedContent,
        'rickRollUrl': isModeratedContent ? _rickRollUrl : null,
        'generationTime': stopwatch.elapsed.inSeconds,
      };
    } catch (e) {
      print('Error in generateVideo: $e');
      onProgress?.call(VideoGenerationStatus.failed, 0);
      if (e is VideoGenerationException) {
        throw e;
      }
      throw VideoGenerationException(
        'Failed to generate video',
        code: 'UNKNOWN',
        details: e.toString()
      );
    }
  }

  Future<Map<String, dynamic>> generateAICaption(String videoUrl) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/caption'),
        headers: await _headers,
        body: jsonEncode({
          'videoUrl': videoUrl,
        }),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode != 200) {
        throw VideoGenerationException(
          'Failed to generate caption',
          code: 'CAPTION_FAILED',
          statusCode: response.statusCode,
          responseBody: response.body
        );
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (!data['success']) {
        throw VideoGenerationException(
          'Caption generation failed',
          code: 'CAPTION_ERROR',
          details: data['error']
        );
      }

      return data;
    } catch (e) {
      throw VideoGenerationException(
        'Failed to generate caption',
        code: 'CAPTION_ERROR',
        details: e.toString()
      );
    }
  }
} 