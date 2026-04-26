import 'package:flutter/material.dart';
import 'package:walkies/services/supabase_service.dart';
import 'package:walkies/services/network_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  final _supabaseService = SupabaseService();
  final _networkService = NetworkService();

  String _friendlyAuthError(Object error) {
    if (_networkService.isNetworkError(error)) {
      return _networkService.getNetworkErrorMessage(error);
    }
    final message = error.toString().toLowerCase();
    if (message.contains('invalid login credentials')) {
      return 'Email or password is incorrect. Please try again.';
    }
    if (message.contains('email not confirmed')) {
      return 'Please confirm your email before signing in.';
    }
    if (message.contains('user already registered')) {
      return 'An account with this email already exists. Please sign in.';
    }
    if (message.contains('password')) {
      return 'Password requirements were not met. Please use a stronger password.';
    }
    return 'Something went wrong. Please try again.';
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleSignIn() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Check connectivity first
      final hasConnection = await _networkService.hasInternetConnection();
      if (!hasConnection) {
        setState(() {
          _errorMessage =
              'No internet connection. Please check your network and try again.';
        });
        return;
      }

      await _supabaseService.signIn(
        _emailController.text,
        _passwordController.text,
      );

      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/dashboard');
      }
    } catch (e) {
      setState(() {
        _errorMessage = _friendlyAuthError(e);
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handleSignUp() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Check connectivity first
      final hasConnection = await _networkService.hasInternetConnection();
      if (!hasConnection) {
        setState(() {
          _errorMessage =
              'No internet connection. Please check your network and try again.';
        });
        return;
      }

      await _supabaseService.signUp(
        _emailController.text,
        _passwordController.text,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Check your email to confirm signup')),
        );
      }
    } catch (e) {
      setState(() {
        _errorMessage = _friendlyAuthError(e);
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final hasConnection = await _networkService.hasInternetConnection();
      if (!hasConnection) {
        setState(() {
          _errorMessage =
              'No internet connection. Please check your network and try again.';
        });
        return;
      }

      await _supabaseService.signInWithGoogle();
      // Session is resolved via Supabase auth state stream in _AuthWrapper.
    } catch (e) {
      setState(() {
        _errorMessage = _friendlyAuthError(e);
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Walkies - App Locker')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_errorMessage != null)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 16.0),
                padding: const EdgeInsets.all(12.0),
                decoration: BoxDecoration(
                  color: Colors.orange[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Text(
                  _errorMessage!,
                  style: TextStyle(color: Colors.orange.shade900),
                ),
              ),
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(
                labelText: 'Email',
                border: OutlineInputBorder(),
              ),
              enabled: !_isLoading,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _passwordController,
              decoration: const InputDecoration(
                labelText: 'Password',
                border: OutlineInputBorder(),
              ),
              obscureText: true,
              enabled: !_isLoading,
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _handleSignIn,
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Sign In'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isLoading ? null : _handleSignUp,
                    child: const Text('Sign Up'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _isLoading ? null : _handleGoogleSignIn,
                icon: const Icon(Icons.account_circle_outlined),
                label: const Text('Continue with Google'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
