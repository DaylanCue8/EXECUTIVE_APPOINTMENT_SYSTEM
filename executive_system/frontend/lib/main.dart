import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart'; // Add this
import 'package:shared_preferences/shared_preferences.dart';
import 'firebase_options.dart';
import 'login_page.dart';
import 'dashboard_page.dart';

// 1. BACKGROUND MESSAGE HANDLER
// This handles notifications when the app is completely closed.
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  print("Handling a background message: ${message.messageId}");
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    
    // Set background handler
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // Request permissions for iOS/Android 13+
    FirebaseMessaging messaging = FirebaseMessaging.instance;
    await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    print("Firebase Initialized Successfully ✅");
  } catch (e) {
    print("Firebase Initialization Error: $e");
  }

  // Session Check
  SharedPreferences prefs = await SharedPreferences.getInstance();
  bool isLoggedIn = prefs.getBool('isLoggedIn') ?? false;
  String? role = prefs.getString('role');
  String? name = prefs.getString('fullName');
  int? userId = prefs.getInt('userId');

  runApp(ExecutiveApp(
    isLoggedIn: isLoggedIn,
    role: role,
    name: name,
    userId: userId,
  ));
}

class ExecutiveApp extends StatefulWidget {
  final bool isLoggedIn;
  final String? role;
  final String? name;
  final int? userId;

  const ExecutiveApp({
    super.key,
    required this.isLoggedIn,
    this.role,
    this.name,
    this.userId,
  });

  @override
  State<ExecutiveApp> createState() => _ExecutiveAppState();
}

class _ExecutiveAppState extends State<ExecutiveApp> {
  
  @override
  void initState() {
    super.initState();

    // 2. FOREGROUND MESSAGE LISTENER
    // This shows a popup if the notification arrives while you are using the app.
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      if (message.notification != null) {
        _showInAppNotification(
          message.notification!.title ?? "Notification",
          message.notification!.body ?? "",
        );
      }
    });
  }

  void _showInAppNotification(String title, String body) {
    // This shows a "Snack-bar" style notification inside the app
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
            Text(body),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF14C6B1),
        duration: const Duration(seconds: 5),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Executive Management System',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF14C6B1)),
        useMaterial3: true,
      ),
      home: widget.isLoggedIn
          ? DashboardPage(
              role: widget.role!, 
              name: widget.name!, 
              userId: widget.userId!
            )
          : LoginPage(),
    );
  }
}