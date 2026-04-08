import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'admin_register_screen.dart';

class _SidebarFeature {
  final String   title;
  final String   subtitle;
  final IconData icon;
  const _SidebarFeature(this.title, this.subtitle, this.icon);
}

class AdminLoginScreen extends StatefulWidget {
  const AdminLoginScreen({super.key});

  @override
  State<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends State<AdminLoginScreen>
    with SingleTickerProviderStateMixin {
  final _emailController    = TextEditingController();
  final _passwordController = TextEditingController();
  final _emailFocus         = FocusNode();
  final _passwordFocus      = FocusNode();

  bool    _showPassword = false;
  bool    _isLoading    = false;
  bool    _isSuperAdmin = false;
  String? _error;

  late final AnimationController _animCtrl;
  late final Animation<double>   _fadeAnim;
  late final Animation<Offset>   _slideAnim;

  static const List<_SidebarFeature> _sidebarFeatures = [
    _SidebarFeature(
      'Requests',
      'View and manage all citizen service requests',
      Icons.inbox_rounded,
    ),
    _SidebarFeature(
      'Staff',
      'Assign and monitor staff task progress',
      Icons.people_alt_rounded,
    ),
    _SidebarFeature(
      'Reports',
      'Generate reports and track performance',
      Icons.bar_chart_rounded,
    ),
    _SidebarFeature(
      'Notifications',
      'Send updates to citizens instantly',
      Icons.notifications_outlined,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 700));
    _fadeAnim = CurvedAnimation(
        parent: _animCtrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(CurvedAnimation(
        parent: _animCtrl, curve: Curves.easeOutCubic));
    _animCtrl.forward();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    _animCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    final email    = _emailController.text.trim();
    final password = _passwordController.text;
    if (email.isEmpty || password.isEmpty) {
      setState(() =>
          _error = 'Please enter your email and password.');
      return;
    }
    setState(() {
      _isLoading = true;
      _error     = null;
    });
    try {
      final cred = await FirebaseAuth.instance
          .signInWithEmailAndPassword(
              email: email, password: password);
      await _checkAdminAccess(cred.user!.uid);
    } on FirebaseAuthException catch (e) {
      String msg = 'Login failed. Please try again.';
      if (e.code == 'user-not-found' ||
          e.code == 'wrong-password' ||
          e.code == 'invalid-credential') {
        msg = 'Invalid email or password.';
      } else if (e.code == 'invalid-email') {
        msg = 'Please enter a valid email address.';
      } else if (e.code == 'too-many-requests') {
        msg = 'Too many attempts. Try again later.';
      }
      if (mounted) {
        setState(() {
          _error     = msg;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error     = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _checkAdminAccess(String uid) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('admin')
          .doc(uid)
          .get();

      if (!doc.exists) {
        await FirebaseAuth.instance.signOut();
        if (mounted) {
          setState(() {
            _error =
                'No admin account found for this email.';
            _isLoading = false;
          });
        }
        return;
      }

      final data         = doc.data()!;
      final role         = data['role'] ?? '';
      final expectedRole = _isSuperAdmin ? 'superadmin' : 'admin';

      if (role != expectedRole) {
        await FirebaseAuth.instance.signOut();
        if (mounted) {
          setState(() {
            _error = _isSuperAdmin
                ? 'This account is not a Super Admin.'
                : 'This account is not a Staff Admin.';
            _isLoading = false;
          });
        }
        return;
      }

      if (data['isActive'] == false) {
        await FirebaseAuth.instance.signOut();
        if (mounted) {
          setState(() {
            _error =
                'Account pending approval. Contact your superadmin.';
            _isLoading = false;
          });
        }
        return;
      }

      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/admin');
    } catch (e) {
      await FirebaseAuth.instance.signOut();
      if (mounted) {
        setState(() {
          _error     = 'Authentication error: ${e.toString()}';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      body: LayoutBuilder(builder: (ctx, constraints) {
        final w = constraints.maxWidth;
        if (w < 720) return _buildMobileLayout();
        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(flex: 4, child: _buildSidebar()),
            Expanded(flex: 6, child: _buildFormPanel()),
          ],
        );
      }),
    );
  }

  Widget _buildSidebar() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 360;
        final sidebarPadding = isCompact ? 20.0 : 36.0;
        final logoSize = isCompact ? 72.0 : 100.0;
        final titleSize = isCompact ? 24.0 : 30.0;

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
          child: Stack(children: [
        Positioned.fill(
          child: CustomPaint(painter: _DotGridPainter()),
        ),
        Positioned(
          top: 0, left: 0, right: 0,
          child: Container(
              height: 4,
              color: Colors.black.withValues(alpha: 0.15)),
        ),
        SafeArea(
          child: Padding(
            padding: EdgeInsets.symmetric(
                horizontal: sidebarPadding, vertical: 40),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                Row(children: [
                  Container(
                    width: logoSize, height: logoSize,
                    decoration: BoxDecoration(
                      color: Colors.transparent,
                      shape: BoxShape.circle,
                    ),
                    child: ClipOval(
                      child: Image.asset(
                          'assets/logo.jpg',
                          fit: BoxFit.contain),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        Text('SerbisyoAlisto',
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.dmSans(
                              fontSize: titleSize,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            )),
                        Text('City Government of Laoag',
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.dmSans(
                              fontSize: 11,
                              color: Colors.white
                                  .withValues(alpha: 0.80),
                            )),
                      ],
                    ),
                  ),
                ]),

                const SizedBox(height: 48),

                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.20),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                        color: Colors.white
                            .withValues(alpha: 0.40)),
                  ),
                  child: Text('ADMIN PORTAL',
                      style: GoogleFonts.dmSans(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        letterSpacing: 2,
                      )),
                ),

                const SizedBox(height: 16),

                Text('Centralized\nService Management',
                    style: GoogleFonts.dmSans(
                      fontSize: isCompact ? 24 : 28,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      height: 1.25,
                    )),

                const SizedBox(height: 14),

                Text(
                  'Manage citizen service requests, assign tasks to staff, and monitor progress — all in one place.',
                  style: GoogleFonts.dmSans(
                    fontSize: 13,
                    color: Colors.white.withValues(alpha: 0.82),
                    height: 1.7,
                  ),
                ),

                const SizedBox(height: 40),

                Container(
                    height: 1,
                    color: Colors.white.withValues(alpha: 0.25)),
                const SizedBox(height: 32),

                ..._sidebarFeatures.map((f) => Padding(
                      padding: const EdgeInsets.only(bottom: 22),
                      child: Row(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 36, height: 36,
                            decoration: BoxDecoration(
                              color: Colors.white
                                  .withValues(alpha: 0.18),
                              borderRadius:
                                  BorderRadius.circular(10),
                              border: Border.all(
                                  color: Colors.white
                                      .withValues(alpha: 0.25)),
                            ),
                            child: Icon(f.icon,
                                size: 17, color: Colors.white),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Text(f.title,
                                    style: GoogleFonts.dmSans(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                    )),
                                const SizedBox(height: 2),
                                Text(f.subtitle,
                                    style: GoogleFonts.dmSans(
                                      fontSize: 11,
                                      color: Colors.white
                                          .withValues(alpha: 0.75),
                                      height: 1.5,
                                    )),
                              ],
                            ),
                          ),
                        ],
                      ),
                    )),

