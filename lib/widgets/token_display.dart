import 'package:flutter/material.dart';
import '../models/app_user.dart';
import '../services/user_service.dart';

class TokenDisplay extends StatelessWidget {
  final UserService userService;

  const TokenDisplay({
    super.key,
    required this.userService,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<AppUser?>(
      future: userService.getCurrentUser(),
      builder: (context, snapshot) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.token, size: 14),
              const SizedBox(width: 4),
              Text(
                '${snapshot.data?.tokens ?? 0}',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
} 