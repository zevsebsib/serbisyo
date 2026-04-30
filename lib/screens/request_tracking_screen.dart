import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:serbisyo_alisto/helpers/request_status.dart';
import '../theme/app_theme.dart';
import '../widgets/bottom_nav.dart';

class RequestTrackingScreen extends StatefulWidget {
  final String? requestId;
  const RequestTrackingScreen({super.key, this.requestId});

  @override
  State<RequestTrackingScreen> createState() =>
      _RequestTrackingScreenState();
}

class _RequestTrackingScreenState
    extends State<RequestTrackingScreen> {
  // ── Unified pipeline ───────────────────────────────────────────────
  static const List<Map<String, dynamic>> _pipeline = [
    {'key': 'submitted',        'label': 'Submitted',         'icon': LucideIcons.clipboardList},
    {'key': 'pending_review',   'label': 'Pending Review',    'icon': LucideIcons.clock3},
    {'key': 'processing',       'label': 'Processing',        'icon': LucideIcons.loader},
    {'key': 'approved',         'label': 'Approved',          'icon': LucideIcons.checkCircle2},
    {'key': 'ready_for_pickup', 'label': 'Ready for Pick Up', 'icon': LucideIcons.packageCheck},
  ];

  int _currentIndex(String status) {
    final s = normalizeRequestStatus(status);
    if (s == 'completed') return _pipeline.length;
    if (s == 'rejected' || s == 'returned')  return 0;
    final idx    = _pipeline.indexWhere((step) => step['key'] == s);
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
          return normalizeRequestStatus(s) == stepKey;
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
    final routeArgs = ModalRoute.of(context)?.settings.arguments
        as Map<String, dynamic>?;
    final resolvedId = widget.requestId?.isNotEmpty == true
        ? widget.requestId
        : routeArgs?['requestId'] as String?;
    final uid = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          resolvedId != null ? 'Request Status' : 'My Requests',
        ),
        leading: resolvedId != null
            ? IconButton(
                icon: const Icon(LucideIcons.chevronLeft,
                    color: AppColors.primary),
                onPressed: () => Navigator.pop(context),
              )
            : null,
      ),
      bottomNavigationBar: const BottomNav(selectedIndex: 1),

      // ── If no requestId → show requests list ───────────────────────
      body: resolvedId == null || uid == null
          ? _buildRequestList(context, uid)
          : _buildTrackingView(context, resolvedId, uid),
    );
  }

  // ── NEW: All Requests List ─────────────────────────────────────────
  Widget _buildRequestList(BuildContext context, String? uid) {
    if (uid == null) {
      return _buildEmptyList(context);
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('requests')
          .where('userId', isEqualTo: uid)
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator(
                  color: AppColors.primary));
        }

        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) return _buildEmptyList(context);

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(18, 20, 18, 120),
          itemCount: docs.length,
          separatorBuilder: (_, __) =>
              const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final doc  = docs[index];
            final data = doc.data() as Map<String, dynamic>;
            return _buildRequestListItem(context, doc.id, data);
          },
        );
      },
    );
  }

  Widget _buildRequestListItem(
    BuildContext context,
    String docId,
    Map<String, dynamic> data,
  ) {
    final serviceName =
        data['serviceName']?.toString() ?? 'Service Request';
    final rawStatus   =
        data['status']?.toString().toLowerCase() ?? 'submitted';
    final trackingId  = data['trackingId']?.toString() ?? '';
    final shortId     = trackingId.isNotEmpty
        ? trackingId
        : '#${docId.length > 8 ? docId.substring(0, 8).toUpperCase() : docId.toUpperCase()}';
    final createdAt   = data['createdAt'];

    // Status style
    final Map<String, Map<String, dynamic>> statusStyles = {
      'submitted':        {'label': 'Submitted',         'color': const Color(0xFF5C6BC0)},
      'pending_review':   {'label': 'Pending Review',    'color': const Color(0xFFF59E0B)},
      'pending':          {'label': 'Pending Review',    'color': const Color(0xFFF59E0B)},
      'processing':       {'label': 'Processing',        'color': const Color(0xFF3B82F6)},
      'in_progress':      {'label': 'Processing',        'color': const Color(0xFF3B82F6)},
      'approved':         {'label': 'Approved',          'color': const Color(0xFF8B5CF6)},
      'ready_for_pickup': {'label': 'Ready for Pick Up', 'color': AppColors.primary},
      'ready':            {'label': 'Ready for Pick Up', 'color': AppColors.primary},
      'completed':        {'label': 'Completed',         'color': AppColors.success},
      'returned':         {'label': 'Returned',          'color': const Color(0xFFF97316)},
      'rejected':         {'label': 'Rejected',          'color': AppColors.danger},
    };
    final style = statusStyles[rawStatus] ??
        {'label': rawStatus, 'color': AppColors.muted};
    final statusColor = style['color'] as Color;
    final statusLabel = style['label'] as String;

    return GestureDetector(
      onTap: () => Navigator.pushNamed(
        context,
        '/requests/track',
        arguments: {'requestId': docId},
      ),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          boxShadow: AppShadows.card,
        ),
        child: Row(
          children: [
            // Icon
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: AppColors.cardBg,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(LucideIcons.clipboard,
                  color: AppColors.primary, size: 24),
            ),
            const SizedBox(width: 14),

            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    serviceName,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF111111),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          shortId,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: AppColors.muted,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                      if (createdAt != null) ...[
                        const SizedBox(width: 6),
                        Container(
                          width: 3, height: 3,
                          decoration: BoxDecoration(
                            color: AppColors.muted
                                .withValues(alpha: 0.4),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            _formatDate(createdAt),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              color: AppColors.muted,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),

            // Status chip + arrow
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 116),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.10),
                      borderRadius:
                          BorderRadius.circular(AppRadius.pill),
                      border: Border.all(
                          color: statusColor.withValues(alpha: 0.25)),
                    ),
                    child: Text(
                      statusLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: statusColor,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Icon(
                    LucideIcons.chevronRight,
                    size: 14,
                    color: AppColors.muted.withValues(alpha: 0.5),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyList(BuildContext context) {
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
          Text('No requests yet', style: AppTextStyles.h2),
          const SizedBox(height: 8),
          Text('Submit a request to get started.',
              style: AppTextStyles.bodyMuted),
          const SizedBox(height: 24),
          GestureDetector(
            onTap: () =>
                Navigator.pushNamed(context, '/services'),
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius:
                    BorderRadius.circular(AppRadius.pill),
              ),
              child: Text('Submit a Request',
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

  // ── Existing: Tracking View ────────────────────────────────────────
  Widget _buildTrackingView(
      BuildContext context, String resolvedId, String uid) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('requests')
          .doc(resolvedId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return _buildEmptyList(context);
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

        final isRejected  = normalizeRequestStatus(rawStatus) == 'rejected';
        final isReturned  = normalizeRequestStatus(rawStatus) == 'returned';
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
              // ── Header ─────────────────────────────────────
              Column(
                children: [
                  Text(
                    category.isNotEmpty
                        ? category.toUpperCase()
                        : 'SERVICE REQUEST',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color:
                          Colors.black.withValues(alpha: 0.4),
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
                          : isReturned
                            ? const Color(0xFFF97316)
                          : isCompleted
                              ? AppColors.success
                              : AppColors.primary,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                            color: (isRejected
                                  ? AppColors.danger
                                : isReturned
                                  ? const Color(0xFFF97316)
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
                              : isReturned
                                ? LucideIcons.undo2
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
                              : isReturned
                                ? 'RETURN'
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
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 5),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2196F3)
                            .withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(
                            AppRadius.pill),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(LucideIcons.userCheck,
                              size: 11,
                              color: Color(0xFF2196F3)),
                          const SizedBox(width: 5),
                          Text(
                            'Assigned to staff',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF2196F3),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  // Returned banner
                  if (isReturned) ...[
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF3E8),
                        borderRadius: BorderRadius.circular(
                            AppRadius.lg),
                        border: Border.all(
                            color: const Color(0xFFF97316)
                                .withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(LucideIcons.undo2,
                              color: Color(0xFFF97316), size: 18),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              data['returnReason']
                                          ?.toString()
                                          .isNotEmpty ==
                                      true
                                  ? data['returnReason']
                                      .toString()
                                  : 'Your request was returned for correction. Please review and resubmit.',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: const Color(0xFFF97316),
                                height: 1.5,
                              ),
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
                        borderRadius: BorderRadius.circular(
                            AppRadius.lg),
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
                        borderRadius: BorderRadius.circular(
                            AppRadius.lg),
                        border: Border.all(
                            color: AppColors.success
                                .withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(LucideIcons.checkCircle2,
                              color: AppColors.success, size: 18),
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
                        borderRadius: BorderRadius.circular(
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
                                  fontWeight: FontWeight.w800,
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
                          ...missingDocs.map((doc) => Padding(
                                padding: const EdgeInsets.only(
                                    bottom: 6),
                                child: Row(children: [
                                  Container(
                                    width: 6, height: 6,
                                    decoration:
                                        const BoxDecoration(
                                      color: AppColors.warning,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(doc,
                                        style: GoogleFonts.inter(
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
                        borderRadius: BorderRadius.circular(
                            AppRadius.lg),
                        border: Border.all(
                            color: AppColors.success
                                .withValues(alpha: 0.4)),
                      ),
                      child: Column(
                        children: [
                          Row(children: [
                            const Icon(LucideIcons.checkCircle2,
                                color: AppColors.success,
                                size: 16),
                            const SizedBox(width: 8),
                            Text('Your Document is Ready!',
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
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
                                if (await canLaunchUrl(uri)) {
                                  await launchUrl(uri,
                                      mode: LaunchMode
                                          .externalApplication);
                                }
                              },
                              icon: const Icon(
                                  LucideIcons.download,
                                  size: 16),
                              label: Text('Download Document',
                                  style: GoogleFonts.inter(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                  )),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.success,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                padding:
                                    const EdgeInsets.symmetric(
                                        vertical: 12),
                                shape: RoundedRectangleBorder(
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

              // ── Resubmit Button for Returned Requests ─────────────────
              if (isReturned) ...[
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      // Navigate to service form with request ID to resubmit
                      Navigator.of(context).pushNamed(
                        '/service_form',
                        arguments: {'fromRequestId': resolvedId},
                      ).then((_) {
                        // Reload request after resubmission
                        setState(() {});
                      });
                    },
                    icon: const Icon(LucideIcons.redo2, size: 18),
                    label: Text(
                      'Resubmit Request',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                      ),
                    ),
                  ),
                ),
              ],

              // ── Stepper ───────────────────────────────────────
              if (!isRejected && !isReturned)
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _pipeline.length,
                  itemBuilder: (context, idx) {
                    final step      = _pipeline[idx];
                    final stepState =
                        _stepState(idx, currentIdx);
                    final isLast    = idx == _pipeline.length - 1;
                    final date = _stepDate(
                        history, step['key'] as String);

                    return IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          // Circle + connector
                          Column(
                            children: [
                              Container(
                                width: 40, height: 40,
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
                                  boxShadow:
                                      stepState == 'completed'
                                          ? [
                                              BoxShadow(
                                                color: AppColors
                                                    .primary
                                                    .withValues(
                                                        alpha: 0.3),
                                                blurRadius: 10,
                                                offset:
                                                    const Offset(
                                                        0, 4),
                                              )
                                            ]
                                          : null,
                                ),
                                child: Center(
                                  child: stepState == 'completed'
                                      ? const Icon(
                                          LucideIcons.check,
                                          color: Colors.white,
                                          size: 20)
                                      : Text(
                                          '${idx + 1}',
                                          style: GoogleFonts.inter(
                                            fontSize: 12,
                                            fontWeight:
                                                FontWeight.w900,
                                            color: stepState ==
                                                    'current'
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
                                    margin: const EdgeInsets
                                        .symmetric(vertical: 4),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(width: 24),

                          // Label + date + badge
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
                                        step['label'] as String,
                                        style: GoogleFonts.inter(
                                          fontSize: 14,
                                          fontWeight:
                                              FontWeight.w900,
                                          color: stepState ==
                                                  'pending'
                                              ? Colors.black
                                                  .withValues(
                                                      alpha: 0.2)
                                              : Colors.black,
                                        ),
                                      ),
                                      if (date.isNotEmpty)
                                        Padding(
                                          padding:
                                              const EdgeInsets
                                                  .only(top: 4),
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
                                      color: stepState ==
                                              'completed'
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
      'returned':         {'label': 'Returned',          'color': const Color(0xFFF97316)},
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
        border:
            Border.all(color: color.withValues(alpha: 0.30)),
      ),
      child: Text(label,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: color,
          )),
    );
  }
}