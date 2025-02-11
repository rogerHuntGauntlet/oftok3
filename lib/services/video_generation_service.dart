import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class VideoGenerationService {
  static const String baseUrl = 'https://api.replicate.com/v1';
  
  Future<Map<String, dynamic>> generateVideo(String prompt) async {
    final apiKey = dotenv.env['REPLICATE_API_KEY'];
    if (apiKey == null) throw Exception('Replicate API key not found');

    try {
      print('Starting video generation with prompt: $prompt');
      
      // Create prediction
      final response = await http.post(
        Uri.parse('$baseUrl/predictions'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiKey',
          'Prefer': 'wait=60'  // Wait up to 60 seconds for the model to run
        },
        body: jsonEncode({
          'version': 'ee6dae0d5c7dc809d3731e0f4a701c1e5b9e0c06a6a6bf2ac6be2c8141b0a120',
          'input': {
            'prompt': prompt
          }
        }),
      );

      if (response.statusCode != 201) {
        final error = jsonDecode(response.body);
        throw Exception('Failed to start video generation: ${error['detail'] ?? response.body}');
      }

      final prediction = jsonDecode(response.body);
      final String predictionId = prediction['id'];
      print('Created prediction: $predictionId');
      
      // Poll for completion
      while (true) {
        final statusResponse = await http.get(
          Uri.parse('$baseUrl/predictions/$predictionId'),
          headers: {
            'Authorization': 'Bearer $apiKey',
          },
        );

        if (statusResponse.statusCode != 200) {
          final error = jsonDecode(statusResponse.body);
          throw Exception('Failed to check generation status: ${error['detail'] ?? statusResponse.body}');
        }

        final status = jsonDecode(statusResponse.body);
        print('Status update: ${status['status']}');
        
        if (status['status'] == 'succeeded') {
          print('Generation succeeded: ${status['output']}');
          return {
            'success': true,
            'videoUrl': status['output'],
            'remainingToday': 'unlimited'
          };
        } else if (status['status'] == 'failed') {
          throw Exception('Video generation failed: ${status['error']}');
        } else if (status['status'] == 'canceled') {
          throw Exception('Video generation was canceled');
        }

        // Wait before polling again
        await Future.delayed(const Duration(seconds: 2));
      }
    } catch (e) {
      print('Error in video generation: $e');
      throw Exception('Error generating video: $e');
    }
  }
} 