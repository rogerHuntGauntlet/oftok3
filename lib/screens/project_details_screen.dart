import 'dart:io';
import 'dart:async';  // For StreamSubscription
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../models/app_user.dart';
import '../models/project.dart';
import '../models/video.dart';
import '../models/comment.dart';
import '../services/video_service.dart';
import '../services/project_service.dart';
import '../services/user_service.dart';
import '../services/video/video_preload_service.dart';
import '../widgets/video_thumbnail.dart';
import '../widgets/video_generation_dialog.dart';
import '../widgets/token_purchase_dialog.dart';
import '../widgets/app_bottom_navigation.dart';
import '../services/social_service.dart';
import '../services/analytics_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;
import 'video_feed_screen.dart';
import 'projects_screen.dart';
import 'project_network_screen.dart';
import 'notifications_screen.dart';
import 'project_analytics_screen.dart';
import '../screens/project_details_widgets/index.dart';
import '../screens/project_details_widgets/token_display.dart' as project_details;
import '../screens/project_details_widgets/video_card.dart' as project_details;
import '../screens/project_details_widgets/video_grid.dart' as project_details;
import 'package:permission_handler/permission_handler.dart';
import 'package:app_settings/app_settings.dart';
import '../widgets/error_dialog.dart';

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
  final _analyticsService = AnalyticsService();
  final _imagePicker = ImagePicker();
  final _searchController = TextEditingController();
  final _commentController = TextEditingController();
  final _firestore = FirebaseFirestore.instance;
  bool _isLoading = false;
  double _uploadProgress = 0;
  late Stream<Project?> _projectStream;
  Video? _draggedVideo;
  DateTime? _sessionStartTime;
  String? _progressStatus;
  double? _progressValue;
  late StreamSubscription<Project?> _projectStreamSubscription;
  late Project _currentProject;

  @override
  void initState() {
    super.initState();
    _currentProject = widget.project;
    _initializeProjectStream();
  }

  void _initializeProjectStream() {
    // Initialize with the current project data first
    _projectStream = Stream.value(_currentProject).asyncExpand((initialProject) {
      // Then switch to the live stream
      return _projectService
          .getProjectStream(_currentProject.id)
          .map<Project>((updatedProject) {
            // Merge initial project data with updates to ensure we don't lose data
            if (updatedProject != null) {
              _currentProject = Project(
                id: updatedProject.id,
                name: updatedProject.name,
                description: updatedProject.description,
                userId: updatedProject.userId,
                videoIds: updatedProject.videoIds,
                collaboratorIds: updatedProject.collaboratorIds,
                isPublic: updatedProject.isPublic,
                score: updatedProject.score,
                likeCount: updatedProject.likeCount,
                commentCount: updatedProject.commentCount,
                createdAt: updatedProject.createdAt,
                shareCount: updatedProject.shareCount,
                totalSessionDuration: updatedProject.totalSessionDuration,
                sessionCount: updatedProject.sessionCount,
                videoCompletionRates: updatedProject.videoCompletionRates,
                lastEngagement: updatedProject.lastEngagement,
              );
              return _currentProject;
            }
            return initialProject;
          })
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
    }).asBroadcastStream();

    // Force immediate data load and start session tracking
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // Increment project score
      await _projectService.incrementProjectScore(_currentProject.id, 1);
      
      // Start session tracking
      _sessionStartTime = DateTime.now();
    });

    _projectStreamSubscription = _projectStream.listen((project) {
      if (mounted && project != null) {
        setState(() {
          _currentProject = project;
        });
      }
    });
  }

  void _refreshProjectStream() {
    setState(() {
      _initializeProjectStream();
    });
  }

  @override
  void dispose() {
    _projectStreamSubscription.cancel();
    // Update session duration when leaving the screen
    if (_sessionStartTime != null) {
      final sessionDuration = DateTime.now().difference(_sessionStartTime!);
      _analyticsService.logEvent(
        'screen_time',
        parameters: {
          'screen': 'project_details',
          'duration': sessionDuration.inSeconds,
          'project_id': _currentProject.id,
        },
      );
    }
    
    _searchController.dispose();
    _commentController.dispose();
    super.dispose();
  }

  Future<bool> _requestCameraPermission() async {
    final status = await Permission.camera.status;
    if (status.isGranted) {
      return true;
    }

    if (status.isDenied) {
      final result = await Permission.camera.request();
      return result.isGranted;
    }

    if (status.isPermanentlyDenied) {
      // Show dialog to open app settings
      if (!mounted) return false;
      
      final shouldOpenSettings = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Camera Permission Required'),
          content: const Text('Please enable camera access in settings to record videos.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Open Settings'),
            ),
          ],
        ),
      );

      if (shouldOpenSettings == true) {
        await openAppSettings();
        // Check if permission was granted after returning from settings
        return await Permission.camera.status.isGranted;
      }
    }

    return false;
  }

  Future<void> _uploadVideo() async {
    try {
      final source = await showDialog<ImageSource>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Upload Video'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text('Record Video'),
                onTap: () => Navigator.pop(context, ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Choose from Gallery'),
                onTap: () => Navigator.pop(context, ImageSource.gallery),
              ),
            ],
          ),
        ),
      );

      if (source == null) return;

      if (source == ImageSource.camera) {
        final hasCameraPermission = await _requestCameraPermission();
        if (!hasCameraPermission) {
          if (!mounted) return;
          ErrorDialog.show(
            context,
            message: 'Camera permission is required to record videos',
          );
          return;
        }
      }

      final XFile? video = await ImagePicker().pickVideo(
        source: source,
        maxDuration: const Duration(minutes: 10),
      );

      if (video == null) return;

      if (!mounted) return;
      
      setState(() {
        _isLoading = true;
        _uploadProgress = 0;
        _progressStatus = 'Preparing video...';
      });

      final videoFile = File(video.path);
      final videoService = VideoService();
      
      // Add retry logic for upload
      int retryAttempts = 3;
      int currentAttempt = 0;
      bool uploadSuccess = false;

      while (currentAttempt < retryAttempts && !uploadSuccess) {
        try {
          currentAttempt++;
          if (currentAttempt > 1) {
            // Add delay between retries
            if (!mounted) return;
            setState(() {
              _progressStatus = 'Retrying upload (attempt $currentAttempt of $retryAttempts)...';
            });
            await Future.delayed(Duration(seconds: currentAttempt * 2));
          }

          final uploadedVideo = await videoService.uploadVideo(
            videoFile: videoFile,
            userId: FirebaseAuth.instance.currentUser?.uid ?? '',
            title: 'Video ${_currentProject.videoIds.length + 1}',
            duration: 0,
            context: context,
            onProgress: (progress, status) {
              if (!mounted) return;
              setState(() {
                _uploadProgress = progress;
                _progressStatus = status;
              });
            },
          );

          // Add video to project after successful upload
          await _projectService.addVideoToProject(
            _currentProject.id,
            uploadedVideo.id,
          );

          uploadSuccess = true;
        } catch (e) {
          print('Upload attempt $currentAttempt failed: $e');
          if (currentAttempt == retryAttempts) {
            rethrow;
          }
        }
      }

      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _uploadProgress = 0;
        _progressStatus = null;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Video uploaded successfully')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _uploadProgress = 0;
        _progressStatus = null;
      });
      
      ErrorDialog.show(
        context,
        title: 'Error uploading video',
        message: e.toString(),
      );
    }
  }

  Future<void> _viewVideos(String projectId, {int startIndex = 0}) async {
    try {
      final videos = await _videoService.getProjectVideos([projectId]);
      if (!mounted) return;

      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => VideoFeedScreen(
            projectId: projectId,
            videoUrls: videos.map((v) => v.url).toList(),
            videoIds: videos.map((v) => v.id).toList(),
            projectName: _currentProject.name,
            preloadService: widget.preloadService,
            initialIndex: startIndex,
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
          _currentProject.id,
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
      await _projectService.updateVideoOrder(_currentProject.id, newVideoIds);
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
                                      print('Direct Project Data: ${_currentProject}');
                                      print('Direct Project CollaboratorIds: ${_currentProject.collaboratorIds}');
                                      print('Initial Users Count: ${users.length}');
                                      
                                      // Filter out collaborator IDs after initial load using widget.project
                                      final filteredUsers = users.where((user) {
                                        final collaboratorIds = _currentProject.collaboratorIds;
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
                                                    _currentProject.id,
                                                    userId,
                                                  );
                                                  if (mounted) {
                                                    setState(() {
                                                      _currentProject.collaboratorIds.add(userId);
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
                          print('Manage tab - Project data direct: ${_currentProject}');
                          print('Manage tab - Collaborator IDs direct: ${_currentProject.collaboratorIds}');

                          final collaboratorIds = _currentProject.collaboratorIds;
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
                                            _currentProject.id,
                                            userId,
                                          );
                                          if (mounted) {
                                            // Update local state immediately
                                            setState(() {
                                              _currentProject.collaboratorIds.remove(userId);
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
                previewUrl: video.previewUrl,
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
                                  previewUrl: updatedVideo.previewUrl,
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
                  if (project.id == _currentProject.id) return const SizedBox.shrink();
                  
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

  void _showAddVideoOptions() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.upload_file),
            title: const Text('Upload Video'),
            onTap: () {
              Navigator.pop(context);
              _uploadVideo();
            },
          ),
          ListTile(
            leading: const Icon(Icons.auto_awesome),
            title: Row(
              children: [
                const Text('Generate Video'),
                const SizedBox(width: 8),
                project_details.TokenDisplay(userService: _userService),
              ],
            ),
            onTap: () {
              Navigator.pop(context);
              _showVideoGenerationDialog();
            },
          ),
        ],
      ),
    );
  }

  Future<void> _findVideos() async {
    Navigator.pop(context);
    try {
      final availableVideos = await _videoService.getAvailableVideos(_currentProject.videoIds);
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
            projectId: _currentProject.id,
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

  Widget _buildVideoList(List<Video> videos) {
    return ListView.builder(
      itemCount: videos.length,
      padding: const EdgeInsets.all(16),
      itemBuilder: (context, index) {
        final video = videos[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: GestureDetector(
            onTap: () => _onVideoTap(video),
            child: project_details.VideoCard(
              video: video,
              onTap: () => _onVideoTap(video),
            ),
          ),
        );
      },
    );
  }

  void _onVideoTap(Video video) {
    _viewVideos(_currentProject.id, startIndex: _currentProject.videoIds.indexOf(video.id));
  }

  void _showVideoOptions(Video video) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.info),
            title: const Text('View Details'),
            onTap: () {
              Navigator.pop(context);
              _showVideoMetadataDialog(video);
            },
          ),
          ListTile(
            leading: const Icon(Icons.save),
            title: const Text('Save to Project'),
            onTap: () {
              Navigator.pop(context);
              _showProjectSelectionDialog(video);
            },
          ),
          ListTile(
            leading: const Icon(Icons.delete),
            title: const Text('Remove from Project'),
            onTap: () {
              Navigator.pop(context);
              _showDeleteConfirmation(video);
            },
          ),
        ],
      ),
    );
  }

  void _showVideoGenerationDialog() {
    showDialog(
      context: context,
      builder: (context) => VideoGenerationDialog(
        onVideoGenerated: (video) {
          if (mounted) {
            setState(() {});
          }
        },
      ),
    );
  }

  void _showCommentsSheet(Project project) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.9,
        builder: (_, controller) => Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Comments',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              Expanded(
                child: StreamBuilder<List<Comment>>(
                  stream: _socialService.getComments(project.id),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return Center(child: Text('Error: ${snapshot.error}'));
                    }
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final comments = snapshot.data!;
                    return ListView.builder(
                      controller: controller,
                      itemCount: comments.length,
                      itemBuilder: (context, index) {
                        final comment = comments[index];
                        return ListTile(
                          title: Text(comment.text),
                          subtitle: Text(comment.authorName),
                          trailing: Text(
                            comment.createdAt.toLocal().toString(),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
              Padding(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).viewInsets.bottom,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _commentController,
                        decoration: const InputDecoration(
                          hintText: 'Add a comment...',
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.send),
                      onPressed: () async {
                        final text = _commentController.text.trim();
                        if (text.isEmpty) return;
                        try {
                          await _socialService.addComment(
                            projectId: project.id,
                            text: text,
                            authorId: FirebaseAuth.instance.currentUser?.uid ?? '',
                            authorName: FirebaseAuth.instance.currentUser?.displayName ?? 'Anonymous',
                          );
                          _commentController.clear();
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Error adding comment: $e'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        }
                      },
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Project Details'),
            Flexible(
              child: StreamBuilder<Project?>(
                stream: _projectStream,
                builder: (context, snapshot) {
                  return Text(
                    snapshot.data?.name ?? _currentProject.name,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onPrimary.withOpacity(0.8),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  );
                },
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add),
            onPressed: _showInviteCollaboratorsOverlay,
            tooltip: 'Invite Collaborators',
          ),
          IconButton(
            icon: const Icon(Icons.analytics),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ProjectAnalyticsScreen(project: _currentProject),
                ),
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
                    onPressed: _refreshProjectStream,
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
                  _refreshProjectStream();
                },
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    SliverToBoxAdapter(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ProjectHeader(
                            project: project,
                            socialService: _socialService,
                            projectService: _projectService,
                            onRefresh: _refreshProjectStream,
                            showCommentsSheet: (context) => _showCommentsSheet(project),
                          ),
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
                            EmptyVideoState(onUploadVideo: _uploadVideo)
                          else
                            project_details.VideoGrid(
                              project: project,
                              videoService: _videoService,
                              onViewVideos: _viewVideos,
                              onVideoOptions: _showVideoOptions,
                            ),
                          const SizedBox(height: 100), // Bottom padding for FAB
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (_isLoading) LoadingOverlay(
                uploadProgress: _uploadProgress,
                status: _progressStatus,
              ),
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
}

class LoadingOverlay extends StatelessWidget {
  final double uploadProgress;
  final String? status;

  const LoadingOverlay({
    super.key,
    required this.uploadProgress,
    this.status,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black54,
      child: Center(
        child: Card(
          margin: const EdgeInsets.symmetric(horizontal: 32),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                if (status != null) ...[
                  Text(
                    status!,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 8),
                ],
                Text(
                  '${(uploadProgress * 100).toInt()}%',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
} 