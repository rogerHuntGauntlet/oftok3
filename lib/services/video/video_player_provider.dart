import 'package:flutter/foundation.dart';
import 'video_player_service.dart';

/// Manages the state and lifecycle of the video player.
class VideoPlayerProvider extends ChangeNotifier {
  VideoPlayerService? _player;
  bool _isLoading = false;
  String? _error;
  String? _currentVideoUrl;
  bool _isPlaying = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;

  final VideoPlayerFactory factory;
  
  VideoPlayerProvider({required this.factory});

  // Getters
  VideoPlayerService? get player => _player;
  bool get isLoading => _isLoading;
  String? get error => _error;
  String? get currentVideoUrl => _currentVideoUrl;
  bool get isPlaying => _isPlaying;
  Duration get position => _position;
  Duration get duration => _duration;
  double get progress => _duration.inMilliseconds > 0 
    ? _position.inMilliseconds / _duration.inMilliseconds 
    : 0.0;

  /// Initializes a new video for playback
  Future<void> initializeVideo(String videoUrl, {VideoPlayerService? preloadedPlayer}) async {
    if (_currentVideoUrl == videoUrl) return;

    _setLoading(true);
    _clearError();
    
    try {
      // Clean up previous player
      await _cleanupCurrentPlayer();
      
      if (preloadedPlayer != null) {
        _player = preloadedPlayer;
        _currentVideoUrl = videoUrl;
      } else {
        // Create and initialize new player
        _player = factory.createPlayer();
        await _player!.initialize(videoUrl);
        _currentVideoUrl = videoUrl;
      }
      
      // Setup streams
      _setupStreams();
      
      // Start playback
      await _player!.play();
    } catch (e) {
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }

  /// Plays the current video
  Future<void> play() async {
    try {
      await _player?.play();
    } catch (e) {
      _setError(e.toString());
    }
  }

  /// Pauses the current video
  Future<void> pause() async {
    try {
      await _player?.pause();
    } catch (e) {
      _setError(e.toString());
    }
  }

  /// Seeks to a specific position in the video
  Future<void> seek(Duration position) async {
    try {
      await _player?.seek(position);
    } catch (e) {
      _setError(e.toString());
    }
  }

  /// Sets up stream subscriptions for the current player
  void _setupStreams() {
    _player?.positionStream.listen(
      (position) {
        _position = position;
        notifyListeners();
      },
      onError: (error) => _setError(error.toString()),
    );

    _player?.playingStream.listen(
      (playing) {
        _isPlaying = playing;
        notifyListeners();
      },
      onError: (error) => _setError(error.toString()),
    );
  }

  /// Cleans up the current player instance
  Future<void> _cleanupCurrentPlayer() async {
    await _player?.dispose();
    _player = null;
    _currentVideoUrl = null;
    _position = Duration.zero;
    _duration = Duration.zero;
    _isPlaying = false;
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String error) {
    _error = error;
    notifyListeners();
  }

  void _clearError() {
    _error = null;
    notifyListeners();
  }

  @override
  Future<void> dispose() async {
    await _cleanupCurrentPlayer();
    super.dispose();
  }
} 