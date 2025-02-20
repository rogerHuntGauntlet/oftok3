import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/project.dart';
import '../services/project_service.dart';
import '../services/auth_service.dart';
import '../services/social_service.dart';
import 'project_details_screen.dart';

class ProjectConnectionsScreen extends StatelessWidget {
  final _projectService = ProjectService();
  final _authService = AuthService();
  final _socialService = SocialService();

  ProjectConnectionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Popular Projects'),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('About Project Scores'),
                  content: const Text(
                    'Project scores are calculated based on:\n'
                    '• Number of visits\n'
                    '• Video views\n'
                    '• User favorites\n\n'
                    'Projects are sorted by your favorites first, followed by popularity.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Got it'),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: StreamBuilder<List<Project>>(
        stream: _projectService.getProjectsSortedByFavoritesAndScore(),
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

          final projects = snapshot.data!;
          if (projects.isEmpty) {
            return const Center(
              child: Text('No projects found'),
            );
          }

          return ListView.builder(
            itemCount: projects.length,
            itemBuilder: (context, index) {
              final project = projects[index];
              return _buildProjectNode(project);
            },
          );
        },
      ),
    );
  }

  Widget _buildProjectNode(Project project) {
    final currentUser = FirebaseAuth.instance.currentUser;
    final isOwner = project.userId == currentUser?.uid;
    final isCollaborator = project.collaboratorIds.contains(currentUser?.uid);

    return StreamBuilder<bool>(
      stream: _socialService.getLikeStatus(project.id),
      builder: (context, snapshot) {
        final isLiked = snapshot.data ?? false;
        
        return Card(
          margin: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 8,
          ),
          child: InkWell(
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ProjectDetailsScreen(project: project),
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
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              project.name,
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              project.description ?? 'No description',
                              style: Theme.of(context).textTheme.bodyMedium,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      if (currentUser != null)
                        IconButton(
                          icon: Icon(
                            isLiked
                                ? Icons.favorite
                                : Icons.favorite_border,
                            color: isLiked ? Colors.red : null,
                          ),
                          onPressed: () {
                            _projectService.toggleProjectFavorite(
                              project.id,
                              currentUser.uid,
                            );
                          },
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.star, color: Colors.amber),
                          const SizedBox(width: 4),
                          Text(
                            'Score: ${project.score}',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          Icon(
                            Icons.favorite,
                            size: 14,
                            color: isLiked ? Colors.red : Colors.grey,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${project.likeCount}',
                            style: TextStyle(
                              fontSize: 12,
                              color: isLiked ? Colors.red : Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      }
    );
  }
} 