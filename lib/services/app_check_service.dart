import 'dart:async';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/foundation.dart';

class AppCheckService {
  static final AppCheckService _instance = AppCheckService._internal();
  factory AppCheckService() => _instance;
  AppCheckService._internal();

  bool _isInitialized = false;
  static const String _debugToken = 'YOUR-DEBUG-TOKEN'; // Replace with your debug token

  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // In debug mode, set up debug token
      if (kDebugMode) {
        await FirebaseAppCheck.instance.setTokenAutoRefreshEnabled(true);
        await FirebaseAppCheck.instance.activate(
          androidProvider: AndroidProvider.debug,
          appleProvider: AppleProvider.debug,
        );
        print('App Check initialized in debug mode');
      } else {
        // In release mode, use proper attestation
        await FirebaseAppCheck.instance.setTokenAutoRefreshEnabled(true);
        await FirebaseAppCheck.instance.activate(
          androidProvider: AndroidProvider.playIntegrity,
          appleProvider: AppleProvider.deviceCheck,
          webProvider: ReCaptchaV3Provider('YOUR-RECAPTCHA-SITE-KEY'), // Only if you need web support
        );
        print('App Check initialized in release mode');
      }

      // Set up token listener for debugging
      FirebaseAppCheck.instance.onTokenChange.listen((token) {
        if (token != null) {
          print('App Check token refreshed: ${token.substring(0, 5)}...'); // Only log first 5 chars for security
        }
      });

      _isInitialized = true;
    } catch (e, stackTrace) {
      print('Error initializing App Check: $e');
      print('Stack trace: $stackTrace');
      // In debug mode, we'll try to continue without App Check
      if (kDebugMode) {
        print('Continuing without App Check in debug mode');
        _isInitialized = true;
        return;
      }
      rethrow;
    }
  }

  Future<String?> getToken({bool forceRefresh = false}) async {
    try {
      if (!_isInitialized) {
        await initialize();
      }
      
      final token = await FirebaseAppCheck.instance.getToken(forceRefresh);
      if (token != null) {
        print('Successfully obtained App Check token: ${token.substring(0, 5)}...'); // Only log first 5 chars
      }
      return token;
    } catch (e, stackTrace) {
      print('Error getting App Check token: $e');
      print('Stack trace: $stackTrace');
      if (kDebugMode) {
        print('Returning debug token in debug mode');
        return _debugToken;
      }
      rethrow;
    }
  }

  Future<void> refreshToken() async {
    try {
      if (!_isInitialized) {
        await initialize();
      }
      final token = await FirebaseAppCheck.instance.getToken(true);
      if (token != null) {
        print('App Check token refreshed successfully');
      }
    } catch (e) {
      print('Error refreshing App Check token: $e');
      rethrow;
    }
  }
} 