import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart'; 
import 'package:shared_preferences/shared_preferences.dart'; // Add this
import 'firebase_options.dart'; 
import 'login_page.dart';
import 'dashboard_page.dart'; // Ensure this is imported

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    print("Firebase Initialized Successfully ✅");
  } catch (e) {
    print("Firebase Initialization Error: $e");
  }

  // --- SESSION CHECK LOGIC ---
  SharedPreferences prefs = await SharedPreferences.getInstance();
  bool isLoggedIn = prefs.getBool('isLoggedIn') ?? false;
  String? role = prefs.getString('role');
  String? name = prefs.getString('fullName');
  int? userId = prefs.getInt('userId');

  runApp(ExecutiveApp(
    isLoggedIn: isLoggedIn, 
    role: role, 
    name: name, 
    userId: userId
  ));
}

class ExecutiveApp extends StatelessWidget {
  final bool isLoggedIn;
  final String? role;
  final String? name;
  final int? userId;

  const ExecutiveApp({
    super.key, 
    required this.isLoggedIn, 
    this.role, 
    this.name, 
    this.userId
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Executive Management System',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF14C6B1)),
        useMaterial3: true,
      ),
      // If logged in, go to Dashboard. Otherwise, go to Login.
      home: isLoggedIn 
          ? DashboardPage(role: role!, name: name!, userId: userId!) 
          : LoginPage(),
    );
  }
}