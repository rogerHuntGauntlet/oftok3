import 'package:flutter/material.dart';

class SocialStat extends StatelessWidget {
  final IconData icon;
  final int? count;
  final String label;
  final Color color;
  final bool isActive;

  const SocialStat({
    super.key,
    required this.icon,
    this.count,
    required this.label,
    required this.color,
    this.isActive = false,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<int>(
      tween: IntTween(begin: 0, end: count ?? 0),
      duration: const Duration(milliseconds: 500),
      builder: (context, value, child) {
        return Column(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isActive ? color.withOpacity(0.1) : Colors.transparent,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: isActive ? color : Colors.grey,
                size: 24,
              ),
            ),
            const SizedBox(height: 4),
            if (count != null) ...[
              Text(
                value.toString(),
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: isActive ? color : null,
                ),
              ),
            ],
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: isActive ? color : Colors.grey,
              ),
            ),
          ],
        );
      },
    );
  }
} 