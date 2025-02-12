import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/project.dart';
import '../models/video.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'ai_caption_service.dart';
import 'video_service.dart';
import '../services/notification_service.dart';
import '../services/auth_service.dart';
import '../services/social_service.dart';

class ProjectService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final _aiCaptionService = AICaptionService();
  final _videoService = VideoService();
  final AuthService _authService = AuthService();
  final NotificationService _notificationService = NotificationService();

  // Create a new project
  Future<Project> createProject({
    required String name,
    required String description,
    required String userId,
  }) async {
    final projectData = Project(
      id: _firestore.collection('projects').doc().id,
      name: name,
      description: description,
      userId: userId,
      createdAt: DateTime.now(),
      videoIds: [],
    );

    await _firestore
        .collection('projects')
        .doc(projectData.id)
        .set(projectData.toJson());

    print('Created project: ${projectData.id}'); // Debug print
    return projectData;
  }

  // Get all projects for a user
  Stream<List<Project>> getUserProjects(String userId) {
    print('Getting projects for user: $userId'); // Debug print
    return _firestore
        .collection('projects')
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) {
          try {
            final projects = snapshot.docs.map((doc) {
              try {
                final data = doc.data();
                // Ensure id is included in the data
                data['id'] = doc.id;
                return Project.fromJson(data);
              } catch (e) {
                print('Error parsing project document ${doc.id}: $e');
                // Skip invalid documents instead of failing the entire stream
                return null;
              }
            })
            .where((project) => project != null)
            .cast<Project>()
            .toList();
            
            print('Found ${projects.length} valid projects'); // Debug print
            return projects;
          } catch (e) {
            print('Error processing projects snapshot: $e');
            rethrow;
          }
        });
  }

  // Add a video to a project
  Future<void> addVideoToProject(String projectId, String videoId) async {
    try {
      // Get the project first to check if it exists and get its name
      final projectDoc = await _firestore.collection('projects').doc(projectId).get();
      if (!projectDoc.exists) {
        throw Exception('Project not found');
      }

      final projectData = projectDoc.data()!;
      final projectName = projectData['name'] as String;
      final userId = projectData['userId'] as String;

      // Add the video to the project
      await _firestore.collection('projects').doc(projectId).update({
        'videoIds': FieldValue.arrayUnion([videoId]),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Create notification for the project owner
      await _notificationService.notifyVideoAdded(
        userId: userId,
        projectName: projectName,
        projectId: projectId,
        videoId: videoId,
      );
    } catch (e) {
      print('Error adding video to project: $e');
      rethrow;
    }
  }

  // Remove a video from a project
  Future<void> removeVideoFromProject(String projectId, String videoId) async {
    await _firestore.collection('projects').doc(projectId).update({
      'videoIds': FieldValue.arrayRemove([videoId])
    });
  }

  // Delete a project
  Future<void> deleteProject(String projectId) async {
    await _firestore.collection('projects').doc(projectId).delete();
  }

  // Get a single project
  Future<Project?> getProject(String projectId) async {
    final doc = await _firestore.collection('projects').doc(projectId).get();
    if (!doc.exists) return null;
    return Project.fromJson(doc.data()!);
  }

  // Get a stream of project updates
  Stream<Project?> getProjectStream(String projectId) {
    return _firestore
        .collection('projects')
        .doc(projectId)
        .snapshots()
        .map((snapshot) {
          if (!snapshot.exists) return null;
          final data = snapshot.data()!;
          data['id'] = snapshot.id; // Ensure ID is included
          return Project.fromJson(data);
        });
  }

  // Update video order in project
  Future<void> updateVideoOrder(String projectId, List<String> newVideoIds) async {
    await _firestore
        .collection('projects')
        .doc(projectId)
        .update({'videoIds': newVideoIds});
  }

  // Toggle project visibility
  Future<void> toggleProjectVisibility(String projectId, bool isPublic) async {
    await _firestore
        .collection('projects')
        .doc(projectId)
        .update({'isPublic': isPublic});
  }

  // Add a collaborator to project
  Future<void> addCollaborator(String projectId, String userId) async {
    await _firestore.collection('projects').doc(projectId).update({
      'collaboratorIds': FieldValue.arrayUnion([userId])
    });
  }

  // Remove a collaborator from project
  Future<void> removeCollaborator(String projectId, String userId) async {
    await _firestore.collection('projects').doc(projectId).update({
      'collaboratorIds': FieldValue.arrayRemove([userId])
    });
  }

  // Get all projects where user is owner or collaborator
  Stream<List<Project>> getUserAccessibleProjects(String userId) {
    return _firestore
        .collection('projects')
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) {
              try {
                final data = doc.data();
                data['id'] = doc.id;
                return Project.fromJson(data);
              } catch (e) {
                print('Error parsing project document ${doc.id}: $e');
                return null;
              }
            })
            .where((project) => project != null)
            .cast<Project>()
            .toList());
  }

  // Get projects where user is collaborator
  Stream<List<Project>> getCollaboratedProjects(String userId) {
    return _firestore
        .collection('projects')
        .where('collaboratorIds', arrayContains: userId)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) {
              try {
                final data = doc.data();
                data['id'] = doc.id;
                return Project.fromJson(data);
              } catch (e) {
                print('Error parsing project document ${doc.id}: $e');
                return null;
              }
            })
            .where((project) => project != null)
            .cast<Project>()
            .toList());
  }

  // Get all public projects
  Stream<List<Project>> getPublicProjects() {
    print('Getting public projects'); // Debug print
    return _firestore
        .collection('projects')
        .where('isPublic', isEqualTo: true)
        .snapshots()
        .map((snapshot) {
          try {
            final projects = snapshot.docs.map((doc) {
              try {
                final data = doc.data();
                data['id'] = doc.id;
                return Project.fromJson(data);
              } catch (e) {
                print('Error parsing project document ${doc.id}: $e');
                return null;
              }
            })
            .where((project) => project != null)
            .cast<Project>()
            .toList();
            
            print('Found ${projects.length} public projects'); // Debug print
            return projects;
          } catch (e) {
            print('Error processing public projects snapshot: $e');
            rethrow;
          }
        });
  }

  // Increment the project score
  Future<void> incrementProjectScore(String projectId, int incrementBy) async {
    print('Incrementing score for project $projectId by $incrementBy'); // Debug print
    try {
      await _firestore.collection('projects').doc(projectId).update({
        'score': FieldValue.increment(incrementBy),
      });
      print('Successfully incremented project score'); // Debug print
    } catch (e) {
      print('Error incrementing project score: $e');
      rethrow;
    }
  }

  // Get projects sorted by score
  Stream<List<Project>> getProjectsSortedByScore({int limit = 10}) {
    print('Getting projects sorted by score'); // Debug print
    return _firestore
        .collection('projects')
        .where('isPublic', isEqualTo: true)
        .orderBy('score', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) {
          try {
            final projects = snapshot.docs.map((doc) {
              try {
                final data = doc.data();
                data['id'] = doc.id;
                return Project.fromJson(data);
              } catch (e) {
                print('Error parsing project document ${doc.id}: $e');
                return null;
              }
            })
            .where((project) => project != null)
            .cast<Project>()
            .toList();
            
            print('Found ${projects.length} projects sorted by score'); // Debug print
            return projects;
          } catch (e) {
            print('Error processing projects by score snapshot: $e');
            rethrow;
          }
        });
  }

  // Toggle project favorite status
  Future<void> toggleProjectFavorite(String projectId, String userId) async {
    print('Toggling favorite for project $projectId by user $userId'); // Debug print
    try {
      final doc = await _firestore.collection('projects').doc(projectId).get();
      if (!doc.exists) throw Exception('Project not found');

      final socialService = SocialService();
      await socialService.toggleLike(projectId);

      print('Successfully toggled project favorite status'); // Debug print
    } catch (e) {
      print('Error toggling project favorite: $e');
      rethrow;
    }
  }

  // Get all public projects sorted by favorites and score
  Stream<List<Project>> getProjectsSortedByFavoritesAndScore({int limit = 20}) {
    print('Getting projects sorted by favorites and score'); // Debug print
    return _firestore
        .collection('projects')
        .where('isPublic', isEqualTo: true)
        .orderBy('score', descending: true)
        .limit(limit)
        .snapshots()
        .asyncMap((snapshot) async {
          try {
            final projects = snapshot.docs.map((doc) {
              try {
                final data = doc.data();
                data['id'] = doc.id;
                return Project.fromJson(data);
              } catch (e) {
                print('Error parsing project document ${doc.id}: $e');
                return null;
              }
            })
            .where((project) => project != null)
            .cast<Project>()
            .toList();

            // Sort projects using the async sorting method
            final sortedProjects = await _sortProjectsByRelevance(projects);
            
            print('Found ${projects.length} projects sorted by favorites and score'); // Debug print
            return sortedProjects;
          } catch (e) {
            print('Error processing projects by favorites and score: $e');
            rethrow;
          }
        });
  }

  // Calculate engagement score based on multiple metrics
  double _calculateEngagementScore(Project project) {
    const sessionWeight = 0.4;
    const scoreWeight = 0.3;
    const likesWeight = 0.2;
    const commentsWeight = 0.1;

    // Normalize session duration (assuming 5 minutes is a good session)
    final avgSessionDuration = project.sessionCount > 0
        ? project.totalSessionDuration.inSeconds / project.sessionCount
        : 0;
    final normalizedSessionScore = avgSessionDuration / 300; // 300 seconds = 5 minutes

    return (normalizedSessionScore * sessionWeight) +
           (project.score * scoreWeight) +
           (project.likeCount * likesWeight) +
           (project.commentCount * commentsWeight);
  }

  // Sort projects by relevance
  Future<List<Project>> _sortProjectsByRelevance(List<Project> projects) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return projects;

    final socialService = SocialService();
    final likeStatusFutures = projects.map((p) => socialService.hasUserLiked(p.id));
    final likeStatuses = await Future.wait(likeStatusFutures);
    
    final projectsWithLikes = List.generate(
      projects.length,
      (i) => MapEntry(projects[i], likeStatuses[i]),
    );

    projectsWithLikes.sort((a, b) {
      final aProject = a.key;
      final bProject = b.key;
      final aLiked = a.value;
      final bLiked = b.value;
      
      // Owner's projects come first
      if (aProject.userId == currentUser.uid && bProject.userId != currentUser.uid) return -1;
      if (bProject.userId == currentUser.uid && aProject.userId != currentUser.uid) return 1;

      // Collaborator's projects come second
      final aIsCollaborator = aProject.collaboratorIds.contains(currentUser.uid);
      final bIsCollaborator = bProject.collaboratorIds.contains(currentUser.uid);
      if (aIsCollaborator && !bIsCollaborator) return -1;
      if (bIsCollaborator && !aIsCollaborator) return 1;

      // Liked projects come third
      if (aLiked && !bLiked) return -1;
      if (bLiked && !aLiked) return 1;

      // Then sort by total likes
      final likesComparison = bProject.likeCount.compareTo(aProject.likeCount);
      if (likesComparison != 0) return likesComparison;

      // Finally sort by most recent
      return bProject.lastEngagement.compareTo(aProject.lastEngagement);
    });

    return projectsWithLikes.map((e) => e.key).toList();
  }

  // Search user accessible projects
  Stream<List<Project>> searchUserAccessibleProjects(String userId, String searchQuery) {
    searchQuery = searchQuery.toLowerCase();
    return _firestore
        .collection('projects')
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) {
              try {
                final data = doc.data();
                data['id'] = doc.id;
                return Project.fromJson(data);
              } catch (e) {
                print('Error parsing project document ${doc.id}: $e');
                return null;
              }
            })
            .where((project) => project != null)
            .cast<Project>()
            .where((project) =>
                project.name.toLowerCase().contains(searchQuery) ||
                (project.description?.toLowerCase() ?? '').contains(searchQuery))
            .toList());
  }

  // Search public projects
  Stream<List<Project>> searchPublicProjects(String searchQuery) {
    searchQuery = searchQuery.toLowerCase();
    return _firestore
        .collection('projects')
        .where('isPublic', isEqualTo: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) {
              try {
                final data = doc.data();
                data['id'] = doc.id;
                return Project.fromJson(data);
              } catch (e) {
                print('Error parsing project document ${doc.id}: $e');
                return null;
              }
            })
            .where((project) => project != null)
            .cast<Project>()
            .where((project) =>
                project.name.toLowerCase().contains(searchQuery) ||
                (project.description?.toLowerCase() ?? '').contains(searchQuery))
            .toList());
  }

  // Create a project with AI-generated content and automatic video suggestions
  Future<Project> createProjectWithAI({
    required String voiceTranscript,
    required String userId,
  }) async {
    try {
      // Use AI to generate title and description
      final aiResponse = await _aiCaptionService.generateProjectDetails(voiceTranscript);
      final title = aiResponse['title'] ?? 'New Project';
      final description = aiResponse['description'] ?? voiceTranscript;

      // Create the project first
      final project = await createProject(
        name: title,
        description: description,
        userId: userId,
      );

      // Find related videos based on the content
      final allVideos = await _videoService.getAllVideos();
      final relatedVideos = await _aiCaptionService.findRelatedVideos(
        description: description,
        availableVideos: allVideos,
        minVideos: 3,
      );

      // Update project with related video IDs
      if (relatedVideos.isNotEmpty) {
        final videoIds = relatedVideos.map((v) => v.id).toList();
        await _firestore
            .collection('projects')
            .doc(project.id)
            .update({'videoIds': videoIds});
        
        // Return updated project
        return project.copyWith(videoIds: videoIds);
      }

      return project;
    } catch (e) {
      print('Error creating project with AI: $e');
      throw Exception('Failed to create project with AI: $e');
    }
  }

  // Update session metrics for a project
  Future<void> updateSessionMetrics(String projectId, Duration sessionDuration) async {
    print('Updating session metrics for project $projectId with duration ${sessionDuration.inSeconds}s'); // Debug print
    try {
      await _firestore.collection('projects').doc(projectId).update({
        'totalSessionDuration': FieldValue.increment(sessionDuration.inMilliseconds),
        'sessionCount': FieldValue.increment(1),
      });
      print('Successfully updated session metrics'); // Debug print
    } catch (e) {
      print('Error updating session metrics: $e');
      rethrow;
    }
  }

  // Get average session duration for a project
  Future<Duration> getAverageSessionDuration(String projectId) async {
    try {
      final doc = await _firestore.collection('projects').doc(projectId).get();
      if (!doc.exists) throw Exception('Project not found');

      final data = doc.data()!;
      final totalDuration = data['totalSessionDuration'] as int? ?? 0;
      final sessionCount = data['sessionCount'] as int? ?? 0;

      if (sessionCount == 0) return Duration.zero;
      return Duration(milliseconds: totalDuration ~/ sessionCount);
    } catch (e) {
      print('Error getting average session duration: $e');
      rethrow;
    }
  }

  // Get projects sorted by engagement (combining session metrics and score)
  Stream<List<Project>> getProjectsSortedByEngagement({int limit = 20}) {
    print('Getting projects sorted by engagement'); // Debug print
    return _firestore
        .collection('projects')
        .where('isPublic', isEqualTo: true)
        .orderBy('score', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) {
          try {
            final projects = snapshot.docs.map((doc) {
              try {
                final data = doc.data();
                data['id'] = doc.id;
                return Project.fromJson(data);
              } catch (e) {
                print('Error parsing project document ${doc.id}: $e');
                return null;
              }
            })
            .where((project) => project != null)
            .cast<Project>()
            .toList();

            // Sort projects by engagement score (combination of session metrics and score)
            projects.sort((a, b) {
              // Calculate engagement scores
              final aEngagement = _calculateEngagementScore(a);
              final bEngagement = _calculateEngagementScore(b);
              return bEngagement.compareTo(aEngagement);
            });
            
            print('Found ${projects.length} projects sorted by engagement'); // Debug print
            return projects;
          } catch (e) {
            print('Error processing projects by engagement: $e');
            rethrow;
          }
        });
  }

  Future<Map<String, dynamic>> getProjectSummary(Project project, String userId) async {
    final isOwner = project.userId == userId;
    final isCollaborator = project.collaboratorIds.contains(userId);
    final hasAccess = isOwner || isCollaborator || project.isPublic;
    
    // Get like status from social service
    final socialService = SocialService();
    final isLiked = await socialService.hasUserLiked(project.id);

    return {
      'id': project.id,
      'name': project.name,
      'description': project.description,
      'isOwner': isOwner,
      'isCollaborator': isCollaborator,
      'hasAccess': hasAccess,
      'isLiked': isLiked,
      'likeCount': project.likeCount,
      'commentCount': project.commentCount,
      'shareCount': project.shareCount,
    };
  }

  double _calculateProjectScore(Project project) {
    const double viewsWeight = 1.0;
    const double likesWeight = 4.0;
    const double commentsWeight = 3.0;
    const double sharesWeight = 5.0;
    
    return (project.likeCount * likesWeight) +
           (project.commentCount * commentsWeight) +
           (project.shareCount * sharesWeight);
  }

  // Get projects containing a video
  Future<List<Project>> getProjectsContainingVideo(String videoId) async {
    try {
      final querySnapshot = await _firestore
          .collection('projects')
          .where('videoIds', arrayContains: videoId)
          .get();
      
      return querySnapshot.docs
          .map((doc) => Project.fromJson(doc.data(), id: doc.id))
          .toList();
    } catch (e) {
      print('Error getting projects containing video: $e');
      rethrow;
    }
  }

  // Remove video from multiple projects
  Future<void> removeVideoFromProjects(String videoId, List<String> projectIds) async {
    try {
      final batch = _firestore.batch();
      
      for (final projectId in projectIds) {
        final projectRef = _firestore.collection('projects').doc(projectId);
        batch.update(projectRef, {
          'videoIds': FieldValue.arrayRemove([videoId]),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
      
      await batch.commit();
    } catch (e) {
      print('Error removing video from projects: $e');
      rethrow;
    }
  }
} 