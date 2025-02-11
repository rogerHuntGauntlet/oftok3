import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/project_service.dart';
import '../services/video/video_preload_service.dart';
import '../models/project.dart';
import 'project_details_screen.dart';
import 'project_connections_screen.dart';
import 'project_network_screen.dart';
import 'login_screen.dart';
import '../widgets/app_bottom_navigation.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'dart:async';
import 'package:permission_handler/permission_handler.dart';

class ProjectsScreen extends StatefulWidget {
  final VideoPreloadService? preloadService;

  const ProjectsScreen({
    super.key,
    this.preloadService,
  });

  @override
  State<ProjectsScreen> createState() => _ProjectsScreenState();
}

class _ProjectsScreenState extends State<ProjectsScreen> with SingleTickerProviderStateMixin {
  final _projectService = ProjectService();
  final _auth = FirebaseAuth.instance;
  late TabController _tabController;
  final TextEditingController _myProjectsSearchController = TextEditingController();
  final TextEditingController _findProjectsSearchController = TextEditingController();
  String _myProjectsSearchQuery = '';
  String _findProjectsSearchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _myProjectsSearchController.addListener(() {
      setState(() {
        _myProjectsSearchQuery = _myProjectsSearchController.text;
      });
    });
    _findProjectsSearchController.addListener(() {
      setState(() {
        _findProjectsSearchQuery = _findProjectsSearchController.text;
      });
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _myProjectsSearchController.dispose();
    _findProjectsSearchController.dispose();
    super.dispose();
  }

  void _createProject() {
    showDialog(
      context: context,
      builder: (context) => _CreateProjectDialog(),
    ).then((_) {
      // Force a rebuild of the screen to refresh the project list
      if (mounted) {
        setState(() {});
      }
    });
  }

  void _showConnections() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ProjectConnectionsScreen(),
      ),
    );
  }

  void _logout() async {
    try {
      await _auth.signOut();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error signing out: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildSearchBar(TextEditingController controller, String hintText) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          hintText: hintText,
          prefixIcon: const Icon(Icons.search),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;
    
    if (user == null) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Projects'),
        actions: [
          IconButton(
            icon: const Icon(Icons.trending_up),
            tooltip: 'Popular Projects',
            onPressed: _showConnections,
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(
              icon: Icon(Icons.folder),
              text: 'My Projects',
            ),
            Tab(
              icon: Icon(Icons.search),
              text: 'Find Projects',
            )
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // My Projects Tab
          Column(
            children: [
              _buildSearchBar(_myProjectsSearchController, 'Search my projects...'),
              Expanded(
                child: StreamBuilder<List<Project>>(
                  stream: _myProjectsSearchQuery.isEmpty
                      ? _projectService.getUserAccessibleProjects(user.uid)
                      : _projectService.searchUserAccessibleProjects(user.uid, _myProjectsSearchQuery),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      print('ProjectsScreen error: ${snapshot.error}');
                      if (snapshot.error.toString().contains('permission-denied')) {
                        return _buildErrorView(
                          'Access Denied',
                          'You don\'t have permission to view these projects.',
                        );
                      }
                      return _buildErrorView(
                        'Error',
                        'Error loading projects: ${snapshot.error}',
                      );
                    }

                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return _buildLoadingView();
                    }

                    final projects = snapshot.data ?? [];
                    if (projects.isEmpty) {
                      return _buildEmptyView();
                    }

                    return _buildProjectList(projects);
                  },
                ),
              ),
            ],
          ),
          // Find Projects Tab
          Column(
            children: [
              _buildSearchBar(_findProjectsSearchController, 'Search public projects...'),
              Expanded(
                child: StreamBuilder<List<Project>>(
                  stream: _findProjectsSearchQuery.isEmpty
                      ? _projectService.getPublicProjects()
                      : _projectService.searchPublicProjects(_findProjectsSearchQuery),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return _buildErrorView(
                        'Error',
                        'Error loading public projects: ${snapshot.error}',
                      );
                    }

                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return _buildLoadingView();
                    }

                    final projects = snapshot.data ?? [];
                    if (projects.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.search_off,
                              size: 64,
                              color: Colors.grey,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _findProjectsSearchQuery.isEmpty
                                  ? 'No public projects found'
                                  : 'No projects match your search',
                              style: const TextStyle(
                                fontSize: 20,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    return _buildProjectList(projects);
                  },
                ),
              ),
            ],
          ),
         
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _createProject,
        child: const Icon(Icons.add),
      ),
      bottomNavigationBar: AppBottomNavigation(currentIndex: 0),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }

  Widget _buildErrorView(String title, String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 48, color: Colors.red),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.red,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => setState(() {}),
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingView() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('Loading projects...'),
        ],
      ),
    );
  }

  Widget _buildEmptyView() {
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
            'No projects yet',
            style: TextStyle(
              fontSize: 20,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _createProject,
            icon: const Icon(Icons.add),
            label: const Text('Create Your First Project'),
          ),
        ],
      ),
    );
  }

  Widget _buildProjectList(List<Project> projects) {
    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: projects.length,
      itemBuilder: (context, index) {
        final project = projects[index];
        return Card(
          child: ListTile(
            leading: Icon(
              project.isPublic ? Icons.public : Icons.lock_outline,
              color: project.isPublic ? Colors.green : Colors.grey,
            ),
            title: Text(project.name),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(project.description ?? 'No description'),
                const SizedBox(height: 4),
                Text(
                  '${project.videoIds.length} videos',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
            isThreeLine: true,
            trailing: project.userId == _auth.currentUser?.uid
              ? const Icon(Icons.edit, color: Colors.blue)
              : const Icon(Icons.visibility, color: Colors.grey),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ProjectDetailsScreen(
                    project: project,
                    preloadService: widget.preloadService,
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _CreateProjectDialog extends StatefulWidget {
  @override
  State<_CreateProjectDialog> createState() => _CreateProjectDialogState();
}

class _CreateProjectDialogState extends State<_CreateProjectDialog> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormFieldState>();
  final _projectService = ProjectService();
  final _speechToText = SpeechToText();
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  bool _isLoading = false;
  bool _isListening = false;
  bool _speechInitialized = false;
  bool _isInitializing = false;
  String _voiceTranscript = '';
  String _errorMessage = '';
  Timer? _initTimer;
  bool _mounted = true;
  
  @override
  void initState() {
    super.initState();
    
    // Initialize pulse animation
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(
        parent: _pulseController,
        curve: Curves.easeInOut,
      ),
    );
    _pulseController.repeat(reverse: true);
    
    // Check permissions and initialize speech
    _checkPermissionsAndInit();
  }

  @override
  void dispose() {
    _mounted = false;
    _pulseController.dispose();
    _speechToText.stop();
    _initTimer?.cancel();
    super.dispose();
  }

  void _safeSetState(VoidCallback fn) {
    if (_mounted && mounted) {
      setState(fn);
    }
  }

  Future<void> _checkPermissionsAndInit() async {
    if (_speechInitialized) return;
    
    final status = await Permission.microphone.status;
    
    if (status.isGranted) {
      _initSpeechWithRetry();
    } else {
      final newStatus = await Permission.microphone.request();
      if (newStatus.isGranted) {
        _initSpeechWithRetry();
      }
    }
  }

  Future<void> _initSpeechWithRetry() async {
    if (_speechInitialized) return;
    
    try {
      final isAvailable = await _speechToText.initialize(
        onError: (error) => print('Speech recognition error: $error'),
        onStatus: (status) => print('Speech recognition status: $status'),
      );

      if (isAvailable) {
        _speechInitialized = true;
      }
    } catch (e) {
      print('Error initializing speech: $e');
    }
  }

  void _toggleRecording() async {
    if (_isListening) {
      if (_speechToText.isListening) {
        await _speechToText.stop();
      }
      _safeSetState(() => _isListening = false);
    } else {
      if (!_speechInitialized) {
        await _initSpeechWithRetry();
      }

      _safeSetState(() => _isListening = true);
      
      try {
        await _speechToText.listen(
          onResult: (result) {
            _safeSetState(() {
              _voiceTranscript = result.recognizedWords;
            });
          },
          listenFor: Duration(seconds: 300),
          pauseFor: Duration(seconds: 3),
          partialResults: true,
          cancelOnError: false,
          listenMode: ListenMode.dictation,
        );
      } catch (e) {
        print('Error starting speech recognition: $e');
        _safeSetState(() => _isListening = false);
      }
    }
  }

  void _stopListening() {
    if (_speechToText.isListening) {
      _speechToText.stop();
    }
    _safeSetState(() => _isListening = false);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Create New Project'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Tap the microphone to start recording, tap again to stop. AI will generate a title and description, and find related videos.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            SizedBox(height: 20),
            if (_isInitializing)
              Container(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Initializing speech recognition...',
                      style: TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
            if (_isInitializing) SizedBox(height: 20),
            // Recording status indicator
            if (_isListening)
              Container(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.red),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Recording...',
                      style: TextStyle(color: Colors.red),
                    ),
                  ],
                ),
              ),
            SizedBox(height: 20),
            // Microphone button with pulse animation
            GestureDetector(
              onTap: _toggleRecording,
              child: AnimatedBuilder(
                animation: _pulseAnimation,
                builder: (context, child) {
                  return Transform.scale(
                    scale: _isListening ? _pulseAnimation.value : 1.0,
                    child: Container(
                      padding: EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _isListening ? Colors.red : Theme.of(context).primaryColor,
                        boxShadow: _isListening
                          ? [
                              BoxShadow(
                                color: Colors.red.withOpacity(0.3),
                                blurRadius: 10,
                                spreadRadius: 2,
                              ),
                            ]
                          : null,
                      ),
                      child: Icon(
                        _isListening ? Icons.mic : Icons.mic_none,
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                  );
                },
              ),
            ),
            SizedBox(height: 20),
            // Transcript display
            if (_voiceTranscript.isNotEmpty) ...[
              Text(
                'Your recording:',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 8),
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Colors.grey[300]!,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _voiceTranscript,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    if (_isListening) ...[
                      SizedBox(height: 8),
                      Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: Colors.green,
                              shape: BoxShape.circle,
                            ),
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Listening...',
                            style: TextStyle(
                              color: Colors.green,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _createProject,
          child: _isLoading
              ? SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text('Create Project'),
        ),
      ],
    );
  }

  Future<void> _createProject() async {
    if (_voiceTranscript.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please record your project description first')),
      );
      return;
    }

    _safeSetState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not logged in');

      await _projectService.createProjectWithAI(
        voiceTranscript: _voiceTranscript,
        userId: user.uid,
      );

      if (_mounted && mounted) {
        // Close the dialog first
        Navigator.of(context).pop();
        
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Project created successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('Error creating project: $e');
      if (_mounted && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error creating project: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (_mounted) {
        _safeSetState(() => _isLoading = false);
      }
    }
  }
} 