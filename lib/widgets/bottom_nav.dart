import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../theme/app_theme.dart';

class BottomNav extends StatefulWidget {
  final int selectedIndex;
  final Function(int)? onTap;

  const BottomNav({super.key, this.selectedIndex = 0, this.onTap});

  @override
  State<BottomNav> createState() => _BottomNavState();
}

class _BottomNavState extends State<BottomNav> {
  void _handleTap(int index) {
    if (widget.onTap != null) {
      widget.onTap!(index);
      return;
    }

    // Avoid navigating to the same page
    if (index == widget.selectedIndex) return;

    switch (index) {
      case 0: // Home
        Navigator.pushReplacementNamed(context, '/');
        break;
      case 1: // Request
        Navigator.pushReplacementNamed(context, '/requests/track');
        break;
      case 2: // Notification
        Navigator.pushReplacementNamed(context, '/notifications');
        break;
      case 3: // Profile
        Navigator.pushReplacementNamed(context, '/profile');
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 80,
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildNavItem(icon: LucideIcons.home, label: 'HOME', index: 0),
          _buildNavItem(icon: LucideIcons.clipboardList, label: 'REQUEST', index: 1),
          _buildNavItem(icon: LucideIcons.bell, label: 'NOTIFICATION', index: 2),
          _buildNavItem(icon: LucideIcons.user, label: 'PROFILE', index: 3),
        ],
      ),
    );
  }

  Widget _buildNavItem({required IconData icon, required String label, required int index}) {
    final bool active = index == widget.selectedIndex;
    final color = active ? AppColors.primary : AppColors.secondary.withOpacity(0.6);

    return Expanded(
      child: InkWell(
        onTap: () => _handleTap(index),
        borderRadius: BorderRadius.circular(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 5),
            Text(
              label,
              style: GoogleFonts.inter(
                color: color,
                fontSize: 10,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.0,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
