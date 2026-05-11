import 'package:flutter/material.dart';
import 'notification_manager.dart';

class NotificationsPage extends StatefulWidget {
  @override
  _NotificationsPageState createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  List<NotificationItem> notifications = [];

  @override
  void initState() {
    super.initState();
    _loadNotifications();
    // Mark as read when viewing
    NotificationManager.unreadCountNotifier.value = 0;
  }

  Future<void> _loadNotifications() async {
    final notifs = await NotificationManager.getNotifications();
    setState(() => notifications = notifs);
  }

  Future<void> _clearAll() async {
    await NotificationManager.clearNotifications();
    setState(() => notifications = []);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Notifications cleared')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
        actions: [
          if (notifications.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear_all),
              onPressed: _clearAll,
              tooltip: 'Clear all',
            ),
        ],
      ),
      body: notifications.isEmpty
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.notifications_none, size: 48, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('No notifications yet', style: TextStyle(color: Colors.grey)),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: notifications.length,
              itemBuilder: (context, index) {
                final notif = notifications[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: Color(0xFF14C6B1),
                      child: Icon(Icons.notifications, color: Colors.white),
                    ),
                    title: Text(notif.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(notif.body),
                        const SizedBox(height: 4),
                        Text(
                          _formatTimestamp(notif.timestamp),
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inDays > 0) {
      return '${difference.inDays} day${difference.inDays > 1 ? 's' : ''} ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hour${difference.inHours > 1 ? 's' : ''} ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minute${difference.inMinutes > 1 ? 's' : ''} ago';
    } else {
      return 'Just now';
    }
  }
}