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

  VideoGenerationService({
    UserService? userService, 
    AppCheckService? appCheckService,
    PlatformConfigService? platformConfig
  })  : _userService = userService,
        _appCheckService = appCheckService,
        _platformConfig = platformConfig ?? PlatformConfigService();

  Future<Map<String, String>> get _headers async {
    final apiSecretKey = const String.fromEnvironment('API_SECRET_KEY');
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
        final response = await http.get(
          Uri.parse(_baseUrl),
          headers: await _headers,
        ).timeout(const Duration(seconds: 10));
        
        print('Response status code: ${response.statusCode}');
        print('Response body: ${response.body}');
        
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          print('Server response: $data');
          return true;
        }
        
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
    final stopwatch = Stopwatch()..start();
    int pollCount = 0;

    try {
      onProgress?.call(VideoGenerationStatus.starting, 0.1);
      onError?.call('Starting video generation...');

      // Start video generation
      final response = await http.post(
        Uri.parse('$_baseUrl'),
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

      // Poll for completion
      while (stopwatch.elapsed < _maxGenerationTime) {
        try {
          final statusResponse = await http.get(
            Uri.parse('$_baseUrl?id=$predictionId'),
            headers: await _headers,
          ).timeout(const Duration(seconds: 10));

          if (statusResponse.statusCode != 200) {
            throw VideoGenerationException(
              'Failed to check video status',
              code: 'STATUS_CHECK_FAILED',
              details: statusResponse.statusCode,
              statusCode: statusResponse.statusCode,
              responseBody: statusResponse.body
            );
          }

          final statusData = jsonDecode(statusResponse.body) as Map<String, dynamic>;
          
          if (!statusData['success']) {
            throw VideoGenerationException(
              'Video generation failed',
              code: 'GENERATION_FAILED',
              details: statusData['error'],
              statusCode: statusResponse.statusCode,
              responseBody: statusResponse.body
            );
          }

          final status = statusData['status'];
          pollCount++;
          final timeProgress = stopwatch.elapsed.inMilliseconds / _maxGenerationTime.inMilliseconds;
          final progress = 0.1 + (timeProgress * 0.7); // Scale from 10% to 80%
          
          final elapsedSeconds = stopwatch.elapsed.inSeconds;
          final estimatedTotalSeconds = (elapsedSeconds / progress).round();
          final remainingSeconds = estimatedTotalSeconds - elapsedSeconds;
          
          onProgress?.call(
            VideoGenerationStatus.values.firstWhere(
              (s) => s.toString().split('.').last == status,
              orElse: () => VideoGenerationStatus.processing
            ),
            progress.clamp(0.0, 1.0)
          );
          
          onError?.call(
            'Generating video... ${(progress * 100).round()}%\n'
            'Time elapsed: ${elapsedSeconds}s\n'
            'Estimated time remaining: ${remainingSeconds}s'
          );
          
          if (status == 'succeeded') {
            videoUrl = statusData['output'];
            break;
          } else if (status == 'failed') {
            throw VideoGenerationException(
              'Video generation failed',
              code: 'GENERATION_FAILED',
              details: statusData['error'],
              statusCode: statusResponse.statusCode,
              responseBody: statusResponse.body
            );
          }
        } catch (e) {
          if (e is! VideoGenerationException) {
            onError?.call('Status check failed, retrying...');
            print('Status check error: $e');
            await Future.delayed(const Duration(seconds: 1));
            continue;
          }
          rethrow;
        }

        await Future.delayed(_pollInterval);
      }

      if (videoUrl == null) {
        throw VideoGenerationException(
          'Video generation timed out',
          code: 'TIMEOUT',
          details: 'Generation exceeded $_maxGenerationTime'
        );
      }

      // Update metadata through Vercel API
      onProgress?.call(VideoGenerationStatus.processing, 0.9);
      onError?.call('Updating video metadata...');

      final metadataResponse = await http.post(
        Uri.parse('${_baseUrl.replaceAll('/api', '/api/metadata')}'),
        headers: await _headers,
        body: jsonEncode({
          'videoId': predictionId,
          'title': prompt,
          'isAiGenerated': true
        }),
      ).timeout(const Duration(seconds: 10));

      if (metadataResponse.statusCode != 200) {
        print('Warning: Failed to update metadata: ${metadataResponse.statusCode}');
        print('Response: ${metadataResponse.body}');
      }

      onProgress?.call(VideoGenerationStatus.succeeded, 1.0);
      final generationTime = stopwatch.elapsed.inSeconds;
      onError?.call('Video generated successfully in ${generationTime}s!');
      
      return {
        'success': true,
        'videoUrl': videoUrl,
        'generationTime': generationTime,
        'pollCount': pollCount,
      };

    } catch (e) {
      onProgress?.call(VideoGenerationStatus.failed, 1.0);
      if (e is VideoGenerationException) {
        onError?.call('Generation failed: ${e.message}');
        rethrow;
      }
      onError?.call('Unexpected error: $e');
      throw VideoGenerationException(
        'Unexpected error during video generation',
        code: 'UNEXPECTED_ERROR',
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