import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../services/user_service.dart';
import '../services/video_service.dart';
import '../models/app_user.dart';
import '../models/video.dart';
import 'video_feed_screen.dart';
import '../models/project.dart';
import '../services/project_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> with SingleTickerProviderStateMixin {
  final _userService = UserService();
  final _videoService = VideoService();
  final _projectService = ProjectService();
  final _auth = FirebaseAuth.instance;
  final _bioController = TextEditingController();
  final _displayNameController = TextEditingController();
  late TabController _tabController;
  bool _isLoading = false;
  AppUser? _user;
  File? _imageFile;
  List<Video> _uploadedVideos = [];
  List<Video> _generatedVideos = [];
  bool _isLoadingVideos = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadUserData();
    _loadVideos();
  }

  @override
  void dispose() {
    _bioController.dispose();
    _displayNameController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    setState(() => _isLoading = true);
    try {
      final user = await _userService.getCurrentUser();
      if (mounted) {
        setState(() {
          _user = user;
          _displayNameController.text = user?.displayName ?? '';
          _bioController.text = user?.bio ?? '';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading profile: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadVideos() async {
    if (_auth.currentUser == null) return;
    
    setState(() => _isLoadingVideos = true);
    try {
      // Get all videos
      final allVideos = await _videoService.getAllVideos();
      
      // Get user's generated video IDs
      final generatedIds = await _userService.getUserGeneratedVideos(_auth.currentUser!.uid);
      
      // Filter videos
      setState(() {
        _generatedVideos = allVideos.where((v) => generatedIds.contains(v.id)).toList();
        _uploadedVideos = allVideos.where((v) => 
          v.userId == _auth.currentUser!.uid && !generatedIds.contains(v.id)
        ).toList();
      });
    } catch (e) {
      print('Error loading videos: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading videos: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingVideos = false);
      }
    }
  }

  Future<void> _pickImage() async {
    setState(() => _isLoading = true);
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024, // Limit image size
        maxHeight: 1024,
        imageQuality: 85, // Compress image
      );
      
      if (pickedFile != null) {
        print('Image picked: ${pickedFile.path}'); // Debug log
        final imageFile = File(pickedFile.path);
        
        // Verify file exists and has content
        if (await imageFile.exists() && await imageFile.length() > 0) {
          setState(() => _imageFile = imageFile);
          await _updateProfilePhoto();
        } else {
          throw Exception('Invalid image file');
        }
      }
    } catch (e) {
      print('Error picking image: $e'); // Debug log
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error picking image: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _updateProfilePhoto() async {
    if (_imageFile == null) return;

    setState(() => _isLoading = true);
    try {
      print('Starting profile photo update...'); // Debug log
      await _userService.updateProfilePhoto(_imageFile!);
      await _loadUserData(); // Reload user data to get new photo URL
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile photo updated successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('Error updating profile photo: $e'); // Debug log
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating profile photo: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _imageFile = null; // Clear the image file
        });
      }
    }
  }

  Future<void> _updateProfile() async {
    if (_displayNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Display name cannot be empty'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      await _userService.updateProfile(
        displayName: _displayNameController.text.trim(),
        bio: _bioController.text.trim(),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile updated successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
      await _loadUserData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating profile: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _showVideoProjectsSheet(Video video) async {
    final projects = await _projectService.getProjectsContainingVideo(video.id!);
    if (!mounted) return;

    final selectedProjects = <Project>{};

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            final allSelected = selectedProjects.length == projects.length;

            return DraggableScrollableSheet(
              initialChildSize: 0.6,
              minChildSize: 0.4,
              maxChildSize: 0.8,
              expand: false,
              builder: (context, scrollController) {
                return Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Theme.of(context).scaffoldBackgroundColor,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                'Projects (${projects.length})',
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                              const Spacer(),
                              if (projects.isNotEmpty) ...[
                                // Select All Checkbox
                                Row(
                                  children: [
                                    Checkbox(
                                      value: allSelected,
                                      onChanged: (checked) {
                                        setState(() {
                                          if (checked ?? false) {
                                            selectedProjects.addAll(projects);
                                          } else {
                                            selectedProjects.clear();
                                          }
                                        });
                                      },
                                    ),
                                    const Text('Select All'),
                                  ],
                                ),
                              ],
                            ],
                          ),
                          if (selectedProjects.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                '${selectedProjects.length} selected',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: projects.isEmpty
                        ? Center(
                            child: Text(
                              'Not added to any projects',
                              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                color: Colors.grey,
                              ),
                            ),
                          )
                        : ListView.builder(
                            controller: scrollController,
                            itemCount: projects.length,
                            itemBuilder: (context, index) {
                              final project = projects[index];
                              final isSelected = selectedProjects.contains(project);

                              return ListTile(
                                leading: Checkbox(
                                  value: isSelected,
                                  onChanged: (checked) {
                                    setState(() {
                                      if (checked ?? false) {
                                        selectedProjects.add(project);
                                      } else {
                                        selectedProjects.remove(project);
                                      }
                                    });
                                  },
                                ),
                                title: Text(project.name),
                                subtitle: Text(
                                  project.description ?? 'No description',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              );
                            },
                          ),
                    ),
                    if (selectedProjects.isNotEmpty)
                      SafeArea(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: () async {
                                    final projectIds = selectedProjects
                                        .map((p) => p.id)
                                        .toList();
                                    
                                    Navigator.pop(context); // Close sheet

                                    try {
                                      await _projectService.removeVideoFromProjects(
                                        video.id!,
                                        projectIds,
                                      );
                                      
                                      if (mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              'Removed video from ${projectIds.length} projects'
                                            ),
                                            backgroundColor: Colors.green,
                                          ),
                                        );
                                      }
                                      
                                      // Refresh videos
                                      _loadVideos();
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
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.red,
                                    foregroundColor: Colors.white,
                                  ),
                                  child: Text(
                                    'Remove from ${selectedProjects.length} projects'
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildVideoGrid(List<Video> videos) {
    if (_isLoadingVideos) {
      return const Center(child: CircularProgressIndicator());
    }

    if (videos.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.videocam_off, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              'No videos yet',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Colors.grey,
              ),
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 4,
        mainAxisSpacing: 4,
      ),
      itemCount: videos.length,
      itemBuilder: (context, index) {
        final video = videos[index];
        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => VideoFeedScreen(
                  videoUrls: [video.url!],
                  videoIds: [video.id!],
                  projectName: 'Video Preview',
                ),
              ),
            );
          },
          onLongPress: () => _showVideoProjectsSheet(video),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (video.thumbnailUrl != null)
                Image.network(
                  video.thumbnailUrl!,
                  fit: BoxFit.cover,
                )
              else
                Container(
                  color: Colors.grey[300],
                  child: const Icon(Icons.video_library),
                ),
              // Video duration overlay
              Positioned(
                bottom: 4,
                right: 4,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    video.duration != null 
                      ? '${(video.duration! ~/ 60)}:${(video.duration! % 60).toString().padLeft(2, '0')}'
                      : '0:00',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          TextButton(
            onPressed: _updateProfile,
            child: const Text('Save'),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Profile'),
            Tab(text: 'Uploaded'),
            Tab(text: 'Generated'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Profile Tab
          SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Profile Photo
                Center(
                  child: Stack(
                    children: [
                      CircleAvatar(
                        radius: 50,
                        backgroundImage: _user?.photoUrl != null
                            ? NetworkImage(_user!.photoUrl!)
                            : null,
                        child: _user?.photoUrl == null
                            ? const Icon(Icons.person, size: 50)
                            : null,
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Theme.of(context).primaryColor,
                            shape: BoxShape.circle,
                          ),
                          child: IconButton(
                            icon: const Icon(Icons.camera_alt, color: Colors.white),
                            onPressed: _pickImage,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                
                // Display Name
                TextField(
                  controller: _displayNameController,
                  decoration: const InputDecoration(
                    labelText: 'Display Name',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                
                // Bio
                TextField(
                  controller: _bioController,
                  decoration: const InputDecoration(
                    labelText: 'Bio',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 16),
                
                // Email (non-editable)
                TextField(
                  enabled: false,
                  controller: TextEditingController(text: _user?.email ?? ''),
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 24),
                
                // Account Stats
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Account Statistics',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 16),
                        _buildStatRow('Tokens', '${_user?.tokens ?? 0}'),
                        const Divider(),
                        _buildStatRow(
                          'Videos Generated',
                          '${_generatedVideos.length}',
                        ),
                        const Divider(),
                        _buildStatRow(
                          'Videos Uploaded',
                          '${_uploadedVideos.length}',
                        ),
                        const Divider(),
                        _buildStatRow(
                          'Member Since',
                          _user?.createdAt != null
                              ? '${_user!.createdAt.day}/${_user!.createdAt.month}/${_user!.createdAt.year}'
                              : 'N/A',
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Uploaded Videos Tab
          _buildVideoGrid(_uploadedVideos),
          
          // Generated Videos Tab
          _buildVideoGrid(_generatedVideos),
        ],
      ),
    );
  }

  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
} 