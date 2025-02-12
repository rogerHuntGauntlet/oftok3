import 'dart:collection';
import 'package:flutter/foundation.dart';
import 'media_kit_player_service.dart';

class PlayerPool {
  final int maxPlayers;
  final Map<String, MediaKitPlayerService> _activePlayers = {};
  final Queue<MediaKitPlayerService> _availablePlayers = Queue();
  final Set<String> _preloadingUrls = {};
  bool _isDisposed = false;

  // Stats for monitoring
  int get activePlayerCount => _activePlayers.length;
  int get availablePlayerCount => _availablePlayers.length;
  bool get hasAvailablePlayers => _availablePlayers.isNotEmpty;

  PlayerPool({required this.maxPlayers}) {
    assert(maxPlayers > 0, 'maxPlayers must be greater than 0');
  }

  Future<MediaKitPlayerService> checkoutPlayer(String videoUrl) async {
    if (_isDisposed) {
      throw StateError('PlayerPool has been disposed');
    }

    // Check if player already exists for this URL
    if (_activePlayers.containsKey(videoUrl)) {
      return _activePlayers[videoUrl]!;
    }

    MediaKitPlayerService player;

    // Try to reuse an available player
    if (_availablePlayers.isNotEmpty) {
      player = _availablePlayers.removeFirst();
      try {
        await player.setSource(videoUrl);
      } catch (e) {
        // If setting source fails, create new player
        await player.dispose();
        player = await _createNewPlayer(videoUrl);
      }
    } else if (_activePlayers.length < maxPlayers) {
      // Create new player if under limit
      player = await _createNewPlayer(videoUrl);
    } else {
      // If at capacity, recycle least recently used player
      final lruUrl = _findLeastRecentlyUsedUrl();
      player = _activePlayers.remove(lruUrl)!;
      await player.setSource(videoUrl);
    }

    _activePlayers[videoUrl] = player;
    return player;
  }

  String _findLeastRecentlyUsedUrl() {
    // Find a URL that's not currently being preloaded
    for (final url in _activePlayers.keys) {
      if (!_preloadingUrls.contains(url)) {
        return url;
      }
    }
    // If all are being preloaded, return the first one
    return _activePlayers.keys.first;
  }

  Future<void> returnPlayer(String videoUrl) async {
    if (_isDisposed) return;

    final player = _activePlayers.remove(videoUrl);
    if (player != null) {
      try {
        await player.pause();
        if (_availablePlayers.length < maxPlayers ~/ 2) {
          _availablePlayers.add(player);
        } else {
          await player.dispose();
        }
      } catch (e) {
        debugPrint('Error returning player: $e');
        await player.dispose();
      }
    }
  }

  Future<void> preloadPlayer(String videoUrl) async {
    if (_isDisposed || 
        _activePlayers.containsKey(videoUrl) || 
        _preloadingUrls.contains(videoUrl)) {
      return;
    }

    try {
      _preloadingUrls.add(videoUrl);
      final player = await checkoutPlayer(videoUrl);
      await player.preload();
    } catch (e) {
      debugPrint('Error preloading player: $e');
    } finally {
      _preloadingUrls.remove(videoUrl);
    }
  }

  Future<MediaKitPlayerService> _createNewPlayer(String videoUrl) async {
    final player = MediaKitPlayerService();
    await player.initialize(videoUrl);
    return player;
  }

  Future<void> cleanupInactivePlayers() async {
    if (_isDisposed) return;

    // Dispose all available players that exceed half the max
    while (_availablePlayers.length > maxPlayers ~/ 2) {
      final player = _availablePlayers.removeLast();
      await player.dispose();
    }

    // Cleanup any active players that aren't being used
    final urlsToRemove = <String>[];
    for (final entry in _activePlayers.entries) {
      if (!_preloadingUrls.contains(entry.key)) {
        urlsToRemove.add(entry.key);
      }
    }

    for (final url in urlsToRemove) {
      await returnPlayer(url);
    }
  }

  Future<void> dispose() async {
    if (_isDisposed) return;
    _isDisposed = true;

    // Dispose all active players
    for (final player in _activePlayers.values) {
      await player.dispose();
    }
    _activePlayers.clear();

    // Dispose all available players
    while (_availablePlayers.isNotEmpty) {
      final player = _availablePlayers.removeFirst();
      await player.dispose();
    }

    _preloadingUrls.clear();
  }
} 