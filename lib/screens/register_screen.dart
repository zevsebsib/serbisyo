import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  bool _agreed = false;
  bool _isError = false;
  bool _isLoading = false;

  // FIX: password visibility toggles added (was missing from original)
  bool _showPassword = false;
  bool _showConfirmPassword = false;

  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  // FIX: focus nodes for keyboard tab-flow between fields
  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();
  final _confirmFocus = FocusNode();

  // Password strength (0–4)
  int get _passwordStrength {
    final p = _passwordController.text;
    if (p.isEmpty) return 0;
    int score = 0;
    if (p.length >= 8) score++;
    if (RegExp(r'[A-Z]').hasMatch(p)) score++;
    if (RegExp(r'[0-9]').hasMatch(p)) score++;
    if (RegExp(r'[!@#\$&*~%^()_\-+=]').hasMatch(p)) score++;
    return score;
  }

  Color _strengthColor(int strength) {
    switch (strength) {
      case 1:
        return AppColors.danger;
      case 2:
        return AppColors.warning;
      case 3:
        return AppColors.primary;
      case 4:
        return AppColors.success;
      default:
        return AppColors.divider;
    }
  }

  String _strengthLabel(int strength) {
    switch (strength) {
      case 1:
        return 'Weak';
      case 2:
        return 'Fair';
      case 3:
        return 'Good';
      case 4:
        return 'Strong';
      default:
        return '';
    }
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    _confirmFocus.dispose();
    super.dispose();
  }

  void _triggerError(String message) {
    setState(() => _isError = true);
    HapticFeedback.mediumImpact();
    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) setState(() => _isError = false);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(LucideIcons.alertCircle, color: Colors.white, size: 18),
            const SizedBox(width: 10),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: AppColors.danger,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
      ),
    );
  }

  Future<void> _handleRegister() async {
    final fullName = _fullNameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final confirmPassword = _confirmPasswordController.text;

    if (fullName.isEmpty || email.isEmpty || password.isEmpty || confirmPassword.isEmpty) {
      _triggerError('Please fill in all fields.');
      return;
    }

    if (!_agreed) {
      _triggerError('Please accept the Terms and Conditions.');
      return;
    }

    if (password != confirmPassword) {
      _triggerError('Passwords do not match.');
      return;
    }

    if (_passwordStrength < 2) {
      _triggerError('Password is too weak. Use at least 8 characters.');
      return;
    }

    setState(() => _isLoading = true);
    try {
      final credential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(email: email, password: password);

      await credential.user?.updateDisplayName(fullName);

      // FIX: save user profile to Firestore for later use
      await FirebaseFirestore.instance
          .collection('users')
          .doc(credential.user!.uid)
          .set({
        'fullName': fullName,
        'email': email,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      // FIX: was navigating to /status_success — should go to dashboard after register
      Navigator.of(context).pushReplacementNamed('/');
    } on FirebaseAuthException catch (error) {
      if (!mounted) return;
      String message = 'Registration failed. Please try again.';
      if (error.code == 'email-already-in-use') {
        message = 'An account with this email already exists.';
      } else if (error.code == 'invalid-email') {
        message = 'Please enter a valid email address.';
      } else if (error.code == 'weak-password') {
        message = 'Password is too weak. Choose a stronger password.';
      }
      _triggerError(message);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildHeader(context),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 48),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Create your account', style: AppTextStyles.h1),
                  const SizedBox(height: 4),
                  Text(
                    'Fill in your details to get started.',
                    style: AppTextStyles.bodyMuted,
                  ),

                  const SizedBox(height: 28),

                  // ── Form fields ──────────────────────────────────
                  Column(
                    children: [
                      _buildField(
                        label: 'Full name',
                        hint: 'Juan Dela Cruz',
                        controller: _fullNameController,
                        icon: LucideIcons.user,
                        action: TextInputAction.next,
                        onSubmitted: (_) =>
                            FocusScope.of(context).requestFocus(_emailFocus),
                      ),
                      const SizedBox(height: 18),
                      _buildField(
                        label: 'Email address',
                        hint: 'you@email.com',
                        controller: _emailController,
                        icon: LucideIcons.mail,
                        type: TextInputType.emailAddress,
                        focusNode: _emailFocus,
                        action: TextInputAction.next,
                        onSubmitted: (_) =>
                            FocusScope.of(context).requestFocus(_passwordFocus),
                      ),
                      const SizedBox(height: 18),

                      // Password with strength meter
                      _buildPasswordField(
                        label: 'Password',
                        hint: '••••••••',
                        controller: _passwordController,
                        focusNode: _passwordFocus,
                        showPassword: _showPassword,
                        onToggle: () =>
                            setState(() => _showPassword = !_showPassword),
                        action: TextInputAction.next,
                        onSubmitted: (_) =>
                            FocusScope.of(context).requestFocus(_confirmFocus),
                        showStrength: true,
                      ),

                      const SizedBox(height: 18),

                      // Confirm password
                      _buildPasswordField(
                        label: 'Confirm password',
                        hint: '••••••••',
                        controller: _confirmPasswordController,
                        focusNode: _confirmFocus,
                        showPassword: _showConfirmPassword,
                        onToggle: () => setState(
                            () => _showConfirmPassword = !_showConfirmPassword),
                        action: TextInputAction.done,
                        onSubmitted: (_) => _handleRegister(),
                        showStrength: false,
                      ),
                    ],
                  )
                      .animate(target: _isError ? 1 : 0)
                      .shakeX(hz: 8, amount: 8, duration: 400.ms),

                  const SizedBox(height: 20),

                  // ── Terms checkbox ───────────────────────────────
                  GestureDetector(
                    onTap: () => setState(() => _agreed = !_agreed),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 22,
                          height: 22,
                          child: Checkbox(
                            value: _agreed,
                            onChanged: (v) =>
                                setState(() => _agreed = v ?? false),
                            activeColor: AppColors.primary,
                            side: const BorderSide(
                                color: AppColors.muted, width: 1.5),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(5),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text.rich(
                            TextSpan(
                              text: 'I agree with the ',
                              style: AppTextStyles.small.copyWith(
                                color: AppColors.secondary,
                                fontWeight: FontWeight.w500,
                              ),
                              children: [
                                TextSpan(
                                  text: 'Terms and Conditions',
                                  style: AppTextStyles.small.copyWith(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w700,
                                    decoration: TextDecoration.underline,
                                    decorationColor: AppColors.primary,
                                  ),
                                ),
                                TextSpan(
                                  text: ' of SerbisyoAlisto.',
                                  style: AppTextStyles.small.copyWith(
                                    color: AppColors.secondary,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 28),

                  // ── Register button ──────────────────────────────
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: double.infinity,
                    decoration: BoxDecoration(
                      gradient: (!_isLoading && _agreed)
                          ? AppColors.primaryGradient
                          : null,
                      color: (!_isLoading && _agreed)
                          ? null
                          : AppColors.muted.withOpacity(0.25),
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                      boxShadow:
                          (!_isLoading && _agreed) ? AppShadows.primary : [],
                    ),
                    child: ElevatedButton(
                      onPressed: (_isLoading || !_agreed) ? null : _handleRegister,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        disabledBackgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        padding: const EdgeInsets.symmetric(vertical: 17),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.lg),
                        ),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: AppColors.primary,
                              ),
                            )
                          : Text(
                              'Create Account',
                              style: GoogleFonts.inter(
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                                color: _agreed ? Colors.white : AppColors.muted,
                                letterSpacing: 0.2,
                              ),
                            ),
                    ),
                  ),

                  const SizedBox(height: 32),

                  // ── Login link ───────────────────────────────────
                  Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Already have an account? ',
                          style: AppTextStyles.body
                              .copyWith(color: AppColors.muted),
                        ),
                        GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: Text(
                            'Sign in',
                            style: AppTextStyles.body.copyWith(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: AppColors.headerGradient,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 24),
          child: Row(
            children: [
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(LucideIcons.arrowLeft,
                      color: Colors.white, size: 20),
                ),
              ),
              const SizedBox(width: 14),
              Text(
                'Register',
                style: GoogleFonts.inter(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildField({
    required String label,
    required String hint,
    required TextEditingController controller,
    required IconData icon,
    TextInputType? type,
    FocusNode? focusNode,
    TextInputAction? action,
    ValueChanged<String>? onSubmitted,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTextStyles.small.copyWith(
            color: AppColors.secondary,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: type,
          focusNode: focusNode,
          textInputAction: action,
          onSubmitted: onSubmitted,
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w500,
            fontSize: 15,
            color: AppColors.secondary,
          ),
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: Icon(icon, size: 18, color: AppColors.muted),
          ),
        ),
      ],
    );
  }

  Widget _buildPasswordField({
    required String label,
    required String hint,
    required TextEditingController controller,
    required FocusNode focusNode,
    required bool showPassword,
    required VoidCallback onToggle,
    required TextInputAction action,
    required ValueChanged<String> onSubmitted,
    required bool showStrength,
  }) {
    final strength = showStrength ? _passwordStrength : 0;
    final strengthColor = _strengthColor(strength);
    final strengthLabel = _strengthLabel(strength);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTextStyles.small.copyWith(
            color: AppColors.secondary,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          focusNode: focusNode,
          obscureText: !showPassword,
          textInputAction: action,
          onSubmitted: onSubmitted,
          onChanged: showStrength ? (_) => setState(() {}) : null,
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w500,
            fontSize: 15,
            color: AppColors.secondary,
          ),
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon:
                Icon(LucideIcons.lock, size: 18, color: AppColors.muted),
            suffixIcon: IconButton(
              icon: Icon(
                showPassword ? LucideIcons.eyeOff : LucideIcons.eye,
                size: 18,
                color: AppColors.muted,
              ),
              onPressed: onToggle,
            ),
          ),
        ),

        // Password strength bar
        if (showStrength && controller.text.isNotEmpty) ...[
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Row(
                  children: List.generate(4, (i) {
                    return Expanded(
                      child: Container(
                        margin: EdgeInsets.only(right: i < 3 ? 4 : 0),
                        height: 4,
                        decoration: BoxDecoration(
                          color: i < strength
                              ? strengthColor
                              : AppColors.divider,
                          borderRadius:
                              BorderRadius.circular(AppRadius.pill),
                        ),
                      ),
                    );
                  }),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                strengthLabel,
                style: AppTextStyles.small.copyWith(
                  color: strengthColor,
                  fontWeight: FontWeight.w600,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}