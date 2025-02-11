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

class VideoGenerationDialog extends StatefulWidget {
  final Function(String)? onVideoGenerated;

  const VideoGenerationDialog({Key? key, this.onVideoGenerated}) : super(key: key);

  @override
  _VideoGenerationDialogState createState() => _VideoGenerationDialogState();
}

class _VideoGenerationDialogState extends State<VideoGenerationDialog> with SingleTickerProviderStateMixin {
  final _speechToText = SpeechToText();
  final _userService = UserService();
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  bool _isLoading = false;
  bool _isListening = false;
  bool _speechInitialized = false;
  bool _isInitializing = false;
  String _voiceTranscript = '';
  String _errorMessage = '';
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
          listenFor: Duration(seconds: 300), // Increased to 5 minutes
          pauseFor: Duration(seconds: 3),
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

  Future<void> _generateVideo() async {
    if (_voiceTranscript.isEmpty) {
      _safeSetState(() {
        _errorMessage = 'Please record your video description first';
      });
      return;
    }

    _safeSetState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final videoService = VideoGenerationService();
      print('Calling video generation API...');
      
      final result = await videoService.generateVideo(_voiceTranscript);
      print('API call completed');

      if (result['success'] == true) {
        final videoUrl = result['videoUrl'] as String;
        final remaining = result['remainingToday'];
        
        if (_mounted && mounted) {
          Navigator.of(context).pop();
          if (widget.onVideoGenerated != null) {
            widget.onVideoGenerated!(videoUrl);
          }
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Video generated successfully! $remaining generations remaining today.'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        throw Exception(result['error'] ?? 'Unknown error occurred');
      }
    } catch (e) {
      print('Error generating video: $e');
      String errorMessage = e.toString();
      
      if (errorMessage.contains('API key not found')) {
        errorMessage = 'API key not configured. Please check your environment setup.';
      }
      
      _safeSetState(() {
        _errorMessage = errorMessage;
      });
      
      if (_mounted && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to generate video: $errorMessage'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      _safeSetState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Generate Video',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.token, size: 14),
                        const SizedBox(width: 4),
                        Text(
                          '${_currentUser?.tokens ?? 0}',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onPrimaryContainer,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (_currentUser != null && _currentUser!.tokens < 250)
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.errorContainer.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Theme.of(context).colorScheme.error.withOpacity(0.5),
                    ),
                  ),
                  child: Column(
                    children: [
                      Text(
                        'Insufficient tokens (${_currentUser?.tokens ?? 0}/250)',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ElevatedButton.icon(
                        onPressed: () {
                          Navigator.of(context).pop(); // Close current dialog
                          showDialog(
                            context: context,
                            builder: (context) => const TokenPurchaseDialog(),
                          );
                        },
                        icon: const Icon(Icons.shopping_cart, size: 18),
                        label: const Text('Buy Tokens'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(context).colorScheme.error,
                          foregroundColor: Theme.of(context).colorScheme.onError,
                        ),
                      ),
                    ],
                  ),
                ),
              Text(
                'Tap the microphone to start recording, tap again to stop. AI will generate a video based on your description.',
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              if (_errorMessage.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Icon(Icons.error_outline, color: Colors.red, size: 16),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _errorMessage,
                              style: TextStyle(color: Colors.red, fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                      if (_errorMessage.contains('permission'))
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: ElevatedButton(
                            onPressed: _requestMicrophonePermission,
                            child: Text('Grant Permission'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              if (_errorMessage.isNotEmpty) const SizedBox(height: 20),
              if (_isInitializing)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Initializing speech recognition...',
                        style: TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),
              if (_isInitializing) const SizedBox(height: 20),
              if (_isListening)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.red),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Recording...',
                        style: TextStyle(color: Colors.red),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 20),
              GestureDetector(
                onTap: _toggleRecording,
                child: AnimatedBuilder(
                  animation: _pulseAnimation,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: _isListening ? _pulseAnimation.value : 1.0,
                      child: Container(
                        padding: EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _isListening ? Colors.red : Theme.of(context).primaryColor,
                          boxShadow: _isListening
                            ? [
                                BoxShadow(
                                  color: Colors.red.withOpacity(0.3),
                                  blurRadius: 10,
                                  spreadRadius: 2,
                                ),
                              ]
                            : null,
                        ),
                        child: Icon(
                          _isListening ? Icons.mic : Icons.mic_none,
                          color: Colors.white,
                          size: 32,
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 20),
              if (_voiceTranscript.isNotEmpty) ...[
                Text(
                  'Your recording:',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.grey[300]!,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _voiceTranscript,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      if (_isListening) ...[
                        SizedBox(height: 8),
                        Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: Colors.green,
                                shape: BoxShape.circle,
                              ),
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Listening...',
                              style: TextStyle(
                                color: Colors.green,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 20),
              _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ElevatedButton(
                    onPressed: (_currentUser?.tokens ?? 0) < 250 || _voiceTranscript.isEmpty ? null : _generateVideo,
                    child: const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Text('Generate Video'),
                    ),
                  ),
            ],
          ),
        ),
      ),
    );
  }
} 