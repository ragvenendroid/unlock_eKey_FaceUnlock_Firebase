import 'package:flutter/material.dart';
import '../services/firebase_service.dart';

class AuthPage extends StatefulWidget {
  const AuthPage({Key? key}) : super(key: key);

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _isLogin = true;
  bool _loading = false;
  String? _error;

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      if (_isLogin) {
        await FirebaseService.login(_emailCtrl.text, _passCtrl.text);
      } else {
        await FirebaseService.register(_emailCtrl.text, _passCtrl.text);
      }
      // Navigation handled by StreamBuilder in main.dart
    } on Exception catch (e) {
      setState(() => _error = e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
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
      appBar: AppBar(title: Text(_isLogin ? 'Login' : 'Register')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Logo / title
                const Icon(Icons.lock, size: 72, color: Colors.indigo),
                const SizedBox(height: 8),
                const Text(
                  'SmartLock',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 32),

                // Email
                TextFormField(
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    prefixIcon: Icon(Icons.email_outlined),
                  ),
                  validator: (v) =>
                      v == null || !v.contains('@') ? 'Enter valid email' : null,
                ),
                const SizedBox(height: 16),

                // Password
                TextFormField(
                  controller: _passCtrl,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Password',
                    prefixIcon: Icon(Icons.lock_outline),
                  ),
                  validator: (v) => v == null || v.length < 6
                      ? 'Min 6 characters'
                      : null,
                ),
                const SizedBox(height: 8),

                // Error message
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      _error!,
                      style: const TextStyle(color: Colors.red, fontSize: 13),
                      textAlign: TextAlign.center,
                    ),
                  ),
                const SizedBox(height: 8),

                // Submit button
                _loading
                    ? const Center(child: CircularProgressIndicator())
                    : ElevatedButton(
                        onPressed: _submit,
                        child: Text(
                          _isLogin ? 'Login' : 'Register',
                          style: const TextStyle(fontSize: 16),
                        ),
                      ),
                const SizedBox(height: 12),

                // Toggle login/register
                TextButton(
                  onPressed: () =>
                      setState(() => _isLogin = !_isLogin),
                  child: Text(
                    _isLogin
                        ? "Don't have an account? Register"
                        : 'Already have an account? Login',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
