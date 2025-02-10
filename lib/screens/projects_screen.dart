import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/project_service.dart';
import '../models/project.dart';
import 'project_details_screen.dart';
import 'login_screen.dart';

class ProjectsScreen extends StatefulWidget {
  const ProjectsScreen({super.key});

  @override
  State<ProjectsScreen> createState() => _ProjectsScreenState();
}

class _ProjectsScreenState extends State<ProjectsScreen> with SingleTickerProviderStateMixin {
  final _projectService = ProjectService();
  final _auth = FirebaseAuth.instance;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _createProject() {
    showDialog(
      context: context,
      builder: (context) => _CreateProjectDialog(),
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
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // My Projects Tab
          StreamBuilder<List<Project>>(
            stream: _projectService.getUserAccessibleProjects(user.uid),
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
          // Find Projects Tab
          StreamBuilder<List<Project>>(
            stream: _projectService.getPublicProjects(),
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
                      const Text(
                        'No public projects found',
                        style: TextStyle(
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
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _createProject,
        child: const Icon(Icons.add),
      ),
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
                Text(project.description),
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
                  builder: (_) => ProjectDetailsScreen(project: project),
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

class _CreateProjectDialogState extends State<_CreateProjectDialog> {
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _projectService = ProjectService();
  final _auth = FirebaseAuth.instance;
  bool _isLoading = false;

  Future<void> _createProject() async {
    if (_nameController.text.isEmpty || _descriptionController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all fields')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      await _projectService.createProject(
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim(),
        userId: _auth.currentUser!.uid,
      );
      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Create New Project'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Project Name',
              hintText: 'Enter project name',
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _descriptionController,
            decoration: const InputDecoration(
              labelText: 'Description',
              hintText: 'Enter project description',
            ),
            maxLines: 3,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _createProject,
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Create'),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }
} 