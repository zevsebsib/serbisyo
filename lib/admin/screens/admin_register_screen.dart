import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';

class AdminRegisterScreen extends StatefulWidget {
  const AdminRegisterScreen({super.key});

  @override
  State<AdminRegisterScreen> createState() => _AdminRegisterScreenState();
}

class _AdminRegisterScreenState extends State<AdminRegisterScreen> {
  final _fullNameController = TextEditingController();
  final _emailController    = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController  = TextEditingController();

  bool _showPassword        = false;
  bool _showConfirmPassword = false;
  bool _isLoading           = false;
  bool _submitted           = false;
  String? _error;

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _handleRegister() async {
    final fullName = _fullNameController.text.trim();
    final email    = _emailController.text.trim();
    final password = _passwordController.text;
    final confirm  = _confirmController.text;

    if (fullName.isEmpty || email.isEmpty ||
        password.isEmpty || confirm.isEmpty) {
      setState(() => _error = 'Please fill in all fields.');
      return;
    }

    if (password != confirm) {
      setState(() => _error = 'Passwords do not match.');
      return;
    }

    if (password.length < 8) {
      setState(() => _error = 'Password must be at least 8 characters.');
      return;
    }

    setState(() { _isLoading = true; _error = null; });

    try {
      // Create Firebase Auth account
      final credential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
              email: email, password: password);

      await credential.user?.updateDisplayName(fullName);

      // Save to /admins with isActive: false — awaiting superadmin approval
      await FirebaseFirestore.instance
          .collection('admins')
          .doc(credential.user!.uid)
          .set({
        'fullName':   fullName,
        'email':      email,
        'role':       'staff',
        'department': "Mayor's Office",
        'isActive':   false,    // ← pending approval
        'createdAt':  FieldValue.serverTimestamp(),
      });

      // Sign out immediately — can't use portal until approved
      await FirebaseAuth.instance.signOut();

      if (mounted) setState(() { _submitted = true; _isLoading = false; });

    } on FirebaseAuthException catch (e) {
      String message = 'Registration failed. Please try again.';
      if (e.code == 'email-already-in-use') {
        message = 'An account with this email already exists.';
      } else if (e.code == 'invalid-email') {
        message = 'Please enter a valid email address.';
      } else if (e.code == 'weak-password') {
        message = 'Password is too weak.';
      }
      setState(() { _error = message; _isLoading = false; });
    } catch (_) {
      setState(() {
        _error = 'An unexpected error occurred.';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      body: Row(
        children: [
          // ── Left branding panel (same as login) ───────────────────
          Expanded(
            flex: 5,
            child: Container(
              decoration: const BoxDecoration(
                  gradient: AppColors.headerGradient),
              child: Stack(children: [
                Positioned(top: -80, left: -80,
                    child: _circle(300, 0.06)),
                Positioned(bottom: -60, right: -60,
                    child: _circle(260, 0.06)),
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(48),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 80, height: 80,
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                              color: Colors.white, shape: BoxShape.circle),
                          child: ClipOval(
                            child: Image.asset('assets/logo.jpg',
                                fit: BoxFit.cover),
                          ),
                        ),
                        const SizedBox(height: 32),
                        Text('SerbisyoAlisto',
                            style: GoogleFonts.inter(
                              fontSize: 36, fontWeight: FontWeight.w900,
                              color: Colors.white, letterSpacing: -1.5,
                            )),
                        const SizedBox(height: 8),
                        Text('Admin Portal',
                            style: GoogleFonts.inter(
                              fontSize: 16, fontWeight: FontWeight.w600,
                              color: Colors.white.withValues(alpha: 0.80),
                              letterSpacing: 2.0,
                            )),
                        const SizedBox(height: 24),
                        Container(
                          width: 48, height: 4,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.50),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'Request an account to manage\ncitizen service requests for\nthe City Government of Laoag.',
                          style: GoogleFonts.inter(
                            fontSize: 14, fontWeight: FontWeight.w500,
                            color: Colors.white.withValues(alpha: 0.70),
                            height: 1.8,
                          ),
                        ),
                        const SizedBox(height: 32),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(children: [
                            const Icon(Icons.info_outline,
                                color: Colors.white, size: 18),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Your account will be reviewed and activated by a superadmin before you can log in.',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: Colors.white.withValues(alpha: 0.85),
                                  height: 1.5,
                                ),
                              ),
                            ),
                          ]),
                        ),
                      ],
                    ),
                  ),
                ),
              ]),
            ),
          ),

          // ── Right register panel ───────────────────────────────────
          Expanded(
            flex: 4,
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(48),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 400),
                  child: _submitted
                      ? _buildSuccessState()
                      : _buildForm(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Success state ──────────────────────────────────────────────────────────
  Widget _buildSuccessState() {
    return Column(
      children: [
        Container(
          width: 80, height: 80,
          decoration: const BoxDecoration(
            color: AppColors.successLight, shape: BoxShape.circle),
          child: const Icon(Icons.check_circle_outline,
              color: AppColors.success, size: 40),
        ),
        const SizedBox(height: 24),
        Text('Request Submitted!',
            style: GoogleFonts.inter(
              fontSize: 26, fontWeight: FontWeight.w800,
              color: const Color(0xFF1A1A1A), letterSpacing: -0.5,
            )),
        const SizedBox(height: 12),
        Text(
          'Your account request has been submitted.\nA superadmin will review and activate your account.',
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            fontSize: 14, color: AppColors.muted, height: 1.6,
          ),
        ),
        const SizedBox(height: 32),
        SizedBox(
          width: double.infinity, height: 52,
          child: ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary, elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: Text('Back to Login',
                style: GoogleFonts.inter(
                    fontSize: 15, fontWeight: FontWeight.w700,
                    color: Colors.white)),
          ),
        ),
      ],
    );
  }

  // ── Register form ──────────────────────────────────────────────────────────
  Widget _buildForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Back button
        GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Row(children: [
            const Icon(Icons.arrow_back, size: 18, color: AppColors.muted),
            const SizedBox(width: 6),
            Text('Back to Login',
                style: GoogleFonts.inter(
                    color: AppColors.muted, fontSize: 13,
                    fontWeight: FontWeight.w500)),
          ]),
        ),

        const SizedBox(height: 28),

        Text('Request Access',
            style: GoogleFonts.inter(
              fontSize: 30, fontWeight: FontWeight.w800,
              color: const Color(0xFF1A1A1A), letterSpacing: -1,
            )),
        const SizedBox(height: 8),
        Text('Fill in your details to request an admin account.',
            style: GoogleFonts.inter(
                fontSize: 14, color: AppColors.muted,
                fontWeight: FontWeight.w500)),

        const SizedBox(height: 32),

        // Error banner
        if (_error != null) ...[
          Container(
            width: double.infinity, padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFFDEAEA),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: AppColors.danger.withValues(alpha: 0.3)),
            ),
            child: Row(children: [
              const Icon(Icons.error_outline,
                  color: AppColors.danger, size: 18),
              const SizedBox(width: 10),
              Expanded(child: Text(_error!,
                  style: GoogleFonts.inter(
                      color: AppColors.danger, fontSize: 13,
                      fontWeight: FontWeight.w500))),
            ]),
          ),
          const SizedBox(height: 20),
        ],

        _buildLabel('Full Name'),
        const SizedBox(height: 8),
        _buildTextField(
            controller: _fullNameController,
            hint: 'Juan Dela Cruz',
            icon: Icons.person_outline),

        const SizedBox(height: 18),

        _buildLabel('Email address'),
        const SizedBox(height: 8),
        _buildTextField(
            controller: _emailController,
            hint: 'juan@laoag.gov.ph',
            icon: Icons.email_outlined,
            type: TextInputType.emailAddress),

        const SizedBox(height: 18),

        _buildLabel('Password'),
        const SizedBox(height: 8),
        _buildTextField(
            controller: _passwordController,
            hint: '••••••••',
            icon: Icons.lock_outline,
            obscure: !_showPassword,
            suffix: IconButton(
              icon: Icon(
                _showPassword
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                color: AppColors.muted, size: 20,
              ),
              onPressed: () =>
                  setState(() => _showPassword = !_showPassword),
            )),

        const SizedBox(height: 18),

        _buildLabel('Confirm Password'),
        const SizedBox(height: 8),
        _buildTextField(
            controller: _confirmController,
            hint: '••••••••',
            icon: Icons.lock_outline,
            obscure: !_showConfirmPassword,
            suffix: IconButton(
              icon: Icon(
                _showConfirmPassword
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                color: AppColors.muted, size: 20,
              ),
              onPressed: () => setState(
                  () => _showConfirmPassword = !_showConfirmPassword),
            )),

        const SizedBox(height: 32),

        SizedBox(
          width: double.infinity, height: 52,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _handleRegister,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              disabledBackgroundColor:
                  AppColors.muted.withValues(alpha: 0.3),
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: _isLoading
                ? const SizedBox(width: 22, height: 22,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2.5))
                : Text('Submit Request',
                    style: GoogleFonts.inter(
                      fontSize: 15, fontWeight: FontWeight.w700,
                      color: Colors.white,
                    )),
          ),
        ),
      ],
    );
  }

  Widget _circle(double size, double opacity) => Container(
    width: size, height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: Colors.white.withValues(alpha: opacity),
    ),
  );

  Widget _buildLabel(String text) => Text(text,
      style: GoogleFonts.inter(
          fontSize: 13, fontWeight: FontWeight.w600,
          color: const Color(0xFF1A1A1A)));

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool obscure = false,
    TextInputType? type,
    Widget? suffix,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      keyboardType: type,
      style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w500),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.inter(color: AppColors.muted, fontSize: 14),
        prefixIcon: Icon(icon, color: AppColors.muted, size: 20),
        suffixIcon: suffix,
        filled: true, fillColor: Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFEEEEEE)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFEEEEEE)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
      ),
    );
  }
}