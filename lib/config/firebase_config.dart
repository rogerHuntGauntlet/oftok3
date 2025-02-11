import 'package:flutter/foundation.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_core/firebase_core.dart';

class FirebaseConfig {
  static bool useEmulator = false;

  static Future<void> initialize() async {
    if (useEmulator) {
      try {
        FirebaseFunctions.instance.useFunctionsEmulator('localhost', 5001);
      } catch (e) {
        print('Failed to configure functions emulator: $e');
      }
    }
  }
} 