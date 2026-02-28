import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../theme/app_theme.dart';
import '../widgets/bottom_nav.dart';

class ServicesScreen extends StatelessWidget {
  const ServicesScreen({super.key});

  static final List<ServiceCategory> categories = [
    ServiceCategory(
      id: 'mayor',
      title: 'Office of the City Mayor – Administrative Division',
      services: [
        'Provision of Consumer Assistance',
        'Issuance of Certificate of Good Moral Character',
        'Permit for Use of Government Facilities and Equipment',
        'Receipt of Complaints',
      ],
    ),
    ServiceCategory(
      id: 'civil',
      title: 'Civil Registry Services',
      services: [
        'Registration of Live Birth, Death and Marriage',
        'Late Registration of Birth, Death or Marriage',
        'Application for Marriage License',
        'Out-of-Town Registration / Reporting',
        'Registration of Legal Instruments',
        'Issuance of Certified Machine Copy',
      ],
    ),
    ServiceCategory(
      id: 'community',
      title: 'Office of the Community Affairs Officer',
      services: [
        'Local Employment Referral (Applicants)',
        'Local Employment Referral (Employers)',
        'SPES Program',
        'Livelihood Assistance (Animal Dispersal)',
        'Sama-Summer Together Program',
      ],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(title: const Text('Services')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: ListView.separated(
          itemCount: categories.length,
          separatorBuilder: (_, __) => const SizedBox(height: 16),
          itemBuilder: (context, index) {
            final category = categories[index];
            return _CategoryCard(category: category);
          },
        ),
      ),
      bottomNavigationBar: const BottomNav(selectedIndex: 2),
    );
  }
}

class _CategoryCard extends StatelessWidget {
  final ServiceCategory category;
  const _CategoryCard({required this.category});

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      collapsedBackgroundColor: Colors.white,
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      collapsedShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: Text(
        category.title,
        style: GoogleFonts.inter(fontWeight: FontWeight.w900),
      ),
      children: category.services.map((service) {
        return ListTile(
          title: Text(service, style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
          trailing: const Icon(LucideIcons.chevronRight, color: AppColors.primary),
          onTap: () {
            Navigator.pushNamed(
              context,
              '/service_form',
              arguments: {'serviceName': service},
            );
          },
        );
      }).toList(),
    );
  }
}

class ServiceCategory {
  final String id;
  final String title;
  final List<String> services;

  ServiceCategory({
    required this.id,
    required this.title,
    required this.services,
  });
}