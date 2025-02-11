import 'package:flutter/material.dart';

class VideoThumbnail extends StatelessWidget {
  final String videoUrl;
  final String? thumbnailUrl;

  const VideoThumbnail({
    super.key,
    required this.videoUrl,
    this.thumbnailUrl,
  });

  @override
  Widget build(BuildContext context) {
    if (thumbnailUrl != null) {
      return Image.network(
        thumbnailUrl!,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return _buildPlaceholder();
        },
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return _buildPlaceholder(showLoading: true);
        },
      );
    }
    return _buildPlaceholder();
  }

  Widget _buildPlaceholder({bool showLoading = false}) {
    return Container(
      color: Colors.grey[200],
      child: Center(
        child: showLoading
            ? const CircularProgressIndicator()
            : const Icon(Icons.video_library, size: 48, color: Colors.grey),
      ),
    );
  }
} 