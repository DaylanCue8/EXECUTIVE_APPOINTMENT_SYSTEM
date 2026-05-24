import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'app_theme.dart';
import 'api_config.dart';

class RegisterPage extends StatefulWidget {
  @override
  _RegisterPageState createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final TextEditingController _userController = TextEditingController();
  final TextEditingController _passController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();

  bool _isObscured = true;
  bool _isLoading = false;

  final Color _navy = AppColors.primary;
  final Color _navyLight = AppColors.primaryLight;
  final Color _gold = AppColors.accent;
  final Color _border = AppColors.border;
  final Color _hint = AppColors.hint;

  Future<void> registerUser() async {
    if (_nameController.text.isEmpty ||
        _userController.text.isEmpty ||
        _passController.text.isEmpty) {
      _showSnackBar("Please fill all fields", AppColors.error);
      return;
    }

    if (_passController.text.length < 6) {
      _showSnackBar("Password must be at least 6 characters", AppColors.warning);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final response = await http.post(
        Uri.parse(ApiConfig.register),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "username": _userController.text.trim(),
          "password": _passController.text,
          "full_name": _nameController.text.trim(),
        }),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 201) {
        _showSnackBar("Account created successfully!", _gold);
        if (mounted) Navigator.pop(context);
      } else {
        final error = jsonDecode(response.body);
        _showSnackBar(error['error'] ?? "Registration failed", AppColors.error);
      }
    } catch (e) {
      _showSnackBar("Connection error. Is the server running?", AppColors.error);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
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
            colors: [AppColors.primary, AppColors.primaryDark],
          ),
        ),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // TOP HEADER
              Padding(
                padding: const EdgeInsets.fromLTRB(28, 24, 28, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.white.withOpacity(0.2)),
                        ),
                        child: const Icon(
                          Icons.arrow_back_ios_new_rounded,
                          color: Colors.white70,
                          size: 16,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
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
                        Icons.person_add_alt_1_rounded,
                        color: Color(0xFF1D2939),
                        size: 24,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      "Create account",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      "Join and manage your appointments",
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
                    color: AppColors.secondary.withOpacity(0.08),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(32),
                      topRight: Radius.circular(32),
                    ),
                    border: Border.all(color: AppColors.secondary.withOpacity(0.08)),
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
                        _buildLabel("FULL NAME"),
                        const SizedBox(height: 8),
                        _buildInputField(
                          controller: _nameController,
                          hint: "Your full name",
                          icon: Icons.person_outline_rounded,
                        ),
                        const SizedBox(height: 16),

                        _buildLabel("USERNAME"),
                        const SizedBox(height: 8),
                        _buildInputField(
                          controller: _userController,
                          hint: "Choose a username",
                          icon: Icons.alternate_email_rounded,
                        ),
                        const SizedBox(height: 16),

                        _buildLabel("PASSWORD"),
                        const SizedBox(height: 8),
                        _buildInputField(
                          controller: _passController,
                          hint: "Min. 6 characters",
                          icon: Icons.lock_outline_rounded,
                          isPassword: true,
                        ),
                        const SizedBox(height: 28),

                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : registerUser,
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
                                    "CREATE ACCOUNT",
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
                                "Already have an account? ",
                                style: TextStyle(color: _hint, fontSize: 13),
                              ),
                              GestureDetector(
                                onTap: () => Navigator.pop(context),
                                child: Text(
                                  "Sign in",
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