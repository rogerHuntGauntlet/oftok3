import 'package:flutter/foundation.dart';

/// Abstract interface defining the core video player operations.
/// This interface hides the implementation details of any underlying video solution.
abstract class VideoPlayerService {
  /// Prepares the player for a given video.
  Future<void> initialize(String videoUrl);

  /// Begins or resumes video playback.
  Future<void> play();

  /// Pauses video playback.
  Future<void> pause();

  /// Jumps to the specified position in the video.
  Future<void> seek(Duration position);

  /// Returns the current playback position.
  Future<Duration> get position;

  /// Returns the total duration of the video.
  Future<Duration> get duration;

  /// Returns whether the video is currently playing.
  Future<bool> get isPlaying;

  /// Stream of video position updates.
  Stream<Duration> get positionStream;

  /// Stream of video playback state changes.
  Stream<bool> get playingStream;

  /// Cleans up resources.
  Future<void> dispose();
}

/// Factory interface for creating VideoPlayerService instances.
/// This allows for flexible instantiation and easy swapping of implementations.
abstract class VideoPlayerFactory {
  /// Creates a new video player instance.
  VideoPlayerService createPlayer();
} 