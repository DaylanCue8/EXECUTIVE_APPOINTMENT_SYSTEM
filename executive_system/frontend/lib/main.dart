import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'firebase_options.dart';
import 'login_page.dart';
import 'dashboard_page.dart';
import 'api_config.dart';
import 'notification_manager.dart';
import 'notification_service.dart'; // ✅ ADDED
import 'chat_page.dart';
import 'app_theme.dart';

final GlobalKey<ScaffoldMessengerState> snackbarKey = GlobalKey<ScaffoldMessengerState>();
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
    
    await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
      alert: true, badge: true, sound: true,
    );

    // Request notification permissions
    await NotificationService.initialize();
  } catch (e) {
    debugPrint("Firebase Init Error: $e");
  }

  // Initialize notification manager
  await NotificationManager.initialize();

  SharedPreferences prefs = await SharedPreferences.getInstance();
  bool isLoggedIn = prefs.getBool('isLoggedIn') ?? false;
  String role = prefs.getString('role') ?? "requester";
  String name = prefs.getString('fullName') ?? "User";
  int userId = prefs.getInt('userId') ?? 0;

  runApp(ExecutiveApp(
    isLoggedIn: isLoggedIn && userId != 0,
    role: role,
    name: name,
    userId: userId,
  ));
}

class ExecutiveApp extends StatefulWidget {
  final bool isLoggedIn;
  final String role;
  final String name;
  final int userId;

  const ExecutiveApp({
    super.key,
    required this.isLoggedIn,
    required this.role,
    required this.name,
    required this.userId,
  });

  @override
  State<ExecutiveApp> createState() => _ExecutiveAppState();
}

class _ExecutiveAppState extends State<ExecutiveApp> {
  @override
  void initState() {
    super.initState();
    
    if (widget.isLoggedIn) {
      _refreshFCMToken();
      FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpenedApp);
      FirebaseMessaging.instance.getInitialMessage().then((message) {
        if (message != null) {
          _handleMessageOpenedApp(message);
        }
      });
    }

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      if (message.notification != null) {
        String title = message.notification!.title!;
        String body = message.notification!.body!;
        NotificationManager.addNotification(title, body); // ✅ SAVE NOTIFICATION
        _showInAppNotification(title, body);
      }
    });
  }

  Future<void> _refreshFCMToken() async {
    try {
      String? token = await FirebaseMessaging.instance.getToken();
      if (token != null) {
        await http.post(
          Uri.parse(ApiConfig.updateToken), // ✅ CHANGED
          headers: {"Content-Type": "application/json"},
          body: jsonEncode({"user_id": widget.userId, "fcm_token": token}),
        );
      }
    } catch (e) {
      debugPrint("Token refresh failed: $e");
    }
  }

  void _showInAppNotification(String title, String body) {
    snackbarKey.currentState?.showSnackBar(
      SnackBar(
        content: Text("$title: $body"),
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.accent,
      ),
    );
  }

  void _handleMessageOpenedApp(RemoteMessage message) {
    final type = message.data['type'];
    if (type != 'chat') return;

    final appointmentId = int.tryParse(message.data['appointment_id']?.toString() ?? '');
    final receiverId = int.tryParse(message.data['sender_id']?.toString() ?? '');
    final appointmentTitle = message.data['sender_name']?.toString() ?? message.notification?.title ?? 'Chat';

    if (appointmentId == null || receiverId == null) return;

    navigatorKey.currentState?.push(
      MaterialPageRoute(
        builder: (_) => ChatPage(
          appointmentId: appointmentId,
          senderId: widget.userId,
          receiverId: receiverId,
          appointmentTitle: appointmentTitle,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      scaffoldMessengerKey: snackbarKey,
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: AppColors.secondary,
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.primaryDark,
          foregroundColor: AppColors.onPrimary,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
        ),
        cardTheme: CardThemeData(
          color: AppColors.secondary,
          elevation: 6,
          shadowColor: Colors.black.withAlpha((0.12 * 255).round()),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.accent,
            foregroundColor: AppColors.onSecondary,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            elevation: 4,
            textStyle: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: AppColors.surface,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 18, horizontal: 18),
        ),
      ),
      home: widget.isLoggedIn
          ? DashboardPage(role: widget.role, name: widget.name, userId: widget.userId)
          : LoginPage(),
    );
  }
}