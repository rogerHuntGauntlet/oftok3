import 'package:flutter/material.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:permission_handler/permission_handler.dart';
import '../config/firebase_config.dart';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'dart:math';
import '../services/video_generation_service.dart';
import '../services/user_service.dart';
import '../models/app_user.dart';
import './token_purchase_dialog.dart';
import 'package:url_launcher/url_launcher.dart';

class VideoGenerationDialog extends StatefulWidget {
  final Function(String)? onVideoGenerated;

  const VideoGenerationDialog({Key? key, this.onVideoGenerated}) : super(key: key);

  @override
  _VideoGenerationDialogState createState() => _VideoGenerationDialogState();
}

class _VideoGenerationDialogState extends State<VideoGenerationDialog> with SingleTickerProviderStateMixin {
  final _speechToText = SpeechToText();
  final _userService = UserService();
  final _videoGenerationService = VideoGenerationService();
  
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  bool _isLoading = false;
  bool _isListening = false;
  bool _speechInitialized = false;
  bool _isInitializing = false;
  String _voiceTranscript = '';
  String _errorMessage = '';
  String _progressMessage = '';
  double _progressValue = 0.0;
  Timer? _initTimer;
  bool _mounted = true;
  AppUser? _currentUser;

  @override
  void initState() {
    super.initState();
    
    // Initialize pulse animation
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(
        parent: _pulseController,
        curve: Curves.easeInOut,
      ),
    );
    _pulseController.repeat(reverse: true);
    
    // Check permissions and initialize speech
    _checkPermissionsAndInit();
    
