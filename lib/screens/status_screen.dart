import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';

class StatusScreen extends StatelessWidget {
  final bool isSuccess;
  const StatusScreen({super.key, this.isSuccess = true});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Exact Concentric Glows
            Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 320,
                  height: 320,
                  decoration: BoxDecoration(
                    color: (isSuccess ? AppColors.primary : AppColors.danger).withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                ).animate(onPlay: (c) => c.repeat(reverse: true)).blurXY(begin: 80, end: 120, duration: 3000.ms),
                
                Container(
                  width: 160,
                  height: 160,
                  decoration: BoxDecoration(
                    color: isSuccess ? AppColors.primary : AppColors.danger,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: (isSuccess ? AppColors.primary : AppColors.danger).withOpacity(0.3),
                        blurRadius: 60,
                        offset: const Offset(0, 30)
                      )
                    ],
                    border: Border.all(
                      color: (isSuccess ? AppColors.primary : AppColors.danger).withOpacity(0.1),
                      width: 12
                    ),
                  ),
                  child: Icon(
                    isSuccess ? LucideIcons.check : LucideIcons.x, 
                    color: Colors.white, 
                    size: 80
                  ),
                ).animate().scaleXY(begin: 0, end: 1, duration: 700.ms, curve: Curves.easeOutCubic),
              ],
            ),
            
            const SizedBox(height: 56),
            
            Text(
              isSuccess ? 'Success!' : 'Failed!', 
              style: GoogleFonts.inter(fontSize: 40, fontWeight: FontWeight.w900, letterSpacing: -2.0)
            ),
            
            const SizedBox(height: 64),
            
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pushReplacementNamed('/'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(48)),
                  elevation: 20,
                  shadowColor: AppColors.primary.withOpacity(0.3),
                ),
                child: Text(
                  isSuccess ? 'CONTINUE' : 'TRY AGAIN', 
                  style: GoogleFonts.inter(fontWeight: FontWeight.w900, fontSize: 14, letterSpacing: 3.0)
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
