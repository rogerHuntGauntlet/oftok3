# Project Popularity & Engagement Tracking Feature

This document outlines a proposed feature that tracks project engagement by using a simple scoring mechanism. Every time a user opens a project or watches a video associated with that project, the project's score is incremented. Later, these scores can be used for analytics, smarter recommendations, AI‑driven clustering, or visualizations.

---

## Feature Overview

- **Project Visit Tracking:**  
  When a user opens a project's details page, the project's score is incremented by 1.

- **Video View Tracking:**  
  When a video starts playing (for the first time) within the project, the project's score is incremented by an additional 1.

- **Future Possibilities:**  
  - Use project scores as part of an AI‑powered recommendation system.
  - Dynamically sort and display popular projects.
  - Generate node‑and‑edge graphs to visualize relationships between highly engaged projects.

---

## Implementation Details

1. **Backend Management (Firestore):**  
   - Use Firestore's `FieldValue.increment()` to atomically update a numeric `score` field in the project document.
   
2. **User Interaction Triggers:**  
   - Increment the score when a project is viewed.
   - Increment the score when video playback is detected (using a callback).

3. **UI Components:**  
   - **ProjectDetailsScreen:** Trigger score increments on page load.
   - **VideoFeedItem:** Use a specialized video player widget that calls a callback once playback starts.
   - **VideoPlayerWidget:** Enhanced to support an `onVideoStarted` callback for notifying when the video begins playing.

---

## Proposed Code Changes

### 1. Update the Project Service

Add an `incrementProjectScore` method to update the score field in Firestore.

```dart
// File: lib/services/project_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/project.dart';

class ProjectService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Other service methods ...

  // Increment the project score by a specified amount.
  Future<void> incrementProjectScore(String projectId, int incrementBy) async {
    await _firestore.collection('projects').doc(projectId).update({
      'score': FieldValue.increment(incrementBy),
    });
    print('Successfully incremented project score');
  }
}
```

### 2. Project Details Screen

Call the `incrementProjectScore` method when the project details screen loads.

```dart
// File: lib/screens/project_details_screen.dart
import 'package:flutter/material.dart';
import '../services/project_service.dart';
import '../models/project.dart';

class ProjectDetailsScreen extends StatefulWidget {
  final Project project;

  const ProjectDetailsScreen({Key? key, required this.project})
      : super(key: key);

  @override
  _ProjectDetailsScreenState createState() => _ProjectDetailsScreenState();
}

class _ProjectDetailsScreenState extends State<ProjectDetailsScreen> {
  final ProjectService _projectService = ProjectService();

  @override
  void initState() {
    super.initState();
    // Increment score when the screen loads.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _projectService.incrementProjectScore(widget.project.id, 1);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.project.name),
      ),
      body: Center(
        child: Text('Project details for ${widget.project.name}'),
      ),
    );
  }
}
```

### 3. Enhance the Video Player Widget

Modify the video player widget to support a callback that fires when playback starts.

```dart
// File: lib/widgets/video_player_widget.dart
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class VideoPlayerWidget extends StatefulWidget {
  final String videoUrl;
  final bool autoPlay;
  final bool showControls;
  final VoidCallback? onVideoStarted;

  const VideoPlayerWidget({
    Key? key,
    required this.videoUrl,
    this.autoPlay = false,
    this.showControls = false,
    this.onVideoStarted,
  }) : super(key: key);

  @override
  _VideoPlayerWidgetState createState() => _VideoPlayerWidgetState();
}

class _VideoPlayerWidgetState extends State<VideoPlayerWidget> {
  late VideoPlayerController _controller;
  bool _hasNotifiedStart = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.network(widget.videoUrl)
      ..initialize().then((_) {
        setState(() {});
        if (widget.autoPlay) {
          _controller.play();
        }
        _controller.setLooping(true);
      });

    // Listen for playback start and call the callback once.
    _controller.addListener(() {
      if (!_hasNotifiedStart && _controller.value.isPlaying) {
        _hasNotifiedStart = true;
        widget.onVideoStarted?.call();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _controller.value.isInitialized
        ? SizedBox.expand(
            child: FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: _controller.value.size.width,
                height: _controller.value.size.height,
                child: VideoPlayer(_controller),
              ),
            ),
          )
        : const Center(child: CircularProgressIndicator());
  }
}
```

### 4. Video Feed Item Widget

Detects when a video starts playing to trigger a score increment.

```dart
// File: lib/widgets/video_feed_item.dart
import 'package:flutter/material.dart';
import '../services/project_service.dart';
import 'video_player_widget.dart';

class VideoFeedItem extends StatefulWidget {
  final String videoUrl;
  final String videoId;
  final String projectId;
  final String projectName;
  final bool autoPlay;

  const VideoFeedItem({
    Key? key,
    required this.videoUrl,
    required this.videoId,
    required this.projectId,
    required this.projectName,
    this.autoPlay = true,
  }) : super(key: key);

  @override
  _VideoFeedItemState createState() => _VideoFeedItemState();
}

class _VideoFeedItemState extends State<VideoFeedItem> {
  final ProjectService _projectService = ProjectService();
  bool _hasTrackedWatch = false;

  void _onVideoStarted() {
    if (!_hasTrackedWatch) {
      _hasTrackedWatch = true;
      print('Incrementing score for project ${widget.projectId} by 1');
      _projectService.incrementProjectScore(widget.projectId, 1);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        VideoPlayerWidget(
          videoUrl: widget.videoUrl,
          autoPlay: widget.autoPlay,
          showControls: true,
          onVideoStarted: _onVideoStarted,
        ),
        // Overlay to display project name.
        Positioned(
          top: MediaQuery.of(context).padding.top + 16,
          left: 16,
          right: 16,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.5),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              widget.projectName,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
        // Additional UI elements (buttons, etc.) can be added here.
      ],
    );
  }
}
```

---

## Observations from Debug Logs

The provided logs demonstrate the following:

- The project's list of video IDs is correctly retrieved.
- Videos are fetched for the corresponding ID list, and the number of found videos matches the request.
- Each time a project is viewed or a video starts playing, a log confirms that the project score is incremented.
- Firestore queries (for sorting projects by score) may trigger an index creation prompt. If you see an error like:  
  _"The query requires an index. You can create it here: ..."_,  
  follow the provided link in the error message to set up the composite index.

---

## Reasoning Behind the Approach

- **Maintainability:**  
  Modularizing the tracking functionality in `ProjectService` and introducing callbacks in UI components lets you change the scoring logic or extend it (e.g., different weights for different actions) with minimal impact on other parts of the code.

- **Scalability:**  
  Using Firestore's atomic operations (`FieldValue.increment`) ensures robust, concurrent-safe updates even under heavy usage.

- **User Engagement Insights:**  
  Incrementing scores for both page views and video interactions allows a granular insight into project popularity, forming a solid basis for future recommendation algorithms and visualizations.

- **Performance:**  
  Offloading the scoring update to asynchronous calls helps maintain a smooth and responsive user interface.

---

## Future Enhancements

- **Refine Scoring Logic:**  
  You might adjust weights (for instance, more points for longer video watches) or add decay factors to keep scores current.

- **AI‑driven Clustering and Recommendations:**  
  Use the score data along with additional metrics (such as video content analysis, user engagement patterns, and project metadata) to drive more intelligent recommendations.

- **Visual Representations:**  
  Integrate node‑and‑edge graph visualizations where nodes represent popular projects and edges represent similarities or interactions between them.

- **Optimize Video Playback:**  
  Consider sharing a single video player instance or implementing caching/preloading mechanisms to improve performance in feeds. 