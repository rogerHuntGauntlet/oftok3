Play your videos
In this guide you will learn how to play Mux videos in your application.


Error NaN
In this guide:
1
Get your playback ID
Get the PLAYBACK_ID for your asset or live stream.

2
Create an HLS URL
Use the PLAYBACK_ID with stream.mux.com to create a playback URL.

3
Use the HLS URL in a player
Start streaming your asset or live stream in your web and mobile applications

4
Find a player
Find an HLS player that works best for your application

5
Advanced playback features
6
Next steps
1
Get your playback ID
Each asset and each live_stream in Mux can have one or more Playback IDs.

This is an example of the "playback_ids" from the body of your asset or live_stream in Mux. In this example, the PLAYBACK_ID is "uNbxnGLKJ00yfbijDO8COxTOyVKT01xpxW" and the policy is "public".

Playback IDs can have a policy of "public" or "signed". For the purposes of this guide we will be working with "public" playback IDs.

If this is your first time using Mux, start out with "public" playback IDs and then read more about securing video playback with signed URLs later.

copy
"playback_ids": [
  {
    "policy": "public",
    "id": "uNbxnGLKJ00yfbijDO8COxTOyVKT01xpxW"
  }
],
2
Create an HLS URL
HLS is a standard protocol for streaming video over the internet. Most of the videos you watch on the internet, both live video and on-demand video is delivered over HLS. Mux delivers your videos in this standard format.

Because HLS is an industry standard, you are free to use any HLS player of your choice when working with Mux Video.

HLS URLs end with the extension .m3u8. Use your PLAYBACK_ID to create an HLS URL like this:

copy
https://stream.mux.com/{PLAYBACK_ID}.m3u8
If you're curious to learn more about how HLS works you might find this informational site howvideo.works makes for some good bedtime reading.

Other formats
HLS (.m3u8) is used for streaming assets (video on demand) and live streams. For offline viewing and post-production editing take a look at the guide for download your videos which covers mp4 formats and master access.

3
Use the HLS URL in a player
Most browsers do not support HLS natively in the video element (Safari and IE edge are exceptions). Some JavaScript will be needed in order to support HLS playback in your web application.

The default player in iOS and TVOS (AVPlayer) supports HLS natively, so no extra effort is needed. In the Swift example below we're using the VideoPlayer struct that comes with SwiftUI and AVKit.

Similarly, the default player ExoPlayer on Android also supports HLS natively.

Next.js React example

If you're using Next.js or React for your application, the with-mux-video example is a good place to start.

npx create-next-app --example with-mux-video with-mux-video-app

android
html
react
swift
copy
implementation 'com.google.android.exoplayer:exoplayer-hls:2.X.X'

// Create a player instance.
SimpleExoPlayer player = new SimpleExoPlayer.Builder(context).build();
// Set the media item to be played.
player.setMediaItem(MediaItem.fromUri("https://stream.mux.com/{PLAYBACK_ID}.m3u8"));
// Prepare the player.
player.prepare();
4
Find a player
The examples below are meant to be a starting point. You are free to use any player that supports HLS with Mux videos. Here's some popular players that we have seen:

Mux Player
html
react
copy
<script src="https://cdn.jsdelivr.net/npm/@mux/mux-player"></script>

<mux-player
  playback-id="{PLAYBACK_ID}"
  metadata-video-title="Test video title"
  metadata-viewer-user-id="user-id-007"
></mux-player>
See the Mux Player guide for more details and configuration options.

Mux Video Element
If Mux Player does more than you're looking for, and you're interested in using something more like the native HTML5 <video> element for your web application, take a look at the <mux-video> element. The Mux Video Element is a drop-in replacement for the HTML5 <video> element, but it works with Mux and has Mux Data automatically configured.

