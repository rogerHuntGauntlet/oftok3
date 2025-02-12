import 'package:flutter/material.dart';
import '../widgets/video_feed_item.dart';
import '../services/video/video_preload_service.dart';
import '../services/video/media_kit_player_service.dart';
import '../models/video.dart';
import '../models/project.dart';
import '../services/video_service.dart';
import '../services/social_service.dart';
import '../services/project_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../screens/project_details_screen.dart';

class VideoFeedScreen extends StatefulWidget {
  final List<String> videoUrls;
  final List<String> videoIds;
  final String? projectId;
  final String projectName;
  final VideoPreloadService? preloadService;
  final int initialIndex;

  const VideoFeedScreen({
    super.key,
    required this.videoUrls,
    required this.videoIds,
    this.projectId,
    required this.projectName,
    this.preloadService,
    this.initialIndex = 0,
  });

  @override
  State<VideoFeedScreen> createState() => _VideoFeedScreenState();
}

class _VideoFeedScreenState extends State<VideoFeedScreen> with WidgetsBindingObserver {
  PageController? _pageController;
  List<MediaKitPlayerService>? _players;
  int _currentPage = 0;
  bool _isLoading = true;
  String? _error;
  final VideoService _videoService = VideoService();
  final ProjectService _projectService = ProjectService();
  final SocialService _socialService = SocialService();
  final TextEditingController _commentController = TextEditingController();
  List<Video> _videos = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    print('\n🟢 === VideoFeedScreen Lifecycle: initState ===');
    print('Video URLs (${widget.videoUrls.length}): ${widget.videoUrls}');
    print('Video IDs (${widget.videoIds.length}): ${widget.videoIds}');
    print('Project Name: ${widget.projectName}');
    print('Project ID: ${widget.projectId ?? 'Not provided'}');
    print('Initial Index: ${widget.initialIndex}');
    print('Auth State: ${FirebaseAuth.instance.currentUser?.uid ?? 'Not signed in'}');
    print('=====================================');
    
