import 'package:flutter/material.dart';
import 'notification_manager.dart';
import 'notifications_page.dart';

class NotificationIcon extends StatefulWidget {
  @override
  _NotificationIconState createState() => _NotificationIconState();
}

class _NotificationIconState extends State<NotificationIcon> {
  @override
  void initState() {
    super.initState();
    // Listen to changes in unread count
    NotificationManager.unreadCountNotifier.addListener(_onUnreadCountChanged);
  }

  @override
  void dispose() {
    NotificationManager.unreadCountNotifier.removeListener(_onUnreadCountChanged);
    super.dispose();
  }

  void _onUnreadCountChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final unreadCount = NotificationManager.unreadCountNotifier.value;

    return Stack(
      children: [
        IconButton(
          icon: const Icon(Icons.notifications_outlined),
          onPressed: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => NotificationsPage()),
            );
            // Refresh count after viewing (in case they cleared)
            // But since we listen to notifier, it should update automatically
          },
        ),
        if (unreadCount > 0)
          Positioned(
            right: 8,
            top: 8,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(10),
              ),
              constraints: const BoxConstraints(
                minWidth: 16,
                minHeight: 16,
              ),
              child: Text(
                unreadCount > 99 ? '99+' : unreadCount.toString(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }
}