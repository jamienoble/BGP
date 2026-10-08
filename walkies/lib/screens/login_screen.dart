import 'package:flutter/material.dart';
import 'package:walkies/theme/app_theme.dart';
import 'package:walkies/widgets/ui.dart';
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
  final _preferredNameController = TextEditingController();
  bool _isLoading = false;
  bool _isCreatingAccount = false;
  bool _obscurePassword = true;
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
    _preferredNameController.dispose();
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

      // The auth wrapper in main.dart shows the dashboard once signed in
      await _supabaseService.signIn(
        _emailController.text.trim(),
        _passwordController.text,
      );
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
    final preferredName = _preferredNameController.text.trim();
    if (preferredName.isEmpty) {
      setState(() {
        _errorMessage = 'Please tell us what to call you.';
      });
      return;
    }

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
        _emailController.text.trim(),
        _passwordController.text,
        preferredName: preferredName,
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

  Future<void> _handleForgotPassword() async {
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      setState(() {
        _errorMessage = 'Enter your email above, then tap Forgot password.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await _supabaseService.sendPasswordResetEmail(email);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'If that account exists, a reset link is on its way.',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = _friendlyAuthError(e);
        });
      }
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
    final text = Theme.of(context).textTheme;
    final creating = _isCreatingAccount;
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          children: [
            const _Hero(),
            const SizedBox(height: 28),
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: false, label: Text('Sign in')),
                ButtonSegment(value: true, label: Text('Create account')),
              ],
              selected: {creating},
              showSelectedIcon: false,
              onSelectionChanged: _isLoading
                  ? null
                  : (value) => setState(() {
                      _isCreatingAccount = value.first;
                      _errorMessage = null;
                    }),
              style: SegmentedButton.styleFrom(
                backgroundColor: AppPalette.white,
                selectedBackgroundColor: AppPalette.forest,
                selectedForegroundColor: AppPalette.white,
                foregroundColor: AppPalette.body,
                side: const BorderSide(color: AppPalette.line),
                minimumSize: const Size(0, 48),
                textStyle: text.labelLarge,
              ),
            ),
            const SizedBox(height: 20),
            if (_errorMessage != null) ...[
              NoticeCard(
                tone: NoticeTone.danger,
                icon: Icons.error_outline_rounded,
                title: _errorMessage!,
              ),
              const SizedBox(height: 16),
            ],
            if (creating) ...[
              TextField(
                controller: _preferredNameController,
                enabled: !_isLoading,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'What should we call you?',
                  prefixIcon: Icon(Icons.person_outline_rounded),
                ),
              ),
              const SizedBox(height: 14),
            ],
            TextField(
              controller: _emailController,
              enabled: !_isLoading,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              decoration: const InputDecoration(
                labelText: 'Email',
                prefixIcon: Icon(Icons.mail_outline_rounded),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _passwordController,
              enabled: !_isLoading,
              obscureText: _obscurePassword,
              autofillHints: [
                creating ? AutofillHints.newPassword : AutofillHints.password,
              ],
              decoration: InputDecoration(
                labelText: 'Password',
                prefixIcon: const Icon(Icons.lock_outline_rounded),
                suffixIcon: IconButton(
                  tooltip: _obscurePassword ? 'Show password' : 'Hide password',
                  icon: Icon(
                    _obscurePassword
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                  onPressed: () =>
                      setState(() => _obscurePassword = !_obscurePassword),
                ),
              ),
            ),
            if (!creating)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _isLoading ? null : _handleForgotPassword,
                  child: const Text('Forgot password?'),
                ),
              )
            else
              const SizedBox(height: 16),
            const SizedBox(height: 4),
            FilledButton(
              onPressed: _isLoading
                  ? null
                  : (creating ? _handleSignUp : _handleSignIn),
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(creating ? 'Create account' : 'Sign in'),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                const Expanded(child: Divider()),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text('or', style: text.bodySmall),
                ),
                const Expanded(child: Divider()),
              ],
            ),
            const SizedBox(height: 18),
            OutlinedButton.icon(
              onPressed: _isLoading ? null : _handleGoogleSignIn,
              icon: const Text(
                'G',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                  color: AppPalette.forest,
                ),
              ),
              label: const Text('Continue with Google'),
            ),
          ],
        ),
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero();

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(32),
      // At least 250 tall, growing with large system text
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 250),
        child: Stack(
          children: [
            const Positioned.fill(
              child: ArtworkPlaceholder(
                seed: 'walkies',
                icon: Icons.circle,
                iconSize: 0,
                palette: 0,
              ),
            ),
            const Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0x002D5A4A), Color(0xCC1E3D33)],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.directions_walk_rounded,
                      color: AppPalette.forest,
                      size: 30,
                    ),
                  ),
                  const SizedBox(height: 56),
                  Text(
                    'Walkies',
                    style: text.displayMedium!.copyWith(color: Colors.white),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Walk more. Scroll less. Your apps unlock when you hit '
                    'your daily steps.',
                    style: text.bodyLarge!.copyWith(color: Colors.white70),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
