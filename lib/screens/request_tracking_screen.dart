import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_theme.dart';
import '../widgets/bottom_nav.dart';

class RequestTrackingScreen extends StatelessWidget {
  final String? requestId;
  const RequestTrackingScreen({super.key, this.requestId});

  // ── Unified pipeline ─────────────────────────────────────────────
  static const List<Map<String, dynamic>> _pipeline = [
    {'key': 'submitted',        'label': 'Submitted',         'icon': LucideIcons.clipboardList},
    {'key': 'pending_review',   'label': 'Pending Review',    'icon': LucideIcons.clock3},
    {'key': 'processing',       'label': 'Processing',        'icon': LucideIcons.loader},
    {'key': 'approved',         'label': 'Approved',          'icon': LucideIcons.checkCircle2},
    {'key': 'ready_for_pickup', 'label': 'Ready for Pick Up', 'icon': LucideIcons.packageCheck},
  ];

  // ── Map legacy status values ──────────────────────────────────────
  String _mapLegacyStatus(String status) {
    switch (status) {
      case 'pending':     return 'pending_review';
      case 'in_progress': return 'processing';
      case 'ready':       return 'ready_for_pickup';
      default:            return status;
    }
  }

  // ── Current index in pipeline ─────────────────────────────────────
  // completed = ALL 5 steps done → return _pipeline.length
  // rejected  = show rejection banner, not stepper
  int _currentIndex(String status) {
    final s = status.toLowerCase();
    if (s == 'completed') return _pipeline.length; // ✅ all steps done
    if (s == 'rejected')  return 0;
    final mapped = _mapLegacyStatus(s);
    final idx    = _pipeline.indexWhere((step) => step['key'] == mapped);
    return idx < 0 ? 0 : idx;
  }

  String _stepState(int stepIndex, int currentIndex) {
    if (stepIndex < currentIndex)  return 'completed';
    if (stepIndex == currentIndex) return 'current';
    return 'pending';
  }

  String _formatDate(dynamic value) {
    if (value == null) return '';
    if (value is Timestamp) {
      final d = value.toDate();
      const months = [
        'Jan','Feb','Mar','Apr','May','Jun',
        'Jul','Aug','Sep','Oct','Nov','Dec'
      ];
      final h      = d.hour % 12 == 0 ? 12 : d.hour % 12;
      final m      = d.minute.toString().padLeft(2, '0');
      final period = d.hour >= 12 ? 'PM' : 'AM';
      return '${months[d.month - 1]} ${d.day}, ${d.year} · $h:$m $period';
    }
    return value.toString();
  }

