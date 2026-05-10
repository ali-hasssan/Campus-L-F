import 'package:flutter/material.dart';
import '../main.dart';
import '../services/firebase_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _form = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _obscure = true;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    final user = await FirebaseService.signIn(
      _emailCtrl.text.trim(),
      _passCtrl.text,
    );
    if (user == null) {
      setState(() {
        _loading = false;
        _error = 'Invalid email or password.';
      });
      return;
    }

    if (!mounted) return;
    setState(() => _loading = false);
    Navigator.pushReplacementNamed(
        context, user.profileComplete ? '/home' : '/profile-setup');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 64),
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: AppTheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.manage_search_rounded,
                    color: AppTheme.primary, size: 30),
              ),
              const SizedBox(height: 24),
              const Text('Welcome back 👋',
                  style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.txtPri)),
              const SizedBox(height: 6),
              const Text('Sign in to your account',
                  style: TextStyle(fontSize: 15, color: AppTheme.txtSec)),
              const SizedBox(height: 40),
              Form(
                key: _form,
                child: Column(
                  children: [
                    TextFormField(
                      controller: _emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        hintText: 'Email address',
                        prefixIcon: Icon(Icons.mail_outline_rounded),
                      ),
                      validator: (v) => v == null || !v.contains('@')
                          ? 'Enter a valid email'
                          : null,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _passCtrl,
                      obscureText: _obscure,
                      decoration: InputDecoration(
                        hintText: 'Password',
                        prefixIcon: const Icon(Icons.lock_outline_rounded),
                        suffixIcon: IconButton(
                          icon: Icon(_obscure
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined),
                          onPressed: () => setState(() => _obscure = !_obscure),
                        ),
                      ),
                      validator: (v) =>
                          v == null || v.length < 6 ? 'Min 6 characters' : null,
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      _ErrorBox(_error!),
                    ],
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: _loading ? null : _login,
                      child: _loading ? const _Loader() : const Text('Sign In'),
                    ),
                    const SizedBox(height: 20),
                    _AuthLink(
                      prefix: "Don't have an account? ",
                      linkText: 'Sign Up',
                      onTap: () => Navigator.pushNamed(context, '/signup'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Shared small widgets
class _ErrorBox extends StatelessWidget {
  final String message;
  const _ErrorBox(this.message);
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppTheme.lost.withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppTheme.lost.withOpacity(0.3)),
        ),
        child: Row(children: [
          const Icon(Icons.error_outline_rounded,
              color: AppTheme.lost, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(message,
                style: const TextStyle(color: AppTheme.lost, fontSize: 13)),
          ),
        ]),
      );
}

class _Loader extends StatelessWidget {
  const _Loader();
  @override
  Widget build(BuildContext context) => const SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
      );
}

class _AuthLink extends StatelessWidget {
  final String prefix;
  final String linkText;
  final VoidCallback onTap;
  const _AuthLink(
      {required this.prefix, required this.linkText, required this.onTap});
  @override
  Widget build(BuildContext context) => Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(prefix,
              style: const TextStyle(color: AppTheme.txtSec, fontSize: 14)),
          GestureDetector(
            onTap: onTap,
            child: Text(linkText,
                style: const TextStyle(
                    color: AppTheme.primary,
                    fontWeight: FontWeight.w600,
                    fontSize: 14)),
          ),
        ],
      );
}
