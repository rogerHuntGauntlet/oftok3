import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:media_kit_video/media_kit_video.dart';
import '../services/video/video_player_provider.dart';
import '../services/video/media_kit_player_service.dart';
import '../services/video/video_player_service.dart';
import '../services/project_service.dart';
import '../widgets/video_player_widget.dart';
import '../widgets/save_button.dart';
import '../services/auth_service.dart';
import '../screens/comments_screen.dart';

class VideoFeedItem extends StatefulWidget {
  final String videoUrl;
  final String videoId;
  final String projectName;
  final String projectId;
  final VideoPlayerService? preloadedPlayer;
  final bool autoPlay;

  const VideoFeedItem({
    super.key,
    required this.videoUrl,
    required this.videoId,
    required this.projectName,
    required this.projectId,
    this.preloadedPlayer,
    this.autoPlay = true,
  });

  @override
  State<VideoFeedItem> createState() => _VideoFeedItemState();
}

class _VideoFeedItemState extends State<VideoFeedItem> with WidgetsBindingObserver {
  VideoPlayerService? _player;
  bool _isInitialized = false;
  bool _hasError = false;
  String? _errorMessage;
  bool _isDisposed = false;
  bool _isPaused = false;
  final ProjectService _projectService = ProjectService();
  bool _hasTrackedView = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializePlayer();
  }

  @override
  void didUpdateWidget(VideoFeedItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.videoUrl != widget.videoUrl ||
        oldWidget.autoPlay != widget.autoPlay) {
      _cleanupPlayer();
      _initializePlayer();
    } else if (oldWidget.autoPlay != widget.autoPlay) {
      _handleAutoPlayChange();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_isDisposed) return;
    
    switch (state) {
      case AppLifecycleState.paused:
        _pauseVideo();
        break;
      case AppLifecycleState.resumed:
        if (widget.autoPlay && !_isPaused) {
          _resumeVideo();
        }
        break;
      default:
        break;
    }
  }

  Future<void> _initializePlayer() async {
    if (_isDisposed) return;

    try {
      setState(() {
        _isInitialized = false;
        _hasError = false;
        _errorMessage = null;
      });

      // Use preloaded player if available, otherwise create new one
      _player = widget.preloadedPlayer ?? MediaKitPlayerService();
      
      // Initialize with retry logic
      int attempts = 0;
      const maxAttempts = 3;
      
      while (attempts < maxAttempts && !_isDisposed) {
        try {
          await _player?.initialize(widget.videoUrl);
          break;
        } catch (e) {
          attempts++;
          if (attempts == maxAttempts) {
            throw e;
          }
          await Future.delayed(Duration(seconds: attempts));
        }
      }

      if (_isDisposed) return;

      setState(() {
        _isInitialized = true;
      });

      if (widget.autoPlay && !_isPaused) {
        await _player?.play();
      }
    } catch (e) {
      print('Error initializing video player: $e');
      if (!_isDisposed) {
        setState(() {
          _hasError = true;
          _errorMessage = 'Failed to load video: ${e.toString()}';
        });
      }
    }
  }

  Future<void> _cleanupPlayer() async {
    try {
      await _player?.pause();
      if (_player != widget.preloadedPlayer) {
        await _player?.dispose();
      }
      _player = null;
    } catch (e) {
      print('Error cleaning up player: $e');
    }
  }

  Future<void> _handleAutoPlayChange() async {
    if (_isDisposed || !_isInitialized) return;

    try {
      if (widget.autoPlay && !_isPaused) {
        await _player?.play();
      } else {
        await _player?.pause();
      }
    } catch (e) {
      print('Error handling autoplay change: $e');
    }
  }

  Future<void> _pauseVideo() async {
    if (_isDisposed || !_isInitialized) return;
    try {
      _isPaused = true;
      await _player?.pause();
    } catch (e) {
      print('Error pausing video: $e');
    }
  }

  Future<void> _resumeVideo() async {
    if (_isDisposed || !_isInitialized) return;
    try {
      _isPaused = false;
      if (widget.autoPlay) {
        await _player?.play();
      }
    } catch (e) {
      print('Error resuming video: $e');
    }
  }

  Future<void> _retryInitialization() async {
    await _cleanupPlayer();
    await _initializePlayer();
  }

  void _showComments(BuildContext context) {
    final authService = AuthService();
    if (!authService.isSignedIn) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please sign in to comment'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.9,
        builder: (_, controller) => Hero(
          tag: 'comments_${widget.videoId}',
          child: Material(
            color: Colors.transparent,
            child: CommentsScreen(
              videoId: widget.videoId,
              userId: authService.currentUserId!,
            ),
          ),
        ),
      ),
    );
  }

  void _onVideoStarted() {
    if (!_hasTrackedView) {
      _hasTrackedView = true;
      _projectService.incrementProjectScore(widget.projectId, 1);
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    WidgetsBinding.instance.removeObserver(this);
    _cleanupPlayer();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 48),
            const SizedBox(height: 16),
            Text(
              _errorMessage ?? 'Error loading video',
              style: const TextStyle(color: Colors.red),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _retryInitialization,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (!_isInitialized) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
        ),
      );
    }

    final mediaKitPlayer = _player as MediaKitPlayerService?;
    final videoController = mediaKitPlayer?.videoController;
    
    if (videoController == null) {
      return const Center(
        child: Text(
          'Video player not ready',
          style: TextStyle(color: Colors.white),
        ),
      );
    }

    return GestureDetector(
      onTap: () async {
        if (_isDisposed) return;
        
        final isPlaying = await _player?.isPlaying ?? false;
        if (isPlaying) {
          await _pauseVideo();
        } else {
          await _resumeVideo();
        }
      },
      child: Stack(
        fit: StackFit.expand,
        children: [
          Container(
            color: Colors.black,
            child: Video(
              controller: videoController,
              controls: NoVideoControls,
              fit: BoxFit.cover,
            ),
          ),
          StreamBuilder<bool>(
            stream: _player?.playingStream,
            builder: (context, snapshot) {
              final isPlaying = snapshot.data ?? false;
              if (!isPlaying && !_isPaused) {
                return Center(
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
                );
              }
              return const SizedBox.shrink();
            },
          ),
        ],
      ),
    );
  }
} 