import 'package:flutter/material.dart';
import 'package:visibility_detector/visibility_detector.dart';

class VideoThumbnail extends StatefulWidget {
  final String videoUrl;
  final String? thumbnailUrl;
  final String? previewUrl;

  const VideoThumbnail({
    super.key,
    required this.videoUrl,
    this.thumbnailUrl,
    this.previewUrl,
  });

  @override
  State<VideoThumbnail> createState() => _VideoThumbnailState();
}

class _VideoThumbnailState extends State<VideoThumbnail> {
  bool _isVisible = false;

  @override
  Widget build(BuildContext context) {
    return VisibilityDetector(
      key: Key('video_${widget.videoUrl}'),
      onVisibilityChanged: (info) {
        if (info.visibleFraction > 0.5) {
          if (!_isVisible) {
            setState(() {
              _isVisible = true;
            });
          }
        } else {
          if (_isVisible) {
            setState(() {
              _isVisible = false;
            });
          }
        }
      },
      child: _buildContent(),
    );
  }

  Widget _buildContent() {
    // If preview URL exists and video is visible, show the GIF
    if (_isVisible && widget.previewUrl != null && widget.previewUrl!.isNotEmpty) {
      return Image.network(
        widget.previewUrl!,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return _buildThumbnail();
        },
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return _buildThumbnail();
        },
      );
    }
    
    return _buildThumbnail();
  }

  Widget _buildThumbnail() {
    if (widget.thumbnailUrl != null && widget.thumbnailUrl!.isNotEmpty && widget.thumbnailUrl!.startsWith('http')) {
      return Image.network(
        widget.thumbnailUrl!,
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