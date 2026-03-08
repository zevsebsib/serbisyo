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

class _AdminLoginScreenState extends State<AdminLoginScreen>
    with TickerProviderStateMixin {
  final _emailController    = TextEditingController();
  final _passwordController = TextEditingController();
  final _emailFocus         = FocusNode();
  final _passwordFocus      = FocusNode();

  bool _showPassword  = false;
  bool _isLoading     = false;
  bool _isSuperAdmin  = false;
  bool _emailFocused  = false;
  bool _passFocused   = false;
  String? _error;

  late final AnimationController _fadeCtrl;
  late final AnimationController _slideCtrl;
  late final Animation<double>   _fadeAnim;
  late final Animation<Offset>   _slideAnim;

  @override
  void initState() {
    super.initState();

    _fadeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _slideCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));

    _fadeAnim = CurvedAnimation(
        parent: _fadeCtrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.04),
      end: Offset.zero,
    ).animate(CurvedAnimation(
        parent: _slideCtrl, curve: Curves.easeOut));

    _fadeCtrl.forward();
    _slideCtrl.forward();

    _emailFocus.addListener(() =>
        setState(() => _emailFocused = _emailFocus.hasFocus));
    _passwordFocus.addListener(() =>
        setState(() => _passFocused = _passwordFocus.hasFocus));
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    _fadeCtrl.dispose();
    _slideCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    final email    = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      setState(() => _error = 'Please enter your email and password.');
      return;
    }

    setState(() {
      _isLoading = true;
      _error     = null;
    });

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
      setState(() {
        _error     = message;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error     = 'Error: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  Future<void> _checkAdminAccess(String uid) async {
    try {
      final adminDoc = await FirebaseFirestore.instance
          .collection('admin')
          .doc(uid)
          .get();

      if (!adminDoc.exists) {
        await FirebaseAuth.instance.signOut();
        setState(() {
          _error     = 'Access denied. No account found for this user.';
          _isLoading = false;
        });
        return;
      }

      final data         = adminDoc.data()!;
      final role         = data['role'] ?? '';
      final expectedRole = _isSuperAdmin ? 'superadmin' : 'admin';

      if (role != expectedRole) {
        await FirebaseAuth.instance.signOut();
        setState(() {
          _error = _isSuperAdmin
              ? 'This account is not a Super Admin. Switch to Admin.'
              : 'This account is not an Admin. Switch to Super Admin.';
          _isLoading = false;
        });
        return;
      }

      if (data['isActive'] == false) {
        await FirebaseAuth.instance.signOut();
        setState(() {
          _error     = 'Your account is pending approval from a superadmin.';
          _isLoading = false;
        });
        return;
      }

      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/admin');
    } catch (e) {
      await FirebaseAuth.instance.signOut();
      setState(() {
        _error     = 'Firestore error: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  // ── BUILD ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FC),
      body: Row(
        children: [
          // Left branding panel — 35%
          Expanded(flex: 35, child: _buildBrandingPanel()),
          // Right login panel — 65%
          Expanded(flex: 65, child: _buildLoginPanel()),
        ],
      ),
    );
  }

  // ── LEFT PANEL ─────────────────────────────────────────────────────────────
  Widget _buildBrandingPanel() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFFF9500),
            Color(0xFFFF7200),
            Color(0xFFE85500),
          ],
          stops: [0.0, 0.55, 1.0],
        ),
      ),
      child: Stack(
        children: [
          // Decorative circles
          Positioned(top: -100,   left: -100,  child: _glowCircle(320, 0.08)),
          Positioned(bottom: -80, right: -80,  child: _glowCircle(280, 0.08)),
          Positioned(top: 200,    right: -60,  child: _glowCircle(180, 0.05)),
          Positioned(bottom: 200, left: -40,   child: _glowCircle(140, 0.05)),

          // Subtle grid overlay
          Positioned.fill(child: CustomPaint(painter: _GridPainter())),

          // Content
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 32, vertical: 48),
              child: Column(
                children: [
                  const Spacer(flex: 1),

                  // Logo
                  Container(
                    width: 200, height: 200,
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.18),
                          blurRadius: 24,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: ClipOval(
                      child: Image.asset(
                          'assets/logo.jpg', fit: BoxFit.cover),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // App name
                  Text('SerbisyoAlisto',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: 50,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: -0.5,
                        height: 1.1,
                      )),

                  const SizedBox(height: 8),

                  // Admin portal badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.25),
                        width: 1,
                      ),
                    ),
                    child: Text('ADMIN PORTAL',
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          letterSpacing: 2.5,
                        )),
                  ),

                  const SizedBox(height: 10),

                  Text('City Government of Laoag',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Colors.white.withValues(alpha: 0.72),
                      )),

                  const SizedBox(height: 36),

                  // Divider
                  Container(
                    height: 1,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [
                        Colors.transparent,
                        Colors.white.withValues(alpha: 0.28),
                        Colors.transparent,
                      ]),
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Feature list
                  ...[
                    _FeatureItem(
                        icon: Icons.assignment_turned_in_rounded,
                        label: 'Manage service requests'),
                    _FeatureItem(
                        icon: Icons.group_rounded,
                        label: 'Assign tasks to staff'),
                    _FeatureItem(
                        icon: Icons.bar_chart_rounded,
                        label: 'Track & generate reports'),
                    _FeatureItem(
                        icon: Icons.notifications_active_rounded,
                        label: 'Notify citizens instantly'),
                  ].map((f) => Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: Row(
                      children: [
                        Container(
                          width: 36, height: 36,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.18),
                              width: 1,
                            ),
                          ),
                          child: Icon(f.icon,
                              color: Colors.white, size: 18),
                        ),
                        const SizedBox(width: 14),
                        Text(f.label,
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: Colors.white
                                  .withValues(alpha: 0.88),
                            )),
                      ],
                    ),
                  )),

                  const SizedBox(height: 32),

                  // How It Works label
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text('HOW IT WORKS',
                        style: GoogleFonts.inter(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          color: Colors.white.withValues(alpha: 0.50),
                          letterSpacing: 2.5,
                        )),
                  ),

                  const SizedBox(height: 14),

                  // Steps row
                  Row(
                    children: [
                      Expanded(
                          child: _buildMiniStep('01', 'Citizen\nSubmits')),
                      _buildStepArrow(),
                      Expanded(
                          child: _buildMiniStep('02', 'Staff\nVerifies')),
                      _buildStepArrow(),
                      Expanded(
                          child: _buildMiniStep('03', 'Status\nUpdated')),
                      _buildStepArrow(),
                      Expanded(
                          child: _buildMiniStep('04', 'Citizen\nClaims')),
                    ],
                  ),

                  const Spacer(flex: 2),

                  // Footer text
                  Text(
                    '© ${DateTime.now().year} City Government of Laoag',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      color: Colors.white.withValues(alpha: 0.40),
                    ),
                  ),

                  const SizedBox(height: 4),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniStep(String num, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.11),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
            color: Colors.white.withValues(alpha: 0.18), width: 1),
      ),
      child: Column(
        children: [
          Text(num,
              style: GoogleFonts.inter(
                fontSize: 15,
                fontWeight: FontWeight.w900,
                color: Colors.white,
              )),
          const SizedBox(height: 4),
          Text(label,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 9,
                fontWeight: FontWeight.w500,
                color: Colors.white.withValues(alpha: 0.72),
                height: 1.4,
              )),
        ],
      ),
    );
  }

  Widget _buildStepArrow() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Icon(Icons.chevron_right_rounded,
          color: Colors.white.withValues(alpha: 0.32), size: 16),
    );
  }

  Widget _glowCircle(double size, double opacity) => Container(
    width: size, height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: Colors.white.withValues(alpha: opacity),
    ),
  );

  // ── RIGHT PANEL ────────────────────────────────────────────────────────────
  Widget _buildLoginPanel() {
    return FadeTransition(
      opacity: _fadeAnim,
      child: SlideTransition(
        position: _slideAnim,
        child: Container(
          color: const Color(0xFFF7F8FC),
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                  horizontal: 48, vertical: 48),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Header
                      _buildHeader(),
                      const SizedBox(height: 32),

                      // Login card
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.06),
                              blurRadius: 40,
                              offset: const Offset(0, 8),
                            ),
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.03),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Role toggle
                            _buildRoleToggle(),
                            const SizedBox(height: 14),

                            // Role description
                            _buildRoleDescription(),
                            const SizedBox(height: 24),

                            // Error banner
                            if (_error != null) ...[
                              _buildErrorBanner(),
                              const SizedBox(height: 16),
                            ],

                            // Email field
                            _buildFieldLabel('Email Address'),
                            const SizedBox(height: 8),
                            _buildEmailField(),
                            const SizedBox(height: 16),

                            // Password field
                            _buildFieldLabel('Password'),
                            const SizedBox(height: 8),
                            _buildPasswordField(),
                            const SizedBox(height: 28),

                            // Sign in button
                            _buildSignInButton(),
                            const SizedBox(height: 20),

                            // Divider
                            _buildDivider(),
                            const SizedBox(height: 20),

                            // Google button
                            _buildGoogleButton(),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Register link
                      _buildRegisterLink(),

                      const SizedBox(height: 32),

                      // Footer
                      Center(
                        child: Text(
                          '© ${DateTime.now().year} City Government of Laoag · All rights reserved.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: const Color(0xFFBBBBBB),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: 'Welcome ',
                style: GoogleFonts.inter(
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF111111),
                  letterSpacing: -1.0,
                  height: 1.1,
                ),
              ),
              TextSpan(
                text: 'Admin',
                style: GoogleFonts.inter(
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary,
                  letterSpacing: -1.0,
                  height: 1.1,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Sign in to access the admin portal.',
          style: GoogleFonts.inter(
            fontSize: 14,
            color: const Color(0xFF888888),
            fontWeight: FontWeight.w400,
            height: 1.5,
          ),
        ),
      ],
    );
  }

  Widget _buildRoleToggle() {
    return Container(
      height: 48,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFF2F3F7),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          _buildRoleTab(
            label: 'Admin',
            icon: Icons.badge_rounded,
            selected: !_isSuperAdmin,
            onTap: () => setState(() => _isSuperAdmin = false),
          ),
          _buildRoleTab(
            label: 'Super Admin',
            icon: Icons.shield_rounded,
            selected: _isSuperAdmin,
            onTap: () => setState(() => _isSuperAdmin = true),
          ),
        ],
      ),
    );
  }

  Widget _buildRoleTab({
    required String label,
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          decoration: BoxDecoration(
            color: selected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon,
                  size: 15,
                  color: selected
                      ? AppColors.primary
                      : const Color(0xFFAAAAAA)),
              const SizedBox(width: 6),
              Text(label,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: selected
                        ? FontWeight.w700
                        : FontWeight.w500,
                    color: selected
                        ? AppColors.primary
                        : const Color(0xFFAAAAAA),
                  )),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRoleDescription() {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      child: Container(
        key: ValueKey(_isSuperAdmin),
        padding: const EdgeInsets.symmetric(
            horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: AppColors.primary.withValues(alpha: 0.12),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 28, height: 28,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                _isSuperAdmin
                    ? Icons.shield_rounded
                    : Icons.badge_rounded,
                color: AppColors.primary,
                size: 15,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _isSuperAdmin
                    ? 'Full system access — manage users, departments & activity.'
                    : 'Staff access — process assigned requests & update statuses.',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: AppColors.primary.withValues(alpha: 0.85),
                  fontWeight: FontWeight.w500,
                  height: 1.45,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF1F1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
            color: const Color(0xFFFFCDD2), width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline_rounded,
              color: Color(0xFFE53935), size: 16),
          const SizedBox(width: 10),
          Expanded(
            child: Text(_error!,
                style: GoogleFonts.inter(
                  color: const Color(0xFFB71C1C),
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  height: 1.4,
                )),
          ),
        ],
      ),
    );
  }

  Widget _buildFieldLabel(String label) {
    return Text(label,
        style: GoogleFonts.inter(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: const Color(0xFF333333),
          letterSpacing: 0.1,
        ));
  }

  Widget _buildEmailField() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: _emailFocused
            ? [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: TextField(
        controller: _emailController,
        focusNode: _emailFocus,
        keyboardType: TextInputType.emailAddress,
        textInputAction: TextInputAction.next,
        style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: const Color(0xFF111111)),
        decoration: _buildInputDecoration(
          hint: 'Enter your email address',
          icon: Icons.email_outlined,
          focused: _emailFocused,
        ),
      ),
    );
  }

  Widget _buildPasswordField() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: _passFocused
            ? [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: TextField(
        controller: _passwordController,
        focusNode: _passwordFocus,
        obscureText: !_showPassword,
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => _handleLogin(),
        style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: const Color(0xFF111111)),
        decoration: _buildInputDecoration(
          hint: 'Enter your password',
          icon: Icons.lock_outline_rounded,
          focused: _passFocused,
          suffix: GestureDetector(
            onTap: () =>
                setState(() => _showPassword = !_showPassword),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Icon(
                _showPassword
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                color: const Color(0xFFAAAAAA),
                size: 18,
              ),
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _buildInputDecoration({
    required String hint,
    required IconData icon,
    required bool focused,
    Widget? suffix,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.inter(
        color: const Color(0xFFCCCCCC),
        fontSize: 13,
        fontWeight: FontWeight.w400,
      ),
      prefixIcon: Padding(
        padding: const EdgeInsets.all(14),
        child: Icon(icon,
            color: focused
                ? AppColors.primary
                : const Color(0xFFCCCCCC),
            size: 18),
      ),
      suffixIcon: suffix,
      filled: true,
      fillColor: focused
          ? Colors.white
          : const Color(0xFFFAFAFC),
      contentPadding: const EdgeInsets.symmetric(
          horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(
            color: Color(0xFFEEEEEE), width: 1.5),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(
            color: Color(0xFFEEEEEE), width: 1.5),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide:
            const BorderSide(color: AppColors.primary, width: 2),
      ),
    );
  }

  Widget _buildSignInButton() {
    return SizedBox(
      height: 52,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _handleLogin,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          disabledBackgroundColor: Colors.transparent,
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
        ),
        child: Ink(
          decoration: BoxDecoration(
            gradient: _isLoading
                ? null
                : const LinearGradient(
                    colors: [Color(0xFFFF9200), Color(0xFFFF5E00)],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
            color: _isLoading
                ? const Color(0xFFEEEEEE)
                : null,
            borderRadius: BorderRadius.circular(12),
            boxShadow: _isLoading
                ? null
                : [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.35),
                      blurRadius: 14,
                      offset: const Offset(0, 5),
                    ),
                  ],
          ),
          child: Container(
            alignment: Alignment.center,
            child: _isLoading
                ? const SizedBox(
                    width: 22, height: 22,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2.5))
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.login_rounded,
                          color: Colors.white, size: 18),
                      const SizedBox(width: 10),
                      Text(
                        'Sign In as ${_isSuperAdmin ? "Super Admin" : "Admin"}',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Row(children: [
      Expanded(
          child: Container(height: 1,
              color: const Color(0xFFF0F0F0))),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Text('or',
            style: GoogleFonts.inter(
              color: const Color(0xFFCCCCCC),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            )),
      ),
      Expanded(
          child: Container(height: 1,
              color: const Color(0xFFF0F0F0))),
    ]);
  }

  Widget _buildGoogleButton() {
    return SizedBox(
      height: 50,
      child: OutlinedButton(
        onPressed: () => setState(
            () => _error = 'Google Sign-In is not yet available.'),
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
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF4285F4),
                )),
            const SizedBox(width: 12),
            Text('Continue with Google',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF444444),
                )),
          ],
        ),
      ),
    );
  }

  Widget _buildRegisterLink() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text("Don't have an account? ",
            style: GoogleFonts.inter(
                color: const Color(0xFF999999),
                fontSize: 13,
                fontWeight: FontWeight.w400)),
        GestureDetector(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => const AdminRegisterScreen()),
          ),
          child: Text('Request Access',
              style: GoogleFonts.inter(
                color: AppColors.primary,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              )),
        ),
      ],
    );
  }
}

// ── Helper classes ─────────────────────────────────────────────────────────
class _FeatureItem {
  final IconData icon;
  final String   label;
  const _FeatureItem({required this.icon, required this.label});
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.04)
      ..strokeWidth = 1;

    const spacing = 40.0;
    for (double x = 0; x < size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}