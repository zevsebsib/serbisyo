import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';
import 'admin_register_screen.dart';

class AdminLoginScreen extends StatefulWidget {
  const AdminLoginScreen({super.key});

  @override
  State<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends State<AdminLoginScreen> {
  final _emailController    = TextEditingController();
  final _passwordController = TextEditingController();
  bool _showPassword = false;
  bool _isLoading    = false;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    final email    = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      setState(() => _error = 'Please enter your email and password.');
      return;
    }

    setState(() { _isLoading = true; _error = null; });

    try {
      final credential = await FirebaseAuth.instance
          .signInWithEmailAndPassword(email: email, password: password);
      await _checkAdminAccess(credential.user!.uid);
    } on FirebaseAuthException catch (e) {
      String message = 'Login failed. Please try again.';
      if (e.code == 'user-not-found' ||
          e.code == 'wrong-password' ||
          e.code == 'invalid-credential') {
        message = 'Invalid email or password.';
      } else if (e.code == 'invalid-email') {
        message = 'Please enter a valid email address.';
      } else if (e.code == 'too-many-requests') {
        message = 'Too many attempts. Please try again later.';
      }
      setState(() { _error = message; _isLoading = false; });
    } catch (_) {
      setState(() {
        _error = 'An unexpected error occurred.';
        _isLoading = false;
      });
    }
  }

  Future<void> _checkAdminAccess(String uid) async {
    final adminDoc = await FirebaseFirestore.instance
        .collection('admins')
        .doc(uid)
        .get();

    if (!adminDoc.exists) {
      await FirebaseAuth.instance.signOut();
      setState(() {
        _error = 'Access denied. No admin account found for this user.';
        _isLoading = false;
      });
      return;
    }

    final data = adminDoc.data()!;

    if (data['isActive'] == false) {
      await FirebaseAuth.instance.signOut();
      setState(() {
        _error = 'Your account is pending approval from a superadmin.';
        _isLoading = false;
      });
      return;
    }

    if (!mounted) return;
    Navigator.pushReplacementNamed(context, '/admin');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      body: Row(
        children: [
          // ── Left branding panel ────────────────────────────────────
          Expanded(
            flex: 5,
            child: Container(
              decoration: const BoxDecoration(
                  gradient: AppColors.headerGradient),
              child: Stack(
                children: [
                  Positioned(top: -80,    left: -80,  child: _circle(300, 0.06)),
                  Positioned(bottom: -60, right: -60, child: _circle(260, 0.06)),
                  Positioned(top: 120,    right: -40, child: _circle(160, 0.04)),
                  SafeArea(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 48, vertical: 48),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            minHeight:
                                MediaQuery.of(context).size.height - 96,
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              // ── Logo ──────────────────────────────
                              Container(
                                width: 190, height: 190,
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle),
                                child: ClipOval(
                                  child: Image.asset('assets/logo.jpg',
                                      fit: BoxFit.cover),
                                ),
                              ),

                              const SizedBox(height: 32),

                              Text('SerbisyoAlisto',
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.inter(
                                    fontSize: 100,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white,
                                    letterSpacing: -1.5,
                                  )),

                              const SizedBox(height: 8),

                              Text('Admin Portal',
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.inter(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
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

                              const SizedBox(height: 20),

                              Text(
                                'City Government of Laoag\nService Request Management System',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.inter(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.white.withValues(alpha: 0.70),
                                  height: 1.6,
                                ),
                              ),

                              const SizedBox(height: 40),

                              // ── Feature list ───────────────────────
                              ...[
                                {'icon': '📋', 'label': 'Manage citizen service requests'},
                                {'icon': '👥', 'label': 'Assign tasks to staff'},
                                {'icon': '📊', 'label': 'Track performance & reports'},
                                {'icon': '🔔', 'label': 'Send notifications to citizens'},
                              ].map((item) => Padding(
                                padding: const EdgeInsets.only(bottom: 16),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(item['icon']!,
                                        style: const TextStyle(fontSize: 20)),
                                    const SizedBox(width: 14),
                                    Text(item['label']!,
                                        style: GoogleFonts.inter(
                                          fontSize: 15,
                                          color: Colors.white
                                              .withValues(alpha: 0.85),
                                          fontWeight: FontWeight.w500,
                                        )),
                                  ],
                                ),
                              )),

                              const SizedBox(height: 40),

                              // ── Divider ────────────────────────────
                              Container(
                                width: double.infinity,
                                height: 1,
                                color: Colors.white.withValues(alpha: 0.15),
                              ),

                              const SizedBox(height: 36),

                              // ── How it works ───────────────────────
                              Text(
                                'HOW IT WORKS',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white.withValues(alpha: 0.60),
                                  letterSpacing: 2.5,
                                ),
                              ),

                              const SizedBox(height: 24),

                              // FIX: 2x2 grid layout
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: _buildStep(
                                      '01',
                                      'Citizen Submits Request',
                                      'Citizen fills out the service form and uploads required documents via the mobile app.',
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: _buildStep(
                                      '02',
                                      'Staff Verifies & Processes',
                                      'Assigned staff reviews the request, verifies documents, and processes accordingly.',
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 16),

                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: _buildStep(
                                      '03',
                                      'Status Updated',
                                      'Admin updates the request status and the citizen is automatically notified.',
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: _buildStep(
                                      '04',
                                      'Citizen Claims Document',
                                      'Once completed, the citizen is notified to claim or download their document.',
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 16),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Right login panel ──────────────────────────────────────
          Expanded(
            flex: 4,
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(48),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 400),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Welcome!!',
                          style: GoogleFonts.inter(
                            fontSize: 30,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF1A1A1A),
                            letterSpacing: -1,
                          )),

                      const SizedBox(height: 8),

                      Text(
                        'Sign in to your admin account to continue.',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: AppColors.muted,
                          fontWeight: FontWeight.w500,
                        ),
                      ),

                      const SizedBox(height: 32),

                      // Error banner
                      if (_error != null) ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFDEAEA),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: AppColors.danger
                                    .withValues(alpha: 0.3)),
                          ),
                          child: Row(children: [
                            const Icon(Icons.error_outline,
                                color: AppColors.danger, size: 18),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(_error!,
                                  style: GoogleFonts.inter(
                                    color: AppColors.danger,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  )),
                            ),
                          ]),
                        ),
                        const SizedBox(height: 20),
                      ],

                      // Email
                      _buildLabel('Email address'),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        style: GoogleFonts.inter(
                            fontSize: 15, fontWeight: FontWeight.w500),
                        decoration: _inputDecoration(
                          hint: 'admin@laoag.gov.ph',
                          icon: Icons.email_outlined,
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Password
                      _buildLabel('Password'),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _passwordController,
                        obscureText: !_showPassword,
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => _handleLogin(),
                        style: GoogleFonts.inter(
                            fontSize: 15, fontWeight: FontWeight.w500),
                        decoration: _inputDecoration(
                          hint: '••••••••',
                          icon: Icons.lock_outline,
                          suffix: IconButton(
                            icon: Icon(
                              _showPassword
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                              color: AppColors.muted, size: 20,
                            ),
                            onPressed: () => setState(
                                () => _showPassword = !_showPassword),
                          ),
                        ),
                      ),

                      const SizedBox(height: 28),

                      // Sign In button
                      SizedBox(
                        width: double.infinity, height: 52,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _handleLogin,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            disabledBackgroundColor:
                                AppColors.muted.withValues(alpha: 0.3),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  width: 22, height: 22,
                                  child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2.5))
                              : Text('Sign In',
                                  style: GoogleFonts.inter(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  )),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Divider
                      Row(children: [
                        const Expanded(child: Divider()),
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14),
                          child: Text('or',
                              style: GoogleFonts.inter(
                                  color: AppColors.muted, fontSize: 13)),
                        ),
                        const Expanded(child: Divider()),
                      ]),

                      const SizedBox(height: 16),

                      // Google Sign In
                      SizedBox(
                        width: double.infinity, height: 52,
                        child: OutlinedButton(
                          onPressed: () => setState(() => _error =
                              'Run: flutter pub add google_sign_in'),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(
                                color: Color(0xFFEEEEEE), width: 1.5),
                            backgroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text('G',
                                  style: GoogleFonts.inter(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w800,
                                    color: const Color(0xFF4285F4),
                                  )),
                              const SizedBox(width: 12),
                              Text('Continue with Google',
                                  style: GoogleFonts.inter(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: const Color(0xFF1A1A1A),
                                  )),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 28),

                      // Register link
                      Center(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text("Don't have an account? ",
                                style: GoogleFonts.inter(
                                    color: AppColors.muted,
                                    fontSize: 13)),
                            GestureDetector(
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) =>
                                        const AdminRegisterScreen()),
                              ),
                              child: Text('Request Access',
                                  style: GoogleFonts.inter(
                                    color: AppColors.primary,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                  )),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 40),

                      Center(
                        child: Text(
                          '© ${DateTime.now().year} City Government of Laoag\nAll rights reserved.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: AppColors.muted,
                            height: 1.6,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── How it works step card ─────────────────────────────────────────────────
  Widget _buildStep(String step, String title, String desc) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.15),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32, height: 32,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.20),
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.40),
                width: 1.5,
              ),
            ),
            child: Center(
              child: Text(step,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  )),
            ),
          ),
          const SizedBox(height: 10),
          Text(title,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              )),
          const SizedBox(height: 6),
          Text(desc,
              style: GoogleFonts.inter(
                fontSize: 11,
                color: Colors.white.withValues(alpha: 0.70),
                height: 1.5,
              )),
        ],
      ),
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
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: const Color(0xFF1A1A1A)));

  InputDecoration _inputDecoration({
    required String hint,
    required IconData icon,
    Widget? suffix,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.inter(color: AppColors.muted, fontSize: 14),
      prefixIcon: Icon(icon, color: AppColors.muted, size: 20),
      suffixIcon: suffix,
      filled: true,
      fillColor: Colors.white,
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
        borderSide:
            const BorderSide(color: AppColors.primary, width: 2),
      ),
    );
  }
}