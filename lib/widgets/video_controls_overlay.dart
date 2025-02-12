import 'package:flutter/material.dart';
import '../models/video.dart';

class VideoControlsOverlay extends StatelessWidget {
  final Video video;
  final String projectName;
  final VoidCallback? onLike;
  final VoidCallback? onShare;
  final VoidCallback? onProjectTap;

  const VideoControlsOverlay({
    super.key,
    required this.video,
    required this.projectName,
    this.onLike,
    this.onShare,
    this.onProjectTap,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Video Info (Title, Description)
        Positioned(
          left: 16,
          right: 72,
          bottom: 16,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (video.title != null)
                Text(
                  video.title!,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              if (video.description != null)
                Text(
                  video.description!,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              const SizedBox(height: 8),
              if (onProjectTap != null)
                GestureDetector(
                  onTap: onProjectTap,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.folder_outlined,
                        color: Colors.white,
                        size: 16,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        projectName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),

        // Action Buttons (Like, Share)
        Positioned(
          right: 8,
          bottom: MediaQuery.of(context).padding.bottom + 16,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (onLike != null)
                _ActionButton(
                  icon: Icons.favorite_border,
                  label: video.likedBy.length.toString(),
                  onTap: onLike!,
                ),
              const SizedBox(height: 16),
              if (onShare != null)
                _ActionButton(
                  icon: Icons.share,
                  label: 'Share',
                  onTap: onShare!,
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.5),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
} 