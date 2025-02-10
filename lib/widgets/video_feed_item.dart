import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/video/video_player_provider.dart';
import '../services/video/media_kit_player_service.dart';
import '../services/video/video_player_service.dart';
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
    Key? key,
    required this.videoUrl,
    required this.videoId,
    required this.projectName,
    required this.projectId,
    this.preloadedPlayer,
    this.autoPlay = true,
  }) : super(key: key);

  @override
  State<VideoFeedItem> createState() => _VideoFeedItemState();
}

class _VideoFeedItemState extends State<VideoFeedItem> {
  late final VideoPlayerProvider _provider;
  bool _isInitialized = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _provider = VideoPlayerProvider(
      factory: MediaKitPlayerFactory(),
      onError: _handleError,
    );
    _initializePlayer();
  }

  Future<void> _initializePlayer() async {
    try {
      await _provider.initializeVideo(
        widget.videoUrl,
        preloadedPlayer: widget.preloadedPlayer,
      );
      if (mounted) {
        setState(() => _isInitialized = true);
      }
    } catch (e) {
      _handleError(e.toString());
    }
  }

  void _handleError(String error) {
    if (!mounted) return;
    
    setState(() => _error = error);
    
    // Show error to user
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Video playback error: $error'),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
        action: SnackBarAction(
          label: 'Retry',
          onPressed: () {
            setState(() => _error = null);
            _initializePlayer();
          },
        ),
      ),
    );
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

  @override
  void dispose() {
    _provider.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _provider,
      child: Consumer<VideoPlayerProvider>(
        builder: (context, provider, child) {
          if (!_isInitialized && _error == null) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (_error != null) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.error_outline,
                    color: Colors.red,
                    size: 48,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Failed to load video',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: () {
                      setState(() => _error = null);
                      _initializePlayer();
                    },
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          return Stack(
            fit: StackFit.expand,
            children: [
              VideoPlayerWidget(
                key: ValueKey(widget.videoUrl),
                videoUrl: widget.videoUrl,
                autoPlay: widget.autoPlay,
                showControls: true,
                preloadedPlayer: widget.preloadedPlayer,
              ),
              // Project name header
              Positioned(
                top: MediaQuery.of(context).padding.top + 16,
                left: 16,
                right: 16,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    widget.projectName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
              // Interaction buttons (Comments and Save)
              Positioned(
                right: 16,
                bottom: MediaQuery.of(context).padding.bottom + 16,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.comment, color: Colors.white),
                      onPressed: () => _showComments(context),
                    ),
                    const SizedBox(height: 8),
                    SaveButton(
                      videoId: widget.videoId,
                      projectId: widget.projectId,
                      initialSaveState: true,
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
} 