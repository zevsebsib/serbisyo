import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../widgets/bottom_nav.dart';

class RequestTrackingScreen extends StatelessWidget {
  const RequestTrackingScreen({super.key});

  // ── Status pipeline — defines the order of steps ──────────────────────────
  static const List<Map<String, dynamic>> _pipeline = [
    {
      'key':   'submitted',
      'label': 'Submitted',
      'icon':  LucideIcons.clipboardList,
    },
    {
      'key':   'pending',
      'label': 'Pending Review',
      'icon':  LucideIcons.clock3,
    },
    {
      'key':   'processing',
      'label': 'Processing',
      'icon':  LucideIcons.loader,
    },
    {
      'key':   'approved',
      'label': 'Approved',
      'icon':  LucideIcons.checkCircle2,
    },
    {
      'key':   'ready',
      'label': 'Ready for Pick Up',
      'icon':  LucideIcons.packageCheck,
    },
  ];

  // ── Get step state relative to current status ──────────────────────────────
  String _stepState(int stepIndex, int currentIndex) {
    if (stepIndex < currentIndex)  return 'completed';
    if (stepIndex == currentIndex) return 'current';
    return 'pending';
  }

  int _currentIndex(String status) {
    final idx = _pipeline.indexWhere((s) => s['key'] == status.toLowerCase());
    return idx < 0 ? 0 : idx;
  }

