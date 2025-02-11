import 'package:flutter/material.dart';
import 'dart:math' as math;

class SplashScreen extends StatefulWidget {
  final VoidCallback onComplete;

  const SplashScreen({super.key, required this.onComplete});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  late final AnimationController _rotationController;
  late final AnimationController _pulseController;
  late final AnimationController _colorController;
  late final AnimationController _scaleController;
  
  final List<Color> _psychedelicColors = [
    const Color(0xFFFF1493), // Deep Pink
    const Color(0xFF00FF00), // Electric Lime
    const Color(0xFFFF4500), // Orange Red
    const Color(0xFF4B0082), // Indigo
    const Color(0xFFFF00FF), // Magenta
    const Color(0xFF00FFFF), // Cyan
  ];

  @override
  void initState() {
    super.initState();
    
    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _colorController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();

    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..forward().then((_) => widget.onComplete());

    // Add some wild particle effects
    _setupParticles();
  }

  void _setupParticles() {
    for (int i = 0; i < 20; i++) {
      _particles.add(
        ParticleData(
          position: Offset(
            math.Random().nextDouble() * 400,
            math.Random().nextDouble() * 400,
          ),
          velocity: Offset(
            math.Random().nextDouble() * 2 - 1,
            math.Random().nextDouble() * 2 - 1,
          ),
          color: _psychedelicColors[
            math.Random().nextInt(_psychedelicColors.length)
          ],
          size: math.Random().nextDouble() * 10 + 5,
        ),
      );
    }
  }

  final List<ParticleData> _particles = [];

  @override
  void dispose() {
    _rotationController.dispose();
    _pulseController.dispose();
    _colorController.dispose();
    _scaleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Psychedelic background
          AnimatedBuilder(
            animation: _colorController,
            builder: (context, child) {
              return CustomPaint(
                painter: PsychedelicBackgroundPainter(
                  colors: _psychedelicColors,
                  progress: _colorController.value,
                ),
                size: Size.infinite,
              );
            },
          ),
          
          // Floating particles
          ...List.generate(_particles.length, (index) {
            return AnimatedBuilder(
              animation: _pulseController,
              builder: (context, child) {
                _particles[index].update();
                return Positioned(
                  left: _particles[index].position.dx,
                  top: _particles[index].position.dy,
                  child: Container(
                    width: _particles[index].size * _pulseController.value,
                    height: _particles[index].size * _pulseController.value,
                    decoration: BoxDecoration(
                      color: _particles[index].color.withOpacity(0.6),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: _particles[index].color.withOpacity(0.3),
                          blurRadius: 10,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          }),
          
          // Main logo/text
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Rotating and pulsing logo
                AnimatedBuilder(
                  animation: Listenable.merge([_rotationController, _pulseController, _scaleController]),
                  builder: (context, child) {
                    return Transform.scale(
                      scale: _scaleController.value * (1 + _pulseController.value * 0.2),
                      child: Transform.rotate(
                        angle: _rotationController.value * 2 * math.pi,
                        child: Container(
                          width: 150,
                          height: 150,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: SweepGradient(
                              colors: _psychedelicColors,
                              transform: GradientRotation(_rotationController.value * 2 * math.pi),
                            ),
                            boxShadow: [
                              for (var color in _psychedelicColors)
                                BoxShadow(
                                  color: color.withOpacity(0.5),
                                  blurRadius: 20,
                                  spreadRadius: 2,
                                ),
                            ],
                          ),
                          child: Center(
                            child: Text(
                              'OHF',
                              style: TextStyle(
                                fontSize: 48,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                shadows: [
                                  for (var color in _psychedelicColors)
                                    Shadow(
                                      color: color,
                                      blurRadius: 20,
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 40),
                // Animated text
                AnimatedBuilder(
                  animation: _scaleController,
                  builder: (context, child) {
                    return Opacity(
                      opacity: _scaleController.value,
                      child: Transform.scale(
                        scale: _scaleController.value,
                        child: const Text(
                          'Get Ready to Create',
                          style: TextStyle(
                            fontSize: 24,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 2,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ParticleData {
  Offset position;
  Offset velocity;
  final Color color;
  final double size;

  ParticleData({
    required this.position,
    required this.velocity,
    required this.color,
    required this.size,
  });

  void update() {
    position += velocity;
    // Bounce off screen edges
    if (position.dx < 0 || position.dx > 400) velocity = Offset(-velocity.dx, velocity.dy);
    if (position.dy < 0 || position.dy > 400) velocity = Offset(velocity.dx, -velocity.dy);
  }
}

class PsychedelicBackgroundPainter extends CustomPainter {
  final List<Color> colors;
  final double progress;

  PsychedelicBackgroundPainter({required this.colors, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) * 0.8;

    for (int i = 0; i < colors.length; i++) {
      final path = Path();
      final startAngle = (i / colors.length + progress) * 2 * math.pi;
      final sweepAngle = 2 * math.pi / colors.length;
      
      path.moveTo(center.dx, center.dy);
      path.arcTo(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        false,
      );
      path.lineTo(center.dx, center.dy);
      
      paint.shader = RadialGradient(
        colors: [colors[i], colors[i].withOpacity(0)],
        stops: const [0.5, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: radius));
      
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant PsychedelicBackgroundPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
} 