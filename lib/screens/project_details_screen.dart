import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../models/project.dart';
import '../models/video.dart';
import '../services/video_service.dart';
import '../services/project_service.dart';
import '../services/user_service.dart';
import '../widgets/video_thumbnail.dart';
import 'video_feed_screen.dart';

class ProjectDetailsScreen extends StatefulWidget {
  final Project project;

  const ProjectDetailsScreen({
    super.key,
    required this.project,
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
    bool isInitialLoad = true;
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => DraggableScrollableSheet(
          initialChildSize: 0.9,
          minChildSize: 0.5,
          maxChildSize: 0.9,
          builder: (_, controller) => Container(
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              children: [
                // Drag handle
                Container(
                  height: 4,
                  width: 40,
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                // Header
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      const Text(
                        'Invite Collaborators',
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
                // Search bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search by name or email',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onChanged: (value) {
                      setModalState(() {
                        searchQuery = value;
                        isInitialLoad = false;
                      });
                    },
                  ),
                ),
                const SizedBox(height: 16),
                // Search results
                Expanded(
                  child: StreamBuilder<Project?>(
                    stream: _projectStream,
                    builder: (context, projectSnapshot) {
                      if (!projectSnapshot.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      final project = projectSnapshot.data!;

                      return FutureBuilder<List<AppUser>>(
                        future: isInitialLoad 
                          ? _userService.getInitialUsers()
                          : _userService.searchUsers(searchQuery),
                        builder: (context, snapshot) {
                          if (snapshot.hasError) {
                            print('Error in user search: ${snapshot.error}'); // Debug print
                            print('Error stack trace: ${snapshot.stackTrace}'); // Debug print
                            return Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.error_outline, size: 48, color: Colors.red),
                                  const SizedBox(height: 16),
                                  Text(
                                    'Error loading users: ${snapshot.error}',
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(color: Colors.red),
                                  ),
                                  const SizedBox(height: 16),
                                  ElevatedButton.icon(
                                    onPressed: () => setModalState(() {
                                      isInitialLoad = true;
                                    }),
                                    icon: const Icon(Icons.refresh),
                                    label: const Text('Retry'),
                                  ),
                                ],
                              ),
                            );
                          }

                          if (!snapshot.hasData) {
                            return const Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  CircularProgressIndicator(),
                                  SizedBox(height: 16),
                                  Text('Loading users...'),
                                ],
                              ),
                            );
                          }

                          final users = snapshot.data!;
                          if (users.isEmpty) {
                            if (isInitialLoad) {
                              return const Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.group_outlined, size: 48, color: Colors.grey),
                                    SizedBox(height: 16),
                                    Text(
                                      'No other users found',
                                      style: TextStyle(color: Colors.grey),
                                    ),
                                  ],
                                ),
                              );
                            }
                            return Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.search_off, size: 48, color: Colors.grey),
                                  const SizedBox(height: 16),
                                  Text(
                                    'No users found for "$searchQuery"',
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            );
                          }

                          return ListView.builder(
                            controller: controller,
                            itemCount: users.length,
                            itemBuilder: (context, index) {
                              final user = users[index];
                              final isCollaborator = project.collaboratorIds.contains(user.id);
                              final isOwner = project.userId == user.id;

                              if (isOwner) return const SizedBox.shrink();

                              return ListTile(
                                leading: CircleAvatar(
                                  backgroundImage: user.photoUrl != null
                                      ? NetworkImage(user.photoUrl!)
                                      : null,
                                  child: user.photoUrl == null
                                      ? Text(user.displayName[0].toUpperCase())
                                      : null,
                                ),
                                title: Text(user.displayName),
                                subtitle: Text(user.email),
                                trailing: isCollaborator
                                    ? TextButton.icon(
                                        icon: const Icon(Icons.remove),
                                        label: const Text('Remove'),
                                        style: TextButton.styleFrom(
                                          foregroundColor: Colors.red,
                                        ),
                                        onPressed: () async {
                                          try {
                                            await _projectService.removeCollaborator(
                                              project.id,
                                              user.id,
                                            );
                                            setModalState(() {}); // Refresh the list
                                            if (mounted) {
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
                                      )
                                    : TextButton.icon(
                                        icon: const Icon(Icons.add),
                                        label: const Text('Add'),
                                        onPressed: () async {
                                          try {
                                            await _projectService.addCollaborator(
                                              project.id,
                                              user.id,
                                            );
                                            setModalState(() {}); // Refresh the list
                                            if (mounted) {
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
          StreamBuilder<Project?>(
            stream: _projectStream,
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const SizedBox();
              
              final project = snapshot.data!;
              return Row(
                children: [
                  // Invite button
                  IconButton(
                    icon: const Icon(Icons.person_add),
                    onPressed: _showInviteCollaboratorsOverlay,
                    tooltip: 'Invite Collaborators',
                  ),
                  // Visibility toggle
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
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          project.description,
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                        const SizedBox(height: 24),
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