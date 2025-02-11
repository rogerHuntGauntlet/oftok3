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
  final _imagePicker = ImagePicker();
  final _searchController = TextEditingController();
  bool _isLoading = false;
  double _uploadProgress = 0;
  late Stream<Project?> _projectStream;
  Video? _draggedVideo;

  @override
  void initState() {
    super.initState();
    _projectStream = _projectService
        .getProjectStream(widget.project.id)
        .asBroadcastStream();

    // Increment project score when screen is loaded
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _projectService.incrementProjectScore(widget.project.id, 1);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
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
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.project.name,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            if (widget.project.description != null)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(
                  widget.project.description!,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ),
            // ... rest of the header code ...
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.project.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.movie_creation),
            tooltip: 'Generate AI Video',
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => VideoGenerationDialog(
                  onVideoGenerated: (String videoUrl) async {
                    // Create a new video entry
                    try {
                      final video = await _videoService.createVideoFromUrl(
                        url: videoUrl,
                        userId: widget.project.userId,
                        title: 'AI Generated Video',
                        duration: 10, // AI videos are limited to 10 seconds
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
                  },
                ),
              );
            },
          ),
          // Invite button
          IconButton(
            icon: const Icon(Icons.person_add),
            onPressed: () {
              print("Opening invite collaborators dialog"); // Debug print
              _showInviteCollaboratorsOverlay();
            },
            tooltip: 'Invite Collaborators',
          ),
          // Public/Private toggle
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
                    onChanged: (value) async {
                      try {
                        await _projectService.toggleProjectVisibility(
                          project.id,
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
                    },
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
            return Center(child: Text('Error: ${projectSnapshot.error}'));
          }

          if (!projectSnapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final project = projectSnapshot.data!;
          print('Current project videoIds: ${project.videoIds}');

          return Stack(
            children: [
              Column(
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
                    Expanded(
                      child: Center(
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
                      ),
                    )
                  else
                    Expanded(
                      child: FutureBuilder<List<Video>>(
                        future: _videoService.getProjectVideos(project.videoIds),
                        builder: (context, snapshot) {
                          if (snapshot.hasError) {
                            return Center(child: Text('Error: ${snapshot.error}'));
                          }

                          if (!snapshot.hasData) {
                            return const Center(child: CircularProgressIndicator());
                          }

                          final videos = snapshot.data!;
                          return Column(
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
                              Expanded(
                                child: DragTarget<Video>(
                                  onWillAccept: (video) => true,
                                  onAccept: (video) {
                                    if (_draggedVideo != null) {
                                      _showDeleteConfirmation(video);
                                    }
                                  },
                                  builder: (context, candidateData, rejectedData) {
                                    return GridView.builder(
                                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                        crossAxisCount: 4,
                                        childAspectRatio: 16 / 9,
                                        crossAxisSpacing: 8,
                                        mainAxisSpacing: 8,
                                      ),
                                      itemCount: videos.length,
                                      itemBuilder: (context, index) {
                                        final video = videos[index];
                                        return LongPressDraggable<Video>(
                                          data: video,
                                          onDragStarted: () => setState(() => _draggedVideo = video),
                                          onDragEnd: (_) => setState(() => _draggedVideo = null),
                                          onDraggableCanceled: (_, __) => setState(() => _draggedVideo = null),
                                          feedback: SizedBox(
                                            width: 200,
                                            child: Card(
                                              elevation: 8,
                                              child: AspectRatio(
                                                aspectRatio: 16 / 9,
                                                child: VideoThumbnail(
                                                  videoUrl: video.url,
                                                  thumbnailUrl: video.thumbnailUrl,
                                                ),
                                              ),
                                            ),
                                          ),
                                          childWhenDragging: Container(
                                            decoration: BoxDecoration(
                                              border: Border.all(
                                                color: Colors.blue,
                                                width: 2,
                                              ),
                                              color: Colors.grey[300]?.withOpacity(0.5),
                                            ),
                                          ),
                                          child: DragTarget<Video>(
                                            onWillAccept: (incoming) => incoming != video,
                                            onAccept: (incoming) {
                                              final oldIndex = videos.indexOf(incoming);
                                              final newIndex = videos.indexOf(video);
                                              _reorderVideos(videos, oldIndex, newIndex);
                                            },
                                            builder: (context, candidateData, rejectedData) {
                                              return GestureDetector(
                                                onTap: () => _viewVideos(project.id),
                                                onLongPress: () => _showProjectSelectionDialog(video),
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
                                                      if (candidateData.isNotEmpty)
                                                        Container(
                                                          decoration: BoxDecoration(
                                                            color: Colors.blue.withOpacity(0.3),
                                                            border: Border.all(
                                                              color: Colors.blue,
                                                              width: 2,
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
                                        );
                                      },
                                    );
                                  },
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                ],
              ),
              if (_isLoading)
                Container(
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
                ),
            ],
          );
        },
      ),
      floatingActionButton: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton.extended(
            heroTag: 'find_videos',
            onPressed: () async {
              try {
                // Get videos not in the project
                final availableVideos = await _videoService.getAvailableVideos(widget.project.videoIds);

                if (!mounted) return;

                if (availableVideos.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('No available videos to add'),
                    ),
                  );
                  return;
                }

                // Show videos in video feed
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
            },
            icon: const Icon(Icons.video_library),
            label: const Text('Find Videos'),
          ),
          const SizedBox(width: 16),
          FloatingActionButton.extended(
            heroTag: 'upload_video',
            onPressed: _uploadVideo,
            icon: const Icon(Icons.upload),
            label: const Text('Upload'),
          ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
} 