import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import './user_service.dart';
import './app_check_service.dart';

class VideoGenerationService {
  static const String _baseUrl = 'https://oftok3.onrender.com'; // Updated to Render deployment URL
  static const int _maxRetryAttempts = 3;
  static const Duration _initialRetryDelay = Duration(seconds: 2);
  
  final UserService? _userService;
  final AppCheckService? _appCheckService;

  VideoGenerationService({UserService? userService, AppCheckService? appCheckService})
      : _userService = userService,
        _appCheckService = appCheckService;

  // Test server connection
  Future<bool> testConnection() async {
    try {
      print('Testing connection to $_baseUrl');
      final response = await http.get(Uri.parse(_baseUrl));
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('Server response: $data');
        return data['status'] == 'ok';
      }
      
      print('Server returned status code: ${response.statusCode}');
      return false;
    } catch (e) {
      print('Connection test failed: $e');
      return false;
    }
  }

  Future<Map<String, dynamic>> generateVideo(String prompt) async {
    // First test the connection
    final isConnected = await testConnection();
    if (!isConnected) {
      throw Exception('Could not connect to video generation server');
    }

    try {
      print('Starting video generation with prompt: $prompt');
      
      // Implement retry logic
      int retryCount = 0;
      Exception? lastError;

      while (retryCount < _maxRetryAttempts) {
        try {
          final response = await http.post(
            Uri.parse('$_baseUrl/generate-video'),
            headers: {
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'prompt': prompt,
            }),
          );

          if (response.statusCode == 200) {
            final data = jsonDecode(response.body) as Map<String, dynamic>;
            
            if (!data['success']) {
              throw Exception('Video generation failed: ${data['error']}');
            }

            return {
              'success': true,
              'videoUrl': data['videoUrl'],
            };
          } else {
            throw Exception('Server error: ${response.statusCode}');
          }
        } catch (e) {
          lastError = e is Exception ? e : Exception(e.toString());
          print('Attempt ${retryCount + 1} failed: $e');
          
          retryCount++;
          if (retryCount < _maxRetryAttempts) {
            final delay = _initialRetryDelay * (1 << retryCount);
            print('Retrying in ${delay.inSeconds} seconds...');
            await Future.delayed(delay);
            continue;
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