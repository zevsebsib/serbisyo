import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../widgets/bottom_nav.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  ServiceCategoryDetailScreen — Citizen mobile app
//
//  FIX: Previously had services hardcoded in a static map. Now fetches from
//  the Firestore 'services' collection filtered by categoryId so that changes
//  from the admin portal are reflected here immediately.
// ─────────────────────────────────────────────────────────────────────────────

class ServiceCategoryDetailScreen extends StatefulWidget {
  final String categoryId;
  const ServiceCategoryDetailScreen(
      {super.key, required this.categoryId});

  @override
  State<ServiceCategoryDetailScreen> createState() =>
      _ServiceCategoryDetailScreenState();
}

class _ServiceCategoryDetailScreenState
    extends State<ServiceCategoryDetailScreen> {
  bool   _loading  = true;
  bool   _hasError = false;

  List<Map<String, dynamic>> _services = [];
  String _categoryName = '';
  String _department   = '';

  // Category display titles
  static const Map<String, Map<String, String>> _catMeta = {
    'mayor': {
      'title':      "City Mayor's Office",
      'department': 'City Administration Office',
    },
    'civil': {
      'title':      'Office of the City Civil Registrar',
      'department': 'Office of the City Civil Registrar',
    },
    'community': {
      'title':      'Office of the Community Affairs',
      'department': 'Office of the City Community Affairs',
    },
  };

  @override
  void initState() {
    super.initState();
    _loadServices();
  }

  Future<void> _loadServices() async {
    setState(() {
      _loading  = true;
      _hasError = false;
    });

    // Set category meta from config
    final meta = _catMeta[widget.categoryId];
    _categoryName = meta?['title'] ?? widget.categoryId;
    _department   = meta?['department'] ?? '';

    try {
      final snap = await FirebaseFirestore.instance
          .collection('services')
          .where('categoryId', isEqualTo: widget.categoryId)
          .where('isActive', isEqualTo: true)
          .orderBy('name')
          .get();

      if (mounted) {
        setState(() {
          _services = snap.docs.map((d) => {
            'id':         d.id,
            'name':       d.data()['name'] ?? '',
            'department': d.data()['department'] ??
                _department,
            'categoryId': widget.categoryId,
          }).toList();

          // Use department from first doc if available
          if (_services.isNotEmpty &&
              (_services.first['department'] as String)
                  .isNotEmpty) {
            _department =
                _services.first['department'] as String;
          }

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          _categoryName,
          maxLines: 2,
          textAlign: TextAlign.center,
        ),
        leading: IconButton(
          icon: const Icon(LucideIcons.chevronLeft,
              color: AppColors.primary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(
                  color: AppColors.primary))
          : _hasError
              ? _buildErrorState()
              : _services.isEmpty
                  ? _buildEmptyState()
                  : SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 32),
                      child: Column(
                        children: [
                          Text(
                            'CHOOSE THE SPECIFIC...',
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Colors.black
                                  .withValues(alpha: 0.3),
                              letterSpacing: 2.0,
                            ),
                          ),
                          const SizedBox(height: 32),
                          ..._services.map(
                              (s) => _buildOptionItem(
                                  context,
                                  s['name'] as String,
                                  s['department'] as String,
                                  s['categoryId'] as String)),
                          const SizedBox(height: 120),
                        ],
                      ),
                    ),
      bottomNavigationBar:
          const BottomNav(selectedIndex: 2),
    );
  }

  Widget _buildOptionItem(BuildContext context,
      String name, String dept, String catId) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            HapticFeedback.lightImpact();
            Navigator.pushNamed(
              context,
              '/service_form',
              arguments: {
                'serviceName': name,
                'category':    catId,
                'department':  dept,
              },
            );
          },
          borderRadius: BorderRadius.circular(24),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                  color: Colors.black
                      .withValues(alpha: 0.05)),
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                    color: Colors.black
                        .withValues(alpha: 0.02),
                    blurRadius: 10,
                    offset: const Offset(0, 4)),
              ],
            ),
            child: Row(
              mainAxisAlignment:
                  MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    name,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.black
                          .withValues(alpha: 0.7),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  width: 32, height: 32,
                  decoration: BoxDecoration(
                    color: AppColors.primary
                        .withValues(alpha: 0.05),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(LucideIcons.plus,
                      color: AppColors.primary, size: 18),
                ),
              ],
            ),
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
          Icon(LucideIcons.folderOpen,
              size: 48,
              color: AppColors.muted
                  .withValues(alpha: 0.4)),
          const SizedBox(height: 16),
          Text('No services available',
              style: AppTextStyles.h3),
          const SizedBox(height: 6),
          Text('This category has no active services.',
              style: AppTextStyles.bodyMuted),
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
                  .withValues(alpha: 0.4)),
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
                borderRadius: BorderRadius.circular(
                    AppRadius.pill),
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