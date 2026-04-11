import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:serbisyo_alisto/helpers/request_status.dart';
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

  // ── FIX: Map filter labels to ALL matching Firestore status values ──────────
  // Previously 'Pending'.toLowerCase() == 'pending' only — missed
  // 'submitted' and 'pending_review' which are the real active statuses.
  List<String> _statusValuesFor(String filter) {
    return requestStatusFilterValues(filter);
  }

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

  // ── FIX: Normalise display label for status values ─────────────────────────
  String _statusLabel(String status) {
    return requestStatusLabel(status);
  }

  Color _getStatusColor(String status) {
    switch (normalizeRequestStatus(status)) {
      case 'submitted':        return const Color(0xFF5C6BC0);
      case 'pending_review':   return AppColors.warning;
      case 'approved':         return const Color(0xFF8B5CF6);
      case 'processing':
      case 'ready_for_pickup': return AppColors.primary;
      case 'completed':        return AppColors.success;
      case 'returned':         return const Color(0xFFF97316);
      case 'rejected':         return AppColors.danger;
      default:                 return AppColors.muted;
    }
  }

  Color _getStatusBgColor(String status) {
    switch (normalizeRequestStatus(status)) {
      case 'submitted':        return const Color(0xFFEDE7F6);
      case 'pending_review':   return AppColors.warningLight;
      case 'approved':         return const Color(0xFFF3E8FF);
      case 'processing':
      case 'ready_for_pickup': return AppColors.cardBg;
      case 'completed':        return AppColors.successLight;
      case 'returned':         return const Color(0xFFFFF3E8);
      case 'rejected':         return const Color(0xFFFFEEEE);
      default:                 return AppColors.cardBg;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (normalizeRequestStatus(status)) {
      case 'submitted':        return LucideIcons.send;
      case 'pending_review':   return LucideIcons.clock3;
      case 'approved':         return LucideIcons.thumbsUp;
      case 'processing':       return LucideIcons.loader;
      case 'ready_for_pickup': return LucideIcons.packageCheck;
      case 'completed':        return LucideIcons.checkCircle2;
      case 'returned':         return LucideIcons.undo2;
      case 'rejected':         return LucideIcons.xCircle;
      default:                 return LucideIcons.clipboard;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_uid == null) {
      return const Scaffold(
        body: Center(child: Text('Not logged in')),
      );
    }

    // ── FIX: Build query correctly for each filter ─────────────────────────
    // Firestore doesn't support OR queries on the same field natively with
    // .where(), so we fetch all for the user and filter client-side for the
    // multi-value filters. For single-value filters (Completed, Rejected)
    // we use the server query directly for efficiency.
    final statusValues = _statusValuesFor(_selectedFilter);
    final bool useClientFilter =
        _selectedFilter != 'All' && statusValues.length > 1;
    final bool useSingleServerFilter =
        _selectedFilter != 'All' && statusValues.length == 1;

    Query query = FirebaseFirestore.instance
        .collection('requests')
        .where('userId', isEqualTo: _uid)
        .orderBy('createdAt', descending: true);

    if (useSingleServerFilter) {
      query = query.where('status', isEqualTo: statusValues.first);
    }
    // For multi-value filters we fetch all and filter in StreamBuilder below

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
                if (snapshot.connectionState ==
                    ConnectionState.waiting) {
                  return const Center(
                      child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Text('Something went wrong.',
                        style: AppTextStyles.bodyMuted),
                  );
                }

                var docs = snapshot.data?.docs ?? [];

                // ── FIX: Client-side filter for multi-value statuses ───────
                if (useClientFilter) {
                  docs = docs.where((doc) {
                    final data =
                        doc.data() as Map<String, dynamic>;
                    final s =
                        data['status']?.toString().toLowerCase() ??
                            '';
                    return statusValues.contains(s);
                  }).toList();
                }

                if (docs.isEmpty) {
                  return _buildEmptyState();
                }

                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(
                      18, 8, 18, 100),
                  itemCount: docs.length,
                  itemBuilder: (context, i) {
                    final data = docs[i].data()
                        as Map<String, dynamic>;
                    final status =
                        data['status']?.toString() ?? 'submitted';
                    return _buildRequestCard(
                      docId: docs[i].id,
                      serviceName:
                          data['serviceName']?.toString() ??
                              'Request',
                      status:   status,
                      createdAt: data['createdAt'],
                      category:
                          data['category']?.toString() ?? '',
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
          bottomLeft:  Radius.circular(28),
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
                  width: 42, height: 42,
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
          final filter   = _filters[i];
          final isActive = _selectedFilter == filter;
          return GestureDetector(
            onTap: () =>
                setState(() => _selectedFilter = filter),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(right: 10),
              padding: const EdgeInsets.symmetric(
                  horizontal: 18, vertical: 10),
              decoration: BoxDecoration(
                color: isActive
                    ? AppColors.primary
                    : AppColors.surface,
                borderRadius:
                    BorderRadius.circular(AppRadius.pill),
                boxShadow: isActive
                    ? AppShadows.primary
                    : AppShadows.card,
              ),
              child: Text(
                filter,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color:
                      isActive ? Colors.white : AppColors.muted,
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
    final label         = _statusLabel(status);
    final shortId =
        '#${docId.length > 7 ? docId.substring(0, 7).toUpperCase() : docId.toUpperCase()}';

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
          borderRadius:
              BorderRadius.circular(AppRadius.lg),
          boxShadow: AppShadows.card,
        ),
        child: Row(
          children: [
            Container(
              width: 50, height: 50,
              decoration: BoxDecoration(
                color: statusBgColor,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(statusIcon,
                  color: statusColor, size: 24),
            ),
            const SizedBox(width: 14),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(serviceName,
                      style: AppTextStyles.h3
                          .copyWith(fontSize: 15)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(shortId,
                          style: AppTextStyles.caption
                              .copyWith(letterSpacing: 0.5)),
                      if (category.isNotEmpty) ...[
                        const SizedBox(width: 6),
                        Container(
                          width: 4, height: 4,
                          decoration: BoxDecoration(
                            color: AppColors.muted
                                .withValues(alpha: 0.4),
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
                        color: AppColors.muted),
                  ),
                ],
              ),
            ),

            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: statusBgColor,
                borderRadius: BorderRadius.circular(
                    AppRadius.pill),
              ),
              child: Text(
                label.toUpperCase(),
                style: GoogleFonts.inter(
                  color: statusColor,
                  fontSize: 10,
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
            width: 100, height: 100,
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
              onTap: () =>
                  Navigator.pushNamed(context, '/services'),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 24, vertical: 12),
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(
                      AppRadius.pill),
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