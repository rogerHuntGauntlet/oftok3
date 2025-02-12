import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:flutter/material.dart';

/// Captures a widget wrapped in a RepaintBoundary and returns the image as PNG bytes.
Future<Uint8List> capturePsychedelicIcon(GlobalKey key, {double pixelRatio = 3.0}) async {
  // Retrieve the RenderRepaintBoundary by key
  final boundary = key.currentContext?.findRenderObject() as RenderRepaintBoundary?;
  if (boundary == null) {
    throw Exception("No render boundary found. Is the key attached to a widget?");
  }
  
  // Convert the boundary to an image
  final ui.Image image = await boundary.toImage(pixelRatio: pixelRatio);
  final ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
  if (byteData == null) {
    throw Exception("Failed to convert image to PNG bytes.");
  }
  
  return byteData.buffer.asUint8List();
} 