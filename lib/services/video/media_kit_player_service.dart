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

  // Expose video controller for UI rendering
  VideoController? get videoController => _videoController;

  @override
  Future<void> initialize(String videoUrl) async {
    print('MediaKitPlayerService: Initializing with URL: $videoUrl');
    
    try {
      _player?.dispose();
      _player = Player();
      _videoController = VideoController(_player!);
      
      print('MediaKitPlayerService: Player and controller created');
      
      // Initialize position and playing controllers if not already created
      _positionController ??= StreamController<Duration>.broadcast();
      _playingController ??= StreamController<bool>.broadcast();
      
      await _player!.open(Media(videoUrl));
      print('MediaKitPlayerService: Media opened successfully');
      
      // Enable looping
      _player!.setPlaylistMode(PlaylistMode.loop);
      
      // Setup position updates with more frequent updates
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

      // Setup playing state updates with error handling
      _playingSubscription = _player!.streams.playing
          .distinct() // Only emit when state actually changes
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
    } catch (e, stackTrace) {
      print('MediaKitPlayerService Error: $e');
      print('MediaKitPlayerService Stack trace: $stackTrace');
      rethrow;
    }
  }

  @override
  Future<void> play() async {
    try {
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