import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../theme/app_theme.dart';
import '../widgets/bottom_nav.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  ServicesScreen — Citizen mobile app
//
//  FIX: Previously used a hardcoded static list. Now fetches from the
//  Firestore 'services' collection so that changes made by the superadmin
//  in admin_services_screen.dart are immediately reflected here.
//
//  Data structure expected per document:
//    name:         String
//    categoryId:   'mayor' | 'civil' | 'community'
//    categoryName: String
//    department:   String
//    isActive:     bool
// ─────────────────────────────────────────────────────────────────────────────

class ServicesScreen extends StatefulWidget {
  const ServicesScreen({super.key});

  @override
  State<ServicesScreen> createState() =>
      _ServicesScreenState();
}

class _ServicesScreenState extends State<ServicesScreen> {
  String _searchQuery = '';
  bool   _loading     = true;
  bool   _hasError    = false;

  final _searchController = TextEditingController();

  // Grouped: categoryId → list of service docs
  Map<String, List<Map<String, dynamic>>> _grouped = {};

  // Category display config (same as admin side)
  static const Map<String, Map<String, dynamic>> _catConfig = {
    'mayor': {
      'icon':     LucideIcons.landmark,
      'color':    Color(0xFF5B6AF0),
      'bgColor':  Color(0xFFEEF0FD),
      'title':    "City - Admin Office",
      'subtitle': 'Administrative Division',
    },
    'civil': {
      'icon':     LucideIcons.fileText,
      'color':    Color(0xFF00A86B),
      'bgColor':  Color(0xFFE6F7F1),
      'title':    'Civil Registry',
      'subtitle': 'Records & Documentation',
    },
    'community': {
      'icon':     LucideIcons.users,
      'color':    Color(0xFFFF8000),
      'bgColor':  Color(0xFFFFF5EB),
      'title':    'Community Affairs',
      'subtitle': 'Employment & Livelihood',
    },
  };

  // Preserve category display order
  static const List<String> _catOrder = [
    'mayor', 'civil', 'community'
  ];

  @override
  void initState() {
    super.initState();
    _loadServices();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadServices() async {
    setState(() {
      _loading  = true;
      _hasError = false;
    });
    try {
      final snap = await FirebaseFirestore.instance
          .collection('services')
          .where('isActive', isEqualTo: true)
          .orderBy('categoryId')
          .orderBy('name')
          .get();

      final grouped =
          <String, List<Map<String, dynamic>>>{};

      for (final doc in snap.docs) {
        final data  = doc.data();
        final catId =
            data['categoryId']?.toString() ?? 'mayor';
        grouped.putIfAbsent(catId, () => []);
        grouped[catId]!.add({
          'id':         doc.id,
          'name':       data['name'] ?? '',
          'categoryId': catId,
          'department': data['department'] ?? '',
        });
      }

      if (mounted) {
        setState(() {
          _grouped = grouped;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _hasError = true;
          _loading  = false;
        });
      }
    }
  }

  // ── Filter across all categories ──────────────────────────────────────────
  Map<String, List<Map<String, dynamic>>> get _filtered {
    if (_searchQuery.isEmpty) return _grouped;

    final q      = _searchQuery.toLowerCase();
    final result = <String, List<Map<String, dynamic>>>{};

    for (final catId in _grouped.keys) {
      final matched = _grouped[catId]!
          .where((s) =>
              s['name'].toString().toLowerCase().contains(q) ||
              s['department']
                  .toString()
                  .toLowerCase()
                  .contains(q))
          .toList();
      if (matched.isNotEmpty) result[catId] = matched;
    }
    return result;
  }

  int get _totalServices =>
      _grouped.values.fold(0, (sum, list) => sum + list.length);

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          _buildHeader(context),
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(
                        color: AppColors.primary))
                : _hasError
                    ? _buildErrorState()
                    : filtered.isEmpty
                        ? _buildEmptyState()
                        : RefreshIndicator(
                            onRefresh: _loadServices,
                            color: AppColors.primary,
                            child: ListView.builder(
                              padding: const EdgeInsets
                                  .fromLTRB(18, 4, 18, 120),
                              // Preserve order: mayor, civil, community
                              itemCount: _catOrder
                                  .where((c) =>
                                      filtered.containsKey(c))
                                  .length,
                              itemBuilder: (context, i) {
                                final catId = _catOrder
                                    .where((c) =>
                                        filtered.containsKey(c))
                                    .elementAt(i);
                                return _CategoryCard(
                                  catId:       catId,
                                  services:    filtered[catId]!,
                                  catConfig:   _catConfig[catId] ?? {},
                                  searchQuery: _searchQuery,
                                );
                              },
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
          bottomLeft:  Radius.circular(28),
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
              Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white
                            .withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                          LucideIcons.arrowLeft,
                          color: Colors.white,
                          size: 20),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
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
                          _loading
                              ? 'Loading...'
                              : '$_totalServices services available',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w400,
                            color: Colors.white
                                .withValues(alpha: 0.80),
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
                  borderRadius:
                      BorderRadius.circular(AppRadius.lg),
                  boxShadow: AppShadows.card,
                ),
                child: TextField(
                  controller: _searchController,
                  onChanged: (v) =>
                      setState(() => _searchQuery = v),
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
                        color: AppColors.muted),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(
                                LucideIcons.x,
                                size: 16,
                                color: AppColors.muted),
                            onPressed: () {
                              _searchController.clear();
                              setState(
                                  () => _searchQuery = '');
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(
                          AppRadius.lg),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(
                          AppRadius.lg),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(
                          AppRadius.lg),
                      borderSide: const BorderSide(
                          color: AppColors.primary,
                          width: 2),
                    ),
                    contentPadding:
                        const EdgeInsets.symmetric(
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
              size: 48,
              color: AppColors.muted
                  .withValues(alpha: 0.5)),
          const SizedBox(height: 16),
          Text('No services found',
              style: AppTextStyles.h3),
          const SizedBox(height: 6),
          Text(
            'Try searching with different keywords.',
            style: AppTextStyles.bodyMuted,
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(LucideIcons.wifiOff,
              size: 48,
              color: AppColors.muted
                  .withValues(alpha: 0.5)),
          const SizedBox(height: 16),
          Text('Could not load services',
              style: AppTextStyles.h3),
          const SizedBox(height: 6),
          Text('Check your connection and try again.',
              style: AppTextStyles.bodyMuted),
          const SizedBox(height: 20),
          GestureDetector(
            onTap: _loadServices,
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius:
                    BorderRadius.circular(AppRadius.pill),
              ),
              child: Text('Retry',
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  )),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
class _CategoryCard extends StatefulWidget {
  final String                    catId;
  final List<Map<String, dynamic>> services;
  final Map<String, dynamic>      catConfig;
  final String                    searchQuery;

