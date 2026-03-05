import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:fsi_courier_app/view/Dashboard/dashboard_page.dart';
import '../../../components/styled_text_box.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LoginCard extends StatefulWidget {
  const LoginCard({super.key});

  @override
  State<LoginCard> createState() => _LoginCardState();
}

class _LoginCardState extends State<LoginCard> {
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController pinController = TextEditingController();
  bool isLoading = false;

  Future<void> loginUser() async {
    setState(() => isLoading = true);

    final url = Uri.parse(
      'https://staging-gdtms-v2.skyward.com.ph/api/mbl/login',
    );

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          "phone_number": phoneController.text.trim(),
          "password": pinController.text.trim(),
        }),
      );

      print("LOGIN RESPONSE: ${response.body}"); // 👈 For debugging

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        // SAVE TOKEN CORRECTLY
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString("auth_token", data["data"]["token"]);

        // ✅ Set expiry 24 hours from now
        final expiry = DateTime.now().add(const Duration(hours: 24));
        await prefs.setString("auth_token_expiry", expiry.toIso8601String());

        // Navigate to Dashboard
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const DashboardPage()),
        );
      } else {
        final err = jsonDecode(response.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(err["message"] ?? "Login failed")),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error: $e")));
    }

    setState(() => isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Transform.translate(
      offset: const Offset(0, -40),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.12),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const _LogoSection(),
              const SizedBox(height: 24),
              _InputSection(
                phoneController: phoneController,
                pinController: pinController,
              ),
              const SizedBox(height: 12),
              _LoginButton(isLoading: isLoading, onLogin: loginUser),
            ],
          ),
        ),
      ),
    );
  }
}

class _LogoSection extends StatelessWidget {
  const _LogoSection();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Image.asset('assets/logo.png', height: 60),
        const SizedBox(height: 8),
        const Text(
          'Courier App',
          style: TextStyle(
            fontSize: 16,
            color: Colors.black87,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _InputSection extends StatelessWidget {
  final TextEditingController phoneController;
  final TextEditingController pinController;

  const _InputSection({
    required this.phoneController,
    required this.pinController,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        StyledTextBox(
          label: 'Mobile Number',
          keyboardType: TextInputType.phone,
          controller: phoneController,
        ),
        const SizedBox(height: 16),
        StyledTextBox(
          label: 'Password',
          obscureText: true,
          keyboardType: TextInputType.text,
          controller: pinController,
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: () {},
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              minimumSize: const Size(0, 0),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text(
              'Forgot Password?',
              style: TextStyle(color: Colors.blueAccent, fontSize: 13),
            ),
          ),
        ),
      ],
    );
  }
}

class _LoginButton extends StatelessWidget {
  final bool isLoading;
  final VoidCallback onLogin;

  const _LoginButton({required this.isLoading, required this.onLogin});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 44,
      child: ElevatedButton(
        onPressed: isLoading ? null : onLogin,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF2E7D32),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        child: isLoading
            ? const CircularProgressIndicator(color: Colors.white)
            : const Text(
                'Login',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
      ),
    );
  }
}