    // Load current user
    _loadCurrentUser();
  }

  @override
  void dispose() {
    _mounted = false;
    _pulseController.dispose();
    _speechToText.stop();
    _initTimer?.cancel();
    super.dispose();
  }

  void _safeSetState(VoidCallback fn) {
    if (_mounted && mounted) {
      setState(fn);
    }
  }

  Future<void> _loadCurrentUser() async {
    final user = await _userService.getCurrentUser();
    if (_mounted) {
      setState(() {
        _currentUser = user;
      });
    }
  }

  Future<void> _checkPermissionsAndInit() async {
    // Only check permissions if not already initialized
    if (_speechInitialized) return;
    
    final status = await Permission.microphone.status;
    
    if (status.isGranted) {
      _initSpeechWithRetry();
    } else if (status.isDenied || status.isPermanentlyDenied) {
      await _requestMicrophonePermission();
    }
  }

  Future<void> _requestMicrophonePermission() async {
    final status = await Permission.microphone.request();
    
    if (status.isGranted) {
      _safeSetState(() => _errorMessage = '');
      _initSpeechWithRetry();
    } else if (status.isPermanentlyDenied) {
      if (_mounted && mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('Microphone Permission Required'),
            content: Text('Please enable microphone access in settings to use voice recording.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Cancel'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  openAppSettings();
                },
                child: Text('Open Settings'),
              ),
            ],
          ),
        );
      }
    }
  }

  Future<void> _initSpeechWithRetry() async {
    int retryCount = 0;
    const maxRetries = 3;
    const retryDelay = Duration(seconds: 1);

    Future<void> tryInit() async {
      if (_speechInitialized || _isInitializing || !_mounted) return;
      
      _safeSetState(() {
        _isInitializing = true;
        _errorMessage = '';
      });
      
      try {
        final isAvailable = await _speechToText.initialize(
          onError: (error) {
            print('Speech recognition error: $error');
            _safeSetState(() {
              _errorMessage = 'Speech recognition error: ${error.errorMsg}';
              _isListening = false;
            });
          },
          onStatus: (status) {
            print('Speech recognition status: $status');
            if (status == 'notListening' || status == 'done') {
              _safeSetState(() => _isListening = false);
            }
          },
        );

        if (isAvailable) {
          _safeSetState(() {
            _speechInitialized = true;
            _isInitializing = false;
            _errorMessage = '';
          });
          return;
        } else {
          throw Exception('Speech recognition not available on this device');
        }
      } catch (e) {
        print('Error initializing speech: $e');
        if (retryCount < maxRetries && _mounted) {
          retryCount++;
          print('Retrying initialization (attempt $retryCount)');
          _initTimer?.cancel();
          _initTimer = Timer(retryDelay, tryInit);
        } else {
          _safeSetState(() {
            _errorMessage = 'Could not initialize speech recognition. Please check microphone permissions and try again.';
            _speechInitialized = false;
            _isInitializing = false;
          });
        }
      }
    }

    await tryInit();
  }

  void _toggleRecording() async {
    if (_isListening) {
      _stopListening();
    } else {
      print('Starting listening...');
      _safeSetState(() => _errorMessage = '');
      
      if (!_speechInitialized) {
        print('Speech not initialized, attempting initialization...');
        await _initSpeechWithRetry();
        
        if (!_speechInitialized) {
          print('Initialization failed, cannot start listening');
          _safeSetState(() {
            _errorMessage = 'Speech recognition not initialized. Please try again.';
          });
          return;
        }
      }

      _safeSetState(() => _isListening = true);
      try {
        print('Calling speech_to_text.listen()...');
        bool? success = await _speechToText.listen(
          onResult: (result) {
            print('Got speech result: ${result.recognizedWords}');
            _safeSetState(() {
              _voiceTranscript = result.recognizedWords;
              if (result.finalResult) {
                _isListening = false;
              }
            });
          },
          listenFor: Duration(seconds: 300), // 5 minutes max
          pauseFor: Duration(seconds: 10),   // Increased pause duration to 10 seconds
          partialResults: true,
          cancelOnError: true,
          listenMode: ListenMode.dictation,
        );

        print('Listen call result: $success');
        
        if (success == false) {
          _safeSetState(() {
            _isListening = false;
            _errorMessage = 'Failed to start listening. Please try again.';
          });
        }
      } catch (e) {
        print('Error starting speech recognition: $e');
        _safeSetState(() {
          _isListening = false;
          _errorMessage = 'Could not start listening. Please check microphone permissions and try again.';
        });
      }
    }
  }

  void _stopListening() {
    print('Stopping listening...');
    if (_speechToText.isListening) {
      _speechToText.stop();
    }
    _safeSetState(() => _isListening = false);
  }

  void _showTokenPurchaseDialog() {
    showDialog(
      context: context,
      builder: (context) => TokenPurchaseDialog(),
    );
  }

  Future<void> _generateVideo(String prompt) async {
    if (_currentUser == null) {
      setState(() {
        _errorMessage = 'Please sign in to generate videos';
      });
      return;
    }

    if (_currentUser!.tokens < 250) {
      setState(() {
        _errorMessage = 'Not enough tokens. You need 250 tokens to generate a video.';
      });
      _showTokenPurchaseDialog();
      return;
    }

    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Video Generation'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('You currently have ${_currentUser!.tokens} tokens.'),
            const SizedBox(height: 16),
            const Text('Generating a video will cost 250 tokens.'),
            const SizedBox(height: 16),
            Text(
              'After generation, you will have ${_currentUser!.tokens - 250} tokens remaining.',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Generate Video'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() {
      _isLoading = true;
      _errorMessage = '';
      _progressMessage = 'Starting video generation...';
      _progressValue = 0.0;
    });

    try {
      final result = await _videoGenerationService.generateVideo(
        prompt,
        onProgress: (status, progress) {
          if (!mounted) return;
          setState(() {
            switch (status) {
              case VideoGenerationStatus.starting:
                _progressMessage = 'Starting video generation...';
                break;
              case VideoGenerationStatus.processing:
                _progressMessage = 'Processing video...';
                break;
              case VideoGenerationStatus.failed:
                _progressMessage = 'Generation failed';
                break;
              case VideoGenerationStatus.succeeded:
                _progressMessage = 'Generation complete!';
                break;
            }
            _progressValue = progress;
          });
        },
        onError: (error) {
          if (!mounted) return;
          setState(() {
            _errorMessage = error;
          });
        },
      );

      if (!mounted) return;

      // Deduct tokens regardless of moderation result
      await _userService.deductTokens(_currentUser!.id, 250);
      await _loadCurrentUser();

      // Check if content was moderated
      if (result['isModeratedContent'] == true) {
        // Show moderation message and prepare for rick roll
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: const Text('Content Moderation'),
            content: const Text(
              'Your prompt has been flagged by our content moderation system. '
              'Please ensure your content follows our community guidelines.'
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  // Launch rick roll
                  launchUrl(
                    Uri.parse(result['rickRollUrl']),
                    mode: LaunchMode.externalApplication,
                  );
                  // Close the generation dialog
                  Navigator.of(context).pop();
                },
                child: const Text('I Understand'),
              ),
            ],
          ),
        );
        return;
      }
      
      if (result['videoId'] != null) {
        await _userService.addGeneratedVideo(_currentUser!.id, result['videoId']);
      }
      
      widget.onVideoGenerated?.call(result['videoUrl']);
      
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Generate AI Video',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),
            if (_isLoading) ...[
              // Progress indicator section
              Column(
                children: [
                  LinearProgressIndicator(
                    value: _progressValue,
                    backgroundColor: Colors.grey[200],
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Theme.of(context).primaryColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _progressMessage,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  if (_errorMessage.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        _errorMessage,
                        style: TextStyle(color: Colors.red),
                        textAlign: TextAlign.center,
                      ),
                    ),
                ],
              ),
            ] else ...[
              // Voice input section
              Text(
                'Speak your video prompt',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 16),
              if (_voiceTranscript.isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: Text(
                    _voiceTranscript,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
                const SizedBox(height: 16),
              ],
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  IconButton(
                    onPressed: _toggleRecording,
                    icon: AnimatedBuilder(
                      animation: _pulseAnimation,
                      builder: (context, child) {
                        return Transform.scale(
                          scale: _isListening ? _pulseAnimation.value : 1.0,
                          child: Icon(
                            _isListening ? Icons.mic : Icons.mic_none,
                            color: _isListening ? Colors.red : null,
                            size: 32,
                          ),
                        );
                      },
                    ),
                  ),
                  ElevatedButton(
                    onPressed: _voiceTranscript.isNotEmpty ? () => _generateVideo(_voiceTranscript) : null,
                    child: Text('Generate Video'),
                  ),
                ],
              ),
              if (_errorMessage.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    _errorMessage,
                    style: TextStyle(color: Colors.red),
                    textAlign: TextAlign.center,
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
} 