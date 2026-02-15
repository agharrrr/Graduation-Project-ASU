import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';

import 'package:shoo_fi/Auth/auth_service.dart';
import 'package:shoo_fi/Auth/app_role.dart';
import 'package:shoo_fi/Organizer/Widgets/organizer_shell.dart';
import 'package:shoo_fi/shared/app_dialog.dart';
import '../User/Widgets/user_repository.dart';
import '../User/Widgets/user_shell.dart';

// NEW
import '../shared/theme/theme_controller.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _nameCtrl = TextEditingController();
  final TextEditingController _emailCtrl = TextEditingController();
  final TextEditingController _passwordCtrl = TextEditingController();
  final TextEditingController _confirmPasswordCtrl = TextEditingController();

  AppRole? _selectedRole;
  bool _isLoading = false;

  bool _hidePassword = true;
  bool _hideConfirmPassword = true;

  final _userRepo = UserRepo();

  Future<void> _showOrganizerVerificationMessage() async {
    await AppDialogs.showInfo(
      context,
      title: 'Account verification',
      message:
      'You have three days to visit our company and verify your account, or it will be rejected and closed.',
    );
  }


  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmPasswordCtrl.dispose();
    super.dispose();
  }

  Future<void> _onSignUpPressed() async {
    final form = _formKey.currentState;
    if (form == null || !form.validate()) return;

    if (_selectedRole == null) {
      await AppDialogs.showError(
        context,
        title: 'Missing role',
        message: 'Please choose whether you are a User or an Organizer.',
      );
      return;
    }

    if (_passwordCtrl.text != _confirmPasswordCtrl.text) {
      await AppDialogs.showError(
        context,
        title: 'Password mismatch',
        message: 'The passwords do not match. Please re-enter them.',
      );
      return;
    }

    // Block admin signup
    if (_selectedRole == AppRole.admin) {
      await AppDialogs.showError(
        context,
        title: 'Admin accounts',
        message: 'Admin accounts are not created from this screen.',
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final role = await AuthService.instance.signup(
        email: _emailCtrl.text.trim(),
        password: _passwordCtrl.text,
        role: _selectedRole!,
        name: _nameCtrl.text.trim().isEmpty ? null : _nameCtrl.text.trim(),
      );

      if (!mounted) return;

      // IMPORTANT: Set theme role immediately
      context.read<ThemeController>().setRole(role);

      final User? user = FirebaseAuth.instance.currentUser;

      switch (role) {
        case AppRole.user:
          if (user == null) {
            await AppDialogs.showError(
              context,
              title: 'Sign up failed',
              message: 'We could not complete sign up. Please try again.',
            );
            return;
          }

          await _userRepo.ensureUserDoc(
            displayName: _nameCtrl.text.trim().isEmpty
                ? (user.displayName ?? 'User')
                : _nameCtrl.text.trim(),
            photoUrl: user.photoURL,
          );

          if (!mounted) return;

          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const UserShellScreen()),
                (_) => false,
          );
          break;

        case AppRole.organizer:
          if (user != null) {
            await FirebaseFirestore.instance
                .collection('organizers')
                .doc(user.uid)
                .set(
              {
                'name': _nameCtrl.text.trim(),
                'profileImageUrl': user.photoURL,
                'createdAt': FieldValue.serverTimestamp(),
                'updatedAt': FieldValue.serverTimestamp(),
              },
              SetOptions(merge: true),
            );
          }

          if (!mounted) return;
          await _showOrganizerVerificationMessage();

          if (!mounted) return;
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const OrganizerShellScreen()),
                (_) => false,
          );
          break;


        case AppRole.admin:
          Navigator.of(context).pop();
          break;
      }
    } catch (e) {
      if (!mounted) return;
      await AppDialogs.showError(
        context,
        title: 'Sign up failed',
        message: _friendlyAuthMessage(e),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _friendlyAuthMessage(Object e) {
    final raw = e.toString();
    final msg = raw.replaceFirst('Exception: ', '').toLowerCase();

    if (msg.contains('email-already-in-use')) {
      return 'This email is already registered. Please log in instead.';
    }
    if (msg.contains('weak-password')) {
      return 'Please choose a stronger password (at least 6 characters).';
    }
    if (msg.contains('invalid-email')) {
      return 'Please enter a valid email address.';
    }
    if (msg.contains('network') || msg.contains('socket')) {
      return 'No internet connection. Please check your network and try again.';
    }
    return 'We could not create your account. Please try again.';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 64,
        title: const Text('Create account'),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 450),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: theme.colorScheme.primaryContainer,
                        ),
                        child: ClipOval(
                          child: Image.asset(
                            'assets/icons/app_icon.png',
                            width: 30,
                            height: 30,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'ShooFi?',
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          Text(
                            'Create your account',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  _buildRoleSelector(),
                  const SizedBox(height: 12),

                  Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        TextFormField(
                          controller: _nameCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Name (optional)',
                            prefixIcon: Icon(Icons.person),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _emailCtrl,
                          keyboardType: TextInputType.emailAddress,
                          decoration: const InputDecoration(
                            labelText: 'Email',
                            prefixIcon: Icon(Icons.email),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) return 'Email is required';
                            if (!value.contains('@')) return 'Enter a valid email.';
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _passwordCtrl,
                          obscureText: _hidePassword,
                          decoration: InputDecoration(
                            labelText: 'Password',
                            prefixIcon: const Icon(Icons.lock),
                            suffixIcon: IconButton(
                              onPressed: () => setState(() => _hidePassword = !_hidePassword),
                              icon: Icon(_hidePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) return 'Password is required';
                            if (value.length < 6) return 'At least 6 characters.';
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _confirmPasswordCtrl,
                          obscureText: _hideConfirmPassword,
                          decoration: InputDecoration(
                            labelText: 'Confirm password',
                            prefixIcon: const Icon(Icons.lock_outline),
                            suffixIcon: IconButton(
                              onPressed: () => setState(() => _hideConfirmPassword = !_hideConfirmPassword),
                              icon: Icon(_hideConfirmPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) return 'Please confirm your password';
                            if (value != _passwordCtrl.text) return 'Passwords do not match';
                            return null;
                          },
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _onSignUpPressed,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              child: _isLoading
                                  ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                                  : const Text('Create account', style: TextStyle(fontSize: 16)),
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
      ),
    );
  }

  Widget _buildRoleSelector() {
    const roles = [AppRole.user, AppRole.organizer];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Select your role', style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Column(
          children: roles.map((role) {
            return RadioListTile<AppRole>(
              value: role,
              groupValue: _selectedRole,
              title: Text(role == AppRole.user ? 'Explorer' : 'Organizer'),
              subtitle: Text(_roleDescription(role)),
              onChanged: (value) => setState(() => _selectedRole = value),
            );
          }).toList(),
        ),
      ],
    );
  }

  String _roleDescription(AppRole role) {
    switch (role) {
      case AppRole.user:
        return 'Browse and save events, book tickets, and explore Jordan.';
      case AppRole.organizer:
        return 'Create and manage your own events, festivals and concerts.';
      case AppRole.admin:
        return 'Monitors the platform (cannot be created here).';
    }
  }
}
