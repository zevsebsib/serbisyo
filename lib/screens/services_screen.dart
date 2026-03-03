import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../theme/app_theme.dart';
import '../widgets/bottom_nav.dart';

class ServicesScreen extends StatefulWidget {
  const ServicesScreen({super.key});

  @override
  State<ServicesScreen> createState() => _ServicesScreenState();
}

class _ServicesScreenState extends State<ServicesScreen> {
  String _searchQuery = '';
  final _searchController = TextEditingController();

  static final List<ServiceCategory> _categories = [
    ServiceCategory(
      id: 'mayor',
      icon: LucideIcons.landmark,
      color: const Color(0xFF5B6AF0),
      lightColor: const Color(0xFFEEF0FD),
      title: "City Mayor's Office",
      subtitle: 'Administrative Division',
      services: [
        'Provision of Consumer Assistance',
        'Issuance of Certificate of Good Moral Character',
        'Permit for Use of Government Facilities and Equipment',
        'Receipt of Complaints',
      ],
    ),
    ServiceCategory(
      id: 'civil',
      icon: LucideIcons.fileText,
      color: const Color(0xFF00A86B),
      lightColor: const Color(0xFFE6F7F1),
      title: 'Civil Registry',
      subtitle: 'Records & Documentation',
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
      icon: LucideIcons.users,
      color: const Color(0xFFFF8000),
      lightColor: const Color(0xFFFFF5EB),
      title: 'Community Affairs',
      subtitle: 'Employment & Livelihood',
      services: [
        'Local Employment Referral (Applicants)',
        'Local Employment Referral (Employers)',
        'SPES Program',
        'Livelihood Assistance (Animal Dispersal)',
        'Sama-Summer Together Program',
      ],
    ),
  ];

  List<ServiceCategory> get _filtered {
    if (_searchQuery.isEmpty) return _categories;
    final q = _searchQuery.toLowerCase();
    return _categories
        .map((cat) {
          final matchedServices = cat.services
              .where((s) => s.toLowerCase().contains(q))
              .toList();
          final titleMatch = cat.title.toLowerCase().contains(q) ||
              cat.subtitle.toLowerCase().contains(q);
          if (titleMatch) return cat;
          if (matchedServices.isNotEmpty) {
            return ServiceCategory(
              id: cat.id,
              icon: cat.icon,
              color: cat.color,
              lightColor: cat.lightColor,
              title: cat.title,
              subtitle: cat.subtitle,
              services: matchedServices,
            );
          }
          return null;
        })
        .whereType<ServiceCategory>()
        .toList();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final results = _filtered;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          _buildHeader(context),
          Expanded(
            child: results.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(18, 4, 18, 120),
                    itemCount: results.length,
                    itemBuilder: (context, i) => _CategoryCard(
                      category: results[i],
                      searchQuery: _searchQuery,
                    ),
                  ),
          ),
        ],
      ),
      bottomNavigationBar: const BottomNav(selectedIndex: 2),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: AppColors.headerGradient,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title row with back button
              Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        LucideIcons.arrowLeft,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'City Services',
                          style: GoogleFonts.inter(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: -0.5,
                          ),
                        ),
                        Text(
                          '${_categories.fold(0, (sum, c) => sum + c.services.length)} services available',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w400,
                            color: Colors.white.withOpacity(0.80),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Search bar
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  boxShadow: AppShadows.card,
                ),
                child: TextField(
                  controller: _searchController,
                  onChanged: (v) => setState(() => _searchQuery = v),
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppColors.secondary,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Search services...',
                    hintStyle: GoogleFonts.inter(
                      color: AppColors.muted,
                      fontWeight: FontWeight.w400,
                      fontSize: 14,
                    ),
                    prefixIcon: const Icon(
                      LucideIcons.search,
                      size: 18,
                      color: AppColors.muted,
                    ),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(LucideIcons.x,
                                size: 16, color: AppColors.muted),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                      borderSide: const BorderSide(
                          color: AppColors.primary, width: 2),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(LucideIcons.searchX,
              size: 48, color: AppColors.muted.withOpacity(0.5)),
          const SizedBox(height: 16),
          Text('No services found', style: AppTextStyles.h3),
          const SizedBox(height: 6),
          Text(
            'Try searching with different keywords.',
            style: AppTextStyles.bodyMuted,
          ),
        ],
      ),
    );
  }
}

class _CategoryCard extends StatefulWidget {
  final ServiceCategory category;
  final String searchQuery;
  const _CategoryCard({required this.category, required this.searchQuery});

  @override
  State<_CategoryCard> createState() => _CategoryCardState();
}

class _CategoryCardState extends State<_CategoryCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final cat = widget.category;

    return Container(
      margin: const EdgeInsets.only(top: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        children: [
          // Category header — tappable
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: BorderRadius.circular(AppRadius.xl),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Row(
                children: [
                  // Category icon
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: cat.lightColor,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(cat.icon, color: cat.color, size: 26),
                  ),
                  const SizedBox(width: 14),

                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          cat.title,
                          style: AppTextStyles.h3.copyWith(fontSize: 15),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          cat.subtitle,
                          style: AppTextStyles.small,
                        ),
                      ],
                    ),
                  ),

                  // Count badge + chevron
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: cat.lightColor,
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                        ),
                        child: Text(
                          '${cat.services.length}',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: cat.color,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      AnimatedRotation(
                        turns: _expanded ? 0.5 : 0,
                        duration: const Duration(milliseconds: 250),
                        child: Icon(
                          LucideIcons.chevronDown,
                          color: AppColors.muted,
                          size: 18,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Expandable services list
          AnimatedCrossFade(
            firstChild: const SizedBox(width: double.infinity),
            secondChild: Column(
              children: [
                Divider(
                  height: 1,
                  indent: 18,
                  endIndent: 18,
                  color: AppColors.divider,
                ),
                ...cat.services.asMap().entries.map((entry) {
                  final isLast = entry.key == cat.services.length - 1;
                  return _ServiceTile(
                    service: entry.value,
                    categoryColor: cat.color,
                    isLast: isLast,
                    onTap: () => Navigator.pushNamed(
                      context,
                      '/service_form',
                      arguments: {'serviceName': entry.value},
                    ),
                  );
                }),
              ],
            ),
            crossFadeState: _expanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 250),
          ),
        ],
      ),
    );
  }
}

class _ServiceTile extends StatelessWidget {
  final String service;
  final Color categoryColor;
  final bool isLast;
  final VoidCallback onTap;

  const _ServiceTile({
    required this.service,
    required this.categoryColor,
    required this.isLast,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  margin: const EdgeInsets.only(right: 14),
                  decoration: BoxDecoration(
                    color: categoryColor.withOpacity(0.5),
                    shape: BoxShape.circle,
                  ),
                ),
                Expanded(
                  child: Text(
                    service,
                    style: AppTextStyles.body.copyWith(
                      color: AppColors.secondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Icon(
                  LucideIcons.arrowRight,
                  size: 16,
                  color: categoryColor.withOpacity(0.7),
                ),
              ],
            ),
          ),
        ),
        if (!isLast)
          Divider(
            height: 1,
            indent: 40,
            endIndent: 18,
            color: AppColors.divider,
          ),
      ],
    );
  }
}

class ServiceCategory {
  final String id;
  final IconData icon;
  final Color color;
  final Color lightColor;
  final String title;
  final String subtitle;
  final List<String> services;

  const ServiceCategory({
    required this.id,
    required this.icon,
    required this.color,
    required this.lightColor,
    required this.title,
    required this.subtitle,
    required this.services,
  });
}