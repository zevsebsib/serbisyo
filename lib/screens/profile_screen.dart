import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../widgets/bottom_nav.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  final List<Map<String, dynamic>> menuItems = const [
    { 'label': 'Personal Information', 'icon': LucideIcons.user, 'path': '/profile_info' },
    { 'label': 'History', 'icon': LucideIcons.history, 'path': '/profile_history' },
    { 'label': 'Help & Support', 'icon': LucideIcons.helpCircle, 'path': '/profile_help' },
    { 'label': 'Settings', 'icon': LucideIcons.settings, 'path': '/profile_settings' },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Header
            Container(
              height: MediaQuery.of(context).size.height * 0.25,
              width: double.infinity,
              decoration: const BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.only(bottomLeft: Radius.circular(48), bottomRight: Radius.circular(48)),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Positioned(
                    top: 64,
                    child: Text('Profile', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.white)),
                  ),
                  Positioned(
                    bottom: -40,
                    child: Column(
                      children: [
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 4),
                            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 20, offset: const Offset(0, 10))],
                          ),
                          child: const Icon(LucideIcons.user, color: AppColors.primary, size: 40),
                        ),
                        const SizedBox(height: 12),
                        Text('First M. Last', style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.black)),
                        Text('firstlast@gmail.com', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black.withOpacity(0.4))),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 80),
            
            // Stats Section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: Colors.black.withOpacity(0.05))),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStat('Pending', '0'),
                    _buildStat('Processing', '0'),
                    _buildStat('Completed', '0'),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 32),
            
            // Menu Items
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  ...menuItems.map((item) => _buildMenuItem(context, item)),
                  const SizedBox(height: 24),
                  _buildLogoutButton(context),
                  const SizedBox(height: 120),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: const BottomNav(selectedIndex: 4),
    );
  }

  Widget _buildStat(String label, String value) {
    return Column(
      children: [
        Text(label.toUpperCase(), style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black.withOpacity(0.4), letterSpacing: -0.5)),
        const SizedBox(height: 4),
        Text(value, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w900, color: Colors.black)),
      ],
    );
  }

  Widget _buildMenuItem(BuildContext context, Map<String, dynamic> item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => Navigator.pushNamed(context, item['path']),
          borderRadius: BorderRadius.circular(24),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.black.withOpacity(0.05)),
              color: Colors.white,
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                  child: Icon(item['icon'], color: AppColors.primary, size: 20),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(item['label'], style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black.withOpacity(0.7))),
                ),
                const Icon(LucideIcons.chevronRight, color: AppColors.primary, size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLogoutButton(BuildContext context) {
    return ElevatedButton(
      onPressed: () => Navigator.of(context).pushReplacementNamed('/login'),
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.all(20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        elevation: 10,
        shadowColor: AppColors.primary.withOpacity(0.3),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(12)),
            child: const Icon(LucideIcons.logOut, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 16),
          Text('Logout', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w900, color: Colors.white)),
          const Spacer(),
        ],
      ),
    );
  }
}
