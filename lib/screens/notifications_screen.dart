import 'package:flutter/material.dart';
import '../models/notification.dart' as app;
import '../services/notification_service.dart';
import '../services/project_service.dart';
import 'project_details_screen.dart';
import '../widgets/app_bottom_navigation.dart';

class NotificationsScreen extends StatelessWidget {
  final NotificationService _notificationService = NotificationService();
  final ProjectService _projectService = ProjectService();

  NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          IconButton(
            icon: const Icon(Icons.done_all),
            onPressed: () => _notificationService.markAllAsRead(),
            tooltip: 'Mark all as read',
          ),
        ],
      ),
      body: StreamBuilder<List<app.Notification>>(
        stream: _notificationService.getNotifications(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text('Error: ${snapshot.error}'),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          final notifications = snapshot.data ?? [];

          if (notifications.isEmpty) {
            return const Center(
              child: Text('No notifications'),
            );
          }

          return ListView.builder(
            itemCount: notifications.length,
            itemBuilder: (context, index) {
              final notification = notifications[index];
              return NotificationTile(notification: notification);
            },
          );
        },
      ),
      bottomNavigationBar: AppBottomNavigation(currentIndex: 2),
    );
  }
}

class NotificationTile extends StatelessWidget {
  final app.Notification notification;
  final NotificationService _notificationService = NotificationService();
  final ProjectService _projectService = ProjectService();

  NotificationTile({
    super.key,
    required this.notification,
  });

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: Key(notification.id),
      background: Container(
        color: Colors.red,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => _notificationService.deleteNotification(notification.id),
      child: ListTile(
        title: Text(
          notification.title,
          style: TextStyle(
            fontWeight: notification.isRead ? FontWeight.normal : FontWeight.bold,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(notification.message),
            Text(
              _getTimeAgo(notification.createdAt),
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 12,
              ),
            ),
          ],
        ),
        leading: Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: notification.isRead ? Colors.transparent : Colors.blue,
          ),
        ),
        onTap: () async {
          _notificationService.markAsRead(notification.id);
          if (notification.projectId != null) {
            try {
              final project = await _projectService.getProject(notification.projectId!);
              if (project != null && context.mounted) {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => ProjectDetailsScreen(
                      project: project,
                    ),
                  ),
                );
              }
            } catch (e) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Error loading project: ${e.toString()}'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            }
          }
        },
      ),
    );
  }

  String _getTimeAgo(DateTime dateTime) {
    final difference = DateTime.now().difference(dateTime);
    
    if (difference.inDays > 365) {
      return '${(difference.inDays / 365).floor()}y ago';
    } else if (difference.inDays > 30) {
      return '${(difference.inDays / 30).floor()}mo ago';
    } else if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'just now';
    }
  }
} 