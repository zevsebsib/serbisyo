import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AdminRegisterScreen extends StatefulWidget {
  const AdminRegisterScreen({super.key});

  @override
  State<AdminRegisterScreen> createState() =>
      _AdminRegisterScreenState();
}

class _AdminRegisterScreenState
    extends State<AdminRegisterScreen>
    with SingleTickerProviderStateMixin {
  final _nameCtrl    = TextEditingController();
  final _emailCtrl   = TextEditingController();
  final _passCtrl    = TextEditingController();
  final _confirmCtrl = TextEditingController();

  bool    _showPass    = false;
  bool    _showConfirm = false;
  bool    _isLoading   = false;
  bool    _submitted   = false;
  String? _error;

  String _selectedDept = 'City Administration Office';
  final List<String> _departments = [
    'City Administration Office',
    'Office of the City Civil Registrar',
    'Office of the City Community Affairs',
  ];

  late final AnimationController _animCtrl;
  late final Animation<double>   _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 600));
    _fadeAnim = CurvedAnimation(
        parent: _animCtrl, curve: Curves.easeOut);
    _animCtrl.forward();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _confirmCtrl.dispose();
    _animCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name    = _nameCtrl.text.trim();
    final email   = _emailCtrl.text.trim();
    final pass    = _passCtrl.text;
    final confirm = _confirmCtrl.text;

    if (name.isEmpty || email.isEmpty ||
        pass.isEmpty || confirm.isEmpty) {
      setState(() => _error = 'Please fill in all fields.');
      return;
    }
    if (pass != confirm) {
      setState(() => _error = 'Passwords do not match.');
      return;
    }
    if (pass.length < 8) {
      setState(() =>
          _error = 'Password must be at least 8 characters.');
      return;
    }

    setState(() {
      _isLoading = true;
      _error     = null;
    });

    try {
      final cred = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
              email: email, password: pass);
      await cred.user?.updateDisplayName(name);
      await FirebaseFirestore.instance
          .collection('admin')
          .doc(cred.user!.uid)
          .set({
        'fullName':     name,
        'email':        email,
        'role':         'admin',
        'department':   _selectedDept,
        'departmentId': '',
        'isActive':     false,
        'createdAt':    FieldValue.serverTimestamp(),
        'updatedAt':    FieldValue.serverTimestamp(),
      });
      await FirebaseAuth.instance.signOut();
      if (mounted) {
        setState(() {
          _submitted = true;
          _isLoading = false;
        });
      }
    } on FirebaseAuthException catch (e) {
      String msg = 'Registration failed. Please try again.';
      if (e.code == 'email-already-in-use') {
        msg = 'An account with this email already exists.';
      } else if (e.code == 'invalid-email') {
        msg = 'Please enter a valid email address.';
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
          _error     = 'Error: ${e.toString()}';
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
        return Row(children: [
          SizedBox(
            width: (w * 0.38).clamp(280.0, 440.0),
            child: _buildSidebar(),
          ),
          Expanded(child: _buildFormPanel()),
        ]);
      }),
    );
  }

  // ── SIDEBAR ────────────────────────────────────────────────────────────────
  Widget _buildSidebar() {
    return Container(
      // ✅ Orange gradient background
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
            padding: const EdgeInsets.symmetric(
                horizontal: 32, vertical: 36),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Logo
                Row(children: [
                  Container(
                    width: 44, height: 44,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black
                              .withValues(alpha: 0.15),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.asset('assets/serbisyo.png',
                          fit: BoxFit.cover),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('SerbisyoAlisto',
                          style: GoogleFonts.dmSans(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          )),
                      Text('City Government of Laoag',
                          style: GoogleFonts.dmSans(
                            fontSize: 10,
                            color: Colors.white
                                .withValues(alpha: 0.80),
                          )),
                    ],
                  ),
                ]),

                const SizedBox(height: 40),

                // Tag badge
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.20),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                        color: Colors.white.withValues(alpha: 0.40)),
                  ),
                  child: Text('STAFF REGISTRATION',
                      style: GoogleFonts.dmSans(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        letterSpacing: 1.5,
                      )),
                ),

                const SizedBox(height: 14),

                Text('Request\nAdmin Access',
                    style: GoogleFonts.dmSans(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      height: 1.25,
                    )),

                const SizedBox(height: 12),

                Text(
                  'Fill in the form to request an admin account. Your request will be reviewed by a superadmin before activation.',
                  style: GoogleFonts.dmSans(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.82),
                    height: 1.7,
                  ),
                ),

                const SizedBox(height: 32),

                Container(
                    height: 1,
                    color: Colors.white.withValues(alpha: 0.25)),
                const SizedBox(height: 28),

                // Steps
                _step('01', 'Complete the form',
                    'Provide your name, email, department and password.'),
                const SizedBox(height: 20),
                _step('02', 'Await superadmin review',
                    'A superadmin will verify and activate your account.'),
                const SizedBox(height: 20),
                _step('03', 'Access the portal',
                    'Once approved, sign in to start managing requests.'),

                const SizedBox(height: 32),

                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: Colors.white.withValues(alpha: 0.25)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.info_outline_rounded,
                          size: 14,
                          color: Colors.white.withValues(alpha: 0.85)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Only authorized City Government of Laoag employees may register.',
                          style: GoogleFonts.dmSans(
                            fontSize: 11,
                            color:
                                Colors.white.withValues(alpha: 0.85),
                            height: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const Spacer(),

                Text(
                  '© ${DateTime.now().year} City Government of Laoag',
                  style: GoogleFonts.dmSans(
                    fontSize: 10,
                    color: Colors.white.withValues(alpha: 0.60),
                  ),
                ),
              ],
            ),
          ),
        ),
      ]),
    );
  }

  Widget _step(String num, String title, String desc) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 26, height: 26,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.20),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
                color: Colors.white.withValues(alpha: 0.35)),
          ),
          child: Center(
            child: Text(num,
                style: GoogleFonts.dmSans(
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                )),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: GoogleFonts.dmSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  )),
              const SizedBox(height: 3),
              Text(desc,
                  style: GoogleFonts.dmSans(
                    fontSize: 11,
                    color: Colors.white.withValues(alpha: 0.75),
                    height: 1.5,
                  )),
            ],
          ),
        ),
      ],
    );
  }

  // ── FORM PANEL ─────────────────────────────────────────────────────────────
  Widget _buildFormPanel() {
    return Container(
      color: const Color(0xFFF0F2F5),
      child: Center(
        child: FadeTransition(
          opacity: _fadeAnim,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(40),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: _submitted ? _buildSuccess() : _buildForm(),
            ),
          ),
        ),
      ),
    );
  }

  // ── SUCCESS ────────────────────────────────────────────────────────────────
  Widget _buildSuccess() {
    return Column(
      children: [
        Container(
          width: 72, height: 72,
          decoration: BoxDecoration(
            color: const Color(0xFF16A34A).withValues(alpha: 0.10),
            shape: BoxShape.circle,
            border: Border.all(
                color: const Color(0xFF16A34A)
                    .withValues(alpha: 0.25)),
          ),
          child: const Icon(Icons.check_rounded,
              color: Color(0xFF16A34A), size: 36),
        ),
        const SizedBox(height: 24),
        Text('Request Submitted',
            style: GoogleFonts.dmSans(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF111827),
            )),
        const SizedBox(height: 10),
        Text(
          'Your account request has been submitted. A superadmin will review and activate your account before you can log in.',
          textAlign: TextAlign.center,
          style: GoogleFonts.dmSans(
            fontSize: 13,
            color: const Color(0xFF6B7280),
            height: 1.6,
          ),
        ),
        const SizedBox(height: 28),
        SizedBox(
          width: double.infinity, height: 46,
          child: ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF7A00),
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: Text('Back to Login',
                style: GoogleFonts.dmSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.white)),
          ),
        ),
      ],
    );
  }

  // ── FORM ───────────────────────────────────────────────────────────────────
  Widget _buildForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Row(children: [
            const Icon(Icons.arrow_back_rounded,
                size: 15, color: Color(0xFF6B7280)),
            const SizedBox(width: 6),
            Text('Back to Login',
                style: GoogleFonts.dmSans(
                    fontSize: 13,
                    color: const Color(0xFF6B7280))),
          ]),
        ),

        const SizedBox(height: 24),

        Text('Request Access',
            style: GoogleFonts.dmSans(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF111827),
            )),
        const SizedBox(height: 6),
        Text(
            'Fill in your details below to request an admin account.',
            style: GoogleFonts.dmSans(
                fontSize: 13, color: const Color(0xFF6B7280))),

        const SizedBox(height: 24),

        // Error
        if (_error != null) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF2F2),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                  color: const Color(0xFFFECACA)),
            ),
            child: Row(children: [
              const Icon(Icons.error_outline_rounded,
                  size: 15, color: Color(0xFFDC2626)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(_error!,
                    style: GoogleFonts.dmSans(
                      fontSize: 12,
                      color: const Color(0xFF991B1B),
                    )),
              ),
            ]),
          ),
          const SizedBox(height: 16),
        ],

        // Form card
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE5E7EB)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 20,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sectionLabel('Personal Information'),
              const SizedBox(height: 14),
              _label('Full Name'),
              const SizedBox(height: 8),
              _field(
                controller: _nameCtrl,
                hint: 'e.g. Juan Dela Cruz',
                icon: Icons.person_outline_rounded,
              ),
              const SizedBox(height: 14),
              _label('Email Address'),
              const SizedBox(height: 8),
              _field(
                controller: _emailCtrl,
                hint: 'e.g. juan@laoag.gov.ph',
                icon: Icons.email_outlined,
                type: TextInputType.emailAddress,
              ),

              const SizedBox(height: 22),

              _sectionLabel('Department Assignment'),
              const SizedBox(height: 14),
              _label('Department'),
              const SizedBox(height: 8),
              _deptDropdown(),

              const SizedBox(height: 22),

              _sectionLabel('Account Security'),
              const SizedBox(height: 14),
              _label('Password'),
              const SizedBox(height: 8),
              _field(
                controller: _passCtrl,
                hint: 'Minimum 8 characters',
                icon: Icons.lock_outline_rounded,
                obscure: !_showPass,
                suffix: _eyeToggle(_showPass,
                    () => setState(() => _showPass = !_showPass)),
              ),
              const SizedBox(height: 14),
              _label('Confirm Password'),
              const SizedBox(height: 8),
              _field(
                controller: _confirmCtrl,
                hint: 'Re-enter your password',
                icon: Icons.lock_outline_rounded,
                obscure: !_showConfirm,
                suffix: _eyeToggle(_showConfirm, () => setState(
                    () => _showConfirm = !_showConfirm)),
              ),
              const SizedBox(height: 10),
              Row(children: [
                const Icon(Icons.info_outline_rounded,
                    size: 12, color: Color(0xFF9CA3AF)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Use at least 8 characters with a mix of letters and numbers.',
                    style: GoogleFonts.dmSans(
                        fontSize: 11,
                        color: const Color(0xFF9CA3AF)),
                  ),
                ),
              ]),
            ],
          ),
        ),

        const SizedBox(height: 20),

        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _submit,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF7A00),
              disabledBackgroundColor: const Color(0xFFFF7A00)
                  .withValues(alpha: 0.50),
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: _isLoading
                ? const SizedBox(
                    width: 20, height: 20,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2))
                : Text('Submit Request',
                    style: GoogleFonts.dmSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    )),
          ),
        ),

        const SizedBox(height: 16),

        Center(
          child: Text(
            '© ${DateTime.now().year} City Government of Laoag · All rights reserved.',
            style: GoogleFonts.dmSans(
                fontSize: 10,
                color: const Color(0xFFBBBBBB)),
          ),
        ),
      ],
    );
  }

  Widget _sectionLabel(String text) {
    return Row(children: [
      Container(
          width: 3, height: 14,
          decoration: BoxDecoration(
            color: const Color(0xFFFF7A00),
            borderRadius: BorderRadius.circular(2),
          )),
      const SizedBox(width: 8),
      Text(text,
          style: GoogleFonts.dmSans(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF374151),
            letterSpacing: 0.2,
          )),
    ]);
  }

  Widget _label(String text) {
    return Text(text,
        style: GoogleFonts.dmSans(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: const Color(0xFF374151),
        ));
  }

  Widget _field({
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
      style: GoogleFonts.dmSans(
          fontSize: 13, color: const Color(0xFF111827)),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.dmSans(
            color: const Color(0xFFD1D5DB), fontSize: 13),
        prefixIcon: Icon(icon,
            size: 16, color: const Color(0xFFD1D5DB)),
        suffixIcon: suffix,
        filled: true,
        fillColor: const Color(0xFFF9FAFB),
        contentPadding: const EdgeInsets.symmetric(
            horizontal: 14, vertical: 13),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(9),
          borderSide:
              const BorderSide(color: Color(0xFFE5E7EB)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(9),
          borderSide:
              const BorderSide(color: Color(0xFFE5E7EB)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(9),
          borderSide: const BorderSide(
              color: Color(0xFFFF7A00), width: 1.5),
        ),
      ),
    );
  }

  Widget _deptDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: 14, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedDept,
          isExpanded: true,
          icon: const Icon(Icons.unfold_more_rounded,
              size: 16, color: Color(0xFF9CA3AF)),
          style: GoogleFonts.dmSans(
              fontSize: 13, color: const Color(0xFF111827)),
          selectedItemBuilder: (context) => _departments
              .map((d) => Align(
                    alignment: Alignment.centerLeft,
                    child: Text(d,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.dmSans(
                            fontSize: 13,
                            color: const Color(0xFF111827))),
                  ))
              .toList(),
          items: _departments.map((d) {
            final sel = d == _selectedDept;
            return DropdownMenuItem(
              value: d,
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(vertical: 6),
                child: Row(children: [
                  Icon(Icons.business_outlined,
                      size: 14,
                      color: sel
                          ? const Color(0xFFFF7A00)
                          : const Color(0xFF9CA3AF)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(d,
                        style: GoogleFonts.dmSans(
                          fontSize: 13,
                          fontWeight: sel
                              ? FontWeight.w600
                              : FontWeight.w400,
                          color: sel
                              ? const Color(0xFFFF7A00)
                              : const Color(0xFF374151),
                        )),
                  ),
                  if (sel)
                    const Icon(Icons.check_rounded,
                        size: 14,
                        color: Color(0xFFFF7A00)),
                ]),
              ),
            );
          }).toList(),
          onChanged: (v) =>
              setState(() => _selectedDept = v!),
        ),
      ),
    );
  }

  Widget _eyeToggle(bool show, VoidCallback onTap) {
    return IconButton(
      icon: Icon(
        show
            ? Icons.visibility_off_outlined
            : Icons.visibility_outlined,
        size: 17,
        color: const Color(0xFF9CA3AF),
      ),
      onPressed: onTap,
    );
  }

  Widget _buildMobileLayout() {
    return Container(
      color: const Color(0xFFF0F2F5),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Column(children: [
              const SizedBox(height: 16),
              _submitted ? _buildSuccess() : _buildForm(),
            ]),
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
    const spacing = 22.0;
    for (double x = spacing; x < size.width; x += spacing) {
      for (double y = spacing; y < size.height; y += spacing) {
        canvas.drawCircle(Offset(x, y), 1.2, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter _) => false;
}