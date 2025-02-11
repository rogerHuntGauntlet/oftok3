import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../models/app_user.dart';
import '../models/project.dart';
import '../models/video.dart';
import '../services/video_service.dart';
import '../services/project_service.dart';
import '../services/user_service.dart';
import '../services/video/video_preload_service.dart';
import '../widgets/video_thumbnail.dart';
import '../widgets/video_generation_dialog.dart';
import 'video_feed_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'projects_screen.dart';
import 'project_network_screen.dart';
import 'notifications_screen.dart';
import '../widgets/token_purchase_dialog.dart';
import '../widgets/app_bottom_navigation.dart';
import '../services/social_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ProjectDetailsScreen extends StatefulWidget {
  final Project project;
  final VideoPreloadService? preloadService;

  const ProjectDetailsScreen({
    super.key,
    required this.project,
    this.preloadService,
  });

  @override
  State<ProjectDetailsScreen> createState() => _ProjectDetailsScreenState();
}

class _ProjectDetailsScreenState extends State<ProjectDetailsScreen> {
  final _videoService = VideoService();
  final _projectService = ProjectService();
  final _userService = UserService();
  final _socialService = SocialService();
  final _imagePicker = ImagePicker();
  final _searchController = TextEditingController();
  final _commentController = TextEditingController();
  bool _isLoading = false;
  double _uploadProgress = 0;
  late Stream<Project?> _projectStream;
  Video? _draggedVideo;

