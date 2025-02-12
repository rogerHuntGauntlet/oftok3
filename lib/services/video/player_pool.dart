import 'dart:collection';
import 'package:flutter/foundation.dart';
import 'media_kit_player_service.dart';

typedef PlayerFactory = MediaKitPlayerService Function();

/// A pool of reusable video players to optimize memory usage and performance
class PlayerPool {
  final int maxPlayers;
  final Map<String, MediaKitPlayerService> _activePlayers = {};
  final Queue<MediaKitPlayerService> _availablePlayers = Queue();
  final PlayerFactory _createPlayer;
  bool _isDisposed = false;

  PlayerPool({
    this.maxPlayers = 3,
    PlayerFactory? createPlayer,
  }) : _createPlayer = createPlayer ?? (() => MediaKitPlayerService()) {
    assert(maxPlayers > 0, 'maxPlayers must be greater than 0');
  }

  /// Get a player for a specific video URL
  /// If a player already exists for this URL, returns that player
  /// Otherwise, returns a new or recycled player
  Future<MediaKitPlayerService> checkoutPlayer(String videoUrl) async {
    if (_isDisposed) {
      throw StateError('PlayerPool has been disposed');
    }

    // If we already have a player for this URL, return it
    if (_activePlayers.containsKey(videoUrl)) {
      debugPrint('🎬 Returning existing player for $videoUrl');
      return _activePlayers[videoUrl]!;
    }

    MediaKitPlayerService player;
    
    // Try to reuse an available player
    if (_availablePlayers.isNotEmpty) {
      debugPrint('♻️ Reusing player from pool');
      player = _availablePlayers.removeFirst();
      await player.initialize(videoUrl);
    } else if (_activePlayers.length < maxPlayers) {
      // Create new player if under limit
      debugPrint('🆕 Creating new player');
      player = _createPlayer();
      await player.initialize(videoUrl);
    } else {
      // Recycle least recently used player
      debugPrint('🔄 Recycling least recently used player');
      String oldestUrl = _activePlayers.keys.first;
      player = _activePlayers.remove(oldestUrl)!;
      await player.initialize(videoUrl);
    }

    _activePlayers[videoUrl] = player;
    return player;
  }

  /// Return a player to the pool for reuse
  Future<void> returnPlayer(String videoUrl) async {
    if (_isDisposed) {
      throw StateError('PlayerPool has been disposed');
    }

    final player = _activePlayers.remove(videoUrl);
    if (player != null) {
      await player.pause();
      _availablePlayers.add(player);
      debugPrint('↩️ Player returned to pool for $videoUrl');
    }
  }

  /// Get the number of active players
  int get activePlayerCount => _activePlayers.length;

  /// Get the number of available players
  int get availablePlayerCount => _availablePlayers.length;

  /// Dispose all players and clear the pool
  Future<void> dispose() async {
    if (_isDisposed) return;
    
    debugPrint('🗑️ Disposing PlayerPool');
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
  }
} 