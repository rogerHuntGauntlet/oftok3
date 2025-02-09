import 'package:flutter/foundation.dart';
import '../services/project_service.dart';

class VideoSaveProvider extends ChangeNotifier {
  final ProjectService _projectService = ProjectService();
  final String projectId;
  List<String> _savedVideoIds = [];
  bool _isLoading = false;

  VideoSaveProvider({required this.projectId}) {
    _loadSavedVideos();
  }

  bool get isLoading => _isLoading;
  List<String> get savedVideoIds => List.unmodifiable(_savedVideoIds);

  bool isVideoSaved(String videoId) {
    return _savedVideoIds.contains(videoId);
  }

  Future<void> _loadSavedVideos() async {
    _isLoading = true;
    notifyListeners();

    try {
      final project = await _projectService.getProject(projectId);
      if (project != null) {
        _savedVideoIds = List<String>.from(project.videoIds);
      }
    } catch (e) {
      print('Error loading saved videos: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> toggleVideoSave(String videoId) async {
    try {
      if (isVideoSaved(videoId)) {
        await _projectService.removeVideoFromProject(projectId, videoId);
        _savedVideoIds.remove(videoId);
      } else {
        await _projectService.addVideoToProject(projectId, videoId);
        _savedVideoIds.add(videoId);
      }
      notifyListeners();
    } catch (e) {
      print('Error toggling video save: $e');
      rethrow;
    }
  }
} 