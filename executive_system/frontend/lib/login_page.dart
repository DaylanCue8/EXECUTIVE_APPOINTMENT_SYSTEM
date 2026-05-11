import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'register_page.dart';
import 'dashboard_page.dart';
import 'api_config.dart';

class LoginPage extends StatefulWidget {
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _userController = TextEditingController();
  final TextEditingController _passController = TextEditingController();

  bool _isObscured = true;
  bool _rememberMe = false;
  bool _isLoading = false;

  final Color _navy = const Color(0xFF1D2939);
  final Color _navyLight = const Color(0xFF263347);
  final Color _gold = const Color(0xFFC9A84C);
  final Color _border = const Color(0xFF334155);
  final Color _hint = const Color(0xFF8A9AB0);

  Future<void> loginUser() async {
    if (_userController.text.isEmpty || _passController.text.isEmpty) {
      _showSnackBar("Please fill in all fields");
      return;
    }

    setState(() => _isLoading = true);

    try {
      final response = await http.post(
        Uri.parse(ApiConfig.login),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "username": _userController.text.trim(),
          "password": _passController.text,
        }),
      ).timeout(const Duration(seconds: 10));

      if (!mounted) return;

      if (response.statusCode == 200) {
        var data = jsonDecode(response.body);

        String role = data['user']['role'];
        String fullName = data['user']['full_name'];
        int userId = data['user']['id'];

        SharedPreferences prefs = await SharedPreferences.getInstance();
        await prefs.setBool('isLoggedIn', true);
        await prefs.setString('role', role);
        await prefs.setString('fullName', fullName);
        await prefs.setInt('userId', userId);

        await _updateFCMToken(userId);

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => DashboardPage(
              role: role,
              name: fullName,
              userId: userId,
            ),
          ),
        );
      } else {
        _showSnackBar("Invalid username or password");
      }
    } catch (e) {
      _showSnackBar("Connection error. Is the server running?");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _updateFCMToken(int userId) async {
    try {
      FirebaseMessaging messaging = FirebaseMessaging.instance;
      String? token = await messaging.getToken();
      if (token != null) {
        await http.post(
          Uri.parse(ApiConfig.updateToken),
          headers: {"Content-Type": "application/json"},
          body: jsonEncode({"user_id": userId, "fcm_token": token}),
        );
      }
    } catch (e) {
      debugPrint("FCM Sync Error: $e");
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF10203A), Color(0xFF152A44)],
          ),
        ),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // TOP HEADER
              Padding(
                padding: const EdgeInsets.fromLTRB(28, 32, 28, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: _gold,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: _gold.withOpacity(0.25),
                            blurRadius: 18,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.business_center_rounded,
                        color: Color(0xFF1D2939),
                        size: 26,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      "EXECUTIVE SYSTEM",
                      style: TextStyle(
                        color: _gold,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      "Welcome back",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      "Sign in to manage meetings quickly",
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.8),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),

              // BOTTOM CARD
              Expanded(
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.08),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(32),
                      topRight: Radius.circular(32),
                    ),
                    border: Border.all(color: Colors.white.withOpacity(0.08)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.16),
                        blurRadius: 28,
                        offset: const Offset(0, -8),
                      ),
                    ],
                  ),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(28, 32, 28, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                      _buildLabel("USERNAME"),
                      const SizedBox(height: 8),
                      _buildInputField(
                        controller: _userController,
                        hint: "Enter your username",
                        icon: Icons.person_outline_rounded,
                      ),
                      const SizedBox(height: 16),

                      _buildLabel("PASSWORD"),
                      const SizedBox(height: 8),
                      _buildInputField(
                        controller: _passController,
                        hint: "••••••••",
                        icon: Icons.lock_outline_rounded,
                        isPassword: true,
                      ),
                      const SizedBox(height: 12),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              GestureDetector(
                                onTap: () => setState(() => _rememberMe = !_rememberMe),
                                child: Container(
                                  width: 16,
                                  height: 16,
                                  decoration: BoxDecoration(
                                    color: _rememberMe ? _gold : Colors.transparent,
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(
                                      color: _rememberMe ? _gold : _hint,
                                    ),
                                  ),
                                  child: _rememberMe
                                      ? Icon(Icons.check, size: 11, color: _navy)
                                      : null,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                "Remember me",
                                style: TextStyle(color: _hint, fontSize: 12),
                              ),
                            ],
                          ),
                          Text(
                            "Forgot password?",
                            style: TextStyle(color: _gold, fontSize: 12),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : loginUser,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _gold,
                            disabledBackgroundColor: _gold.withOpacity(0.5),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            elevation: 0,
                          ),
                          child: _isLoading
                              ? SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    color: _navy,
                                    strokeWidth: 2,
                                  ),
                                )
                              : Text(
                                  "SIGN IN",
                                  style: TextStyle(
                                    color: _navy,
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1.5,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      Center(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              "Don't have an account? ",
                              style: TextStyle(color: _hint, fontSize: 13),
                            ),
                            GestureDetector(
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => RegisterPage(),
                                ),
                              ),
                              child: Text(
                                "Create one",
                                style: TextStyle(
                                  color: _gold,
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: TextStyle(
        color: _hint,
        fontSize: 11,
        letterSpacing: 0.5,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool isPassword = false,
  }) {
    return TextField(
      controller: controller,
      obscureText: isPassword ? _isObscured : false,
      style: const TextStyle(color: Colors.white, fontSize: 14),
      decoration: InputDecoration(
        filled: true,
        fillColor: _navy.withOpacity(0.5),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        hintText: hint,
        hintStyle: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 13),
        prefixIcon: Icon(icon, color: Colors.white70, size: 20),
        suffixIcon: isPassword
            ? IconButton(
                icon: Icon(
                  _isObscured
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: Colors.white70,
                  size: 20,
                ),
                onPressed: () => setState(() => _isObscured = !_isObscured),
              )
            : null,
        contentPadding: const EdgeInsets.symmetric(vertical: 18),
      ),
    );
  }
}
