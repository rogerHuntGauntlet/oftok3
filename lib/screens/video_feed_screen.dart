import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:media_kit/media_kit.dart';
import '../services/video/video_player_provider.dart';
import '../services/video/media_kit_player_service.dart';
import '../widgets/video_player_widget.dart';
import '../widgets/save_button.dart';
import '../providers/video_save_provider.dart';
import '../services/auth_service.dart';
import 'comments_screen.dart';

class VideoFeedScreen extends StatefulWidget {
  final List<String> videoUrls;
  final String projectId;
  final List<String> videoIds;
  final String projectName;

  const VideoFeedScreen({
    super.key,
    required this.videoUrls,
    required this.projectId,
    required this.videoIds,
    required this.projectName,
  });

  @override
  State<VideoFeedScreen> createState() => _VideoFeedScreenState();
}

class _VideoFeedScreenState extends State<VideoFeedScreen> {
  late PageController _pageController;
  int _currentPage = 0;
  final _authService = AuthService();

  @override
  void initState() {
    super.initState();
    // Initialize MediaKit
    MediaKit.ensureInitialized();
    _pageController = PageController();
    _pageController.addListener(_onPageChanged);
  }

  void _onPageChanged() {
    final page = _pageController.page?.round() ?? 0;
    if (page != _currentPage) {
      setState(() => _currentPage = page);
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _showComments(BuildContext context, String videoId) {
    if (!_authService.isSignedIn) {
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
      transitionAnimationController: AnimationController(
        vsync: Navigator.of(context),
        duration: const Duration(milliseconds: 300),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.9,
        builder: (_, controller) => Hero(
          tag: 'comments_$videoId',
          child: Material(
            color: Colors.transparent,
            child: CommentsScreen(
              videoId: videoId,
              userId: _authService.currentUserId!,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => VideoSaveProvider(projectId: widget.projectId),
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            PageView.builder(
              scrollDirection: Axis.vertical,
              controller: _pageController,
              itemCount: widget.videoUrls.length,
              itemBuilder: (context, index) {
                return ChangeNotifierProvider(
                  create: (context) => VideoPlayerProvider(
                    factory: MediaKitPlayerFactory(),
                  ),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      VideoPlayerWidget(
                        videoUrl: widget.videoUrls[index],
                        autoPlay: index == _currentPage,
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
                      // Interaction buttons
                      Positioned(
                        right: 16,
                        bottom: MediaQuery.of(context).padding.bottom + 16,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Comments button
                            Column(
                              children: [
                                GestureDetector(
                                  onTap: () => _showComments(context, widget.videoIds[index]),
                                  child: Container(
                                    width: 48,
                                    height: 48,
                                    decoration: BoxDecoration(
                                      color: Colors.black.withOpacity(0.5),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.comment,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                const Text(
                                  'Comments',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            // Save button
                            Column(
                              children: [
                                Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.5),
                                    shape: BoxShape.circle,
                                  ),
                                  child: SaveButton(
                                    videoId: widget.videoIds[index],
                                    projectId: widget.projectId,
                                    initialSaveState: true,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                const Text(
                                  'Save',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
} 