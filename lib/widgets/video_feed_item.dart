import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:media_kit_video/media_kit_video.dart' as media_kit_video;
import '../services/video/video_player_provider.dart';
import '../services/video/media_kit_player_service.dart';
import '../services/video/video_player_service.dart';
import '../services/project_service.dart';
import '../widgets/video_player_widget.dart';
import '../widgets/save_button.dart';
import '../services/auth_service.dart';
import '../screens/comments_screen.dart';
import '../models/video.dart';
import '../screens/project_details_screen.dart';
import '../widgets/video_controls_overlay.dart';

class VideoFeedItem extends StatefulWidget {
  final Video video;
  final MediaKitPlayerService player;
  final String? projectId;
  final String projectName;
  final bool showInfo;
  final VoidCallback? onLike;
  final VoidCallback? onShare;
  final VoidCallback? onProjectTap;

  const VideoFeedItem({
    super.key,
    required this.video,
    required this.player,
    required this.projectName,
    this.projectId,
    this.showInfo = true,
    this.onLike,
    this.onShare,
    this.onProjectTap,
  });

  @override
  State<VideoFeedItem> createState() => _VideoFeedItemState();
}

class _VideoFeedItemState extends State<VideoFeedItem> with WidgetsBindingObserver {
  bool _isDisposed = false;
  bool _hasTrackedView = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _trackVideoView();
  }

  @override
  void didUpdateWidget(VideoFeedItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.video != widget.video ||
        oldWidget.player != widget.player) {
      _trackVideoView();
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
        _resumeVideo();
        break;
      default:
        break;
    }
  }

  Future<void> _pauseVideo() async {
    if (_isDisposed) return;
    await widget.player.pause();
  }

  Future<void> _resumeVideo() async {
    if (_isDisposed) return;
    await widget.player.play();
  }

  Future<void> _trackVideoView() async {
    if (_hasTrackedView) return;
    _hasTrackedView = true;
    // TODO: Implement view tracking
  }

  @override
  void dispose() {
    _isDisposed = true;
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Video Player
        media_kit_video.Video(
          controller: widget.player.videoController!,
          controls: media_kit_video.NoVideoControls,
        ),

        // Video Controls Overlay (only if showInfo is true)
        if (widget.showInfo)
          VideoControlsOverlay(
            video: widget.video,
            projectName: widget.projectName,
            onLike: widget.onLike,
            onShare: widget.onShare,
            onProjectTap: widget.onProjectTap,
          ),

        // Back Button
        Positioned(
          top: MediaQuery.of(context).padding.top + 16,
          left: 16,
          child: GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.5),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.arrow_back,
                color: Colors.white,
                size: 24,
              ),
            ),
          ),
        ),
      ],
    );
  }
} 