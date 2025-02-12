import 'package:flutter/material.dart';

class EmptyVideoState extends StatelessWidget {
  final VoidCallback onUploadVideo;

  const EmptyVideoState({
    super.key,
    required this.onUploadVideo,
  });

  @override
  Widget build(BuildContext context) {
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
            'No videos yet',
            style: TextStyle(
              fontSize: 20,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: onUploadVideo,
            icon: const Icon(Icons.upload),
            label: const Text('Upload Your First Video'),
          ),
        ],
      ),
    );
  }
} 