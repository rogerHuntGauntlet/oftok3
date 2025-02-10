import 'package:flutter/material.dart';
import '../widgets/video_feed_item.dart';
import '../services/video/video_preload_service.dart';
import '../services/video/media_kit_player_service.dart';

class VideoFeedScreen extends StatefulWidget {
  final List<String> videoUrls;
  final List<String> videoIds;
  final String projectName;
  final String projectId;
  final VideoPreloadService? preloadService;

  const VideoFeedScreen({
    super.key,
    required this.videoUrls,
    required this.videoIds,
    required this.projectId,
    required this.projectName,
    this.preloadService,
  });

  @override
  State<VideoFeedScreen> createState() => _VideoFeedScreenState();
}

class _VideoFeedScreenState extends State<VideoFeedScreen> {
  late PageController _pageController;
  int _currentPage = 0;
  late final VideoPreloadService _preloadService;

  @override
  void initState() {
    super.initState();
    _initializeVideoSystem();
  }

  Future<void> _initializeVideoSystem() async {
    // Initialize page controller
    _pageController = PageController();
    _pageController.addListener(_onPageChanged);

    // Initialize preload service
    _preloadService = widget.preloadService ?? VideoPreloadService(
      factory: MediaKitPlayerFactory(),
      maxPreloadedVideos: 2, // Reduce to 2 to prevent memory issues
    );

    // Start preloading next videos
    if (widget.videoUrls.isNotEmpty) {
      await _preloadNextVideos();
    }
  }

  Future<void> _preloadNextVideos() async {
    if (widget.videoUrls.isEmpty) return;

    final nextVideos = widget.videoUrls
        .skip(_currentPage + 1)
        .take(2) // Preload next 2 videos
        .toList();
    
    if (nextVideos.isNotEmpty) {
      await _preloadService.preloadVideos(nextVideos);
    }
  }

  void _onPageChanged() {
    final page = _pageController.page?.round() ?? 0;
    if (page != _currentPage) {
      setState(() => _currentPage = page);
      // Preload next videos when page changes
      _preloadNextVideos();
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    if (widget.preloadService == null) {
      // Only dispose if we created the service
      _preloadService.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: PageView.builder(
        scrollDirection: Axis.vertical,
        controller: _pageController,
        itemCount: widget.videoUrls.length,
        itemBuilder: (context, index) {
          final videoUrl = widget.videoUrls[index];
          return VideoFeedItem(
            key: ValueKey(videoUrl),
            videoUrl: videoUrl,
            videoId: widget.videoIds[index],
            projectName: widget.projectName,
            projectId: widget.projectId,
            preloadedPlayer: _preloadService.getPreloadedPlayer(videoUrl),
            autoPlay: index == _currentPage,
          );
        },
      ),
    );
  }
} 