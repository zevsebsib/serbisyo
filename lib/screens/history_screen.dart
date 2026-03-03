import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../widgets/bottom_nav.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final _uid = FirebaseAuth.instance.currentUser?.uid;
  String _selectedFilter = 'All';

  final List<String> _filters = [
    'All',
    'Pending',
    'Processing',
    'Completed',
    'Rejected',
  ];

  // ── Helpers ────────────────────────────────────────────────────────────────
  String _formatDate(Timestamp? timestamp) {
    if (timestamp == null) return '';
    final date = timestamp.toDate();
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':    return AppColors.warning;
      case 'processing': return AppColors.primary;
      case 'completed':  return AppColors.success;
      case 'rejected':   return AppColors.danger;
      default:           return AppColors.muted;
    }
  }

  Color _getStatusBgColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':    return AppColors.warningLight;
      case 'processing': return AppColors.cardBg;
      case 'completed':  return AppColors.successLight;
      case 'rejected':   return const Color(0xFFFFEEEE);
      default:           return AppColors.cardBg;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'pending':    return LucideIcons.clock3;
      case 'processing': return LucideIcons.loader;
      case 'completed':  return LucideIcons.checkCircle2;
      case 'rejected':   return LucideIcons.xCircle;
      default:           return LucideIcons.clipboard;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_uid == null) {
      return const Scaffold(
        body: Center(child: Text('Not logged in')),
      );
    }

    // Build Firestore query based on selected filter
    Query query = FirebaseFirestore.instance
        .collection('requests')
        .where('userId', isEqualTo: _uid)
        .orderBy('createdAt', descending: true);

    if (_selectedFilter != 'All') {
      query = query.where('status',
          isEqualTo: _selectedFilter.toLowerCase());
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          _buildHeader(context),
          _buildFilterTabs(),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: query.snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Text('Something went wrong.',
                        style: AppTextStyles.bodyMuted),
                  );
                }

                final docs = snapshot.data?.docs ?? [];

                if (docs.isEmpty) {
                  return _buildEmptyState();
                }

                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(18, 8, 18, 100),
                  itemCount: docs.length,
                  itemBuilder: (context, i) {
                    final data = docs[i].data() as Map<String, dynamic>;
                    final status = data['status']?.toString() ?? 'pending';
                    return _buildRequestCard(
                      docId:       docs[i].id,
                      serviceName: data['serviceName']?.toString() ?? 'Request',
                      status:      status,
                      createdAt:   data['createdAt'],
                      category:    data['category']?.toString() ?? '',
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: const BottomNav(selectedIndex: 3),
    );
  }

  // ── Header ─────────────────────────────────────────────────────────────────
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
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 22),
          child: Row(
            children: [
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(LucideIcons.arrowLeft,
                      color: Colors.white, size: 20),
                ),
              ),
              const SizedBox(width: 14),
              Text(
                'Request History',
                style: GoogleFonts.inter(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Filter Tabs ────────────────────────────────────────────────────────────
  Widget _buildFilterTabs() {
    return Container(
      height: 48,
      margin: const EdgeInsets.only(top: 16),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 18),
        itemCount: _filters.length,
        itemBuilder: (context, i) {
          final filter = _filters[i];
          final isActive = _selectedFilter == filter;
          return GestureDetector(
            onTap: () => setState(() => _selectedFilter = filter),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(right: 10),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              decoration: BoxDecoration(
                color: isActive ? AppColors.primary : AppColors.surface,
                borderRadius: BorderRadius.circular(AppRadius.pill),
                boxShadow: isActive ? AppShadows.primary : AppShadows.card,
              ),
              child: Text(
                filter,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isActive ? Colors.white : AppColors.muted,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ── Request Card ───────────────────────────────────────────────────────────
  Widget _buildRequestCard({
    required String docId,
    required String serviceName,
    required String status,
    required dynamic createdAt,
    required String category,
  }) {
    final statusColor   = _getStatusColor(status);
    final statusBgColor = _getStatusBgColor(status);
    final statusIcon    = _getStatusIcon(status);
    final shortId = '#${docId.length > 7 ? docId.substring(0, 7).toUpperCase() : docId.toUpperCase()}';

    return GestureDetector(
      onTap: () => Navigator.pushNamed(
        context,
        '/requests/track',
        arguments: {'requestId': docId},
      ),
      child: Container(
        margin: const EdgeInsets.only(top: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          boxShadow: AppShadows.card,
        ),
        child: Row(
          children: [
            // Status icon
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: statusBgColor,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(statusIcon, color: statusColor, size: 24),
            ),
            const SizedBox(width: 14),

            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(serviceName,
                      style: AppTextStyles.h3.copyWith(fontSize: 15)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(shortId,
                          style: AppTextStyles.caption
                              .copyWith(letterSpacing: 0.5)),
                      if (category.isNotEmpty) ...[
                        const SizedBox(width: 6),
                        Container(
                          width: 4,
                          height: 4,
                          decoration: BoxDecoration(
                            color: AppColors.muted.withValues(alpha: 0.4),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(category,
                            style: AppTextStyles.caption),
                      ],
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _formatDate(createdAt),
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.muted,
                    ),
                  ),
                ],
              ),
            ),

            // Status badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: statusBgColor,
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
              child: Text(
                status.toUpperCase(),
                style: GoogleFonts.inter(
                  color: statusColor,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Empty State ────────────────────────────────────────────────────────────
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: const BoxDecoration(
              color: AppColors.cardBg,
              shape: BoxShape.circle,
            ),
            child: const Icon(LucideIcons.clipboardX,
                color: AppColors.primary, size: 46),
          ),
          const SizedBox(height: 24),
          Text('No requests found', style: AppTextStyles.h2),
          const SizedBox(height: 8),
          Text(
            _selectedFilter == 'All'
                ? 'Your submitted requests will appear here.'
                : 'No $_selectedFilter requests found.',
            style: AppTextStyles.bodyMuted,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          if (_selectedFilter == 'All')
            GestureDetector(
              onTap: () => Navigator.pushNamed(context, '/services'),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 24, vertical: 12),
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
                child: Text(
                  'Submit a Request',
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}