import 'dart:async';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/foundation.dart';

class AppCheckService {
  static final AppCheckService _instance = AppCheckService._internal();
  factory AppCheckService() => _instance;
  AppCheckService._internal();

  bool _isInitialized = false;

  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      await FirebaseAppCheck.instance.activate(
        androidProvider: AndroidProvider.playIntegrity,
        appleProvider: AppleProvider.appAttest,
      );
      print('App Check initialized successfully');
      _isInitialized = true;
    } catch (e) {
      print('Error initializing App Check: $e');
      rethrow; // In production, we want to know if App Check fails
    }
  }

  Future<String?> getToken({bool forceRefresh = false}) async {
    try {
      if (!_isInitialized) {
        await initialize();
      }
      return await FirebaseAppCheck.instance.getToken(forceRefresh);
    } catch (e) {
      print('Error getting App Check token: $e');
      rethrow; // In production, we want to handle these errors properly
    }
  }
} 