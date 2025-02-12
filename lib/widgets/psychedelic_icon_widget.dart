import 'package:flutter/material.dart';
import 'dart:math' as math;

class PsychedelicIconWidget extends StatelessWidget {
  final GlobalKey repaintKey;
  final double size;

  const PsychedelicIconWidget({
    Key? key, 
    required this.repaintKey,
    this.size = 1024, // Default size for app icon
  }) : super(key: key);

  static const List<Color> psychedelicColors = [
    Color(0xFFFF1493), // Deep Pink
    Color(0xFF00FF00), // Electric Lime
    Color(0xFFFF4500), // Orange Red
    Color(0xFF4B0082), // Indigo
    Color(0xFFFF00FF), // Magenta
    Color(0xFF00FFFF), // Cyan
  ];

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      key: repaintKey,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const SweepGradient(
            colors: psychedelicColors,
            transform: GradientRotation(0), // Static rotation for the icon
          ),
          boxShadow: psychedelicColors.map((color) => BoxShadow(
            color: color.withOpacity(0.5),
            blurRadius: size * 0.133, // 20 when size is 150
            spreadRadius: size * 0.013, // 2 when size is 150
          )).toList(),
        ),
        child: Center(
          child: Text(
            'OHF',
            style: TextStyle(
              fontSize: size * 0.32, // 48 when size is 150
              fontWeight: FontWeight.bold,
              color: Colors.white,
              shadows: psychedelicColors.map((color) => Shadow(
                color: color,
                blurRadius: size * 0.133, // 20 when size is 150
              )).toList(),
            ),
          ),
        ),
      ),
    );
  }
} 