  @override
  void initState() {
    super.initState();
    
    // Initialize the project stream with error handling and trigger immediate load
    _projectStream = _projectService
        .getProjectStream(widget.project.id)
        .handleError((error) {
          print('Error in project stream: $error');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Error loading project: $error'),
                backgroundColor: Colors.red,
              ),
            );
          }
        });

    // Force immediate data load
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // Increment project score
      await _projectService.incrementProjectScore(widget.project.id, 1);
      
      // Force stream to emit current value
      if (mounted) {
        setState(() {
          _projectStream = _projectStream.asBroadcastStream();
        });
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _uploadVideo() async {
    final video = await _imagePicker.pickVideo(
      source: ImageSource.gallery,
      maxDuration: const Duration(minutes: 10),
    );
    
    if (video == null) return;

    setState(() {
      _isLoading = true;
      _uploadProgress = 0;
    });

    try {
      final uploadedVideo = await _videoService.uploadVideo(
        videoFile: File(video.path),
        userId: widget.project.userId,
        title: 'Video ${widget.project.videoIds.length + 1}',
        duration: 0,
        onProgress: (progress) {
          setState(() {
            _uploadProgress = progress;
          });
        },
      );

      await _projectService.addVideoToProject(
        widget.project.id,
        uploadedVideo.id,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Video uploaded successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error uploading video: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _uploadProgress = 0;
        });
      }
    }
  }

  Future<void> _viewVideos(String projectId) async {
    try {
      final videos = await _videoService.getProjectVideos(widget.project.videoIds);
      if (!mounted) return;

      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => VideoFeedScreen(
            projectId: projectId,
            videoUrls: videos.map((v) => v.url).toList(),
            videoIds: videos.map((v) => v.id).toList(),
            projectName: widget.project.name,
            preloadService: widget.preloadService,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading videos: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _showDeleteConfirmation(Video video) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Video'),
        content: Text('Remove "${video.title}" from this project?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        await _projectService.removeVideoFromProject(
          widget.project.id,
          video.id,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Video removed from project')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error removing video: ${e.toString()}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _reorderVideos(List<Video> videos, int oldIndex, int newIndex) async {
    try {
      final newVideoIds = videos.map((v) => v.id).toList();
      // Reorder the IDs
      final String movedId = newVideoIds.removeAt(oldIndex);
      newVideoIds.insert(newIndex, movedId);

      // Update the project with new order
      await _projectService.updateVideoOrder(widget.project.id, newVideoIds);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error reordering videos: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showInviteCollaboratorsOverlay() {
    String searchQuery = '';
    print("Showing invite overlay"); // Debug print
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.9,
        builder: (_, controller) => DefaultTabController(
          length: 2,
          child: Container(
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      const Text(
                        'Project Members',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                ),
                // Tab Bar
                const TabBar(
                  tabs: [
                    Tab(text: 'Invite'),
                    Tab(text: 'Manage'),
                  ],
                ),
                // Tab Views
                Expanded(
                  child: TabBarView(
                    children: [
                      // Invite Tab
                      StatefulBuilder(
                        builder: (context, setState) => Column(
                          children: [
                            // Search Bar
                            Padding(
                              padding: const EdgeInsets.all(16),
                              child: TextField(
                                decoration: InputDecoration(
                                  hintText: 'Search users...',
                                  prefixIcon: const Icon(Icons.search),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 12,
                                  ),
                                ),
                                onChanged: (query) {
                                  setState(() => searchQuery = query);
                                },
                              ),
                            ),
                            // User List
                            Expanded(
                              child: StreamBuilder<Project?>(
                                stream: _projectStream,
                                builder: (context, projectSnapshot) {
                                  return FutureBuilder<List<AppUser>>(
                                    future: _userService.getInitialUsers(
                                      searchQuery: searchQuery,
                                      excludeIds: projectSnapshot.data?.collaboratorIds,
                                    ),
                                    builder: (context, snapshot) {
                                      if (snapshot.hasError) {
                                        return Center(
                                          child: Text('Error: ${snapshot.error}'),
                                        );
                                      }

                                      if (!snapshot.hasData) {
                                        return const Center(
                                          child: CircularProgressIndicator(),
                                        );
                                      }

                                      final users = snapshot.data!;
                                      
                                      // Add debug prints and use widget.project directly
                                      print('Direct Project Data: ${widget.project}');
                                      print('Direct Project CollaboratorIds: ${widget.project.collaboratorIds}');
                                      print('Initial Users Count: ${users.length}');
                                      
                                      // Filter out collaborator IDs after initial load using widget.project
                                      final filteredUsers = users.where((user) {
                                        final collaboratorIds = widget.project.collaboratorIds;
                                        print('Checking user ${user.id} against collaboratorIds: $collaboratorIds');
                                        return !collaboratorIds.contains(user.id);
                                      }).toList();

                                      print('Filtered Users Count: ${filteredUsers.length}');
                                      
                                      if (filteredUsers.isEmpty) {
                                        return const Center(
                                          child: Text('No users found'),
                                        );
                                      }

                                      return ListView.builder(
                                        controller: controller,
                                        itemCount: filteredUsers.length,
                                        itemBuilder: (context, index) {
                                          final user = filteredUsers[index];
                                          return ListTile(
                                            leading: CircleAvatar(
                                              backgroundColor: Theme.of(context).colorScheme.primary,
                                              child: Text(
                                                user.displayName[0].toUpperCase(),
                                                style: TextStyle(
                                                  color: Theme.of(context).colorScheme.onPrimary,
                                                ),
                                              ),
                                            ),
                                            title: Text(user.displayName),
                                            subtitle: Text(user.email),
                                            trailing: TextButton.icon(
                                              icon: const Icon(Icons.add),
                                              label: const Text('Add'),
                                              onPressed: () async {
                                                try {
                                                  final userId = user.id;
                                                  await _projectService.addCollaborator(
                                                    widget.project.id,
                                                    userId,
                                                  );
                                                  if (mounted) {
                                                    // Update local state immediately
                                                    setState(() {
                                                      widget.project.collaboratorIds.add(userId);
                                                    });
                                                    ScaffoldMessenger.of(context).showSnackBar(
                                                      SnackBar(
                                                        content: Text(
                                                          'Added ${user.displayName} to project',
                                                        ),
                                                      ),
                                                    );
                                                  }
                                                } catch (e) {
                                                  if (mounted) {
                                                    ScaffoldMessenger.of(context).showSnackBar(
                                                      SnackBar(
                                                        content: Text('Error: ${e.toString()}'),
                                                        backgroundColor: Colors.red,
                                                      ),
                                                    );
                                                  }
                                                }
                                              },
                                            ),
                                          );
                                        },
                                      );
                                    },
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Manage Tab
                      StreamBuilder<Project?>(
                        stream: _projectStream,
                        builder: (context, projectSnapshot) {
                          print('Manage tab - Project data direct: ${widget.project}');
                          print('Manage tab - Collaborator IDs direct: ${widget.project.collaboratorIds}');

                          final collaboratorIds = widget.project.collaboratorIds;
                          print('Manage tab - Using Collaborator IDs: $collaboratorIds');

                          if (collaboratorIds.isEmpty) {
                            return const Center(
                              child: Text('No collaborators yet'),
                            );
                          }

                          return FutureBuilder<List<AppUser>>(
                            future: _userService.getUsers(collaboratorIds),
                            builder: (context, snapshot) {
                              print('Manage tab - User snapshot state: ${snapshot.connectionState}');
                              print('Manage tab - User snapshot error: ${snapshot.error}');
                              print('Manage tab - User snapshot data length: ${snapshot.data?.length}');

                              if (snapshot.hasError) {
                                return Center(
                                  child: Text('Error: ${snapshot.error}'),
                                );
                              }

                              if (!snapshot.hasData) {
                                return const Center(
                                  child: CircularProgressIndicator(),
                                );
                              }

                              final collaborators = snapshot.data!;
                              return ListView.builder(
                                controller: controller,
                                itemCount: collaborators.length,
                                itemBuilder: (context, index) {
                                  final user = collaborators[index];
                                  return ListTile(
                                    leading: CircleAvatar(
                                      backgroundColor: Theme.of(context).colorScheme.primary,
                                      child: Text(
                                        user.displayName[0].toUpperCase(),
                                        style: TextStyle(
                                          color: Theme.of(context).colorScheme.onPrimary,
                                        ),
                                      ),
                                    ),
                                    title: Text(user.displayName),
                                    subtitle: Text(user.email),
                                    trailing: TextButton.icon(
                                      icon: const Icon(Icons.remove),
                                      label: const Text('Remove'),
                                      style: TextButton.styleFrom(
                                        foregroundColor: Colors.red,
                                      ),
                                      onPressed: () async {
                                        try {
                                          final userId = user.id;
                                          await _projectService.removeCollaborator(
                                            widget.project.id,
                                            userId,
                                          );
                                          if (mounted) {
                                            // Update local state immediately
                                            setState(() {
                                              widget.project.collaboratorIds.remove(userId);
                                            });
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(
                                                content: Text(
                                                  'Removed ${user.displayName} from project',
                                                ),
                                              ),
                                            );
                                          }
                                        } catch (e) {
                                          if (mounted) {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(
                                                content: Text('Error: ${e.toString()}'),
                                                backgroundColor: Colors.red,
                                              ),
                                            );
                                          }
                                        }
                                      },
                                    ),
                                  );
                                },
                              );
                            },
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showVideoMetadataDialog(Video video) async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(video.title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 16 / 9,
              child: VideoThumbnail(
                videoUrl: video.url,
                thumbnailUrl: video.thumbnailUrl,
              ),
            ),
            const SizedBox(height: 16),
            Text('Description: ${video.description ?? 'No description yet'}'),
            const SizedBox(height: 16),
            Center(
              child: ElevatedButton.icon(
                onPressed: () async {
                  try {
                    // Show loading
                    showDialog(
                      context: context,
                      barrierDismissible: false,
                      builder: (context) => const AlertDialog(
                        content: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(),
                            SizedBox(height: 16),
                            Text('Generating AI description...'),
                          ],
                        ),
                      ),
                    );

                    try {
                      // Call the AI caption service and get updated video
                      final updatedVideo = await _videoService.generateAICaption(video.id);
                      
                      if (!mounted) return;
                      Navigator.of(context).pop(); // Close loading dialog
                      
                      // Show updated video metadata in a new dialog
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: Text(updatedVideo.title),
                          content: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              AspectRatio(
                                aspectRatio: 16 / 9,
                                child: VideoThumbnail(
                                  videoUrl: updatedVideo.url,
                                  thumbnailUrl: updatedVideo.thumbnailUrl,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text('Description: ${updatedVideo.description ?? 'No description'}'),
                            ],
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(),
                              child: const Text('Close'),
                            ),
                          ],
                        ),
                      );
                      
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('AI description generated successfully!'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    } catch (e) {
                      if (!mounted) return;
                      Navigator.of(context).pop(); // Close loading dialog
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Error: ${e.toString()}'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  } catch (e) {
                    if (!mounted) return;
                    Navigator.of(context).pop(); // Close loading dialog
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error: ${e.toString()}'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                },
                icon: const Icon(Icons.auto_awesome),
                label: const Text('Generate AI Description'),
              ),
            ),
          ],
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

  Future<void> _showProjectSelectionDialog(Video video) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

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
                  // Don't show current project
                  if (project.id == widget.project.id) return const SizedBox.shrink();
                  
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
                              content: Text('Video added to ${project.name}'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        }
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Error adding video: ${e.toString()}'),
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

  Widget _buildVideoCard(Video video) {
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (video.thumbnailUrl != null)
            Image.network(
              video.thumbnailUrl!,
              fit: BoxFit.cover,
              height: 200,
              width: double.infinity,
            ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  video.title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                if (video.description != null)
                  Text(
                    video.description!,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                Text(
                  'Duration: ${Duration(seconds: video.duration).toString().split('.').first}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProjectHeader() {
    final currentUser = FirebaseAuth.instance.currentUser;
    
    return StreamBuilder<Project?>(
      stream: _projectStream,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Card(
            child: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        final project = snapshot.data!;
        
        return Card(
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Theme.of(context).colorScheme.surface,
                  Theme.of(context).colorScheme.surface.withOpacity(0.9),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            project.name,
                            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (project.description != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: Text(
                                project.description!,
                                style: Theme.of(context).textTheme.bodyLarge,
                              ),
                            ),
                        ],
                      ),
                    ),
                    // Social stats with animations
                    Row(
                      children: [
                        _buildSocialStat(
                          icon: Icons.favorite,
                          count: project.likeCount,
                          label: 'Likes',
                          color: Colors.pink,
                          isActive: project.favoritedBy.contains(currentUser?.uid),
                        ),
                        const SizedBox(width: 24),
                        _buildSocialStat(
                          icon: Icons.comment,
                          count: project.commentCount,
                          label: 'Comments',
                          color: Colors.blue,
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Social interaction buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    StreamBuilder<Project?>(
                      stream: _projectStream,
                      builder: (context, snapshot) {
                        final isLiked = snapshot.hasData && 
                          currentUser != null && 
                          snapshot.data!.favoritedBy.contains(currentUser.uid);
                        
                        return _buildSocialButton(
                          icon: isLiked ? Icons.favorite : Icons.favorite_border,
                          label: isLiked ? 'Liked' : 'Like',
                          isActive: isLiked,
                          onPressed: () async {
                            if (currentUser != null) {
                              try {
                                await _socialService.toggleLike(project.id);
                                // Force refresh of project stream to update UI
                                setState(() {
                                  _projectStream = _projectService
                                      .getProjectStream(widget.project.id)
                                      .handleError((error) {
                                        print('Error in project stream: $error');
                                        if (mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              content: Text('Error loading project: $error'),
                                              backgroundColor: Colors.red,
                                            ),
                                          );
                                        }
                                      });
                                });
                              } catch (e) {
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Error toggling like: $e'),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                }
                              }
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Please sign in to like projects'),
                                ),
                              );
                            }
                          },
                        );
                      }
                    ),
                    _buildSocialButton(
                      icon: Icons.comment,
                      label: 'Comment',
                      onPressed: () => _showCommentsSheet(context),
                    ),
                    _buildSocialButton(
                      icon: Icons.share,
                      label: 'Share',
                      onPressed: () async {
                        final shareUrl = await _socialService.generateShareUrl(project.id);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Share link copied: $shareUrl'),
                              action: SnackBarAction(
                                label: 'Copy',
                                onPressed: () {
                                  // Add clipboard functionality here
                                },
                              ),
                            ),
                          );
                        }
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSocialStat({
    required IconData icon,
    required int count,
    required String label,
    required Color color,
    bool isActive = false,
  }) {
    return TweenAnimationBuilder<int>(
      tween: IntTween(begin: 0, end: count),
      duration: const Duration(milliseconds: 500),
      builder: (context, value, child) {
        return Column(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isActive ? color.withOpacity(0.1) : Colors.transparent,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: isActive ? color : Colors.grey,
                size: 24,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value.toString(),
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: isActive ? color : null,
              ),
            ),
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: isActive ? color : Colors.grey,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSocialButton({
    required IconData icon,
    required String label,
    bool isActive = false,
    required VoidCallback onPressed,
  }) {
    return Container(
      decoration: BoxDecoration(
        gradient: isActive ? LinearGradient(
          colors: [
            Colors.pink.shade400,
            Colors.purple.shade400,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ) : null,
        borderRadius: BorderRadius.circular(20),
        border: !isActive ? Border.all(
          color: Colors.pink.withOpacity(0.5),
          width: 1,
        ) : null,
        boxShadow: isActive ? [
          BoxShadow(
            color: Colors.pink.withOpacity(0.3),
            blurRadius: 8,
            spreadRadius: 1,
          ),
        ] : null,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon == Icons.favorite && isActive ? Icons.favorite : icon,
                  color: isActive ? Colors.white : Colors.pink,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: TextStyle(
                    color: isActive ? Colors.white : Colors.pink,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showCommentsSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.9,
        builder: (_, controller) => Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Theme.of(context).colorScheme.surface,
                Theme.of(context).colorScheme.surface.withOpacity(0.95),
              ],
            ),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 20,
                spreadRadius: 5,
              ),
            ],
          ),
          child: Column(
            children: [
              // Handle bar
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 12),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const Text(
                      'Comments',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: _socialService.getComments(widget.project.id),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return Center(child: Text('Error: ${snapshot.error}'));
                    }

                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final comments = snapshot.data!.docs;
                    
                    if (comments.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.chat_bubble_outline,
                              size: 64,
                              color: Colors.grey.withOpacity(0.5),
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'No comments yet',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Be the first to share your thoughts!',
                              style: TextStyle(
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    return ListView.builder(
                      controller: controller,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: comments.length,
                      itemBuilder: (context, index) {
                        final comment = comments[index].data() as Map<String, dynamic>;
                        return FutureBuilder<AppUser?>(
                          future: _userService.getUser(comment['userId'] as String),
                          builder: (context, userSnapshot) {
                            final user = userSnapshot.data;
                            return Container(
                              margin: const EdgeInsets.only(bottom: 16),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Theme.of(context).colorScheme.surface,
                                    Theme.of(context).colorScheme.surface.withOpacity(0.9),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.1),
                                    blurRadius: 4,
                                    spreadRadius: 0,
                                  ),
                                ],
                              ),
                              child: ListTile(
                                contentPadding: const EdgeInsets.all(12),
                                leading: CircleAvatar(
                                  radius: 24,
                                  backgroundColor: Theme.of(context).colorScheme.primary,
                                  child: Text(
                                    user?.displayName.substring(0, 1).toUpperCase() ?? '?',
                                    style: TextStyle(
                                      color: Theme.of(context).colorScheme.onPrimary,
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                title: Row(
                                  children: [
                                    Text(
                                      user?.displayName ?? 'Unknown User',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      _formatTimestamp(comment['timestamp'] as Timestamp),
                                      style: Theme.of(context).textTheme.bodySmall,
                                    ),
                                  ],
                                ),
                                subtitle: Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Text(
                                    comment['comment'] as String,
                                    style: const TextStyle(fontSize: 16),
                                  ),
                                ),
                              ),
                            );
                          },
                        );
                      },
                    );
                  },
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 4,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                padding: EdgeInsets.only(
                  left: 16,
                  right: 16,
                  bottom: MediaQuery.of(context).viewInsets.bottom + 16,
                  top: 16,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _commentController,
                        decoration: InputDecoration(
                          hintText: 'Add a comment...',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: BorderSide.none,
                          ),
                          filled: true,
                          fillColor: Theme.of(context).colorScheme.surface,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                        ),
                        maxLines: null,
                        textCapitalization: TextCapitalization.sentences,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Theme.of(context).colorScheme.primary,
                            Theme.of(context).colorScheme.secondary,
                          ],
                        ),
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.send),
                        color: Colors.white,
                        onPressed: () {
                          final comment = _commentController.text.trim();
                          if (comment.isNotEmpty) {
                            _socialService.addComment(widget.project.id, comment);
                            _commentController.clear();
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.project.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add),
            onPressed: () => _showInviteCollaboratorsOverlay(),
            tooltip: 'Invite Collaborators',
          ),
          StreamBuilder<Project?>(
            stream: _projectStream,
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const SizedBox();
              
              final project = snapshot.data!;
              return Row(
                children: [
                  Text(
                    project.isPublic ? 'Public' : 'Private',
                    style: TextStyle(
                      color: project.isPublic ? Colors.green : Colors.grey,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Switch(
                    value: project.isPublic,
                    onChanged: (value) => _toggleProjectVisibility(value),
                  ),
                ],
              );
            },
          ),
        ],
      ),
      body: StreamBuilder<Project?>(
        stream: _projectStream,
        builder: (context, projectSnapshot) {
          if (projectSnapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.red),
                  const SizedBox(height: 16),
                  Text('Error: ${projectSnapshot.error}'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _projectStream = _projectService
                            .getProjectStream(widget.project.id)
                            .asBroadcastStream();
                      });
                    },
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          if (!projectSnapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          final project = projectSnapshot.data!;

          return Stack(
            children: [
              RefreshIndicator(
                onRefresh: () async {
                  setState(() {
                    _projectStream = _projectService
                        .getProjectStream(widget.project.id)
                        .asBroadcastStream();
                  });
                },
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    SliverToBoxAdapter(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildProjectHeader(),
                          Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Videos (${project.videoIds.length})',
                                  style: Theme.of(context).textTheme.titleLarge,
                                ),
                              ],
                            ),
                          ),
                          if (project.videoIds.isEmpty)
                            _buildEmptyVideoState()
                          else
                            _buildVideoGrid(project),
                          const SizedBox(height: 100), // Bottom padding for FAB
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (_isLoading) _buildLoadingOverlay(),
            ],
          );
        },
      ),
      bottomNavigationBar: AppBottomNavigation(currentIndex: 0),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddVideoOptions,
        child: const Icon(Icons.add),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }

  Widget _buildEmptyVideoState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.video_library_outlined,
            size: 64,
            color: Colors.grey,
          ),
          const SizedBox(height: 16),
          const Text(
            'No videos yet',
            style: TextStyle(
              fontSize: 20,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _uploadVideo,
            icon: const Icon(Icons.upload),
            label: const Text('Upload Your First Video'),
          ),
        ],
      ),
    );
  }

  Widget _buildVideoGrid(Project project) {
    return FutureBuilder<List<Video>>(
      future: _videoService.getProjectVideos(project.videoIds),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error loading videos: ${snapshot.error}'));
        }

        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final videos = snapshot.data!;
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: ElevatedButton.icon(
                onPressed: () => _viewVideos(project.id),
                icon: const Icon(Icons.play_circle),
                label: const Text('View in Feed'),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 48),
                ),
              ),
            ),
            const SizedBox(height: 16),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 16 / 9,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemCount: videos.length,
              itemBuilder: (context, index) {
                final video = videos[index];
                return GestureDetector(
                  onTap: () => _viewVideos(project.id),
                  onLongPress: () => _showVideoOptions(video),
                  child: Card(
                    clipBehavior: Clip.antiAlias,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        VideoThumbnail(
                          videoUrl: video.url,
                          thumbnailUrl: video.thumbnailUrl,
                        ),
                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                Colors.black.withOpacity(0.7),
                              ],
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: 8,
                          left: 8,
                          right: 8,
                          child: Text(
                            video.title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
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
                              size: 24,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildLoadingOverlay() {
    return Container(
      color: Colors.black54,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(
              value: _uploadProgress,
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
            ),
            const SizedBox(height: 16),
            Text(
              'Uploading: ${(_uploadProgress * 100).toStringAsFixed(1)}%',
              style: const TextStyle(color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _toggleProjectVisibility(bool value) async {
    try {
      await _projectService.toggleProjectVisibility(
        widget.project.id,
        value,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Project is now ${value ? 'public' : 'private'}',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating visibility: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showVideoOptions(Video video) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.edit),
            title: const Text('Edit Details'),
            onTap: () {
              Navigator.pop(context);
              _showVideoMetadataDialog(video);
            },
          ),
          ListTile(
            leading: const Icon(Icons.delete),
            title: const Text('Remove'),
            onTap: () {
              Navigator.pop(context);
              _showDeleteConfirmation(video);
            },
          ),
        ],
      ),
    );
  }

  void _showAddVideoOptions() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.upload),
              title: const Text('Upload Video'),
              onTap: () {
                Navigator.pop(context);
                _uploadVideo();
              },
            ),
            ListTile(
              leading: const Icon(Icons.video_library),
              title: const Text('Find Videos'),
              onTap: () => _findVideos(),
            ),
            ListTile(
              leading: const Icon(Icons.movie_creation),
              title: Row(
                children: [
                  const Text('Generate AI Video'),
                  const SizedBox(width: 8),
                  _buildTokenDisplay(),
                ],
              ),
              onTap: () => _showGenerateVideoDialog(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTokenDisplay() {
    return FutureBuilder<AppUser?>(
      future: _userService.getCurrentUser(),
      builder: (context, snapshot) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.token, size: 14),
              const SizedBox(width: 4),
              Text(
                '${snapshot.data?.tokens ?? 0}',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _findVideos() async {
    Navigator.pop(context);
    try {
      final availableVideos = await _videoService.getAvailableVideos(widget.project.videoIds);
      if (!mounted) return;
      if (availableVideos.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No available videos to add')),
        );
        return;
      }
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => VideoFeedScreen(
            projectId: widget.project.id,
            videoUrls: availableVideos.map((v) => v.url).toList(),
            videoIds: availableVideos.map((v) => v.id).toList(),
            projectName: 'Available Videos',
            preloadService: widget.preloadService,
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading videos: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showGenerateVideoDialog() {
    Navigator.pop(context);
    showDialog(
      context: context,
      builder: (context) => VideoGenerationDialog(
        onVideoGenerated: (String videoUrl) => _handleGeneratedVideo(videoUrl),
      ),
    );
  }

  Future<void> _handleGeneratedVideo(String videoUrl) async {
    try {
      final video = await _videoService.createVideoFromUrl(
        url: videoUrl,
        userId: widget.project.userId,
        title: 'AI Generated Video',
        duration: 10,
      );
      await _projectService.addVideoToProject(
        widget.project.id,
        video.id,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('AI video added to project successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error adding AI video: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
} 