    if (widget.videoUrls.isEmpty || widget.videoIds.isEmpty) {
      print('❌ Error: No videos provided for feed');
      print('URLs empty: ${widget.videoUrls.isEmpty}');
      print('IDs empty: ${widget.videoIds.isEmpty}');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          print('❌ Returning to previous screen due to no videos');
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No videos available to play'),
              backgroundColor: Colors.red,
            ),
          );
        }
      });
      return;
    }

    print('🟢 Starting initialization sequence...');
    // Load video details first, then initialize video system
    _loadVideoDetails().then((_) {
      print('🟢 Video details loaded, proceeding with system initialization');
      if (mounted) {
        _initializeVideoSystem();
      } else {
        print('❌ Widget not mounted after loading video details');
      }
    }).catchError((e, stackTrace) {
      print('❌ Error in initialization sequence:');
      print('Error: $e');
      print('Stack trace: $stackTrace');
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    print('\n🟢 === VideoFeedScreen Lifecycle: didChangeDependencies ===');
    print('Is Loading: $_isLoading');
    print('Has Error: ${_error != null}');
    print('Current Page: $_currentPage');
    print('Number of Players: ${_players?.length}');
    print('Number of Videos: ${_videos.length}');
  }

  @override
  void didUpdateWidget(VideoFeedScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    print('\n🟢 === VideoFeedScreen Lifecycle: didUpdateWidget ===');
    print('Old URLs length: ${oldWidget.videoUrls.length}');
    print('New URLs length: ${widget.videoUrls.length}');
    print('Old IDs length: ${oldWidget.videoIds.length}');
    print('New IDs length: ${widget.videoIds.length}');
    print('Project ID changed: ${oldWidget.projectId != widget.projectId}');
  }

  @override
  void dispose() {
    print('\n🟢 === VideoFeedScreen Lifecycle: dispose ===');
    print('Cleaning up resources...');
    WidgetsBinding.instance.removeObserver(this);
    
    print('Disposing page controller...');
    _pageController?.dispose();
    _pageController = null;
    
    print('Disposing video players...');
    for (final player in _players ?? []) {
      try {
        player.dispose();
      } catch (e) {
        print('❌ Error disposing player: $e');
      }
    }
    _players?.clear();
    _players = null;
    
    print('Disposing comment controller...');
    _commentController.dispose();
    
    print('✓ Cleanup complete');
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    print('\n🟢 === App Lifecycle State Changed: $state ===');
    print('Current Page: $_currentPage');
    print('Is Loading: $_isLoading');
    print('Number of Players: ${_players?.length}');
    
    switch (state) {
      case AppLifecycleState.paused:
        print('App paused - pausing all players');
        _pauseAllPlayers();
        break;
      case AppLifecycleState.resumed:
        print('App resumed - resuming current player');
        _resumeCurrentPlayer();
        break;
      default:
        print('Other lifecycle state: $state');
    }
  }

  Future<void> _pauseAllPlayers() async {
    print('Pausing all players...');
    for (final player in _players ?? []) {
      try {
        await player.pause();
      } catch (e) {
        print('❌ Error pausing player: $e');
      }
    }
  }

  Future<void> _resumeCurrentPlayer() async {
    print('Resuming current player...');
    if (_currentPage >= 0 && _currentPage < (_players?.length ?? 0)) {
      try {
        await _players?[_currentPage].play();
      } catch (e) {
        print('❌ Error resuming player: $e');
      }
    }
  }

  Future<void> _loadVideoDetails() async {
    if (!mounted) {
      print('❌ Widget not mounted during _loadVideoDetails');
      return;
    }

    try {
      print('\n=== Loading Video Details ===');
      print('Number of video IDs to load: ${widget.videoIds.length}');
      
      if (widget.videoIds.isEmpty) {
        throw Exception('No video IDs provided');
      }

      setState(() {
        _isLoading = true;
        _error = null;
      });

      // For doomscroll mode, we don't need to reload video details
      if (widget.projectId == 'doomscroll') {
        print('Doomscroll mode detected, using provided video data');
        final dummyVideos = List.generate(
          widget.videoIds.length,
          (i) => Video(
            id: widget.videoIds[i],
            url: widget.videoUrls[i],
            title: 'Video ${i + 1}',
            description: null,
            thumbnailUrl: null,
            duration: 0,
            userId: FirebaseAuth.instance.currentUser?.uid ?? 'anonymous',
            uploadedAt: DateTime.now(),
            tags: [],
            views: 0,
            likedBy: [],
            isAiGenerated: false,
          ),
        );
        
        if (!mounted) return;
        
        setState(() {
          _videos = dummyVideos;
          _isLoading = false;
        });
        
        print('✓ State updated with dummy videos for doomscroll');
        print('Number of dummy videos: ${dummyVideos.length}');
        print('First dummy video: ${dummyVideos.first.toJson()}');
        return;
      }

      final List<Video> loadedVideos = [];
      
      for (int i = 0; i < widget.videoIds.length; i++) {
        final videoId = widget.videoIds[i];
        final videoUrl = widget.videoUrls[i];
        
        print('\nProcessing video $i:');
        print('ID: $videoId');
        print('URL: $videoUrl');
        
        final video = await _videoService.getVideo(videoId);
        if (video != null) {
          print('✓ Successfully loaded video details');
          loadedVideos.add(video);
        } else {
          print('❌ Failed to load video details');
        }
      }

      if (!mounted) {
        print('❌ Widget not mounted after loading videos');
        return;
      }

      print('\n=== Video Loading Summary ===');
      print('Total videos attempted: ${widget.videoIds.length}');
      print('Successfully loaded: ${loadedVideos.length}');
      print('Failed to load: ${widget.videoIds.length - loadedVideos.length}');

      if (loadedVideos.isEmpty) {
        throw Exception('No valid videos found');
      }

      setState(() {
        _videos = loadedVideos;
        _isLoading = false;
      });
      
      print('✓ State updated with loaded videos');
      print('===========================\n');

    } catch (e, stackTrace) {
      print('\n❌ Error in _loadVideoDetails:');
      print('Error: $e');
      print('Stack trace: $stackTrace');
      
      if (!mounted) return;
      
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
      
      // Navigate back on error
      Navigator.of(context).pop();
    }
  }

  void _initializeVideoSystem() {
    print('\n=== Initializing Video System ===');
    try {
      _pageController = PageController(initialPage: widget.initialIndex);
      _currentPage = widget.initialIndex;
      
      // Initialize video players
      print('Setting up video players...');
      _players = List.generate(
        widget.videoUrls.length,
        (index) => MediaKitPlayerService()
      );
      print('Created ${_players?.length} video players');

      // Preload first video
      if (_players?.isNotEmpty ?? false) {
        print('Preloading first video...');
        _preloadVideo(widget.initialIndex);
      } else {
        print('❌ No videos to preload');
      }

      // Add page change listener
      _pageController?.addListener(() {
        final nextPage = _pageController?.page?.round() ?? 0;
        if (_currentPage != nextPage) {
          print('\nPage changed from $_currentPage to $nextPage');
          _handlePageChange(nextPage);
        }
      });
      
      print('✓ Video system initialization complete');
      print('===========================\n');
    } catch (e, stackTrace) {
      print('❌ Error initializing video system:');
      print('Error: $e');
      print('Stack trace: $stackTrace');
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
        Navigator.of(context).pop();
      }
    }
  }

  void _handlePageChange(int nextPage) async {
    if (nextPage < 0 || nextPage >= (_players?.length ?? 0)) return;
    
    // Pause current video
    if (_currentPage >= 0 && _currentPage < (_players?.length ?? 0)) {
      await _players?[_currentPage].pause();
    }

    // Update current page
    _currentPage = nextPage;

    // Initialize and play next video
    final player = _players?[nextPage];
    if (player != null) {
      try {
        await player.initialize(widget.videoUrls[nextPage]);
        await player.play();
      } catch (e) {
        print('Error initializing/playing video at index $nextPage: $e');
      }
    }

    // Preload next video if available
    if (nextPage + 1 < (_players?.length ?? 0)) {
      final nextPlayer = _players?[nextPage + 1];
      if (nextPlayer != null) {
        try {
          await nextPlayer.initialize(widget.videoUrls[nextPage + 1]);
        } catch (e) {
          print('Error preloading next video: $e');
        }
      }
    }
  }

  Future<void> _preloadVideo(int index) async {
    if (index < 0 || index >= (_players?.length ?? 0)) {
      print('❌ Invalid index for preloading: $index');
      return;
    }

    try {
      print('\nPreloading video at index $index');
      final player = _players?[index];
      if (player == null) return;
      
      await player.initialize(widget.videoUrls[index]);
      
      if (index == _currentPage) {
        await player.play();
        print('✓ Started playing video at index $index');
      }
      
      print('✓ Successfully preloaded video at index $index');
    } catch (e, stackTrace) {
      print('❌ Error preloading video at index $index:');
      print('Error: $e');
      print('Stack trace: $stackTrace');
    }
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    Color? color,
  }) {
    return GestureDetector(
      onTap: onPressed,
      child: Column(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.black.withOpacity(0.3),
            ),
            child: Icon(
              icon,
              color: color ?? Colors.white,
              size: 30,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              shadows: [
                Shadow(
                  blurRadius: 4,
                  color: Colors.black,
                  offset: Offset(0, 1),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showVideoProjectsDialog(Video video) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please sign in to view projects')),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Projects Containing This Video'),
        content: SizedBox(
          width: double.maxFinite,
          height: 300,
          child: FutureBuilder<List<Project>>(
            future: _projectService.getProjectsContainingVideo(video.id),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              }

              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final projects = snapshot.data!;
              if (projects.isEmpty) {
                return const Center(
                  child: Text('This video is not in any other projects'),
                );
              }

              return ListView.builder(
                itemCount: projects.length,
                itemBuilder: (context, index) {
                  final project = projects[index];
                  return ListTile(
                    leading: const Icon(Icons.folder),
                    title: Text(project.name),
                    subtitle: Text(project.description ?? 'No description'),
                    trailing: const Icon(Icons.arrow_forward_ios),
                    onTap: () {
                      Navigator.pop(context); // Close dialog
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ProjectDetailsScreen(project: project),
                        ),
                      );
                    },
                  );
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildVideoInfo(Video video) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            video.title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
              shadows: [
                Shadow(
                  blurRadius: 4,
                  color: Colors.black,
                  offset: Offset(0, 1),
                ),
              ],
            ),
          ),
          if (video.description != null) ...[
            const SizedBox(height: 8),
            Text(
              video.description!,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                shadows: [
                  Shadow(
                    blurRadius: 4,
                    color: Colors.black,
                    offset: Offset(0, 1),
                  ),
                ],
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(
                Icons.folder,
                color: Colors.white,
                size: 16,
                shadows: const [
                  Shadow(
                    blurRadius: 4,
                    color: Colors.black,
                    offset: Offset(0, 1),
                  ),
                ],
              ),
              const SizedBox(width: 4),
              Text(
                widget.projectName,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  shadows: [
                    Shadow(
                      blurRadius: 4,
                      color: Colors.black,
                      offset: Offset(0, 1),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '$minutes:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  void _showCommentSheet(Video video) {
    if (widget.projectId == 'doomscroll' || widget.projectId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Comments are only available in projects'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) {
          return _buildCommentSection(scrollController);
        },
      ),
    );
  }

  Widget _buildCommentSection(ScrollController scrollController) {
    if (widget.projectId == 'doomscroll' || widget.projectId == null) {
      return const SizedBox.shrink();
    }
    
    return StreamBuilder<QuerySnapshot>(
      stream: _socialService.getComments(widget.projectId!),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final comments = snapshot.data!.docs;
        if (comments.isEmpty) {
          return const Center(
            child: Text('No comments yet. Be the first to comment!'),
          );
        }

        return Column(
          children: [
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                itemCount: comments.length,
                itemBuilder: (context, index) {
                  final comment = comments[index].data() as Map<String, dynamic>;
                  final commentId = comments[index].id;
                  final hasReplies = (comment['replies'] as List?)?.isNotEmpty ?? false;
                  
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ListTile(
                        title: Row(
                          children: [
                            Text(comment['userName'] ?? 'Anonymous'),
                            const SizedBox(width: 8),
                            Text(
                              _formatTimestamp(comment['timestamp'] as Timestamp),
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            Text(comment['comment'] as String),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                // Like button
                                StreamBuilder<bool>(
                                  stream: _socialService.getCommentLikeStatus(widget.projectId!, commentId),
                                  builder: (context, snapshot) {
                                    final isLiked = snapshot.data ?? false;
                                    return InkWell(
                                      onTap: () => _socialService.toggleCommentLike(widget.projectId!, commentId),
                                      child: Row(
                                        children: [
                                          Icon(
                                            isLiked ? Icons.favorite : Icons.favorite_border,
                                            size: 16,
                                            color: isLiked ? Colors.red : null,
                                          ),
                                          const SizedBox(width: 4),
                                          Text('${comment['likeCount'] ?? 0}'),
                                        ],
                                      ),
                                    );
                                  }
                                ),
                                const SizedBox(width: 16),
                                // Reply button
                                InkWell(
                                  onTap: () => _showReplyInput(commentId),
                                  child: const Row(
                                    children: [
                                      Icon(Icons.reply, size: 16),
                                      SizedBox(width: 4),
                                      Text('Reply'),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      // Show replies if any
                      if (hasReplies)
                        Padding(
                          padding: const EdgeInsets.only(left: 56),
                          child: StreamBuilder<QuerySnapshot>(
                            stream: _socialService.getReplies(widget.projectId!, commentId),
                            builder: (context, snapshot) {
                              if (!snapshot.hasData) return const SizedBox();
                              
                              final replies = snapshot.data!.docs;
                              return Column(
                                children: replies.map((reply) {
                                  final replyData = reply.data() as Map<String, dynamic>;
                                  return ListTile(
                                    dense: true,
                                    title: Row(
                                      children: [
                                        Text(
                                          replyData['userName'] ?? 'Anonymous',
                                          style: const TextStyle(fontSize: 14),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          _formatTimestamp(replyData['timestamp'] as Timestamp),
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                      ],
                                    ),
                                    subtitle: Text(
                                      replyData['text'] as String,
                                      style: const TextStyle(fontSize: 14),
                                    ),
                                  );
                                }).toList(),
                              );
                            },
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
            // Comment input
            Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                bottom: MediaQuery.of(context).viewInsets.bottom + 16,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _commentController,
                      decoration: const InputDecoration(
                        hintText: 'Add a comment...',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.send),
                    onPressed: () {
                      final comment = _commentController.text.trim();
                      if (comment.isNotEmpty) {
                        _handleCommentSubmit(comment);
                        _commentController.clear();
                        FocusScope.of(context).unfocus();
                      }
                    },
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  void _showReplyInput(String commentId) {
    final replyController = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Container(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: replyController,
                  autofocus: true,
                  decoration: const InputDecoration(
                    hintText: 'Write a reply...',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.send),
                onPressed: () {
                  final reply = replyController.text.trim();
                  if (reply.isNotEmpty) {
                    _handleReplySubmit(commentId, reply);
                    Navigator.pop(context);
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showEmojiPicker(String? commentId) {
    // Show emoji picker and handle reaction
    // You'll need to implement or use an emoji picker package
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        height: 250,
        padding: const EdgeInsets.all(16),
        child: GridView.count(
          crossAxisCount: 8,
          children: ['❤️', '👍', '😂', '😮', '😢', '😡', '🎉', '👏']
              .map((emoji) => InkWell(
                    onTap: () {
                      if (commentId != null) {
                        _handleReactionSubmit(commentId, emoji);
                      } else {
                        _commentController.text += emoji;
                      }
                      Navigator.pop(context);
                    },
                    child: Center(
                      child: Text(
                        emoji,
                        style: const TextStyle(fontSize: 24),
                      ),
                    ),
                  ))
              .toList(),
        ),
      ),
    );
  }

  Future<void> _showProjectSelectionDialog(Video video) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please sign in to save videos')),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Save to Project'),
        content: SizedBox(
          width: double.maxFinite,
          child: StreamBuilder<List<Project>>(
            stream: _projectService.getUserAccessibleProjects(currentUser.uid),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Text('Error: ${snapshot.error}');
              }

              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final projects = snapshot.data!;
              if (projects.isEmpty) {
                return const Text('No projects found');
              }

              return ListView.builder(
                shrinkWrap: true,
                itemCount: projects.length,
                itemBuilder: (context, index) {
                  final project = projects[index];
                  // Skip current project if we have a valid projectId
                  if (widget.projectId != null && project.id == widget.projectId) {
                    return const SizedBox.shrink();
                  }
                  
                  return ListTile(
                    title: Text(project.name),
                    subtitle: Text(project.description ?? 'No description'),
                    onTap: () async {
                      try {
                        await _projectService.addVideoToProject(
                          project.id,
                          video.id,
                        );
                        if (mounted) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Video saved to ${project.name}'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        }
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Error saving video: ${e.toString()}'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      }
                    },
                  );
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  String _formatTimestamp(Timestamp timestamp) {
    final now = DateTime.now();
    final date = timestamp.toDate();
    final difference = now.difference(date);

    if (difference.inDays > 7) {
      return '${date.day}/${date.month}/${date.year}';
    } else if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  Future<void> _handleLike(Video video) async {
    if (widget.projectId == 'doomscroll' || widget.projectId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Likes are only available in projects'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }
    await _socialService.toggleLike(widget.projectId!);
  }

  Future<void> _handleShare(Video video) async {
    if (widget.projectId == 'doomscroll' || widget.projectId == null) {
      // For doomscroll mode, share just the video
      await Share.share(
        'Check out this video: ${video.url}',
        subject: 'Video Share',
      );
      return;
    }
    try {
      final shareUrl = await _socialService.generateShareUrl(widget.projectId!);
      await Share.share(
        'Check out this project: $shareUrl',
        subject: widget.projectName,
      );
    } catch (e) {
      print('Error sharing project: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    print('\n🟢 === VideoFeedScreen Build ===');
    print('Is Loading: $_isLoading');
    print('Has Error: ${_error != null}');
    print('Number of Videos: ${_videos.length}');
    print('Current Page: $_currentPage');
    
    if (_isLoading) {
      print('Rendering loading state');
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
              SizedBox(height: 16),
              Text(
                'Loading videos...',
                style: TextStyle(color: Colors.white),
              ),
            ],
          ),
        ),
      );
    }

    if (_videos.isEmpty) {
      print('Rendering empty state');
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: Colors.white, size: 48),
              const SizedBox(height: 16),
              const Text(
                'No videos available',
                style: TextStyle(color: Colors.white),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Go Back'),
              ),
            ],
          ),
        ),
      );
    }

    print('Rendering video feed with ${_videos.length} videos');
    return Scaffold(
      backgroundColor: Colors.black,
      body: PageView.builder(
        controller: _pageController,
        scrollDirection: Axis.vertical,
        itemCount: widget.videoUrls.length,
        itemBuilder: (context, index) {
          final videoUrl = widget.videoUrls[index];
          final videoId = widget.videoIds[index];
          final preloadedPlayer = _players?[index];
          
          print('Building video item $index:');
          print('URL: $videoUrl');
          print('ID: $videoId');
          print('Has preloaded player: ${preloadedPlayer != null}');
          
          return Stack(
            children: [
              VideoFeedItem(
                videoUrl: videoUrl,
                videoId: videoId,
                projectId: widget.projectId ?? 'doomscroll',
                projectName: widget.projectName,
                preloadedPlayer: preloadedPlayer,
                autoPlay: index == _currentPage,
              ),
              
              // Video info overlay
              if (index < _videos.length)
                Positioned(
                  left: 16,
                  right: 72,
                  bottom: 16,
                  child: _buildVideoInfo(_videos[index]),
                ),
              
              // Action buttons
              if (index < _videos.length)
                Positioned(
                  right: 8,
                  bottom: MediaQuery.of(context).padding.bottom + 16,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Like button
                      _buildLikeButton(_videos[index]),
                      const SizedBox(height: 16),
                      
                      // Comment button
                      _buildActionButton(
                        icon: Icons.comment,
                        label: 'Comment',
                        onPressed: () => _showCommentSheet(_videos[index]),
                      ),
                      const SizedBox(height: 16),
                      
                      // Share button
                      _buildActionButton(
                        icon: Icons.share,
                        label: 'Share',
                        onPressed: () => _handleShare(_videos[index]),
                      ),
                      const SizedBox(height: 16),
                      
                      // Save to project button
                      _buildActionButton(
                        icon: Icons.bookmark_border,
                        label: 'Save',
                        onPressed: () => _showProjectSelectionDialog(_videos[index]),
                      ),
                      const SizedBox(height: 16),
                      
                      // Show projects containing this video
                      _buildActionButton(
                        icon: Icons.folder,
                        label: 'Projects',
                        onPressed: () => _showVideoProjectsDialog(_videos[index]),
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

  // Social features
  Future<void> _toggleLike() async {
    if (widget.projectId == null) return;
    await _socialService.toggleLike(widget.projectId!);
  }

  Future<void> _shareProject() async {
    if (widget.projectId == null) return;
    try {
      final shareUrl = await _socialService.generateShareUrl(widget.projectId!);
      await Share.share(
        'Check out this project: $shareUrl',
        subject: widget.projectName,
      );
    } catch (e) {
      print('Error sharing project: $e');
    }
  }

  Widget _buildLikeButton(Video video) {
    if (widget.projectId == 'doomscroll' || widget.projectId == null) {
      return _buildActionButton(
        icon: Icons.favorite_border,
        label: 'Like',
        onPressed: () => _handleLike(video),
      );
    }
    
    return StreamBuilder<bool>(
      stream: _socialService.getLikeStatus(widget.projectId!),
      builder: (context, snapshot) {
        final isLiked = snapshot.data ?? false;
        return _buildActionButton(
          icon: isLiked ? Icons.favorite : Icons.favorite_border,
          label: 'Like',
          onPressed: () => _handleLike(video),
          color: isLiked ? Colors.red : null,
        );
      },
    );
  }

  void _handleCommentSubmit(String comment) {
    if (widget.projectId == null || widget.projectId == 'doomscroll') return;
    _socialService.addComment(widget.projectId!, comment);
  }

  void _handleReplySubmit(String commentId, String reply) {
    if (widget.projectId == null || widget.projectId == 'doomscroll') return;
    _socialService.addReply(widget.projectId!, commentId, reply);
  }

  void _handleReactionSubmit(String commentId, String emoji) {
    if (widget.projectId == null || widget.projectId == 'doomscroll') return;
    _socialService.addReaction(widget.projectId!, commentId, emoji);
  }
} 