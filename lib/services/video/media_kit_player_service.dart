import 'dart:async';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'video_player_service.dart';

/// Implementation of VideoPlayerService using media_kit package.
class MediaKitPlayerService implements VideoPlayerService {
  Player? _player;
  VideoController? _videoController;
  StreamController<Duration>? _positionController;
  StreamController<bool>? _playingController;
  StreamSubscription? _positionSubscription;
  StreamSubscription? _playingSubscription;
  bool _isPreloaded = false;
  String? _currentUrl;

  // Expose video controller for UI rendering
  VideoController? get videoController => _videoController;

  @override
  Future<void> initialize(String videoUrl) async {
    print('MediaKitPlayerService: Initializing with URL: $videoUrl');
    
    try {
      await dispose(); // Clean up any existing resources
      _player = Player(configuration: const PlayerConfiguration(
        // Use default configuration for now
        bufferSize: 32 * 1024, // 32KB buffer
      ));
      _videoController = VideoController(_player!);
      
      // Initialize controllers
      _positionController = StreamController<Duration>.broadcast();
      _playingController = StreamController<bool>.broadcast();
      
      await setSource(videoUrl);
      
      print('MediaKitPlayerService: Player initialized successfully');
    } catch (e, stackTrace) {
      print('MediaKitPlayerService Error: $e');
      print('MediaKitPlayerService Stack trace: $stackTrace');
      rethrow;
    }
  }

  Future<void> setSource(String videoUrl) async {
    if (_currentUrl == videoUrl && _isPreloaded) {
      return; // Already loaded this URL
    }

    print('MediaKitPlayerService: Setting source: $videoUrl');
    
    try {
      await _player!.open(
        Media(videoUrl),
        play: false, // Don't auto-play
      );
      
      _currentUrl = videoUrl;
      _isPreloaded = false;

      // Setup streams
      _setupStreams();
      
      // Enable looping
      await _player!.setPlaylistMode(PlaylistMode.loop);
      
      print('MediaKitPlayerService: Source set successfully');
    } catch (e) {
      print('MediaKitPlayerService Error setting source: $e');
      rethrow;
    }
  }

  void _setupStreams() {
    // Cancel existing subscriptions
    _positionSubscription?.cancel();
    _playingSubscription?.cancel();

    // Setup position updates
    _positionSubscription = _player!.streams.position
        .distinct() // Only emit when position actually changes
        .listen(
      (position) {
        if (_positionController?.isClosed == false) {
          _positionController?.add(position);
        }
      },
      onError: (error) {
        print('Position stream error: $error');
      },
    );

    // Setup playing state updates
    _playingSubscription = _player!.streams.playing
        .distinct()
        .listen(
      (playing) {
        if (_playingController?.isClosed == false) {
          _playingController?.add(playing);
        }
      },
      onError: (error) {
        print('Playing stream error: $error');
      },
    );
  }

  @override
  Future<void> preload() async {
    if (_isPreloaded || _player == null || _currentUrl == null) return;

    try {
      // Start buffering by seeking to beginning
      await _player!.seek(Duration.zero);
      
      // Wait for initial buffer
      await _player!.streams.buffer.first;
      
      _isPreloaded = true;
      print('MediaKitPlayerService: Preload complete for $_currentUrl');
    } catch (e) {
      print('MediaKitPlayerService Error preloading: $e');
      _isPreloaded = false;
    }
  }

  @override
  Future<void> play() async {
    try {
      if (!_isPreloaded) {
        await preload();
      }
      await _player?.play();
    } catch (e) {
      print('Play error: $e');
      throw Exception('Failed to play video: $e');
    }
  }

  @override
  Future<void> pause() async {
    try {
      await _player?.pause();
    } catch (e) {
      print('Pause error: $e');
      throw Exception('Failed to pause video: $e');
    }
  }

  @override
  Future<void> seek(Duration position) async {
    try {
      await _player?.seek(position);
    } catch (e) {
      print('Seek error: $e');
      throw Exception('Failed to seek video: $e');
    }
  }

  @override
  Future<Duration> get position async {
    try {
      return _player?.state.position ?? Duration.zero;
    } catch (e) {
      print('Get position error: $e');
      return Duration.zero;
    }
  }

  @override
  Future<Duration> get duration async {
    try {
      return _player?.state.duration ?? Duration.zero;
    } catch (e) {
      print('Get duration error: $e');
      return Duration.zero;
    }
  }

  @override
  Future<bool> get isPlaying async {
    try {
      return _player?.state.playing ?? false;
    } catch (e) {
      print('Get playing state error: $e');
      return false;
    }
  }

  @override
  Stream<Duration> get positionStream =>
      _positionController?.stream ?? const Stream.empty();

  @override
  Stream<bool> get playingStream =>
      _playingController?.stream ?? const Stream.empty();

  @override
  Future<void> dispose() async {
    try {
      // Cancel stream subscriptions
      await _positionSubscription?.cancel();
      _positionSubscription = null;
      await _playingSubscription?.cancel();
      _playingSubscription = null;

      // Close stream controllers
      await _positionController?.close();
      _positionController = null;
      await _playingController?.close();
      _playingController = null;

      // Dispose video controller and player
      _videoController = null;
      await _player?.dispose();
      _player = null;
      
      _isPreloaded = false;
      _currentUrl = null;
    } catch (e) {
      print('Dispose error: $e');
    }
  }
}

/// Factory for creating MediaKitPlayerService instances
class MediaKitPlayerFactory implements VideoPlayerFactory {
  @override
  VideoPlayerService createPlayer() => MediaKitPlayerService();
} 