  const _CategoryCard({
    required this.catId,
    required this.services,
    required this.catConfig,
    required this.searchQuery,
  });

  @override
  State<_CategoryCard> createState() =>
      _CategoryCardState();
}

class _CategoryCardState extends State<_CategoryCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final color   =
        widget.catConfig['color'] as Color? ??
            AppColors.primary;
    final bgColor =
        widget.catConfig['bgColor'] as Color? ??
            AppColors.cardBg;
    final icon    =
        widget.catConfig['icon'] as IconData? ??
            Icons.folder_rounded;
    final title   =
        widget.catConfig['title'] as String? ??
            widget.catId;
    final subtitle =
        widget.catConfig['subtitle'] as String? ?? '';

    return Container(
      margin: const EdgeInsets.only(top: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        children: [
          // Category header
          InkWell(
            onTap: () =>
                setState(() => _expanded = !_expanded),
            borderRadius:
                BorderRadius.circular(AppRadius.xl),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Row(
                children: [
                  Container(
                    width: 52, height: 52,
                    decoration: BoxDecoration(
                      color: bgColor,
                      borderRadius:
                          BorderRadius.circular(16),
                    ),
                    child: Icon(icon,
                        color: color, size: 26),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        Text(title,
                            style: AppTextStyles.h3
                                .copyWith(fontSize: 15)),
                        const SizedBox(height: 3),
                        Text(subtitle,
                            style: AppTextStyles.small),
                      ],
                    ),
                  ),
                  Row(
                    children: [
                      Container(
                        padding:
                            const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: bgColor,
                          borderRadius:
                              BorderRadius.circular(
                                  AppRadius.pill),
                        ),
                        child: Text(
                          '${widget.services.length}',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: color,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      AnimatedRotation(
                        turns: _expanded ? 0.5 : 0,
                        duration:
                            const Duration(milliseconds: 250),
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
            firstChild:
                const SizedBox(width: double.infinity),
            secondChild: Column(
              children: [
                Divider(
                  height: 1,
                  indent: 18,
                  endIndent: 18,
                  color: AppColors.divider,
                ),
                ...widget.services
                    .asMap()
                    .entries
                    .map((entry) {
                  final isLast =
                      entry.key == widget.services.length - 1;
                  final service = entry.value;
                  return _ServiceTile(
                    service:       service['name'] as String,
                    categoryColor: color,
                    isLast:        isLast,
                    onTap: () => Navigator.pushNamed(
                      context,
                      '/service_form',
                      arguments: {
                        'serviceName': service['name'],
                        'category':    service['categoryId'],
                        'department':  service['department'],
                      },
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

// ─────────────────────────────────────────────────────────────────────────────
class _ServiceTile extends StatelessWidget {
  final String service;
  final Color  categoryColor;
  final bool   isLast;
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
            padding: const EdgeInsets.symmetric(
                horizontal: 18, vertical: 14),
            child: Row(
              children: [
                Container(
                  width: 8, height: 8,
                  margin:
                      const EdgeInsets.only(right: 14),
                  decoration: BoxDecoration(
                    color: categoryColor
                        .withValues(alpha: 0.5),
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
                  color: categoryColor
                      .withValues(alpha: 0.7),
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