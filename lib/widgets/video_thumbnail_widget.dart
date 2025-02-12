import 'package:flutter/material.dart';
import 'dart:math' as math;

class VideoThumbnailWidget extends StatelessWidget {
  final double size;
  final String title;
  final int seed;

  const VideoThumbnailWidget({
    Key? key, 
    required this.title,
    this.size = 1080,
    this.seed = 0,
  }) : super(key: key);

  static const List<Color> psychedelicColors = [
    Color(0xFFFF1493), // Deep Pink
    Color(0xFF00FF00), // Electric Lime
    Color(0xFFFF4500), // Orange Red
    Color(0xFF4B0082), // Indigo
    Color(0xFFFF00FF), // Magenta
    Color(0xFF00FFFF), // Cyan
  ];

  List<Color> _getRotatedColors() {
    final rotatedColors = List<Color>.from(psychedelicColors);
    // Rotate colors based on seed
    for (int i = 0; i < seed % psychedelicColors.length; i++) {
      rotatedColors.add(rotatedColors.removeAt(0));
    }
    return rotatedColors;
  }

  @override
  Widget build(BuildContext context) {
    final rotatedColors = _getRotatedColors();
    final random = math.Random(seed);
    final rotation = random.nextDouble() * 2 * math.pi;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.black87, Colors.black54],
        ),
      ),
      child: Stack(
        children: [
          // Background gradient circles
          ...List.generate(3, (index) {
            final position = random.nextDouble();
            final scale = 0.5 + random.nextDouble() * 0.5;
            return Positioned(
              left: size * (random.nextDouble() * 0.7),
              top: size * (random.nextDouble() * 0.7),
              child: Container(
                width: size * scale,
                height: size * scale,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: SweepGradient(
                    colors: rotatedColors,
                    transform: GradientRotation(rotation + (index * math.pi / 4)),
                  ),
                ),
              ),
            );
          }),

          // Darkening overlay
          Container(
            color: Colors.black54,
          ),

          // Title text
          Center(
            child: Padding(
              padding: EdgeInsets.all(size * 0.1),
              child: Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: size * 0.08,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  shadows: rotatedColors.map((color) => Shadow(
                    color: color,
                    blurRadius: size * 0.02,
                    offset: Offset(size * 0.01, size * 0.01),
                  )).toList(),
                ),
              ),
            ),
          ),

          // OHF watermark
          Positioned(
            right: size * 0.05,
            bottom: size * 0.05,
            child: Text(
              'OHF',
              style: TextStyle(
                fontSize: size * 0.06,
                fontWeight: FontWeight.bold,
                color: Colors.white.withOpacity(0.3),
              ),
            ),
          ),
        ],
      ),
    );
  }
} 