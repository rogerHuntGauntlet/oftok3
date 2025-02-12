import 'package:flutter/services.dart';

class PlatformConfigService {
  static const platform = MethodChannel('io.gauntletai.ohftok_app/config');

  Future<String?> getReplicateApiToken() async {
    try {
      print('Attempting to get Replicate API token from platform...');
      final String token = await platform.invokeMethod('getReplicateApiToken');
      print('Successfully got token from platform: ${token.substring(0, 10)}...');
      return token;
    } on PlatformException catch (e) {
      print('Failed to get Replicate API token: ${e.message}');
      print('Error details: ${e.details}');
      return null;
    } catch (e) {
      print('Unexpected error getting token: $e');
      return null;
    }
  }
} 