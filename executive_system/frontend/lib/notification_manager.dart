import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:flutter/foundation.dart';

class NotificationItem {
  final String title;
  final String body;
  final DateTime timestamp;

  NotificationItem({
    required this.title,
    required this.body,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
        'title': title,
        'body': body,
        'timestamp': timestamp.toIso8601String(),
      };

  factory NotificationItem.fromJson(Map<String, dynamic> json) => NotificationItem(
        title: json['title'],
        body: json['body'],
        timestamp: DateTime.parse(json['timestamp']),
      );
}

class NotificationManager {
  static const String _key = 'notifications';
  static const int _maxNotifications = 50;

  static final ValueNotifier<int> unreadCountNotifier = ValueNotifier<int>(0);

  static Future<void> addNotification(String title, String body) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> stored = prefs.getStringList(_key) ?? [];

    NotificationItem newNotif = NotificationItem(
      title: title,
      body: body,
      timestamp: DateTime.now(),
    );

    stored.insert(0, jsonEncode(newNotif.toJson()));

    if (stored.length > _maxNotifications) {
      stored = stored.sublist(0, _maxNotifications);
    }

    await prefs.setStringList(_key, stored);
    _updateUnreadCount();
  }

  static Future<List<NotificationItem>> getNotifications() async {
    final prefs = await SharedPreferences.getInstance();
    List<String> stored = prefs.getStringList(_key) ?? [];

    return stored.map((s) => NotificationItem.fromJson(jsonDecode(s))).toList();
  }

  static Future<int> getUnreadCount() async {
    final notifs = await getNotifications();
    return notifs.length;
  }

  static Future<void> _updateUnreadCount() async {
    final count = await getUnreadCount();
    unreadCountNotifier.value = count;
  }

  static Future<void> clearNotifications() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
    unreadCountNotifier.value = 0;
  }

  // Call this on app start to initialize the count
  static Future<void> initialize() async {
    await _updateUnreadCount();
  }
}