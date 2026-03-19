import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    // FIX: removed Future.delayed — button is the ONLY way to navigate
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth  = MediaQuery.of(context).size.width;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor:                    Colors.transparent,
        statusBarIconBrightness:           Brightness.light,
        systemNavigationBarColor:          Colors.transparent,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: AppColors.primary,
        extendBody:             true,
        extendBodyBehindAppBar: true,
        body: SizedBox(
          width:  screenWidth,
          height: screenHeight,
          child: Container(
            width:  double.infinity,
            height: double.infinity,
            color:  AppColors.primary,
            child: SafeArea(
              bottom: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Spacer(flex: 2),

                  // ── Logo ──────────────────────────────────────────
                  Center(
                    child: Container(
                      width:   150,
                      height:  150,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color:  Colors.white,
                        shape:  BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color:      Colors.black.withValues(alpha: 0.12),
                            blurRadius: 24,
                            offset:     const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Container(
                        decoration: BoxDecoration(
                          shape:  BoxShape.circle,
                          border: Border.all(
                            color: AppColors.primary,
                            width: 4,
                          ),
                        ),
                        child: ClipOval(
                          child: Image.asset(
                            'assets/serbisyo.png',
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 36),

                  // ── App name ───────────────────────────────────────
                  Text(
                    'SerbisyoAlisto',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize:      42,
                      fontWeight:    FontWeight.w900,
                      color:         Colors.white,
                      letterSpacing: -1.5,
                    ),
                  ),

                  const SizedBox(height: 10),

                  // ── Tagline ────────────────────────────────────────
                  Text(
                    'SIMPLE ONE CLICK AWAY',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize:      12,
                      fontWeight:    FontWeight.w700,
                      color:         Colors.white.withValues(alpha: 0.80),
                      letterSpacing: 3.0,
                    ),
                  ),

                  const Spacer(flex: 3),

                  // ── GET STARTED button ─────────────────────────────
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 48),
                    child: ElevatedButton(
                      onPressed: () {
                        // Restore system UI before navigating
                        SystemChrome.setEnabledSystemUIMode(
                          SystemUiMode.manual,
                          overlays: SystemUiOverlay.values,
                        );
                        // FIX: check auth — skip login if already logged in
                        final user = FirebaseAuth.instance.currentUser;
                        Navigator.pushReplacementNamed(
                          context,
                          user != null ? '/' : '/login',
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: AppColors.primary,
                        padding:         const EdgeInsets.symmetric(vertical: 18),
                        shape:           const StadiumBorder(),
                        elevation:       0,
                        shadowColor:     Colors.transparent,
                      ),
                      child: Text(
                        'GET STARTED',
                        style: GoogleFonts.inter(
                          fontWeight:    FontWeight.w900,
                          fontSize:      14,
                          letterSpacing: 2.0,
                          color:         AppColors.primary,
                        ),
                      ),
                    ),
                  ),

                  SizedBox(
                    height: MediaQuery.of(context).padding.bottom + 48,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}