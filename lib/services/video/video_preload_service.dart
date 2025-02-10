import 'package:flutter/foundation.dart';
import 'video_player_provider.dart';
import 'video_player_service.dart';

class VideoPreloadService {
  final VideoPlayerFactory _factory;
  final Map<String, VideoPlayerService> _preloadedPlayers = {};
  final int _maxPreloadedVideos;

  VideoPreloadService({
    required VideoPlayerFactory factory,
    int maxPreloadedVideos = 3,
  }) : _factory = factory,
       _maxPreloadedVideos = maxPreloadedVideos;

  Future<void> preloadVideos(List<String> videoUrls) async {
    // Only preload up to maxPreloadedVideos
    final urlsToPreload = videoUrls.take(_maxPreloadedVideos).toList();

    // Clean up any existing preloaded videos that aren't in the new list
    _cleanupUnusedPlayers(urlsToPreload);

    // Preload new videos
    for (final url in urlsToPreload) {
      if (!_preloadedPlayers.containsKey(url)) {
        try {
          final player = _factory.createPlayer();
          await player.initialize(url);
          _preloadedPlayers[url] = player;
        } catch (e) {
          debugPrint('Error preloading video $url: $e');
        }
      }
    }
  }

  VideoPlayerService? getPreloadedPlayer(String videoUrl) {
    return _preloadedPlayers.remove(videoUrl);
  }

  void _cleanupUnusedPlayers(List<String> activeUrls) {
    final urlsToRemove = _preloadedPlayers.keys
        .where((url) => !activeUrls.contains(url))
        .toList();

    for (final url in urlsToRemove) {
      _preloadedPlayers[url]?.dispose();
      _preloadedPlayers.remove(url);
    }
  }

  Future<void> dispose() async {
    for (final player in _preloadedPlayers.values) {
      await player.dispose();
    }
    _preloadedPlayers.clear();
  }
} 