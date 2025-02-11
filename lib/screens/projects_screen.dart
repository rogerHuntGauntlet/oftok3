import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/project_service.dart';
import '../services/video/video_preload_service.dart';
import '../models/project.dart';
import 'project_details_screen.dart';
import 'project_connections_screen.dart';
import 'project_network_screen.dart';
import 'login_screen.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'dart:async';
import 'dart:math' as math;
import 'package:permission_handler/permission_handler.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:simple_animations/simple_animations.dart';

class ProjectsScreen extends StatefulWidget {
  final VideoPreloadService? preloadService;

  const ProjectsScreen({
    super.key,
    this.preloadService,
  });

  @override
  State<ProjectsScreen> createState() => _ProjectsScreenState();
}

class _ProjectsScreenState extends State<ProjectsScreen> with TickerProviderStateMixin {
  final _projectService = ProjectService();
  final _auth = FirebaseAuth.instance;
  late TabController _tabController;
  final TextEditingController _myProjectsSearchController = TextEditingController();
  final TextEditingController _findProjectsSearchController = TextEditingController();
  String _myProjectsSearchQuery = '';
  String _findProjectsSearchQuery = '';

  // Animation controllers
  late AnimationController _backgroundAnimationController;
  late Animation<double> _backgroundAnimation;

  // Psychedelic gradient colors (more subtle)
  final List<Color> _gradientColors = [
    const Color(0xFF9C27B0).withOpacity(0.6), // Purple
    const Color(0xFF673AB7).withOpacity(0.6), // Deep Purple
    const Color(0xFF3F51B5).withOpacity(0.6), // Indigo
    const Color(0xFF2196F3).withOpacity(0.6), // Blue
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
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

    // Initialize background animation with slower speed
    _backgroundAnimationController = AnimationController(
      duration: const Duration(seconds: 20), // Slower animation
      vsync: this,
    )..repeat();

    _backgroundAnimation = CurvedAnimation(
      parent: _backgroundAnimationController,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _backgroundAnimationController.dispose();
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
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(
            color: Colors.purple.withOpacity(0.3),
            blurRadius: 15,
            spreadRadius: 2,
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        style: GoogleFonts.spaceMono(
          color: Colors.white,
          fontSize: 16,
        ),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: TextStyle(color: Colors.white70),
          prefixIcon: Icon(Icons.search, color: Colors.white70),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(25),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: Colors.black87.withOpacity(0.7),
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
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
      extendBodyBehindAppBar: true,
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(120),
        child: AppBar(
          elevation: 0,
          flexibleSpace: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.black87.withOpacity(0.7),
                  Colors.black54.withOpacity(0.5),
                ],
              ),
            ),
          ),
          backgroundColor: Colors.transparent,
          title: Text(
            'Projects',
            style: GoogleFonts.righteous(
              fontSize: 28,
              color: Colors.white,
              shadows: [
                Shadow(
                  color: Colors.purple.withOpacity(0.5),
                  blurRadius: 10,
                  offset: const Offset(2, 2),
                ),
              ],
            ),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.trending_up, color: Colors.white),
              tooltip: 'Popular Projects',
              onPressed: _showConnections,
            ),
            IconButton(
              icon: const Icon(Icons.logout, color: Colors.white),
              onPressed: _logout,
            ),
          ],
          bottom: TabBar(
            controller: _tabController,
            indicatorColor: Colors.white,
            indicatorWeight: 3,
            tabs: [
              Tab(
                icon: Icon(Icons.folder, color: Colors.white),
                child: Text(
                  'My Projects',
                  style: GoogleFonts.spaceMono(color: Colors.white),
                ),
              ),
              Tab(
                icon: Icon(Icons.search, color: Colors.white),
                child: Text(
                  'Find Projects',
                  style: GoogleFonts.spaceMono(color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ),
      body: Stack(
        children: [
          // Animated background
          AnimatedBuilder(
            animation: _backgroundAnimation,
            builder: (context, _) {
              return Container(
                width: MediaQuery.of(context).size.width,
                height: MediaQuery.of(context).size.height,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment(
                      math.sin(_backgroundAnimation.value * math.pi * 2) * 0.2,
                      math.cos(_backgroundAnimation.value * math.pi * 2) * 0.2,
                    ),
                    end: Alignment(
                      -math.sin(_backgroundAnimation.value * math.pi * 2) * 0.2,
                      -math.cos(_backgroundAnimation.value * math.pi * 2) * 0.2,
                    ),
                    colors: _gradientColors,
                    stops: const [0.0, 0.3, 0.6, 1.0],
                  ),
                ),
              );
            },
          ),
          // Content
          SafeArea(
            child: Padding(
              padding: EdgeInsets.zero,
              child: TabBarView(
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
                              return _buildEmptyView();
                            }

                            return _buildProjectList(projects);
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: _buildFloatingActionButton(),
    );
  }

  Widget _buildFloatingActionButton() {
    return AnimatedBuilder(
      animation: _backgroundAnimation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(
            5 * math.sin(_backgroundAnimation.value * 2 * math.pi),
            5 * math.cos(_backgroundAnimation.value * 2 * math.pi),
          ),
          child: FloatingActionButton(
            onPressed: _createProject,
            backgroundColor: Colors.transparent,
            child: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    Colors.purple,
                    Colors.deepPurple,
                    Colors.blue,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.purple.withOpacity(0.5),
                    blurRadius: 15,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: const Icon(
                Icons.add,
                color: Colors.white,
                size: 32,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildProjectList(List<Project> projects) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: projects.length,
      itemBuilder: (context, index) {
        final project = projects[index];
        return Hero(
          tag: 'project-${project.id}',
          child: Container(
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: LinearGradient(
                colors: [
                  Colors.black87.withOpacity(0.7),
                  Colors.black54.withOpacity(0.5),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.purple.withOpacity(0.2),
                  blurRadius: 10,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
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
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            project.isPublic ? Icons.public : Icons.lock_outline,
                            color: project.isPublic ? Colors.green : Colors.grey,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              project.name,
                              style: GoogleFonts.righteous(
                                fontSize: 20,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          if (project.userId == _auth.currentUser?.uid)
                            const Icon(Icons.edit, color: Colors.blue)
                          else
                            const Icon(Icons.visibility, color: Colors.grey),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        project.description ?? 'No description',
                        style: GoogleFonts.spaceMono(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.purple.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${project.videoIds.length} videos',
                          style: GoogleFonts.spaceMono(
                            color: Colors.white,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildErrorView(String title, String message) {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.black87.withOpacity(0.7),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              title,
              style: GoogleFonts.righteous(
                fontSize: 24,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: GoogleFonts.spaceMono(
                color: Colors.white70,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => setState(() {}),
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purple,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
          ),
          const SizedBox(height: 16),
          Text(
            'Loading projects...',
            style: GoogleFonts.spaceMono(
              color: Colors.white,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyView() {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.black87.withOpacity(0.7),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.video_library_outlined,
              size: 64,
              color: Colors.white70,
            ),
            const SizedBox(height: 16),
            Text(
              'No projects yet',
              style: GoogleFonts.righteous(
                fontSize: 24,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _createProject,
              icon: const Icon(Icons.add),
              label: const Text('Create Your First Project'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purple,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CreateProjectDialog extends StatefulWidget {
  @override
  State<_CreateProjectDialog> createState() => _CreateProjectDialogState();
}

class _CreateProjectDialogState extends State<_CreateProjectDialog> with TickerProviderStateMixin {
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