                  const SizedBox(height: 10),

                Container(
                    height: 1,
                    color: Colors.white.withValues(alpha: 0.25)),
                const SizedBox(height: 20),

                Text(
                  '© ${DateTime.now().year} City Government of Laoag.\nAll rights reserved.',
                  style: GoogleFonts.dmSans(
                    fontSize: 20,
                    color: Colors.white.withValues(alpha: 0.65),
                    height: 1.6,
                  ),
                ),
                ],
              ),
            ),
          ),
        ),
      ]),
        );
      },
    );
  }

  Widget _buildFormPanel() {
    return Container(
      color: const Color(0xFFF0F2F5),
      child: Center(
        child: FadeTransition(
          opacity: _fadeAnim,
          child: SlideTransition(
            position: _slideAnim,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(40),
              child: ConstrainedBox(
                constraints:
                    const BoxConstraints(maxWidth: 420),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildFormHeader(),
                    const SizedBox(height: 28),
                    _buildCard(),
                    const SizedBox(height: 20),
                    _buildRegisterLink(),
                    const SizedBox(height: 24),
                    Center(
                      child: Text(
                        '© ${DateTime.now().year} City Government of Laoag',
                        style: GoogleFonts.dmSans(
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
    );
  }

  Widget _buildFormHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Welcome!',
            style: GoogleFonts.dmSans(
              fontSize: 26,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF111827),
            )),
        const SizedBox(height: 6),
        Text('Sign in to your admin account to continue.',
            style: GoogleFonts.dmSans(
              fontSize: 13,
              color: const Color(0xFF6B7280),
            )),
      ],
    );
  }

  Widget _buildCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 24,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildRoleToggle(),
          const SizedBox(height: 24),
          if (_error != null) ...[
            _buildError(),
            const SizedBox(height: 16),
          ],
          _label('Email Address'),
          const SizedBox(height: 8),
          _inputField(
            controller: _emailController,
            focusNode: _emailFocus,
            hint: 'Enter your email address',
            icon: Icons.email_outlined,
            type: TextInputType.emailAddress,
            action: TextInputAction.next,
          ),
          const SizedBox(height: 16),
          _label('Password'),
          const SizedBox(height: 8),
          _inputField(
            controller: _passwordController,
            focusNode: _passwordFocus,
            hint: 'Enter your password',
            icon: Icons.lock_outline_rounded,
            obscure: !_showPassword,
            action: TextInputAction.done,
            onSubmit: (_) => _handleLogin(),
            suffix: IconButton(
              icon: Icon(
                _showPassword
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                size: 18,
                color: const Color(0xFF9CA3AF),
              ),
              onPressed: () => setState(
                  () => _showPassword = !_showPassword),
            ),
          ),
          const SizedBox(height: 24),
          // ✅ Only email/password — Google removed
          _buildSignInBtn(),
        ],
      ),
    );
  }

  Widget _buildRoleToggle() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label('Sign in as'),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFFF9FAFB),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          padding: const EdgeInsets.all(4),
          child: Row(children: [
            _roleTab('Staff Admin', Icons.badge_outlined,
                !_isSuperAdmin,
                () => setState(() => _isSuperAdmin = false)),
            _roleTab('Super Admin', Icons.shield_outlined,
                _isSuperAdmin,
                () => setState(() => _isSuperAdmin = true)),
          ]),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(
              horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF7ED),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
                color: const Color(0xFFFF7A00)
                    .withValues(alpha: 0.20)),
          ),
          child: Row(children: [
            Icon(
              _isSuperAdmin
                  ? Icons.shield_outlined
                  : Icons.badge_outlined,
              size: 14,
              color: const Color(0xFFFF7A00),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _isSuperAdmin
                    ? 'Full system access — manage users, departments & all activity.'
                    : 'Staff access — process assigned requests & update statuses.',
                style: GoogleFonts.dmSans(
                  fontSize: 11,
                  color: const Color(0xFFB45309),
                  height: 1.5,
                ),
              ),
            ),
          ]),
        ),
      ],
    );
  }

  Widget _roleTab(String label, IconData icon, bool selected,
      VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(7),
            border: selected
                ? Border.all(color: const Color(0xFFE5E7EB))
                : null,
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: Colors.black
                          .withValues(alpha: 0.06),
                      blurRadius: 6,
                      offset: const Offset(0, 1),
                    )
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon,
                  size: 14,
                  color: selected
                      ? const Color(0xFFFF7A00)
                      : const Color(0xFF9CA3AF)),
              const SizedBox(width: 6),
              Flexible(
                child: Text(label,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.dmSans(
                      fontSize: 12,
                      fontWeight: selected
                          ? FontWeight.w600
                          : FontWeight.w400,
                      color: selected
                          ? const Color(0xFF111827)
                          : const Color(0xFF9CA3AF),
                    )),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildError() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFFECACA)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline_rounded,
              size: 15, color: Color(0xFFDC2626)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(_error!,
                style: GoogleFonts.dmSans(
                  fontSize: 12,
                  color: const Color(0xFF991B1B),
                  height: 1.4,
                )),
          ),
        ],
      ),
    );
  }

  Widget _label(String text) {
    return Text(text,
        style: GoogleFonts.dmSans(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: const Color(0xFF374151),
        ));
  }

  Widget _inputField({
    required TextEditingController controller,
    required FocusNode focusNode,
    required String hint,
    required IconData icon,
    bool obscure = false,
    TextInputType? type,
    TextInputAction? action,
    ValueChanged<String>? onSubmit,
    Widget? suffix,
  }) {
    return TextField(
      controller: controller,
      focusNode: focusNode,
      obscureText: obscure,
      keyboardType: type,
      textInputAction: action,
      onSubmitted: onSubmit,
      style: GoogleFonts.dmSans(
          fontSize: 14, color: const Color(0xFF111827)),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.dmSans(
            color: const Color(0xFFD1D5DB), fontSize: 13),
        prefixIcon:
            Icon(icon, size: 17, color: const Color(0xFFD1D5DB)),
        suffixIcon: suffix,
        filled: true,
        fillColor: const Color(0xFFF9FAFB),
        contentPadding: const EdgeInsets.symmetric(
            horizontal: 14, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide:
              const BorderSide(color: Color(0xFFE5E7EB)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide:
              const BorderSide(color: Color(0xFFE5E7EB)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(
              color: Color(0xFFFF7A00), width: 1.5),
        ),
      ),
    );
  }

  Widget _buildSignInBtn() {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _handleLogin,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFFF7A00),
          disabledBackgroundColor:
              const Color(0xFFFF7A00).withValues(alpha: 0.50),
          elevation: 0,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10)),
        ),
        child: _isLoading
            ? const SizedBox(
                width: 20, height: 20,
                child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2))
            : Text(
                'Sign In as ${_isSuperAdmin ? 'Super Admin' : 'Staff Admin'}',
                style: GoogleFonts.dmSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                )),
      ),
    );
  }

  Widget _buildRegisterLink() {
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text("Don't have an account? ",
            style: GoogleFonts.dmSans(
                fontSize: 13,
                color: const Color(0xFF6B7280))),
        GestureDetector(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => const AdminRegisterScreen()),
          ),
          child: Text('Request Access',
              style: GoogleFonts.dmSans(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: const Color(0xFFFF7A00),
              )),
        ),
      ],
    );
  }

  Widget _buildMobileLayout() {
    return Container(
      color: const Color(0xFFF0F2F5),
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints:
                  const BoxConstraints(maxWidth: 420),
              child: Column(
                children: [
                  Row(
                      mainAxisAlignment:
                          MainAxisAlignment.center,
                      children: [
                    Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(
                        color: Colors.transparent,
                        shape: BoxShape.circle,
                      ),
                      child: ClipOval(
                        child: Image.asset('assets/logo.jpg',
                            fit: BoxFit.contain),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        Text('SerbisyoAlisto',
                            style: GoogleFonts.dmSans(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF111827),
                            )),
                        Text('Admin Portal',
                            style: GoogleFonts.dmSans(
                                fontSize: 11,
                                color:
                                    const Color(0xFF6B7280))),
                      ],
                    ),
                  ]),
                  const SizedBox(height: 28),
                  _buildFormHeader(),
                  const SizedBox(height: 20),
                  _buildCard(),
                  const SizedBox(height: 16),
                  _buildRegisterLink(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DotGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.08)
      ..style = PaintingStyle.fill;
    const spacing = 24.0;
    for (double x = spacing; x < size.width; x += spacing) {
      for (double y = spacing; y < size.height; y += spacing) {
        canvas.drawCircle(Offset(x, y), 1.2, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter _) => false;
}