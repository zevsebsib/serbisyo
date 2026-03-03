import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../theme/app_theme.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Settings', style: AppTextStyles.h2),
        backgroundColor: AppColors.background,
        elevation: 0,
        foregroundColor: AppColors.secondary,
      ),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          _buildTile(
            context,
            icon: LucideIcons.lock,
            label: 'Change Password',
            onTap: () => Navigator.pushNamed(context, '/forgot_password'),
          ),
          _buildTile(
            context,
            icon: LucideIcons.bell,
            label: 'Notification Preferences',
            onTap: () {},
          ),
          _buildTile(
            context,
            icon: LucideIcons.shieldCheck,
            label: 'Privacy Policy',
            onTap: () {},
          ),
          _buildTile(
            context,
            icon: LucideIcons.info,
            label: 'About / App Version',
            onTap: () {
              showAboutDialog(
                context: context,
                applicationName: 'SerbisyoAlisto',
                applicationVersion: '1.0.0',
              );
            },
          ),
          const SizedBox(height: 24),
          _buildLogoutTile(context),
        ],
      ),
    );
  }

  Widget _buildTile(BuildContext context,
      {required IconData icon,
      required String label,
      required VoidCallback onTap}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: AppShadows.card,
      ),
      child: ListTile(
        leading: Icon(icon, color: AppColors.primary, size: 22),
        title: Text(label, style: AppTextStyles.body),
        trailing: const Icon(LucideIcons.chevronRight,
            size: 18, color: AppColors.muted),
        onTap: onTap,
      ),
    );
  }

  Widget _buildLogoutTile(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.danger.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: ListTile(
        leading: const Icon(LucideIcons.logOut,
            color: AppColors.danger, size: 22),
        title: Text('Logout',
            style: AppTextStyles.body.copyWith(color: AppColors.danger)),
        onTap: () async {
          final confirm = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Logout'),
              content: const Text('Are you sure you want to logout?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: Text('Logout',
                      style: TextStyle(color: AppColors.danger)),
                ),
              ],
            ),
          );
          if (confirm == true) {
            await FirebaseAuth.instance.signOut();
            if (context.mounted) {
              Navigator.pushNamedAndRemoveUntil(
                  context, '/login', (route) => false);
            }
          }
        },
      ),
    );
  }
}