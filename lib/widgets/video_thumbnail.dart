import 'package:flutter/material.dart';

class VideoThumbnail extends StatelessWidget {
  final String videoUrl;
  final String thumbnailUrl;

  const VideoThumbnail({
    super.key,
    required this.videoUrl,
    required this.thumbnailUrl,
  });

  @override
  Widget build(BuildContext context) {
    if (thumbnailUrl.isEmpty) {
      return Container(
        color: Colors.grey[300],
      );
    }

    return Image.network(
      thumbnailUrl,
      fit: BoxFit.cover,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return Container(
          color: Colors.grey[300],
          child: const Center(
            child: CircularProgressIndicator(),
          ),
        );
      },
      errorBuilder: (context, error, stackTrace) => Container(
        color: Colors.grey[300],
      ),
    );
  }
} 