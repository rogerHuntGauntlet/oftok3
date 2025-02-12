import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:ohftok/services/video_generation_service.dart';

void main() {
  late VideoGenerationService service;
  const baseUrl = 'https://vercel-deploy-alpha-five.vercel.app/api';

  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    dotenv.testLoad(fileInput: 'API_SECRET_KEY=test_key');
  });

  group('VideoGenerationService - API Integration', () {
    test('successful video generation flow', () async {
      final client = MockClient((request) async {
        // Initial generation request
        if (request.method == 'POST' && request.url.toString() == baseUrl) {
          expect(request.headers['Authorization'], 'Bearer test_key');
          expect(request.headers['Content-Type'], 'application/json');
          expect(
            jsonDecode(request.body),
            {'prompt': 'test prompt'}
          );
          
          return http.Response(
            jsonEncode({
              'success': true,
              'id': 'test_prediction_id'
            }),
            200
          );
        }
        
        // Status check request
        if (request.method == 'GET' && request.url.toString() == '$baseUrl?id=test_prediction_id') {
          return http.Response(
            jsonEncode({
              'success': true,
              'status': 'succeeded',
              'videoUrl': 'https://example.com/video.mp4',
              'hlsUrl': 'https://example.com/video/playlist.m3u8',
              'thumbnailUrl': 'https://example.com/thumb.jpg',
              'previewUrl': 'https://example.com/preview.gif'
            }),
            200
          );
        }

        return http.Response('Not found', 404);
      });

      service = VideoGenerationService(httpClient: client);
      
      final result = await service.generateVideo('test prompt');
      
      expect(result['success'], true);
      expect(result['videoUrl'], 'https://example.com/video.mp4');
      expect(result['hlsUrl'], 'https://example.com/video/playlist.m3u8');
      expect(result['thumbnailUrl'], 'https://example.com/thumb.jpg');
      expect(result['previewUrl'], 'https://example.com/preview.gif');
    });

    test('handles failed generation start', () async {
      final client = MockClient((request) async {
        if (request.method == 'POST') {
          return http.Response(
            jsonEncode({
              'success': false,
              'error': 'Invalid prompt'
            }),
            400
          );
        }
        return http.Response('Not found', 404);
      });

      service = VideoGenerationService(httpClient: client);
      
      expect(
        () => service.generateVideo('test prompt'),
        throwsA(
          isA<VideoGenerationException>()
            .having((e) => e.code, 'code', 'START_FAILED')
            .having((e) => e.statusCode, 'statusCode', 400)
        )
      );
    });

    test('handles failed generation status', () async {
      final client = MockClient((request) async {
        if (request.method == 'POST') {
          return http.Response(
            jsonEncode({
              'success': true,
              'id': 'test_prediction_id'
            }),
            200
          );
        }
        
        if (request.method == 'GET') {
          return http.Response(
            jsonEncode({
              'success': false,
              'status': 'failed',
              'error': 'Generation failed'
            }),
            200
          );
        }

        return http.Response('Not found', 404);
      });

      service = VideoGenerationService(httpClient: client);
      
      expect(
        () => service.generateVideo('test prompt'),
        throwsA(
          isA<VideoGenerationException>()
            .having((e) => e.code, 'code', 'GENERATION_FAILED')
        )
      );
    });

    test('handles moderated content', () async {
      final client = MockClient((request) async {
        if (request.method == 'POST') {
          return http.Response(
            jsonEncode({
              'success': true,
              'id': 'test_prediction_id'
            }),
            200
          );
        }
        
        if (request.method == 'GET') {
          return http.Response(
            jsonEncode({
              'success': true,
              'status': 'succeeded',
              'isModeratedContent': true
            }),
            200
          );
        }

        return http.Response('Not found', 404);
      });

      service = VideoGenerationService(httpClient: client);
      
      final result = await service.generateVideo('test prompt');
      
      expect(result['success'], true);
      expect(result['isModeratedContent'], true);
      expect(result['rickRollUrl'], isNotNull);
    });

    test('handles connection test', () async {
      final client = MockClient((request) async {
        if (request.url.toString() == baseUrl) {
          return http.Response('OK', 200);
        }
        return http.Response('Not found', 404);
      });

      service = VideoGenerationService(httpClient: client);
      
      final result = await service.testConnection();
      expect(result, true);
    });

    test('handles failed connection test', () async {
      final client = MockClient((request) async {
        throw Exception('Connection failed');
      });

      service = VideoGenerationService(httpClient: client);
      
      final result = await service.testConnection();
      expect(result, false);
    });
  });
} 