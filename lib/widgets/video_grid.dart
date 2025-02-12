import 'package:flutter/material.dart';
import '../models/project.dart';
import '../models/video.dart';
import '../services/video_service.dart';
import 'video_thumbnail.dart';

class VideoGrid extends StatelessWidget {
  final Project project;
  final VideoService videoService;
  final Function(String, {int startIndex}) onViewVideos;
  final Function(Video) onVideoOptions;

  const VideoGrid({
    super.key,
    required this.project,
    required this.videoService,
    required this.onViewVideos,
    required this.onVideoOptions,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Video>>(
      future: videoService.getProjectVideos(project.videoIds),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error loading videos: ${snapshot.error}'));
        }

        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final videos = snapshot.data!;
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: ElevatedButton.icon(
                onPressed: () => onViewVideos(project.id),
                icon: const Icon(Icons.play_circle),
                label: const Text('View in Feed'),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 48),
                ),
              ),
            ),
            const SizedBox(height: 16),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: EdgeInsets.zero,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 0.8,
                crossAxisSpacing: 0,
                mainAxisSpacing: 0,
              ),
              itemCount: videos.length,
              itemBuilder: (context, index) {
                final video = videos[index];
                return GestureDetector(
                  onTap: () => onViewVideos(project.id, startIndex: index),
                  onLongPress: () => onVideoOptions(video),
                  child: Card(
                    margin: EdgeInsets.zero,
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.zero,
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        VideoThumbnail(
                          videoUrl: video.url,
                          thumbnailUrl: video.thumbnailUrl,
                          previewUrl: video.previewUrl,
                        ),
                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                Colors.black.withOpacity(0.7),
                              ],
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: 8,
                          left: 8,
                          right: 8,
                          child: Text(
                            video.title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Center(
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.5),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.play_arrow,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }
} 