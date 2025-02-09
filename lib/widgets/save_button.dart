import 'package:flutter/material.dart';
import '../services/project_service.dart';

class SaveButton extends StatefulWidget {
  final String videoId;
  final String projectId;
  final bool initialSaveState;
  final Function(bool)? onSaveStateChanged;

  const SaveButton({
    super.key,
    required this.videoId,
    required this.projectId,
    required this.initialSaveState,
    this.onSaveStateChanged,
  });

  @override
  State<SaveButton> createState() => _SaveButtonState();
}

class _SaveButtonState extends State<SaveButton> {
  late bool _isSaved;
  final _projectService = ProjectService();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _isSaved = widget.initialSaveState;
  }

  Future<void> _toggleSave() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
    });

    try {
      if (_isSaved) {
        await _projectService.removeVideoFromProject(
          widget.projectId,
          widget.videoId,
        );
      } else {
        await _projectService.addVideoToProject(
          widget.projectId,
          widget.videoId,
        );
      }

      setState(() {
        _isSaved = !_isSaved;
      });

      widget.onSaveStateChanged?.call(_isSaved);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: _isLoading
          ? const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : Icon(
              _isSaved ? Icons.bookmark : Icons.bookmark_border,
              color: Colors.white,
              size: 28,
            ),
      onPressed: _toggleSave,
    );
  }
} 