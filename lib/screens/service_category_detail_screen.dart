import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../widgets/bottom_nav.dart';

class ServiceCategoryDetailScreen extends StatelessWidget {
  final String categoryId;
  const ServiceCategoryDetailScreen({super.key, required this.categoryId});

  static const Map<String, Map<String, dynamic>> categoryData = {
    'mayor': {
      'title': 'Provision of Customer Assistance',
      'options': [
        'For Recommendation Letter',
        'For Recommendation Letter for Transfer',
        'For Referral to Health Services Facilities',
        'For Hanging of Streamers',
        'For Fund Raising Activities',
        'For Temporary Closure of Streets',
      ]
    },
    'civil': {
      'title': 'Office of the City Civil Registrar',
      'options': [
        'Registration of Live Birth, Death and Marriage',
        'Late Registration of Birth, Death or Marriage',
        'Application for Marriage License',
        'Out-of-Town Registration/Reporting',
        'Registration of Legal Instruments',
        'Issuance of Supplemental Report',
        'Petition for Change of First Name',
      ]
    },
    'community': {
      'title': 'Office of the Community Affairs',
      'options': [
        'Local Employment Referrals (Applicants)',
        'Local Employment Referrals (Employers)',
        'No Objection Certificate (Overseas)',
        'Special Program for Employment (SPES)',
        'Claims for Livelihood Assistance',
        'Claims for Prizes',
        'Sama-summer Together Program',
      ]
    }
  };

  @override
  Widget build(BuildContext context) {
    final data = categoryData[categoryId] ?? {'title': 'Services', 'options': []};
    final String title = data['title'] as String;
    final List<String> options = List<String>.from(data['options'] as Iterable);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(title, maxLines: 2, textAlign: TextAlign.center),
        leading: IconButton(
          icon: const Icon(LucideIcons.chevronLeft, color: AppColors.primary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Column(
          children: [
            Text('CHOOSE THE SPECIFIC...', 
              style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black.withOpacity(0.3), letterSpacing: 2.0)
            ),
            const SizedBox(height: 32),
            ...options.map((option) => _buildOptionItem(context, option)),
            const SizedBox(height: 120),
          ],
        ),
      ),
      bottomNavigationBar: const BottomNav(selectedIndex: 2),
    );
  }

  Widget _buildOptionItem(BuildContext context, String option) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            HapticFeedback.lightImpact();
            Navigator.pushNamed(context, '/service_form', arguments: {'serviceName': option});
          },
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
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    option, 
                    style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black.withOpacity(0.7)),
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.05), shape: BoxShape.circle),
                  child: const Icon(LucideIcons.plus, color: AppColors.primary, size: 18),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
