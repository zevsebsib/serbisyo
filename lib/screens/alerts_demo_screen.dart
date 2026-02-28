import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../widgets/bottom_nav.dart';

class AlertsDemoScreen extends StatefulWidget {
  const AlertsDemoScreen({super.key});

  @override
  State<AlertsDemoScreen> createState() => _AlertsDemoScreenState();
}

class _AlertsDemoScreenState extends State<AlertsDemoScreen> {
  final List<Map<String, dynamic>> alertTypes = [
    { 'id': 'success', 'title': 'Success!', 'desc': 'Operation completed successfully.', 'icon': LucideIcons.checkCircle2, 'color': Colors.green, 'bg': Color(0xFFE8F5E9), 'border': Color(0xFFC8E6C9) },
    { 'id': 'failed', 'title': 'Failed!', 'desc': 'Operation failed to complete.', 'icon': LucideIcons.xCircle, 'color': Colors.red, 'bg': Color(0xFFFFEBEE), 'border': Color(0xFFFFCDD2) },
    { 'id': 'error', 'title': 'Error!', 'desc': 'An unexpected error occurred.', 'icon': LucideIcons.alertCircle, 'color': Colors.orange, 'bg': Color(0xFFFFF3E0), 'border': Color(0xFFFFE0B2) },
  ];

  late List<Map<String, dynamic>> alerts;

  @override
  void initState() {
    super.initState();
    alerts = List.from(alertTypes);
  }

  void removeAlert(String id) {
    HapticFeedback.lightImpact();
    setState(() {
      alerts.removeWhere((a) => a['id'] == id);
    });
  }

  void resetAlerts() {
    HapticFeedback.mediumImpact();
    setState(() {
      alerts = List.from(alertTypes);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text('ALERTS', style: GoogleFonts.inter(fontWeight: FontWeight.w900, color: AppColors.primary, letterSpacing: 2.0)),
        automaticallyImplyLeading: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            if (alerts.isNotEmpty)
              ...alerts.asMap().entries.map((entry) {
                final idx = entry.key;
                final alert = entry.value;
                return _buildAlertCard(alert, idx);
              }),
            
            if (alerts.isEmpty)
              GestureDetector(
                onTap: resetAlerts,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 40),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.black.withOpacity(0.05), width: 2, style: BorderStyle.solid), // Flutter doesn't have dashed borders easily without a package
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Center(
                    child: Text('RESET ALERTS', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w900, color: Colors.black.withOpacity(0.2), letterSpacing: 2.0)),
                  ),
                ),
              ).animate().fadeIn(),
            
            const SizedBox(height: 120),
          ],
        ),
      ),
      bottomNavigationBar: const BottomNav(selectedIndex: 3), // Using alerts tab
    );
  }

  Widget _buildAlertCard(Map<String, dynamic> alert, int idx) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: alert['bg'],
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: alert['border']),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)]),
            child: Icon(alert['icon'], color: alert['color'], size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text(alert['title'], style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w900, color: Colors.black)),
                const SizedBox(height: 8),
                Text(alert['desc'], style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black.withOpacity(0.4), letterSpacing: -0.2)),
              ],
            ),
          ),
          const SizedBox(width: 16),
          GestureDetector(
            onTap: () => removeAlert(alert['id']),
            child: Icon(LucideIcons.x, color: Colors.black.withOpacity(0.2), size: 20),
          ),
        ],
      ),
    ).animate().slideX(begin: 1.0, end: 0.0, duration: 400.ms, delay: (idx * 100).ms, curve: Curves.easeOutCubic).fadeIn();
  }
}
