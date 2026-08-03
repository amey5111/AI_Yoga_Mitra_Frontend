import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'instructor_home_screen.dart';

/// Public "Become an Instructor" signup. Creates an account with role
/// instructor and drops the user straight into the instructor dashboard.
class InstructorSignupScreen extends StatefulWidget {
  const InstructorSignupScreen({super.key});

  @override
  State<InstructorSignupScreen> createState() => _InstructorSignupScreenState();
}

class _InstructorSignupScreenState extends State<InstructorSignupScreen> {
  static const _green = Color(0xFF6C63FF); // app accent (purple)
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _saving = false;
  bool _obscure = true;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_name.text.trim().isEmpty ||
        _email.text.trim().isEmpty ||
        _password.text.isEmpty) {
      _snack('Please fill all fields');
      return;
    }
    setState(() => _saving = true);
    try {
      final data = await ApiService.register(
        _name.text.trim(),
        _email.text.trim(),
        _password.text,
        '',
        '',
        role: 'instructor',
      );
      await ApiService.saveSession(
        data['userId'].toString(),
        data['name'] ?? _name.text.trim(),
        data['email'] ?? _email.text.trim(),
        '',
        '',
        role: 'instructor',
      );
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const InstructorHomeScreen()),
        (route) => false,
      );
    } catch (e) {
      _snack(e.toString().replaceAll('Exception: ', ''));
      if (mounted) setState(() => _saving = false);
    }
  }

  void _snack(String m) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: _green,
        foregroundColor: Colors.white,
        title: const Text('Become an Instructor'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const SizedBox(height: 8),
          const Icon(Icons.self_improvement, size: 56, color: _green),
          const SizedBox(height: 8),
          const Center(
            child: Text(
              'Teach live yoga classes to a large audience.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.black54),
            ),
          ),
          const SizedBox(height: 22),
          TextField(
            controller: _name,
            decoration: const InputDecoration(
              labelText: 'Full name',
              prefixIcon: Icon(Icons.person_outline),
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: 'Email',
              prefixIcon: Icon(Icons.email_outlined),
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _password,
            obscureText: _obscure,
            decoration: InputDecoration(
              labelText: 'Password',
              prefixIcon: const Icon(Icons.lock_outline),
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                icon: Icon(
                    _obscure ? Icons.visibility_off : Icons.visibility),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
            ),
          ),
          const SizedBox(height: 26),
          SizedBox(
            height: 52,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: _green,
                foregroundColor: Colors.white,
              ),
              onPressed: _saving ? null : _submit,
              icon: const Icon(Icons.check_circle_outline),
              label:
                  Text(_saving ? 'Creating...' : 'Create instructor account'),
            ),
          ),
        ],
      ),
    );
  }
}
