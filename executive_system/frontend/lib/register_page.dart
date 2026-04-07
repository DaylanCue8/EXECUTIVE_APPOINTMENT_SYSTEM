import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class RegisterPage extends StatefulWidget {
  @override
  _RegisterPageState createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final TextEditingController _userController = TextEditingController();
  final TextEditingController _passController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  
  String _selectedRole = 'requester';
  bool _isObscured = true;

  // --- SYNCED COLORS WITH LOGIN PAGE ---
  final Color _asanaTeal = const Color(0xFF14C6B1);
  final Color _inputBg = const Color(0xFFF4F7F9);

  final String apiUrl = "http://192.168.254.101:5000/register";

  Future<void> registerUser() async {
    if (_userController.text.isEmpty || _passController.text.isEmpty || _nameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please fill all fields")));
      return;
    }

    try {
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "username": _userController.text,
          "password": _passController.text,
          "full_name": _nameController.text,
          "role": _selectedRole,
        }),
      );

      if (response.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: const Text("Registration Successful!"), backgroundColor: _asanaTeal),
        );
        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Registration Failed")));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Connection Error")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _asanaTeal, // Same background color as Login
      body: Stack(
        children: [
          // Header Section
          Column(
            children: [
              const SizedBox(height: 60),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(child: Image.asset('assets/welcome_il.png', height: 160, fit: BoxFit.contain)),
                    const SizedBox(height: 20),
                    const Text(
                      "Create Your Account and\nSimplify Your Workday",
                      style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold, height: 1.2),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // White Form Card
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              height: MediaQuery.of(context).size.height * 0.65,
              width: double.infinity,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(topLeft: Radius.circular(30), topRight: Radius.circular(30)),
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    // New Logo
                    Image.asset('assets/portal_logo.png', height: 35),
                    const SizedBox(height: 8),
                    const Text("Sign up", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                    
                    const SizedBox(height: 20),

                    _buildDesignField(controller: _nameController, hint: "Full Name", icon: Icons.person_outline),
                    const SizedBox(height: 12),
                    _buildDesignField(controller: _userController, hint: "Username (Email Address)", icon: Icons.alternate_email),
                    const SizedBox(height: 12),
                    _buildDesignField(controller: _passController, hint: "Password", icon: Icons.lock_outline, isPassword: true),
                    const SizedBox(height: 12),

                    // Role Selection
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(color: _inputBg, borderRadius: BorderRadius.circular(12)),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          isExpanded: true,
                          value: _selectedRole,
                          items: ['boss', 'secretary', 'requester'].map((role) {
                            return DropdownMenuItem(value: role, child: Text(role.toUpperCase(), style: const TextStyle(color: Colors.grey, fontSize: 14)));
                          }).toList(),
                          onChanged: (val) => setState(() => _selectedRole = val!),
                        ),
                      ),
                    ),

                    const SizedBox(height: 15),

                    // Register Button
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: registerUser,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _asanaTeal,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 0,
                        ),
                        child: const Text("REGISTER NOW", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                    ),

                    const SizedBox(height: 20),
                    const Text("Or Continue With", style: TextStyle(color: Colors.grey, fontSize: 12)),
                    const SizedBox(height: 15),

                    // Social Buttons (using Expanded to prevent overflow)
                    Row(
                      children: [
                        Expanded(child: _buildSocialBtn("Apple", "assets/apple_logo.png", Colors.black, Colors.white)),
                        const SizedBox(width: 12),
                        Expanded(child: _buildSocialBtn("Google", "assets/google_logo.png", Colors.white, Colors.black, border: true)),
                      ],
                    ),

                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text("Already Have An Account? "),
                        GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: Text("Sign in", style: TextStyle(fontWeight: FontWeight.bold, color: _asanaTeal)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          
          // Back Button
          Positioned(
            top: 40,
            left: 10,
            child: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
              onPressed: () => Navigator.pop(context),
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
          Text(label, style: TextStyle(color: text, fontWeight: FontWeight.bold, fontSize: 13)),
        ],
      ),
    );
  }
}