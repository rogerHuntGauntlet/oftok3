import 'package:flutter_test/flutter_test.dart';
import 'package:ohftokv3/services/video_generation_service.dart';

void main() {
  group('VideoGenerationService', () {
    late VideoGenerationService service;

    setUp(() {
      service = VideoGenerationService();
    });

    test('Server Connection Test', () async {
      final isConnected = await service.testConnection();
      expect(isConnected, true, reason: 'Server should be accessible and return status: ok');
    });

    test('Generate Video Test', () async {
      final result = await service.generateVideo('A test video of a cat playing with yarn');
      expect(result['success'], true);
      expect(result['videoUrl'], isNotNull);
      expect(result['videoUrl'], isNotEmpty);
    }, timeout: Timeout(Duration(minutes: 5))); // Increased timeout for video generation
  });
} 