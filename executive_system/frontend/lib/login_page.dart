import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'register_page.dart';
import 'dashboard_page.dart';

class LoginPage extends StatefulWidget {
  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _userController = TextEditingController();
  final TextEditingController _passController = TextEditingController();
  bool _isObscured = true;
  bool _rememberMe = false;

  // Colors from the reference image
  final Color _asanaTeal = const Color(0xFF14C6B1);
  final Color _inputBg = const Color(0xFFF4F7F9);
  final String apiUrl = "http://192.168.254.101:5000";

  Future<void> loginUser() async {
    try {
      final response = await http.post(
        Uri.parse("$apiUrl/login"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "username": _userController.text,
          "password": _passController.text,
        }),
      );

      if (response.statusCode == 200) {
        var data = jsonDecode(response.body);
        String role = data['user']['role'];
        String fullName = data['user']['full_name'];
        int userId = data['user']['id'];

        // FCM Logic
        try {
          FirebaseMessaging messaging = FirebaseMessaging.instance;
          await messaging.requestPermission(alert: true, badge: true, sound: true);
          String? token = await messaging.getToken();
          if (token != null) {
            await http.post(
              Uri.parse("$apiUrl/update_token"),
              headers: {"Content-Type": "application/json"},
              body: jsonEncode({"user_id": userId, "fcm_token": token}),
            );
          }
        } catch (e) { print("FCM Error: $e"); }

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => DashboardPage(role: role, name: fullName, userId: userId)),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Invalid Credentials")));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Connection Error")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _asanaTeal,
      body: Stack(
        children: [
          // 1. Teal Header & Illustration
          Column(
            children: [
              const SizedBox(height: 60),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(child: Image.asset('assets/welcome_il.png', height: 180)),
                    const SizedBox(height: 20),
                    const Text(
                      "Log in to stay on\ntop of your tasks\nand projects.",
                      style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold, height: 1.2),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // 2. White Login Card
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              height: MediaQuery.of(context).size.height * 0.58,
              width: double.infinity,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(topLeft: Radius.circular(30), topRight: Radius.circular(30)),
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    const Text("Login", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text("Don't Have An Account? ", style: TextStyle(color: Colors.grey)),
                        GestureDetector(
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => RegisterPage())),
                          child: Text("Sign Up", style: TextStyle(color: _asanaTeal, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 25),

                    // Username Field
                    _buildDesignField(
                      controller: _userController,
                      hint: "Username",
                      icon: Icons.person_outline,
                    ),
                    const SizedBox(height: 15),

                    // Password Field
                    _buildDesignField(
                      controller: _passController,
                      hint: "Password",
                      icon: Icons.lock_outline,
                      isPassword: true,
                    ),

                    // Remember Me & Forgot Password
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Checkbox(
                              value: _rememberMe,
                              onChanged: (v) => setState(() => _rememberMe = v!),
                              activeColor: _asanaTeal,
                            ),
                            const Text("Remember Me", style: TextStyle(color: Colors.grey, fontSize: 13)),
                          ],
                        ),
                        TextButton(
                          onPressed: () {},
                          child: Text("Forgot Password?", style: TextStyle(color: _asanaTeal, fontSize: 13)),
                        )
                      ],
                    ),

                    const SizedBox(height: 10),

                    // Login Button
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: loginUser,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _asanaTeal,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 0,
                        ),
                        child: const Text("Login", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                    ),

                    const SizedBox(height: 20),
                    const Text("Or Continue With", style: TextStyle(color: Colors.grey, fontSize: 12)),
                    const SizedBox(height: 15),

                    // Social Buttons
                    Row(
                      children: [
                        Expanded(child: _buildSocialBtn("Apple", "assets/apple_logo.png", Colors.black, Colors.white)),
                        const SizedBox(width: 12),
                        Expanded(child: _buildSocialBtn("Google", "assets/google_logo.png", Colors.white, Colors.black, border: true)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDesignField({required TextEditingController controller, required String hint, required IconData icon, bool isPassword = false}) {
    return Container(
      decoration: BoxDecoration(color: _inputBg, borderRadius: BorderRadius.circular(12)),
      child: TextField(
        controller: controller,
        obscureText: isPassword ? _isObscured : false,
        decoration: InputDecoration(
          border: InputBorder.none,
          hintText: hint,
          prefixIcon: Icon(icon, color: Colors.grey, size: 20),
          suffixIcon: isPassword 
            ? IconButton(
                icon: Icon(_isObscured ? Icons.visibility_off : Icons.visibility, color: Colors.grey, size: 20),
                onPressed: () => setState(() => _isObscured = !_isObscured),
              ) 
            : null,
          contentPadding: const EdgeInsets.symmetric(vertical: 15),
        ),
      ),
    );
  }

  Widget _buildSocialBtn(String label, String asset, Color bg, Color text, {bool border = false}) {
    return Container(
      height: 45,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: border ? Border.all(color: Colors.grey.shade300) : null,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.asset(asset, height: 18),
          const SizedBox(width: 8),
          Text(label, style: TextStyle(color: text, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}