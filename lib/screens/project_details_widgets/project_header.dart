import 'package:flutter/material.dart';
import '../../models/project.dart';
import '../../services/social_service.dart';
import '../../services/project_service.dart';
import 'social_stat.dart';
import 'social_button.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ProjectHeader extends StatelessWidget {
  final Project project;
  final SocialService socialService;
  final ProjectService projectService;
  final Function() onRefresh;
  final Function(BuildContext) showCommentsSheet;

  const ProjectHeader({
    super.key,
    required this.project,
    required this.socialService,
    required this.projectService,
    required this.onRefresh,
    required this.showCommentsSheet,
  });

  Future<void> _toggleProjectVisibility(BuildContext context, bool value) async {
    try {
      await projectService.toggleProjectVisibility(
        project.id,
        value,
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Project is now ${value ? 'public' : 'private'}',
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating visibility: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Theme.of(context).colorScheme.primary.withOpacity(0.1),
            Theme.of(context).colorScheme.secondary.withOpacity(0.05),
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Project Info Section
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Project Title and Description
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
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                          if (project.description != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: Text(
                                project.description!,
                                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                // Stats Row
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        spreadRadius: 0,
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      StreamBuilder<bool>(
                        stream: socialService.getLikeStatus(project.id),
                        builder: (context, likeSnapshot) {
                          final isLiked = likeSnapshot.data ?? false;
                          return SocialStat(
                            icon: Icons.favorite,
                            count: project.likeCount,
                            label: 'Likes',
                            color: Colors.pink,
                            isActive: isLiked,
                          );
                        },
                      ),
                      SocialStat(
                        icon: Icons.comment,
                        count: project.commentCount,
                        label: 'Comments',
                        color: Colors.blue,
                      ),
                      GestureDetector(
                        onTap: () => _toggleProjectVisibility(context, !project.isPublic),
                        child: SocialStat(
                          icon: project.isPublic ? Icons.public : Icons.lock_outline,
                          count: null,
                          label: project.isPublic ? 'Public' : 'Private',
                          color: project.isPublic ? Colors.green : Colors.grey,
                          isActive: project.isPublic,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Action Buttons Section
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -5),
                ),
              ],
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    StreamBuilder<bool>(
                      stream: socialService.getLikeStatus(project.id),
                      builder: (context, likeSnapshot) {
                        final isLiked = likeSnapshot.data ?? false;
                        return SocialButton(
                          icon: isLiked ? Icons.favorite : Icons.favorite_border,
                          label: isLiked ? 'Liked' : 'Like',
                          isActive: isLiked,
                          onPressed: () async {
                            if (currentUser != null) {
                              try {
                                await socialService.toggleLike(project.id);
                              } catch (e) {
                                if (context.mounted) {
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
                      },
                    ),
                    SocialButton(
                      icon: Icons.comment,
                      label: 'Comment',
                      onPressed: () => showCommentsSheet(context),
                    ),
                    SocialButton(
                      icon: Icons.share,
                      label: 'Share',
                      onPressed: () async {
                        final shareUrl = await socialService.generateShareUrl(project.id);
                        if (context.mounted) {
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
        ],
      ),
    );
  }
} 