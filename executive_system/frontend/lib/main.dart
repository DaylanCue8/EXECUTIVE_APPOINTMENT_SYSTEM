import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart'; 
import 'firebase_options.dart'; // 1. CRITICAL: Import your options file
import 'login_page.dart';

void main() async {
  // 2. Ensures Flutter framework is ready
  WidgetsFlutterBinding.ensureInitialized();

  try {
    // 3. FIX: Pass the options parameter here. 
    // This stops the "FirebaseOptions cannot be null" error.
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    print("Firebase Initialized Successfully ✅");
  } catch (e) {
    print("Firebase Initialization Error: $e");
  }

  runApp(const ExecutiveApp());
}

class ExecutiveApp extends StatelessWidget {
  const ExecutiveApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Executive Management System',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      // Ensure LoginPage is imported correctly from your login_page.dart
      home: LoginPage(),
    );
  }
}