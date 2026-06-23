import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/app_theme.dart';
import 'home_shell.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _loading = false;
  bool _obscure = true;
  String? _error;

  static const _demoEmail = 'demo@gymgeek.app';
  static const _demoPass = 'gymgeek123';

  @override
  void initState() {
    super.initState();
    _passCtrl.addListener(() {
      if (_error != null && _passCtrl.text.length >= 4) {
        setState(() => _error = null);
      }
    });
  }

  Future<void> _login() async {
    final email = _emailCtrl.text.trim();
    final pass = _passCtrl.text;

    if (email.isEmpty) {
      setState(() => _error = 'Please enter your email.');
      return;
    }
    if (pass.isEmpty) {
      setState(() => _error = 'Please enter your password.');
      return;
    }
    if (pass.length < 4) {
      setState(() => _error = 'Password must be at least 4 characters.');
      return;
    }

    setState(() { _loading = true; _error = null; });

    // Simulate authentication service call (SUC1)
    try {
      await Future.delayed(const Duration(milliseconds: 800))
          .timeout(const Duration(seconds: 10));
    } on TimeoutException {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Connection timeout. Please try again.';
      });
      return;
    }

    if (!mounted) return;

    // Only the demo account is valid (SUC1: validate credentials)
    final valid = email == _demoEmail && pass == _demoPass;

    if (valid) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_email', email);
      await prefs.setBool('is_logged_in', true);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const HomeShell()),
      );
    } else {
      setState(() { _loading = false; _error = 'Incorrect username or password.'; });
    }
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: MediaQuery.of(context).size.height
                  - MediaQuery.of(context).padding.top
                  - MediaQuery.of(context).padding.bottom,
            ),
            child: IntrinsicHeight(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 60),
                  // Logo: "Gym" red + strikethrough "G" + "eek"
                  RichText(
                    text: const TextSpan(
                      style: TextStyle(fontSize: 40, fontWeight: FontWeight.bold),
                      children: [
                        TextSpan(text: 'Gym', style: TextStyle(color: AppColors.primary)),
                        TextSpan(text: 'G', style: TextStyle(
                          color: AppColors.textPrimary,
                          decoration: TextDecoration.lineThrough,
                          decorationColor: AppColors.primary,
                          decorationThickness: 3,
                        )),
                        TextSpan(text: 'eek', style: TextStyle(color: AppColors.textPrimary)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text('AI-Intensive Fitness Guidance',
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 15)),
                  const SizedBox(height: 48),
                  const Text('Sign in', style: TextStyle(
                      color: AppColors.textPrimary, fontSize: 24, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  const Text('Use demo@gymgeek.app / gymgeek123',
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                  const SizedBox(height: 28),
                  TextField(
                    controller: _emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    style: const TextStyle(color: AppColors.textPrimary),
                    decoration: const InputDecoration(
                      hintText: 'Email',
                      prefixIcon: Icon(Icons.mail_outline, color: AppColors.textSecondary),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _passCtrl,
                    obscureText: _obscure,
                    style: const TextStyle(color: AppColors.textPrimary),
                    decoration: InputDecoration(
                      hintText: 'Password',
                      prefixIcon: const Icon(Icons.lock_outline, color: AppColors.textSecondary),
                      suffixIcon: IconButton(
                        icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility,
                            color: AppColors.textSecondary),
                        onPressed: () => setState(() => _obscure = !_obscure),
                      ),
                    ),
                    onSubmitted: (_) => _login(),
                  ),
                  AnimatedSize(
                    duration: const Duration(milliseconds: 200),
                    child: _error != null
                        ? Padding(
                            padding: const EdgeInsets.only(top: 10),
                            child: Row(children: [
                              const Icon(Icons.error_outline, color: Colors.red, size: 15),
                              const SizedBox(width: 6),
                              Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 13)),
                            ]),
                          )
                        : const SizedBox.shrink(),
                  ),
                  const SizedBox(height: 28),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _loading ? null : _login,
                      child: _loading
                          ? const SizedBox(width: 22, height: 22,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Text('Sign In',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const Spacer(),
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.only(bottom: 20, top: 40),
                      child: Text(
                        'GymGeek • Engineering of AI-Intensive Systems\nJeronim Bašić & Beibarys Abissatov',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