  String _stepDate(List<dynamic> history, String stepKey) {
    try {
      final entry = history.firstWhere(
        (h) {
          final s = h['status']?.toString().toLowerCase() ?? '';
          return s == stepKey || _mapLegacyStatus(s) == stepKey;
        },
        orElse: () => null,
      );
      if (entry == null) return '';
      return _formatDate(entry['timestamp'] ?? entry['updatedAt']);
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final routeArgs  = ModalRoute.of(context)?.settings.arguments
        as Map<String, dynamic>?;
    final resolvedId = requestId?.isNotEmpty == true
        ? requestId
        : routeArgs?['requestId'] as String?;
    final uid        = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Request Status'),
        leading: IconButton(
          icon: const Icon(LucideIcons.chevronLeft,
              color: AppColors.primary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      bottomNavigationBar: const BottomNav(selectedIndex: 1),
      body: resolvedId == null || uid == null
          ? _buildNoRequest(context)
          : StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('requests')
                  .doc(resolvedId)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState ==
                    ConnectionState.waiting) {
                  return const Center(
                      child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || !snapshot.data!.exists) {
                  return _buildNoRequest(context);
                }

                final data =
                    snapshot.data!.data() as Map<String, dynamic>;

                final serviceName =
                    data['serviceName']?.toString() ?? 'Service Request';
                final category    = data['category']?.toString() ?? '';
                final rawStatus   =
                    data['status']?.toString() ?? 'submitted';
                final history     =
                    (data['statusHistory'] as List<dynamic>?) ?? [];
                final currentIdx  = _currentIndex(rawStatus);
                final trackingId  = data['trackingId']?.toString() ?? '';
                final shortId     = trackingId.isNotEmpty
                    ? trackingId
                    : '#${resolvedId.length > 8 ? resolvedId.substring(0, 8).toUpperCase() : resolvedId.toUpperCase()}';

                final isRejected  = rawStatus.toLowerCase() == 'rejected';
                final isCompleted = rawStatus.toLowerCase() == 'completed';
                final missingDocs =
                    List<String>.from(data['missingDocuments'] ?? []);
                final finalDocUrl =
                    data['finalDocumentUrl']?.toString() ?? '';
                final hasMissing  = missingDocs.isNotEmpty;
                final hasFinalDoc = finalDocUrl.isNotEmpty;
                final assignedTo  =
                    data['assignedTo']?.toString() ?? '';

                return SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 32, vertical: 24),
                  child: Column(
                    children: [
                      // ── Header ───────────────────────────────────
                      Column(
                        children: [
                          Text(
                            category.isNotEmpty
                                ? category.toUpperCase()
                                : 'SERVICE REQUEST',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.black
                                  .withValues(alpha: 0.4),
                              letterSpacing: 2.0,
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Icon card
                          Container(
                            width: 80, height: 96,
                            decoration: BoxDecoration(
                              color: isRejected
                                  ? AppColors.danger
                                  : isCompleted
                                      ? AppColors.success
                                      : AppColors.primary,
                              borderRadius:
                                  BorderRadius.circular(24),
                              boxShadow: [
                                BoxShadow(
                                  color: (isRejected
                                          ? AppColors.danger
                                          : isCompleted
                                              ? AppColors.success
                                              : AppColors.primary)
                                      .withValues(alpha: 0.2),
                                  blurRadius: 20,
                                  offset: const Offset(0, 10),
                                ),
                              ],
                            ),
                            child: Column(
                              mainAxisAlignment:
                                  MainAxisAlignment.center,
                              children: [
                                Icon(
                                  isRejected
                                      ? LucideIcons.xCircle
                                      : isCompleted
                                          ? LucideIcons.checkCircle2
                                          : LucideIcons.fileText,
                                  color: Colors.white,
                                  size: 40,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  isRejected
                                      ? 'REJECT'
                                      : isCompleted
                                          ? 'DONE'
                                          : 'FILE',
                                  style: GoogleFonts.inter(
                                    fontSize: 8,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white
                                        .withValues(alpha: 0.6),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),

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
                          Text(
                            'TRACKING ID: $shortId',
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              color: Colors.black,
                              letterSpacing: 1.0,
                            ),
                          ),

                          // Status badge
                          const SizedBox(height: 10),
                          _buildStatusBadge(rawStatus),

                          // Assigned badge
                          if (assignedTo.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Container(
                              padding:
                                  const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 5),
                              decoration: BoxDecoration(
                                color: const Color(0xFF2196F3)
                                    .withValues(alpha: 0.10),
                                borderRadius:
                                    BorderRadius.circular(
                                        AppRadius.pill),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                      LucideIcons.userCheck,
                                      size: 11,
                                      color: Color(0xFF2196F3)),
                                  const SizedBox(width: 5),
                                  Text(
                                    'Assigned to staff',
                                    style: GoogleFonts.inter(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color:
                                          const Color(0xFF2196F3),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],

                          // Rejected banner
                          if (isRejected) ...[
                            const SizedBox(height: 16),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFEEEE),
                                borderRadius:
                                    BorderRadius.circular(
                                        AppRadius.lg),
                                border: Border.all(
                                    color: AppColors.danger
                                        .withValues(alpha: 0.3)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                      LucideIcons.alertCircle,
                                      color: AppColors.danger,
                                      size: 18),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      data['rejectionReason']
                                                  ?.toString()
                                                  .isNotEmpty ==
                                              true
                                          ? data['rejectionReason']
                                              .toString()
                                          : 'Your request was rejected. Please contact support.',
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

                          // Completed banner (no final doc)
                          if (isCompleted && !hasFinalDoc) ...[
                            const SizedBox(height: 16),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: AppColors.successLight,
                                borderRadius:
                                    BorderRadius.circular(
                                        AppRadius.lg),
                                border: Border.all(
                                    color: AppColors.success
                                        .withValues(alpha: 0.3)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                      LucideIcons.checkCircle2,
                                      color: AppColors.success,
                                      size: 18),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      'Your request has been completed. Please visit City Hall to claim your document.',
                                      style: GoogleFonts.inter(
                                        fontSize: 12,
                                        color: AppColors.success,
                                        height: 1.5,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],

                          // Missing documents alert
                          if (hasMissing) ...[
                            const SizedBox(height: 16),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: AppColors.warningLight,
                                borderRadius:
                                    BorderRadius.circular(
                                        AppRadius.lg),
                                border: Border.all(
                                    color: AppColors.warning
                                        .withValues(alpha: 0.4)),
                              ),
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Row(children: [
                                    const Icon(
                                        LucideIcons.alertTriangle,
                                        color: AppColors.warning,
                                        size: 16),
                                    const SizedBox(width: 8),
                                    Text('Action Required',
                                        style: GoogleFonts.inter(
                                          fontSize: 13,
                                          fontWeight:
                                              FontWeight.w800,
                                          color: AppColors.warning,
                                        )),
                                  ]),
                                  const SizedBox(height: 6),
                                  Text(
                                    'The following documents are missing or incomplete:',
                                    style: GoogleFonts.inter(
                                        fontSize: 12,
                                        color: Colors.black
                                            .withValues(alpha: 0.6)),
                                  ),
                                  const SizedBox(height: 10),
                                  ...missingDocs.map((doc) =>
                                      Padding(
                                        padding:
                                            const EdgeInsets.only(
                                                bottom: 6),
                                        child: Row(children: [
                                          Container(
                                            width: 6, height: 6,
                                            decoration:
                                                const BoxDecoration(
                                              color:
                                                  AppColors.warning,
                                              shape:
                                                  BoxShape.circle,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(doc,
                                                style: GoogleFonts
                                                    .inter(
                                                  fontSize: 12,
                                                  fontWeight:
                                                      FontWeight.w600,
                                                  color: Colors.black
                                                      .withValues(
                                                          alpha: 0.75),
                                                )),
                                          ),
                                        ]),
                                      )),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Please visit the City Hall office to submit the missing documents.',
                                    style: GoogleFonts.inter(
                                      fontSize: 11,
                                      color: AppColors.warning,
                                      height: 1.4,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],

                          // Final document download
                          if (hasFinalDoc) ...[
                            const SizedBox(height: 16),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: AppColors.successLight,
                                borderRadius:
                                    BorderRadius.circular(
                                        AppRadius.lg),
                                border: Border.all(
                                    color: AppColors.success
                                        .withValues(alpha: 0.4)),
                              ),
                              child: Column(
                                children: [
                                  Row(children: [
                                    const Icon(
                                        LucideIcons.checkCircle2,
                                        color: AppColors.success,
                                        size: 16),
                                    const SizedBox(width: 8),
                                    Text('Your Document is Ready!',
                                        style: GoogleFonts.inter(
                                          fontSize: 13,
                                          fontWeight:
                                              FontWeight.w800,
                                          color: AppColors.success,
                                        )),
                                  ]),
                                  const SizedBox(height: 6),
                                  Text(
                                    'Your processed document is available for download.',
                                    style: GoogleFonts.inter(
                                        fontSize: 12,
                                        color: Colors.black
                                            .withValues(alpha: 0.6),
                                        height: 1.4),
                                  ),
                                  const SizedBox(height: 12),
                                  SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton.icon(
                                      onPressed: () async {
                                        final uri =
                                            Uri.parse(finalDocUrl);
                                        if (await canLaunchUrl(
                                            uri)) {
                                          await launchUrl(uri,
                                              mode: LaunchMode
                                                  .externalApplication);
                                        }
                                      },
                                      icon: const Icon(
                                          LucideIcons.download,
                                          size: 16),
                                      label: Text(
                                          'Download Document',
                                          style: GoogleFonts.inter(
                                            fontWeight:
                                                FontWeight.w700,
                                            fontSize: 13,
                                          )),
                                      style:
                                          ElevatedButton.styleFrom(
                                        backgroundColor:
                                            AppColors.success,
                                        foregroundColor:
                                            Colors.white,
                                        elevation: 0,
                                        padding:
                                            const EdgeInsets
                                                .symmetric(
                                                vertical: 12),
                                        shape:
                                            RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(
                                                  AppRadius.lg),
                                        ),
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
                        width: double.infinity,
                      ),
                      const SizedBox(height: 40),

                      // ── Stepper ──────────────────────────────────
                      if (!isRejected)
                        ListView.builder(
                          shrinkWrap: true,
                          physics:
                              const NeverScrollableScrollPhysics(),
                          itemCount: _pipeline.length,
                          itemBuilder: (context, idx) {
                            final step      = _pipeline[idx];
                            final stepState =
                                _stepState(idx, currentIdx);
                            final isLast =
                                idx == _pipeline.length - 1;
                            final date = _stepDate(
                                history, step['key'] as String);

                            return IntrinsicHeight(
                              child: Row(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  // Circle + connector line
                                  Column(
                                    children: [
                                      Container(
                                        width: 40, height: 40,
                                        decoration: BoxDecoration(
                                          color: stepState ==
                                                  'completed'
                                              ? AppColors.primary
                                              : Colors.white,
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: stepState ==
                                                    'pending'
                                                ? Colors.black
                                                    .withValues(
                                                        alpha: 0.05)
                                                : AppColors.primary,
                                            width: 4,
                                          ),
                                          boxShadow: stepState ==
                                                  'completed'
                                              ? [
                                                  BoxShadow(
                                                    color: AppColors
                                                        .primary
                                                        .withValues(
                                                            alpha:
                                                                0.3),
                                                    blurRadius: 10,
                                                    offset:
                                                        const Offset(
                                                            0, 4),
                                                  )
                                                ]
                                              : null,
                                        ),
                                        child: Center(
                                          child: stepState ==
                                                  'completed'
                                              ? const Icon(
                                                  LucideIcons.check,
                                                  color:
                                                      Colors.white,
                                                  size: 20)
                                              : Text(
                                                  '${idx + 1}',
                                                  style: GoogleFonts
                                                      .inter(
                                                    fontSize: 12,
                                                    fontWeight:
                                                        FontWeight
                                                            .w900,
                                                    color: stepState ==
                                                            'current'
                                                        ? AppColors
                                                            .primary
                                                        : Colors.black
                                                            .withValues(
                                                                alpha:
                                                                    0.1),
                                                  ),
                                                ),
                                        ),
                                      ),
                                      if (!isLast)
                                        Expanded(
                                          child: Container(
                                            width: 2,
                                            color: stepState ==
                                                    'completed'
                                                ? AppColors.primary
                                                    .withValues(
                                                        alpha: 0.3)
                                                : Colors.black
                                                    .withValues(
                                                        alpha: 0.05),
                                            margin: const EdgeInsets
                                                .symmetric(
                                                    vertical: 4),
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(width: 24),

                                  // Label + date + badge
                                  Expanded(
                                    child: Container(
                                      padding:
                                          const EdgeInsets.only(
                                              top: 8, bottom: 32),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment
                                                .spaceBetween,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment
                                                    .start,
                                            children: [
                                              Text(
                                                step['label']
                                                    as String,
                                                style: GoogleFonts
                                                    .inter(
                                                  fontSize: 14,
                                                  fontWeight:
                                                      FontWeight.w900,
                                                  color: stepState ==
                                                          'pending'
                                                      ? Colors.black
                                                          .withValues(
                                                              alpha:
                                                                  0.2)
                                                      : Colors.black,
                                                ),
                                              ),
                                              if (date.isNotEmpty)
                                                Padding(
                                                  padding:
                                                      const EdgeInsets
                                                          .only(
                                                              top: 4),
                                                  child: Text(
                                                    date,
                                                    style: GoogleFonts
                                                        .inter(
                                                      fontSize: 10,
                                                      fontWeight:
                                                          FontWeight
                                                              .bold,
                                                      color: Colors
                                                          .black
                                                          .withValues(
                                                              alpha:
                                                                  0.3),
                                                      letterSpacing:
                                                          -0.5,
                                                    ),
                                                  ),
                                                ),
                                            ],
                                          ),
                                          Text(
                                            stepState == 'completed'
                                                ? 'DONE'
                                                : stepState ==
                                                        'current'
                                                    ? 'IN PROGRESS'
                                                    : 'PENDING',
                                            style: GoogleFonts.inter(
                                              fontSize: 10,
                                              fontWeight:
                                                  FontWeight.w900,
                                              color: stepState ==
                                                      'completed'
                                                  ? AppColors.success
                                                  : stepState ==
                                                          'current'
                                                      ? AppColors
                                                          .primary
                                                      : Colors.black
                                                          .withValues(
                                                              alpha:
                                                                  0.2),
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

  Widget _buildStatusBadge(String rawStatus) {
    final Map<String, Map<String, dynamic>> styles = {
      'submitted':        {'label': 'Submitted',         'color': const Color(0xFF5C6BC0)},
      'pending_review':   {'label': 'Pending Review',    'color': const Color(0xFFF59E0B)},
      'pending':          {'label': 'Pending Review',    'color': const Color(0xFFF59E0B)},
      'processing':       {'label': 'Processing',        'color': const Color(0xFF3B82F6)},
      'in_progress':      {'label': 'Processing',        'color': const Color(0xFF3B82F6)},
      'approved':         {'label': 'Approved',          'color': const Color(0xFF8B5CF6)},
      'ready_for_pickup': {'label': 'Ready for Pick Up', 'color': AppColors.primary},
      'ready':            {'label': 'Ready for Pick Up', 'color': AppColors.primary},
      'completed':        {'label': 'Completed',         'color': AppColors.success},
      'rejected':         {'label': 'Rejected',          'color': AppColors.danger},
    };

    final style = styles[rawStatus.toLowerCase()] ??
        {'label': rawStatus, 'color': AppColors.muted};
    final color = style['color'] as Color;
    final label = style['label'] as String;

    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: color.withValues(alpha: 0.30)),
      ),
      child: Text(label,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: color,
          )),
    );
  }

  Widget _buildNoRequest(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 100, height: 100,
            decoration: const BoxDecoration(
                color: AppColors.cardBg, shape: BoxShape.circle),
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
            onTap: () => Navigator.pushReplacementNamed(
                context, '/profile_history'),
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius:
                    BorderRadius.circular(AppRadius.pill),
              ),
              child: Text('View History',
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