  // ── Format Firestore timestamp ─────────────────────────────────────────────
  String _formatDate(dynamic value) {
    if (value == null) return '';
    if (value is Timestamp) {
      final d = value.toDate();
      const months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ];
      final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
      final m = d.minute.toString().padLeft(2, '0');
      final period = d.hour >= 12 ? 'PM' : 'AM';
      return '${months[d.month - 1]} ${d.day}, ${d.year} · $h:$m $period';
    }
    return value.toString();
  }

  // ── Get timestamp for a specific step from statusHistory ──────────────────
  String _stepDate(List<dynamic> history, String stepKey) {
    try {
      final entry = history.firstWhere(
        (h) => h['status']?.toString().toLowerCase() == stepKey,
        orElse: () => null,
      );
      if (entry == null) return '';
      return _formatDate(entry['timestamp']);
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    // Get requestId passed from history screen or bottom nav
    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    final requestId = args?['requestId'] as String?;
    final uid = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Request Status'),
        leading: IconButton(
          icon: const Icon(LucideIcons.chevronLeft, color: AppColors.primary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      bottomNavigationBar: const BottomNav(selectedIndex: 1),
      body: requestId == null || uid == null
          ? _buildNoRequest(context)
          : StreamBuilder<DocumentSnapshot>(
              // FIX: real-time listener on the specific request document
              stream: FirebaseFirestore.instance
                  .collection('requests')
                  .doc(requestId)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || !snapshot.data!.exists) {
                  return _buildNoRequest(context);
                }

                final data = snapshot.data!.data() as Map<String, dynamic>;
                final serviceName = data['serviceName']?.toString() ?? 'Service Request';
                final category    = data['category']?.toString() ?? '';
                final status      = data['status']?.toString() ?? 'submitted';
                final history     = (data['statusHistory'] as List<dynamic>?) ?? [];
                final currentIdx  = _currentIndex(status);
                final shortId     = '#${requestId.length > 8 ? requestId.substring(0, 8).toUpperCase() : requestId.toUpperCase()}';
                final isRejected  = status.toLowerCase() == 'rejected';

                return SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 32, vertical: 24),
                  child: Column(
                    children: [
                      // ── Request Header ───────────────────────────────────
                      Column(
                        children: [
                          Text(
                            category.isNotEmpty
                                ? category.toUpperCase()
                                : 'SERVICE REQUEST',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.black.withValues(alpha: 0.4),
                              letterSpacing: 2.0,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Container(
                            width: 80,
                            height: 96,
                            decoration: BoxDecoration(
                              color: isRejected
                                  ? AppColors.danger
                                  : AppColors.primary,
                              borderRadius: BorderRadius.circular(24),
                              boxShadow: [
                                BoxShadow(
                                  color: (isRejected
                                          ? AppColors.danger
                                          : AppColors.primary)
                                      .withValues(alpha: 0.2),
                                  blurRadius: 20,
                                  offset: const Offset(0, 10),
                                ),
                              ],
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  isRejected
                                      ? LucideIcons.xCircle
                                      : LucideIcons.fileText,
                                  color: Colors.white,
                                  size: 40,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  isRejected ? 'REJECT' : 'FILE',
                                  style: GoogleFonts.inter(
                                    fontSize: 8,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white.withValues(alpha: 0.6),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Service name
                          Text(
                            serviceName,
                            style: GoogleFonts.inter(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: Colors.black,
                              letterSpacing: -0.5,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 6),

                          // Request ID
                          Text(
                            'REQUEST ID: $shortId',
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              color: Colors.black,
                              letterSpacing: 1.0,
                            ),
                          ),

                          // Rejected banner
                          if (isRejected) ...[
                            const SizedBox(height: 16),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFEEEE),
                                borderRadius:
                                    BorderRadius.circular(AppRadius.lg),
                                border: Border.all(
                                    color: AppColors.danger
                                        .withValues(alpha: 0.3)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(LucideIcons.alertCircle,
                                      color: AppColors.danger, size: 18),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      data['rejectionReason']?.toString() ??
                                          'Your request was rejected. Please contact support for more info.',
                                      style: GoogleFonts.inter(
                                        fontSize: 12,
                                        color: AppColors.danger,
                                        height: 1.5,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),

                      const SizedBox(height: 32),
                      Container(
                          height: 1,
                          color: Colors.black.withValues(alpha: 0.05),
                          width: double.infinity),
                      const SizedBox(height: 40),

                      // ── Stepper ──────────────────────────────────────────
                      if (!isRejected)
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _pipeline.length,
                          itemBuilder: (context, idx) {
                            final step      = _pipeline[idx];
                            final stepState = _stepState(idx, currentIdx);
                            final isLast    = idx == _pipeline.length - 1;
                            final date      = _stepDate(history, step['key']);

                            return IntrinsicHeight(
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // ── Step indicator & line ────────────────
                                  Column(
                                    children: [
                                      Container(
                                        width: 40,
                                        height: 40,
                                        decoration: BoxDecoration(
                                          color: stepState == 'completed'
                                              ? AppColors.primary
                                              : Colors.white,
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: stepState == 'pending'
                                                ? Colors.black
                                                    .withValues(alpha: 0.05)
                                                : AppColors.primary,
                                            width: 4,
                                          ),
                                          boxShadow: stepState == 'completed'
                                              ? [
                                                  BoxShadow(
                                                    color: AppColors.primary
                                                        .withValues(alpha: 0.3),
                                                    blurRadius: 10,
                                                    offset:
                                                        const Offset(0, 4),
                                                  )
                                                ]
                                              : null,
                                        ),
                                        child: Center(
                                          child: stepState == 'completed'
                                              ? const Icon(
                                                  LucideIcons.check,
                                                  color: Colors.white,
                                                  size: 20,
                                                )
                                              : Text(
                                                  '${idx + 1}',
                                                  style: GoogleFonts.inter(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w900,
                                                    color: stepState == 'current'
                                                        ? AppColors.primary
                                                        : Colors.black
                                                            .withValues(
                                                                alpha: 0.1),
                                                  ),
                                                ),
                                        ),
                                      ),
                                      if (!isLast)
                                        Expanded(
                                          child: Container(
                                            width: 2,
                                            color: stepState == 'completed'
                                                ? AppColors.primary
                                                    .withValues(alpha: 0.3)
                                                : Colors.black
                                                    .withValues(alpha: 0.05),
                                            margin: const EdgeInsets.symmetric(
                                                vertical: 4),
                                          ),
                                        ),
                                    ],
                                  ),

                                  const SizedBox(width: 24),

                                  // ── Step content ─────────────────────────
                                  Expanded(
                                    child: Container(
                                      padding: const EdgeInsets.only(
                                          top: 8, bottom: 32),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                step['label'],
                                                style: GoogleFonts.inter(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w900,
                                                  color: stepState == 'pending'
                                                      ? Colors.black
                                                          .withValues(
                                                              alpha: 0.2)
                                                      : Colors.black,
                                                ),
                                              ),
                                              if (date.isNotEmpty)
                                                Padding(
                                                  padding:
                                                      const EdgeInsets.only(
                                                          top: 4),
                                                  child: Text(
                                                    date,
                                                    style: GoogleFonts.inter(
                                                      fontSize: 10,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color: Colors.black
                                                          .withValues(
                                                              alpha: 0.3),
                                                      letterSpacing: -0.5,
                                                    ),
                                                  ),
                                                ),
                                            ],
                                          ),
                                          Text(
                                            stepState == 'completed'
                                                ? 'DONE'
                                                : stepState == 'current'
                                                    ? 'IN PROGRESS'
                                                    : 'PENDING',
                                            style: GoogleFonts.inter(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w900,
                                              color: stepState == 'completed'
                                                  ? AppColors.success
                                                  : stepState == 'current'
                                                      ? AppColors.primary
                                                      : Colors.black
                                                          .withValues(
                                                              alpha: 0.2),
                                              letterSpacing: -0.5,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),

                      const SizedBox(height: 120),
                    ],
                  ),
                );
              },
            ),
    );
  }

  // ── No request selected state ──────────────────────────────────────────────
  Widget _buildNoRequest(BuildContext context) {
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
          Text('No request selected', style: AppTextStyles.h2),
          const SizedBox(height: 8),
          Text('Go to History to track a request.',
              style: AppTextStyles.bodyMuted),
          const SizedBox(height: 24),
          GestureDetector(
            onTap: () =>
                Navigator.pushReplacementNamed(context, '/profile_history'),
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
              child: Text(
                'View History',
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
