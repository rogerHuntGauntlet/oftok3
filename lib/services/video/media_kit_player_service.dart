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
    // Dispose existing resources
    await dispose();

    try {
      // Create new controllers
      _player = Player();
      _videoController = await VideoController(_player!);
      _positionController = StreamController<Duration>.broadcast();
      _playingController = StreamController<bool>.broadcast();

      // Open the media source
      await _player!.open(Media(videoUrl));

      // Setup position updates
      _positionSubscription = _player!.streams.position.listen(
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
      _playingSubscription = _player!.streams.playing.listen(
        (playing) {
          if (_playingController?.isClosed == false) {
            _playingController?.add(playing);
          }
        },
        onError: (error) {
          print('Playing stream error: $error');
        },
      );
    } catch (e) {
      print('MediaKit initialization error: $e');
      await dispose();
      throw Exception('Failed to initialize media_kit player: $e');
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