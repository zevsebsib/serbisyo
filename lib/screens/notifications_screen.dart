import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../widgets/bottom_nav.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Notification'),
        automaticallyImplyLeading: false,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 192,
                  height: 192,
                  decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.05), shape: BoxShape.circle),
                ),
                Transform.rotate(
                  angle: 0.2, // ~12 degrees
                  child: Container(
                    width: 128,
                    height: 128,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                      boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.3), blurRadius: 40, offset: const Offset(0, 20))],
                    ),
                    child: const Icon(LucideIcons.bell, color: Colors.white, size: 64),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Text("You're all caught up", style: AppTextStyles.h2),
            const SizedBox(height: 8),
            Text('All notifications will be displayed here', 
              style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black.withOpacity(0.4))
            ),
            const SizedBox(height: 120), // offset
          ],
        ),
      ),
      bottomNavigationBar: const BottomNav(selectedIndex: 3),
    );
  }
}
