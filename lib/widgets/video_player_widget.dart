import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:media_kit_video/media_kit_video.dart';
import '../services/video/video_player_provider.dart';
import '../services/video/video_player_service.dart';
import '../services/video/media_kit_player_service.dart';

class VideoPlayerWidget extends StatefulWidget {
  final String videoUrl;
  final bool autoPlay;
  final bool showControls;
  final VideoPlayerService? preloadedPlayer;
  final VoidCallback? onVideoStarted;

  const VideoPlayerWidget({
    super.key,
    required this.videoUrl,
    this.autoPlay = true,
    this.showControls = true,
    this.preloadedPlayer,
    this.onVideoStarted,
  });

  @override
  State<VideoPlayerWidget> createState() => _VideoPlayerWidgetState();
}

class _VideoPlayerWidgetState extends State<VideoPlayerWidget> {
  bool _isInitializing = true;
  bool _hasError = false;
  String? _errorMessage;
  bool _hasNotifiedStart = false;

  @override
  void initState() {
    super.initState();
    _initializeVideo();
  }

  Future<void> _initializeVideo() async {
    if (!mounted) return;

    setState(() {
      _isInitializing = true;
      _hasError = false;
      _errorMessage = null;
      _hasNotifiedStart = false;
    });

    try {
      final provider = Provider.of<VideoPlayerProvider>(context, listen: false);
      
      // Initialize the video
      await provider.initializeVideo(
        widget.videoUrl,
        preloadedPlayer: widget.preloadedPlayer,
      );

      // Set up listener for playback state
      provider.addListener(() {
        if (!_hasNotifiedStart && provider.isPlaying) {
          _hasNotifiedStart = true;
          widget.onVideoStarted?.call();
        }
      });

      // Handle autoplay
      if (widget.autoPlay) {
        await provider.play();
      } else {
        await provider.pause();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = e.toString();
        });
      }
      print('Video initialization error: $e'); // Debug log
    } finally {
      if (mounted) {
        setState(() {
          _isInitializing = false;
        });
      }
    }
  }

  @override
  void didUpdateWidget(VideoPlayerWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // Re-initialize if URL changes or autoplay state changes
    if (widget.videoUrl != oldWidget.videoUrl || 
        widget.autoPlay != oldWidget.autoPlay) {
      _initializeVideo();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<VideoPlayerProvider>(
      builder: (context, provider, child) {
        if (_isInitializing || provider.isLoading) {
          return const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          );
        }

        if (_hasError || provider.error != null) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 48),
                const SizedBox(height: 16),
                Text(
                  _errorMessage ?? provider.error ?? 'Error loading video',
                  style: const TextStyle(color: Colors.red),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _initializeVideo,
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        }

        final player = provider.player;
        if (player == null) {
          return const Center(
            child: Text(
              'No video loaded',
              style: TextStyle(color: Colors.white),
            ),
          );
        }

        final mediaKitPlayer = player as MediaKitPlayerService;
        final videoController = mediaKitPlayer.videoController;
        if (videoController == null) {
          return const Center(
            child: Text(
              'Video controller not ready',
              style: TextStyle(color: Colors.white),
            ),
          );
        }

        return GestureDetector(
          onTap: () {
            if (provider.isPlaying) {
              provider.pause();
            } else {
              provider.play();
            }
          },
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Video content
              Container(
                color: Colors.black,
                child: Video(
                  controller: videoController,
                  controls: NoVideoControls,
                  fit: BoxFit.cover,
                ),
              ),

              // Play/Pause overlay
              if (widget.showControls && !provider.isPlaying)
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.5),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.play_arrow,
                      color: Colors.white,
                      size: 48,
                    ),
                  ),
                ),

              // Progress bar
              if (widget.showControls)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: VideoProgressBar(provider: provider),
                ),
            ],
          ),
        );
      },
    );
  }
}

class VideoProgressBar extends StatelessWidget {
  final VideoPlayerProvider provider;

  const VideoProgressBar({
    super.key,
    required this.provider,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.transparent,
            Colors.black.withOpacity(0.5),
          ],
        ),
      ),
      child: Center(
        child: SizedBox(
          width: MediaQuery.of(context).size.width * 0.5,
          child: StreamBuilder<Duration>(
            stream: provider.player?.positionStream,
            builder: (context, snapshot) {
              final position = snapshot.data ?? Duration.zero;
              final progress = provider.duration.inMilliseconds > 0
                  ? position.inMilliseconds / provider.duration.inMilliseconds
                  : 0.0;
              
              return Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Current position
                  Text(
                    _formatDuration(position),
                    style: const TextStyle(color: Colors.white),
                  ),
                  
                  // Progress slider
                  Expanded(
                    child: SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        trackHeight: 2,
                        thumbShape: const RoundSliderThumbShape(
                          enabledThumbRadius: 6,
                        ),
                        overlayShape: const RoundSliderOverlayShape(
                          overlayRadius: 12,
                        ),
                        activeTrackColor: Colors.white,
                        inactiveTrackColor: Colors.white.withOpacity(0.3),
                        thumbColor: Colors.white,
                        overlayColor: Colors.white.withOpacity(0.3),
                      ),
                      child: Slider(
                        value: progress.clamp(0.0, 1.0),
                        onChanged: (value) {
                          final newPosition = Duration(
                            milliseconds: (value * provider.duration.inMilliseconds).round(),
                          );
                          provider.seek(newPosition);
                        },
                      ),
                    ),
                  ),

                  // Total duration
                  Text(
                    _formatDuration(provider.duration),
                    style: const TextStyle(color: Colors.white),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }
} 