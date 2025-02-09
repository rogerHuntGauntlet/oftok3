import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:video_player/video_player.dart';
import 'video_player_service.dart';

/// Default implementation of VideoPlayerService using Flutter's video_player package.
class DefaultVideoPlayerService implements VideoPlayerService {
  VideoPlayerController? _controller;
  StreamController<Duration>? _positionController;
  StreamController<bool>? _playingController;
  Timer? _positionTimer;

  @override
  Future<void> initialize(String videoUrl) async {
    // Dispose existing resources
    await dispose();

    // Create new controllers
    _controller = VideoPlayerController.network(videoUrl);
    _positionController = StreamController<Duration>.broadcast();
    _playingController = StreamController<bool>.broadcast();

    try {
      await _controller!.initialize();
      // Start position timer to emit position updates
      _positionTimer = Timer.periodic(const Duration(milliseconds: 200), (_) {
        if (!_positionController!.isClosed) {
          _positionController!.add(_controller!.value.position);
        }
      });
      
      // Listen to playback state changes
      _controller!.addListener(() {
        if (!_playingController!.isClosed) {
          _playingController!.add(_controller!.value.isPlaying);
        }
      });
    } catch (e) {
      await dispose();
      throw Exception('Failed to initialize video player: $e');
    }
  }

  @override
  Future<void> play() async {
    if (_controller?.value.isInitialized ?? false) {
      await _controller!.play();
    }
  }

  @override
  Future<void> pause() async {
    if (_controller?.value.isInitialized ?? false) {
      await _controller!.pause();
    }
  }

  @override
  Future<void> seek(Duration position) async {
    if (_controller?.value.isInitialized ?? false) {
      await _controller!.seekTo(position);
    }
  }

  @override
  Future<Duration> get position async => 
    _controller?.value.position ?? Duration.zero;

  @override
  Future<Duration> get duration async =>
    _controller?.value.duration ?? Duration.zero;

  @override
  Future<bool> get isPlaying async =>
    _controller?.value.isPlaying ?? false;

  @override
  Stream<Duration> get positionStream => 
    _positionController?.stream ?? const Stream.empty();

  @override
  Stream<bool> get playingStream =>
    _playingController?.stream ?? const Stream.empty();

  @override
  void dispose() {
    _positionTimer?.cancel();
    _positionTimer = null;
    _positionController?.close();
    _positionController = null;
    _playingController?.close();
    _playingController = null;
    _controller?.dispose();
    _controller = null;
  }
}

/// Factory for creating DefaultVideoPlayerService instances
class DefaultVideoPlayerFactory implements VideoPlayerFactory {
  @override
  VideoPlayerService createPlayer() => DefaultVideoPlayerService();
} 