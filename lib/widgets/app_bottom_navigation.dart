import 'package:flutter/material.dart';
import '../models/app_user.dart';
import '../services/user_service.dart';
import '../screens/projects_screen.dart';
import '../screens/project_network_screen.dart';
import '../screens/notifications_screen.dart';
import './token_purchase_dialog.dart';

class AppBottomNavigation extends StatelessWidget {
  final int currentIndex;
  final UserService _userService = UserService();

  AppBottomNavigation({
    super.key,
    required this.currentIndex,
  });

  void _navigateToScreen(BuildContext context, int index) {
    if (currentIndex == index) return;

    Widget screen;
    switch (index) {
      case 0:
        screen = const ProjectsScreen();
        break;
      case 1:
        screen = const ProjectNetworkScreen();
        break;
      case 2:
        screen = NotificationsScreen();
        break;
      default:
        return;
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => screen),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BottomAppBar(
      shape: const CircularNotchedRectangle(),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          // Projects Tab
          IconButton(
            icon: Icon(
              Icons.folder,
              color: currentIndex == 0 ? Theme.of(context).colorScheme.primary : null,
            ),
            onPressed: () => _navigateToScreen(context, 0),
            tooltip: 'Projects',
          ),
          // Network Tab
          IconButton(
            icon: Icon(
              Icons.people,
              color: currentIndex == 1 ? Theme.of(context).colorScheme.primary : null,
            ),
            onPressed: () => _navigateToScreen(context, 1),
            tooltip: 'Network',
          ),
          // Spacer for FAB
          const SizedBox(width: 40),
          // Notifications Tab
          IconButton(
            icon: Icon(
              Icons.notifications,
              color: currentIndex == 2 ? Theme.of(context).colorScheme.primary : null,
            ),
            onPressed: () => _navigateToScreen(context, 2),
            tooltip: 'Notifications',
          ),
          // Buy Tokens Button
          FutureBuilder<AppUser?>(
            future: _userService.getCurrentUser(),
            builder: (context, snapshot) {
              return IconButton(
                icon: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    const Icon(Icons.token),
                    if (snapshot.hasData)
                      Positioned(
                        right: -8,
                        top: -4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.primary,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${snapshot.data?.tokens ?? 0}',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onPrimary,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (context) => const TokenPurchaseDialog(),
                  );
                },
                tooltip: 'Buy Tokens',
              );
            },
          ),
        ],
      ),
    );
  }
} 