HTML: Mux Video element
React: MuxVideo component
Popular web players
HLS.js is free and open source. This library does not have any UI components like buttons and controls. If you want to either use the HTML5 <video> element's default controls or build your own UI elements HLS.js will be a great choice.
Plyr.io is free and open source. Plyr has UI elements and controls that work with the underlying <video> element. Plyr does not support HLS by default, but it can be used with HLS.js. If you like the feel and theming capabilities of Plyr and want to use it with Mux videos, follow the example for using Plyr + HLS.js.
Video.js is a free and open source player. As of version 7 it supports HLS by default. The underlying HLS engine is videojs/http-streaming.
JWPlayer is a commercial player and supports HLS by default. The underlying HLS engine is HLS.js.
Brightcove Player is a commercial player built on Video.js and HLS is supported by default.
Bitmovin Player is a commercial player and supports HLS by default.
THEOplayer is a commercial player and supports HLS by default. The player chrome is built on Video.js, but the HLS engine is custom.
Agnoplay is a fully agnostic, cloud-based player solution for web, iOS and Android with full support for HLS.
Use Video.js with Mux
Video.js kit is a project built on Video.js with additional Mux specific functionality built in. This includes support for:

Enabling timeline hover previews
Mux Data integration
playback_id helper (we'll figure out the full playback URL for you)
For more details, head over to the Use Video.js with Mux page.

5
Advanced playback features
Playback with subtitles/closed captions
Subtitles/Closed Captions text tracks can be added to an asset either on asset creation or later when they are available. Mux supports SubRip Text (SRT) and Web Video Text Tracks format for ingesting Subtitles and Closed Captions text tracks. For more information on Subtitles/Closed Captions, see this blog post and the guide for subtitles.

Mux includes Subtitles/Closed Captions text tracks in HLS (.m3u8) for playback. Video Players show the presence of Subtitles/Closed Captions text tracks and the languages available as an option to enable/disable and to select a language. The player can also default to the viewer's device preferences.

HLS.js video player options menu for Subtitles/Closed Captions text track
HLS.js video player options menu for Subtitles/Closed Captions text track
If you are adding text tracks to your Mux videos, make sure you test them out with your player.

In addition, Mux also supports downloading of Subtitles/Closed Captions text tracks as "sidecar" files when downloading your videos.

copy
https://stream.mux.com/{PLAYBACK_ID}/text/{TRACK_ID}.vtt
Replace {PLAYBACK_ID} with your asset's playback ID and {TRACK_ID} with the unique identifier value returned when this subtitle/closed caption text track was added to this asset.

Add delivery redundancy with Redundant Streams
Mux Video streams are delivered using multiple CDNs. The best performing CDN is selected for the viewer initiating the playback. Video is then streamed by that CDN for that particular user. When the selected CDN has a transient or regional failure, the viewer's playback experience could be interrupted for the duration of the failure. If this happens your application should handle the playback failure and re-initiate the playback session. Mux Video's CDN selection logic would then select a different CDN for streaming.

The redundant streams modifier allows Mux to list each rendition for every CDN in the HLS manifest. The order is based on CDN performance with the best performing one listed first. If your video player supports redundant streams then the player will detect the failure mid-playback and switch to the next CDN on the list during a failure without interrupting the playback.

For more information on the Redundant Streams playback modifier and player support based on our tests, see this blog post.

To use this feature in your application add redundant_streams=true to the HLS URL:

copy
https://stream.mux.com/{PLAYBACK_ID}.m3u8?redundant_streams=true
Using redundant_streams with signed URLs
If you are using signed playback URLs make sure you include the extra parameter in your signed token.

This table shows the support of various video players for redundant streams. This table will be updated as more players are tested or updated. If your player isn't listed here, please reach out.



Below is one complete example of how you can integrate Mux into your Flutter project. This implementation shows how to wrap the native Mux Player SDK on Android with a Flutter widget so you can fetch and play videos from Mux. You can use the instructions from the mux_playback.md guide together with a Flutter screen (like video_feed_screen.dart) that shows each video in a PageView.

Below are the steps and example code:

---

### 1. Configure the Android Project

In your android/app/build.gradle file, add the Mux Player SDK dependency and (if needed) the Maven repository. For example:

```gradle
// In android/app/build.gradle
android {
  …
  buildTypes {
    release {
      minifyEnabled true
      shrinkResources true
      proguardFiles getDefaultProguardFile('proguard-android.txt'), 'proguard-rules.pro'
      ndk {
        abiFilters 'armeabi-v7a', 'arm64-v8a', 'x86_64'
      }
    }
    debug {
      minifyEnabled false
      shrinkResources false
    }
  }
}

dependencies {
  // ... other dependencies
  
  // Add the Mux Player SDK (check for the latest version)
  implementation("com.mux.player:android:1.0.0")
}
```

Also, be sure to add the Mux Maven repository in your project’s settings (or project-level build.gradle) per the [mux_playback.md](#mux_playback.md) instructions:

```gradle
// In your repositories block (settings.gradle or build.gradle)
maven {
  url = uri("https://muxinc.jfrog.io/artifactory/default-maven-release-local")
}
```

---

### 2. Create a Native Android Wrapper for Mux Player

Create a Kotlin class that implements a PlatformView wrapping the native Mux Player SDK. For example, create the file below in your Android module:

```kotlin
// android/app/src/main/kotlin/com/example/cursor_chat/MuxPlayerPlugin.kt
package com.example.cursor_chat

import android.content.Context
import android.view.View
import com.mux.player.android.MuxPlayer
import com.mux.player.android.MuxPlayerView
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory

class MuxPlayerPlugin : FlutterPlugin {
    private lateinit var channel: MethodChannel

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        // Create a MethodChannel if needed; for global operations use a channel named "mux_player"
        channel = MethodChannel(binding.binaryMessenger, "mux_player")
        channel.setMethodCallHandler(null)

        binding.platformViewRegistry.registerViewFactory(
            "mux_player_view",
            MuxPlayerFactory(binding.binaryMessenger)
        )
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }
}

class MuxPlayerFactory(private val messenger: BinaryMessenger) 
    : PlatformViewFactory(StandardMessageCodec.INSTANCE) {

    override fun create(context: Context, viewId: Int, args: Any?): PlatformView {
        return MuxPlayerViewWrapper(context, viewId, messenger)
    }
}

class MuxPlayerViewWrapper(
    private val context: Context,
    private val viewId: Int,
    messenger: BinaryMessenger
) : PlatformView, MethodChannel.MethodCallHandler {

    // Create the native MuxPlayerView. You can configure it further (custom controls, caching, etc.)
    private val muxPlayerView: MuxPlayerView = MuxPlayerView(context)
    private val methodChannel = MethodChannel(messenger, "mux_player_$viewId")

    init {
        methodChannel.setMethodCallHandler(this)
    }

    override fun getView(): View = muxPlayerView

    override fun dispose() {
        methodChannel.setMethodCallHandler(null)
        muxPlayerView.player?.release()
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "loadVideo" -> {
                val playbackId = call.argument<String>("playbackId")
                if (playbackId == null) {
                    result.error("MISSING_PLAYBACK_ID", "Playback ID is required", null)
                    return
                }
                try {
                    // Set the playbackId and prepare the player
                    muxPlayerView.playbackId = playbackId
                    muxPlayerView.player?.prepare()
                    result.success(null)
                } catch (e: Exception) {
                    result.error("LOAD_ERROR", "Failed to load video: ${e.message}", null)
                }
            }
            "play" -> {
                muxPlayerView.player?.play()
                result.success(null)
            }
            "pause" -> {
                muxPlayerView.player?.pause()
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }
}
```

This native wrapper uses the Mux Player SDK per the instructions in mux_playback.md to create and configure a MuxPlayer object. The Flutter side will then communicate with this native view using method calls (e.g. “loadVideo”).

---

### 3. Create a Flutter Widget to Wrap the Native View

Create a widget (for example, in lib/widgets/mux_player.dart) that uses an AndroidView to display the native player. You can also provide options such as playback ID, aspect ratio, autoplay, and looping.

```dart
// lib/widgets/mux_player.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class MuxPlayer extends StatefulWidget {
  final String playbackId;
  final double aspectRatio;
  final bool autoPlay;
  final bool looping;

  const MuxPlayer({
    Key? key,
    required this.playbackId,
    this.aspectRatio = 9 / 16,
    this.autoPlay = true,
    this.looping = true,
  }) : super(key: key);

  @override
  _MuxPlayerState createState() => _MuxPlayerState();
}

class _MuxPlayerState extends State<MuxPlayer> {
  late MethodChannel _channel;

  @override
  void initState() {
    super.initState();
    _initPlayer();
  }

  Future<void> _initPlayer() async {
    // If you need to do any global initialization, you can call methods via a channel here.
    // For example, you might want to call an 'initPlayer' method on the global channel.
    // await _channel.invokeMethod('initPlayer');
    if (widget.autoPlay) {
      loadVideo();
    }
  }

  Future<void> loadVideo() async {
    try {
      await _channel.invokeMethod('loadVideo', {
        'playbackId': widget.playbackId,
      });
    } catch (e) {
      print('Error loading video: $e');
    }
  }

  Future<void> play() async {
    try {
      await _channel.invokeMethod('play');
    } catch (e) {
      print('Error playing video: $e');
    }
  }

  Future<void> pause() async {
    try {
      await _channel.invokeMethod('pause');
    } catch (e) {
      print('Error pausing video: $e');
    }
  }

  @override
  void dispose() {
    // Optionally dispose the player on the native side
    _channel.invokeMethod('dispose');
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: widget.aspectRatio,
      child: AndroidView(
        viewType: 'mux_player_view',
        onPlatformViewCreated: (int id) {
          _channel = MethodChannel('mux_player_$id');
          // When the view is created, load the video.
          loadVideo();
        },
      ),
    );
  }
}
```

---

### 4. Use the MuxPlayer Widget in Your Video Feed Screen

Below is an example of how you might fetch the list of video playback IDs (using your Mux REST API credentials) and display them in a vertically scrolling PageView. This code goes inside your lib/screens/video_feed_screen.dart:

```dart
// lib/screens/video_feed_screen.dart
import 'package:flutter/material.dart';
import '../widgets/mux_player.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class VideoFeedScreen extends StatefulWidget {
  const VideoFeedScreen({Key? key}) : super(key: key);

  @override
  _VideoFeedScreenState createState() => _VideoFeedScreenState();
}

class _VideoFeedScreenState extends State<VideoFeedScreen> {
  final PageController _pageController = PageController();
  List<String> _playbackIds = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchMuxVideos();
  }

  Future<void> _fetchMuxVideos() async {
    try {
      final tokenId = dotenv.env['MUX_TOKEN_ID'];
      final tokenSecret = dotenv.env['MUX_TOKEN_SECRET'];
      final credentials = base64.encode(utf8.encode('$tokenId:$tokenSecret'));

      final response = await http.get(
        Uri.parse('https://api.mux.com/video/v1/assets'),
        headers: {
          'Authorization': 'Basic $credentials',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> assets = data['data'];
        setState(() {
          _playbackIds = assets
              .where((asset) => asset['status'] == 'ready')
              .map<String>((asset) => asset['playback_ids'][0]['id'].toString())
              .toList();
          _isLoading = false;
        });
        print('Fetched ${_playbackIds.length} videos from Mux');
      } else {
        throw Exception('Failed to load videos: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching Mux videos: $e');
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }
  
  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Text('Error: $_error', style: const TextStyle(color: Colors.red)),
        ),
      );
    }

    if (_playbackIds.isEmpty) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Text('No videos available', style: TextStyle(color: Colors.white)),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: PageView.builder(
        scrollDirection: Axis.vertical,
        controller: _pageController,
        itemCount: _playbackIds.length,
        itemBuilder: (context, index) {
          final playbackId = _playbackIds[index];
          return Stack(
            fit: StackFit.expand,
            children: [
              MuxPlayer(
                playbackId: playbackId,
                aspectRatio: 9 / 16,
                autoPlay: index == 0,
                looping: true,
              ),
              // Overlay for video title/description
              Positioned(
                left: 16,
                right: 16,
                bottom: 80,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Text(
                      'Video Title',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        shadows: [
                          Shadow(
                            blurRadius: 10.0,
                            color: Colors.black,
                            offset: Offset(2.0, 2.0),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Video Description',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        shadows: [
                          Shadow(
                            blurRadius: 10.0,
                            color: Colors.black,
                            offset: Offset(2.0, 2.0),
                          ),
                        ],
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
```

---

### Final Notes

• Make sure you have correctly configured your .env file (using flutter_dotenv) with your MUX_TOKEN_ID and MUX_TOKEN_SECRET so that the REST API call to fetch video assets is authenticated.

• Test your native integration first to make sure the Android side loads and plays the video using the native Mux Player SDK. Then verify that the Flutter widget calls over the MethodChannel correctly.

• You can extend this solution by adding play/pause controls or integrating error handling in both the native and Flutter code.

This complete implementation should let you fetch Mux video assets and play them in a Flutter PageView using a custom MuxPlayer widget. Adjust the code as needed for your specific use case and design.
