import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _showPassword    = false;
  bool _rememberMe      = false;
  bool _isError         = false;
  bool _isLoading       = false;
  bool _isGoogleLoading = false;

  final _emailController    = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey            = GlobalKey<FormState>();

  // ── Google Sign-In (v6.x API) ─────────────────────────────────────
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile'],
    serverClientId:
        '337041247718-sf466mblbrva1o84ddeka87pcvvi55q8.apps.googleusercontent.com',
  );

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // ── Email/password login ───────────────────────────────────────────
  Future<void> _handleLogin() async {
    final email    = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      _triggerError('Please enter your email and password.');
      return;
    }

    setState(() => _isLoading = true);
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email, password: password,
      );
      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed('/');
    } on FirebaseAuthException catch (error) {
      if (!mounted) return;
      String message = 'Login failed. Please try again.';
      if (error.code == 'user-not-found' ||
          error.code == 'wrong-password' ||
          error.code == 'invalid-credential') {
        message = 'Invalid email or password.';
      } else if (error.code == 'invalid-email') {
        message = 'Please enter a valid email address.';
      } else if (error.code == 'too-many-requests') {
        message =
            'Too many attempts. Please try again later.';
      }
      _triggerError(message);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── Google Sign-In ─────────────────────────────────────────────────
  Future<void> _handleGoogleSignIn() async {
    setState(() => _isGoogleLoading = true);
    try {
      // Sign out first to force account picker every time
      await _googleSignIn.signOut();

      // Trigger the Google sign-in flow
      final GoogleSignInAccount? googleUser =
          await _googleSignIn.signIn();

      // User cancelled
      if (googleUser == null) {
        if (mounted) {
          setState(() => _isGoogleLoading = false);
        }
        return;
      }

      // Get authentication tokens
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      // Create Firebase credential
      final OAuthCredential credential =
          GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken:     googleAuth.idToken,
      );

      // Sign in to Firebase
      final UserCredential userCredential =
          await FirebaseAuth.instance
              .signInWithCredential(credential);

      final User? user = userCredential.user;
      if (user == null) {
        _triggerError(
            'Google Sign-In failed. Please try again.');
        return;
      }

      // ── Save/update user in Firestore ──────────────────────────────
      final userDoc = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid);

      final docSnap = await userDoc.get();

      if (!docSnap.exists) {
        // First time login — create full citizen document
        await userDoc.set({
          'fullName':        user.displayName ?? '',
          'email':           user.email ?? '',
          'phone':           '',
          'role':            'citizen',
          'profileImageUrl': user.photoURL ?? '',
          'isActive':        true,
          'fcmToken':        '',
          'createdAt':       FieldValue.serverTimestamp(),
          'updatedAt':       FieldValue.serverTimestamp(),
        });
      } else {
        // Returning user — update name + photo only
        await userDoc.update({
          'fullName': user.displayName ??
              docSnap.data()?['fullName'] ?? '',
          'profileImageUrl': user.photoURL ??
              docSnap.data()?['profileImageUrl'] ?? '',
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed('/');
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      String msg = 'Google Sign-In failed. Please try again.';
      if (e.code ==
          'account-exists-with-different-credential') {
        msg = 'An account already exists with this email '
            'using a different sign-in method.';
      } else if (e.code == 'network-request-failed') {
        msg = 'Network error. Please check your connection.';
      }
      _triggerError(msg);
    } catch (e) {
      if (!mounted) return;
      _triggerError('Google Sign-In failed: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _isGoogleLoading = false);
    }
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
            const Icon(LucideIcons.alertCircle,
                color: Colors.white, size: 18),
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

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SingleChildScrollView(
        child: Column(
          children: [
            // ── Header banner ────────────────────────────────────────
            Container(
              width: double.infinity,
              height: size.height * 0.30,
              decoration: const BoxDecoration(
                gradient: AppColors.headerGradient,
                borderRadius: BorderRadius.only(
                  bottomLeft:  Radius.circular(36),
                  bottomRight: Radius.circular(36),
                ),
              ),
              child: SafeArea(
                bottom: false,
                child: Stack(
                  children: [
                    Positioned(
                      top: -30, right: -30,
                      child: Container(
                        width: 160, height: 160,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white
                              .withValues(alpha: 0.07),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 10, left: -50,
                      child: Container(
                        width: 140, height: 140,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white
                              .withValues(alpha: 0.05),
                        ),
                      ),
                    ),
                    Center(
                      child: Column(
                        mainAxisAlignment:
                            MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 80, height: 80,
                            padding: const EdgeInsets.all(3),
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                            child: ClipOval(
                              child: Image.asset(
                                  'assets/logo.jpg',
                                  fit: BoxFit.cover),
                            ),
                          ),
                          const SizedBox(height: 14),
                          Text('SerbisyoAlisto',
                              style: GoogleFonts.inter(
                                fontSize: 26,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                letterSpacing: -1,
                              )),
                          const SizedBox(height: 4),
                          Text('Laoag City Services',
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: Colors.white
                                    .withValues(alpha: 0.80),
                              )),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Form ─────────────────────────────────────────────────
            Padding(
              padding:
                  const EdgeInsets.fromLTRB(24, 28, 24, 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Welcome', style: AppTextStyles.h1),
                  const SizedBox(height: 4),
                  Text(
                      'Sign in to your account to continue.',
                      style: AppTextStyles.bodyMuted),

                  const SizedBox(height: 28),

                  Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        // Email
                        _buildFieldLabel('Email address'),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _emailController,
                          keyboardType:
                              TextInputType.emailAddress,
                          textInputAction:
                              TextInputAction.next,
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.w500,
                            fontSize: 15,
                            color: AppColors.secondary,
                          ),
                          decoration: InputDecoration(
                            hintText: 'you@email.com',
                            prefixIcon: Icon(
                              LucideIcons.mail,
                              size: 18,
                              color: _isError
                                  ? AppColors.danger
                                  : AppColors.muted,
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius:
                                  BorderRadius.circular(
                                      AppRadius.md),
                              borderSide: BorderSide(
                                color: _isError
                                    ? AppColors.danger
                                    : AppColors.divider,
                                width: 1.5,
                              ),
                            ),
                          ),
                        ).animate(target: _isError ? 1 : 0)
                            .shakeX(
                              hz: 8,
                              amount: 8,
                              duration: 400.ms,
                            ),

                        const SizedBox(height: 18),

                        // Password
                        _buildFieldLabel('Password'),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _passwordController,
                          obscureText: !_showPassword,
                          textInputAction:
                              TextInputAction.done,
                          onSubmitted: (_) => _handleLogin(),
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.w500,
                            fontSize: 15,
                            color: AppColors.secondary,
                          ),
                          decoration: InputDecoration(
                            hintText: '••••••••',
                            prefixIcon: Icon(
                              LucideIcons.lock,
                              size: 18,
                              color: _isError
                                  ? AppColors.danger
                                  : AppColors.muted,
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius:
                                  BorderRadius.circular(
                                      AppRadius.md),
                              borderSide: BorderSide(
                                color: _isError
                                    ? AppColors.danger
                                    : AppColors.divider,
                                width: 1.5,
                              ),
                            ),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _showPassword
                                    ? LucideIcons.eyeOff
                                    : LucideIcons.eye,
                                size: 18,
                                color: AppColors.muted,
                              ),
                              onPressed: () => setState(() =>
                                  _showPassword =
                                      !_showPassword),
                            ),
                          ),
                        ).animate(target: _isError ? 1 : 0)
                            .shakeX(
                              hz: 8,
                              amount: 8,
                              duration: 400.ms,
                            ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Remember me + Forgot password
                  Row(
                    mainAxisAlignment:
                        MainAxisAlignment.spaceBetween,
                    children: [
                      Row(children: [
                        SizedBox(
                          width: 22, height: 22,
                          child: Checkbox(
                            value: _rememberMe,
                            onChanged: (v) => setState(() =>
                                _rememberMe = v ?? false),
                            activeColor: AppColors.primary,
                            side: const BorderSide(
                                color: AppColors.muted,
                                width: 1.5),
                            shape: RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.circular(5)),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text('Remember me',
                            style: AppTextStyles.small
                                .copyWith(
                              color: AppColors.secondary,
                              fontWeight: FontWeight.w500,
                            )),
                      ]),
                      TextButton(
                        onPressed: () => Navigator.pushNamed(
                            context, '/forgot_password'),
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize
                              .shrinkWrap,
                        ),
                        child: Text('Forgot password?',
                            style: AppTextStyles.small
                                .copyWith(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w600,
                            )),
                      ),
                    ],
                  ),

                  const SizedBox(height: 28),

                  // Sign In button
                  SizedBox(
                    width: double.infinity,
                    child: AnimatedContainer(
                      duration:
                          const Duration(milliseconds: 200),
                      decoration: BoxDecoration(
                        gradient: _isLoading
                            ? null
                            : AppColors.primaryGradient,
                        color: _isLoading
                            ? AppColors.muted
                                .withValues(alpha: 0.3)
                            : null,
                        borderRadius: BorderRadius.circular(
                            AppRadius.lg),
                        boxShadow: _isLoading
                            ? []
                            : AppShadows.primary,
                      ),
                      child: ElevatedButton(
                        onPressed: _isLoading
                            ? null
                            : _handleLogin,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          disabledBackgroundColor:
                              Colors.transparent,
                          shadowColor: Colors.transparent,
                          padding: const EdgeInsets.symmetric(
                              vertical: 17),
                          shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(
                                    AppRadius.lg),
                          ),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                width: 22, height: 22,
                                child:
                                    CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: AppColors.primary,
                                ))
                            : Text('Sign In',
                                style: GoogleFonts.inter(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                  color: Colors.white,
                                  letterSpacing: 0.3,
                                )),
                      ),
                    ),
                  ),

                  const SizedBox(height: 36),

                  // Divider
                  Row(children: [
                    Expanded(
                        child: Divider(
                            color: AppColors.divider,
                            thickness: 1)),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14),
                      child: Text('or continue with',
                          style: AppTextStyles.small),
                    ),
                    Expanded(
                        child: Divider(
                            color: AppColors.divider,
                            thickness: 1)),
                  ]),

                  const SizedBox(height: 24),

                  // Google Sign-In button
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: _isGoogleLoading
                          ? null
                          : _handleGoogleSignIn,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            vertical: 16),
                        side: const BorderSide(
                            color: AppColors.divider,
                            width: 1.5),
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(
                                  AppRadius.lg),
                        ),
                        backgroundColor: AppColors.surface,
                      ),
                      child: _isGoogleLoading
                          ? const SizedBox(
                              width: 22, height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: AppColors.primary,
                              ))
                          : Row(
                              mainAxisAlignment:
                                  MainAxisAlignment.center,
                              children: [
                                Container(
                                  width: 22, height: 22,
                                  decoration: BoxDecoration(
                                    borderRadius:
                                        BorderRadius.circular(
                                            4),
                                  ),
                                  child: Center(
                                    child: Text('G',
                                        style:
                                            GoogleFonts.inter(
                                          fontSize: 16,
                                          fontWeight:
                                              FontWeight.w800,
                                          color: const Color(
                                              0xFF4285F4),
                                        )),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Text('Continue with Google',
                                    style: AppTextStyles.body
                                        .copyWith(
                                      fontWeight:
                                          FontWeight.w600,
                                      color:
                                          AppColors.secondary,
                                    )),
                              ],
                            ),
                    ),
                  ),

                  const SizedBox(height: 40),

                  // Register link
                  Center(
                    child: Row(
                      mainAxisAlignment:
                          MainAxisAlignment.center,
                      children: [
                        Text("Don't have an account? ",
                            style: AppTextStyles.body
                                .copyWith(
                                    color: AppColors.muted)),
                        GestureDetector(
                          onTap: () => Navigator.pushNamed(
                              context, '/register'),
                          child: Text('Register',
                              style: AppTextStyles.body
                                  .copyWith(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w700,
                              )),
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

  Widget _buildFieldLabel(String label) {
    return Text(label,
        style: AppTextStyles.small.copyWith(
          color: AppColors.secondary,
          fontWeight: FontWeight.w600,
          fontSize: 13,
        ));
  }
}