import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/project.dart';

class ProjectService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

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
    print('Adding video $videoId to project $projectId'); // Debug print
    
    // First get the current project to ensure we have the latest data
    final projectDoc = await _firestore.collection('projects').doc(projectId).get();
    if (!projectDoc.exists) {
      throw Exception('Project not found');
    }

    final project = Project.fromJson(projectDoc.data()!);
    final updatedVideoIds = List<String>.from(project.videoIds)..add(videoId);

    await _firestore.collection('projects').doc(projectId).update({
      'videoIds': updatedVideoIds,
    });

    print('Updated project videoIds: $updatedVideoIds'); // Debug print
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
            .map((doc) => Project.fromJson(doc.data()))
            .toList());
  }

  // Get projects where user is collaborator
  Stream<List<Project>> getCollaboratedProjects(String userId) {
    return _firestore
        .collection('projects')
        .where('collaboratorIds', arrayContains: userId)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Project.fromJson(doc.data()))
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
} 