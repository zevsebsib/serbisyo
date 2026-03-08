import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  String _role     = '';
  String _fullName = '';
  bool   _loading  = true;

  // SuperAdmin stats
  int _totalRequests    = 0;
  int _pendingRequests  = 0;
  int _inProgress       = 0;
  int _completed        = 0;
  int _totalCitizens    = 0;
  int _totalStaff       = 0;
  int _totalDepartments = 0;
  List<Map<String, dynamic>> _recentActivity = [];

  // Admin/Staff stats
  int _myAssigned       = 0;
  int _myPending        = 0;
  int _myCompletedToday = 0;
  int _myRejected       = 0;
  List<Map<String, dynamic>> _myRecentRequests = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    try {
      final adminDoc = await FirebaseFirestore.instance
          .collection('admin')
          .doc(uid)
          .get();

      if (!adminDoc.exists) return;

      final data = adminDoc.data()!;
      _role     = data['role'] ?? '';
      _fullName = data['fullName'] ?? 'Admin';

      if (_role == 'superadmin') {
        await _loadSuperAdminData();
      } else {
        await _loadAdminData(uid);
      }
    } catch (_) {}

    if (mounted) setState(() => _loading = false);
  }

  Future<void> _loadSuperAdminData() async {
    try {
      final results = await Future.wait([
        FirebaseFirestore.instance.collection('requests').get(),
        FirebaseFirestore.instance.collection('users').get(),
        FirebaseFirestore.instance.collection('admin').get(),
        FirebaseFirestore.instance.collection('departments').get(),
      ]);

      final requests    = results[0].docs;
      final citizens    = results[1].docs;
      final admins      = results[2].docs;
      final departments = results[3].docs;

      _totalRequests    = requests.length;
      _totalCitizens    = citizens.length;
      _totalStaff       = admins.where((d) =>
          d.data()['role'] == 'admin').length;
      _totalDepartments = departments.length;

      _pendingRequests = requests.where((d) =>
          d.data()['status'] == 'pending').length;
      _inProgress = requests.where((d) =>
          d.data()['status'] == 'in_progress').length;
      _completed = requests.where((d) =>
          d.data()['status'] == 'completed').length;

      // Recent activity — last 6 requests
      final sorted = requests.toList()
        ..sort((a, b) {
          final aTime = a.data()['createdAt'];
          final bTime = b.data()['createdAt'];
          if (aTime == null || bTime == null) return 0;
          return (bTime as Timestamp)
              .compareTo(aTime as Timestamp);
        });

      _recentActivity = sorted.take(6).map((d) {
        final data = d.data();
        return {
          'id':          d.id,
          'serviceName': data['serviceName'] ?? 'Service Request',
          'status':      data['status'] ?? 'pending',
          'createdAt':   data['createdAt'],
          'trackingId':  data['trackingId'] ?? '',
        };
      }).toList();
    } catch (_) {}
  }

  Future<void> _loadAdminData(String uid) async {
    try {
      final assigned = await FirebaseFirestore.instance
          .collection('requests')
          .where('assignedTo', isEqualTo: uid)
          .get();

      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);

      _myAssigned = assigned.docs.length;
      _myPending  = assigned.docs.where((d) =>
          d.data()['status'] == 'pending' ||
          d.data()['status'] == 'in_progress').length;
      _myRejected = assigned.docs.where((d) =>
          d.data()['status'] == 'rejected').length;
      _myCompletedToday = assigned.docs.where((d) {
        final status = d.data()['status'];
        final ts     = d.data()['updatedAt'] as Timestamp?;
        if (status != 'completed' || ts == null) return false;
        return ts.toDate().isAfter(startOfDay);
      }).length;

      final sorted = assigned.docs.toList()
        ..sort((a, b) {
          final aTime = a.data()['updatedAt'] ?? a.data()['createdAt'];
          final bTime = b.data()['updatedAt'] ?? b.data()['createdAt'];
          if (aTime == null || bTime == null) return 0;
          return (bTime as Timestamp).compareTo(aTime as Timestamp);
        });

      _myRecentRequests = sorted.take(6).map((d) {
        final data = d.data();
        return {
          'id':          d.id,
          'serviceName': data['serviceName'] ?? 'Service Request',
          'status':      data['status'] ?? 'pending',
          'updatedAt':   data['updatedAt'] ?? data['createdAt'],
          'trackingId':  data['trackingId'] ?? '',
        };
      }).toList();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }

    return _role == 'superadmin'
        ? _buildSuperAdminDashboard()
        : _buildAdminDashboard();
  }

  // ── SUPERADMIN DASHBOARD ───────────────────────────────────────────────────
  Widget _buildSuperAdminDashboard() {
    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? 'Good Morning'
        : hour < 17
            ? 'Good Afternoon'
            : 'Good Evening';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Greeting ──────────────────────────────────────────────
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('$greeting, $_fullName 👋',
                        style: GoogleFonts.inter(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF111111),
                          letterSpacing: -0.5,
                        )),
                    const SizedBox(height: 4),
                    Text(
                      _formatDate(DateTime.now()),
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: AppColors.muted,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
              // Refresh button
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFEEEEEE)),
                ),
                child: IconButton(
                  icon: const Icon(Icons.refresh_rounded,
                      size: 18, color: AppColors.muted),
                  onPressed: () {
                    setState(() => _loading = true);
                    _loadData();
                  },
                ),
              ),
            ],
          ),

          const SizedBox(height: 28),

          // ── Request stats (4 cards) ────────────────────────────────
          Text('Request Overview',
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF555555),
                letterSpacing: 0.3,
              )),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _buildStatCard(
                label: 'Total Requests',
                value: _totalRequests,
                icon: Icons.assignment_rounded,
                color: const Color(0xFF5C6BC0),
                bgColor: const Color(0xFFEDE7F6),
              )),
              const SizedBox(width: 16),
              Expanded(child: _buildStatCard(
                label: 'Pending',
                value: _pendingRequests,
                icon: Icons.hourglass_empty_rounded,
                color: const Color(0xFFF59E0B),
                bgColor: const Color(0xFFFFFBEB),
              )),
              const SizedBox(width: 16),
              Expanded(child: _buildStatCard(
                label: 'In Progress',
                value: _inProgress,
                icon: Icons.sync_rounded,
                color: const Color(0xFF3B82F6),
                bgColor: const Color(0xFFEFF6FF),
              )),
              const SizedBox(width: 16),
              Expanded(child: _buildStatCard(
                label: 'Completed',
                value: _completed,
                icon: Icons.check_circle_rounded,
                color: const Color(0xFF10B981),
                bgColor: const Color(0xFFECFDF5),
              )),
            ],
          ),

          const SizedBox(height: 20),

          // ── System stats (3 cards) ─────────────────────────────────
          Text('System Overview',
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF555555),
                letterSpacing: 0.3,
              )),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _buildStatCard(
                label: 'Total Citizens',
                value: _totalCitizens,
                icon: Icons.people_rounded,
                color: const Color(0xFF06B6D4),
                bgColor: const Color(0xFFECFEFF),
              )),
              const SizedBox(width: 16),
              Expanded(child: _buildStatCard(
                label: 'Total Staff',
                value: _totalStaff,
                icon: Icons.badge_rounded,
                color: AppColors.primary,
                bgColor: const Color(0xFFFFF7ED),
              )),
              const SizedBox(width: 16),
              Expanded(child: _buildStatCard(
                label: 'Departments',
                value: _totalDepartments,
                icon: Icons.account_tree_rounded,
                color: const Color(0xFF8B5CF6),
                bgColor: const Color(0xFFF5F3FF),
              )),
              const SizedBox(width: 16),
              // Request completion rate card
              Expanded(child: _buildRateCard()),
            ],
          ),

          const SizedBox(height: 28),

          // ── Bottom row: Status breakdown + Recent Activity ─────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Status breakdown (visual bars)
              Expanded(
                flex: 4,
                child: _buildStatusBreakdown(),
              ),
              const SizedBox(width: 20),
              // Recent activity
              Expanded(
                flex: 6,
                child: _buildRecentActivity(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required String label,
    required int value,
    required IconData icon,
    required Color color,
    required Color bgColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text('Live',
                    style: GoogleFonts.inter(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: color,
                      letterSpacing: 0.5,
                    )),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(value.toString(),
              style: GoogleFonts.inter(
                fontSize: 28,
                fontWeight: FontWeight.w900,
                color: const Color(0xFF111111),
                letterSpacing: -1,
              )),
          const SizedBox(height: 4),
          Text(label,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppColors.muted,
              )),
        ],
      ),
    );
  }

  Widget _buildRateCard() {
    final rate = _totalRequests == 0
        ? 0
        : ((_completed / _totalRequests) * 100).round();
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFF9200), Color(0xFFFF5E00)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.25),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.20),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.trending_up_rounded,
                color: Colors.white, size: 20),
          ),
          const SizedBox(height: 16),
          Text('$rate%',
              style: GoogleFonts.inter(
                fontSize: 28,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                letterSpacing: -1,
              )),
          const SizedBox(height: 4),
          Text('Completion Rate',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Colors.white.withValues(alpha: 0.85),
              )),
        ],
      ),
    );
  }

  Widget _buildStatusBreakdown() {
    final total = _totalRequests == 0 ? 1 : _totalRequests;
    final items = [
      {'label': 'Completed',   'value': _completed,        'color': const Color(0xFF10B981)},
      {'label': 'In Progress', 'value': _inProgress,       'color': const Color(0xFF3B82F6)},
      {'label': 'Pending',     'value': _pendingRequests,  'color': const Color(0xFFF59E0B)},
      {'label': 'Other',
        'value': _totalRequests - _completed - _inProgress - _pendingRequests,
        'color': const Color(0xFFE5E7EB)},
    ];

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Status Breakdown',
              style: GoogleFonts.inter(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF111111),
              )),
          const SizedBox(height: 4),
          Text('All requests by current status',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: AppColors.muted,
              )),
          const SizedBox(height: 24),
          ...items.map((item) {
            final pct = ((item['value'] as int) / total).clamp(0.0, 1.0);
            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(children: [
                        Container(
                          width: 8, height: 8,
                          decoration: BoxDecoration(
                            color: item['color'] as Color,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(item['label'] as String,
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: const Color(0xFF555555),
                            )),
                      ]),
                      Text('${item['value']}',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF111111),
                          )),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: pct,
                      backgroundColor: const Color(0xFFF3F4F6),
                      valueColor: AlwaysStoppedAnimation<Color>(
                          item['color'] as Color),
                      minHeight: 6,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildRecentActivity() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Recent Requests',
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF111111),
                      )),
                  const SizedBox(height: 4),
                  Text('Latest submitted requests',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: AppColors.muted,
                      )),
                ],
              ),
              TextButton(
                onPressed: () {},
                child: Text('View All',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    )),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_recentActivity.isEmpty)
            _buildEmptyState('No requests yet')
          else
            ..._recentActivity.map((r) => _buildActivityItem(r)),
        ],
      ),
    );
  }

  Widget _buildActivityItem(Map<String, dynamic> r) {
    final status    = r['status'] as String;
    final statusMap = _getStatusStyle(status);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFF0F0F0)),
      ),
      child: Row(
        children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: (statusMap['color'] as Color).withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(statusMap['icon'] as IconData,
                color: statusMap['color'] as Color, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(r['serviceName'] as String,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF111111),
                    )),
                const SizedBox(height: 2),
                Text(r['trackingId'] as String,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: AppColors.muted,
                    )),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: (statusMap['color'] as Color).withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(statusMap['label'] as String,
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: statusMap['color'] as Color,
                )),
          ),
        ],
      ),
    );
  }

  // ── ADMIN/STAFF DASHBOARD ──────────────────────────────────────────────────
  Widget _buildAdminDashboard() {
    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? 'Good Morning'
        : hour < 17
            ? 'Good Afternoon'
            : 'Good Evening';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Greeting ──────────────────────────────────────────────
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('$greeting, $_fullName 👋',
                        style: GoogleFonts.inter(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF111111),
                          letterSpacing: -0.5,
                        )),
                    const SizedBox(height: 4),
                    Text(_formatDate(DateTime.now()),
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: AppColors.muted,
                          fontWeight: FontWeight.w400,
                        )),
                  ],
                ),
              ),
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFEEEEEE)),
                ),
                child: IconButton(
                  icon: const Icon(Icons.refresh_rounded,
                      size: 18, color: AppColors.muted),
                  onPressed: () {
                    setState(() => _loading = true);
                    _loadData();
                  },
                ),
              ),
            ],
          ),

          const SizedBox(height: 28),

          // ── Staff role badge ───────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFF9200), Color(0xFFFF5E00)],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.25),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.20),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      _fullName.isNotEmpty
                          ? _fullName[0].toUpperCase()
                          : 'A',
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_fullName,
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          )),
                      Text('Admin / Staff Member',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: Colors.white.withValues(alpha: 0.80),
                          )),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('$_myAssigned',
                        style: GoogleFonts.inter(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        )),
                    Text('Assigned',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: Colors.white.withValues(alpha: 0.80),
                        )),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // ── My stats (4 cards) ─────────────────────────────────────
          Text('My Task Overview',
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF555555),
                letterSpacing: 0.3,
              )),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _buildStatCard(
                label: 'Assigned to Me',
                value: _myAssigned,
                icon: Icons.assignment_ind_rounded,
                color: const Color(0xFF5C6BC0),
                bgColor: const Color(0xFFEDE7F6),
              )),
              const SizedBox(width: 16),
              Expanded(child: _buildStatCard(
                label: 'Pending Actions',
                value: _myPending,
                icon: Icons.pending_actions_rounded,
                color: const Color(0xFFF59E0B),
                bgColor: const Color(0xFFFFFBEB),
              )),
              const SizedBox(width: 16),
              Expanded(child: _buildStatCard(
                label: 'Completed Today',
                value: _myCompletedToday,
                icon: Icons.task_alt_rounded,
                color: const Color(0xFF10B981),
                bgColor: const Color(0xFFECFDF5),
              )),
              const SizedBox(width: 16),
              Expanded(child: _buildStatCard(
                label: 'Rejected',
                value: _myRejected,
                icon: Icons.cancel_rounded,
                color: const Color(0xFFEF4444),
                bgColor: const Color(0xFFFEF2F2),
              )),
            ],
          ),

          const SizedBox(height: 28),

          // ── Bottom row: Quick actions + My recent requests ─────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Quick actions
              Expanded(
                flex: 4,
                child: _buildQuickActions(),
              ),
              const SizedBox(width: 20),
              // Recent assigned requests
              Expanded(
                flex: 6,
                child: _buildMyRecentRequests(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    final actions = [
      {
        'label': 'View Assigned\nRequests',
        'icon': Icons.assignment_rounded,
        'color': const Color(0xFF5C6BC0),
        'bg': const Color(0xFFEDE7F6),
      },
      {
        'label': 'Verify\nDocuments',
        'icon': Icons.verified_rounded,
        'color': const Color(0xFF10B981),
        'bg': const Color(0xFFECFDF5),
      },
      {
        'label': 'Update\nStatus',
        'icon': Icons.update_rounded,
        'color': const Color(0xFF3B82F6),
        'bg': const Color(0xFFEFF6FF),
      },
      {
        'label': 'Send\nNotification',
        'icon': Icons.notifications_rounded,
        'color': AppColors.primary,
        'bg': const Color(0xFFFFF7ED),
      },
    ];

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Quick Actions',
              style: GoogleFonts.inter(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF111111),
              )),
          const SizedBox(height: 4),
          Text('Common tasks',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: AppColors.muted,
              )),
          const SizedBox(height: 20),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.1,
            children: actions.map((a) {
              return InkWell(
                onTap: () {},
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  decoration: BoxDecoration(
                    color: a['bg'] as Color,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: (a['color'] as Color).withValues(alpha: 0.15),
                    ),
                  ),
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(a['icon'] as IconData,
                          color: a['color'] as Color, size: 24),
                      const SizedBox(height: 10),
                      Text(a['label'] as String,
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF333333),
                            height: 1.4,
                          )),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildMyRecentRequests() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('My Assigned Requests',
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF111111),
                      )),
                  const SizedBox(height: 4),
                  Text('Recently updated',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: AppColors.muted,
                      )),
                ],
              ),
              TextButton(
                onPressed: () {},
                child: Text('View All',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    )),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_myRecentRequests.isEmpty)
            _buildEmptyState('No assigned requests yet')
          else
            ..._myRecentRequests.map((r) => _buildActivityItem(r)),
        ],
      ),
    );
  }

  // ── Shared helpers ─────────────────────────────────────────────────────────
  Widget _buildEmptyState(String message) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.inbox_rounded,
                size: 40, color: AppColors.muted.withValues(alpha: 0.4)),
            const SizedBox(height: 12),
            Text(message,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: AppColors.muted,
                  fontWeight: FontWeight.w500,
                )),
          ],
        ),
      ),
    );
  }

  Map<String, dynamic> _getStatusStyle(String status) {
    switch (status) {
      case 'completed':
        return {
          'label': 'Completed',
          'color': const Color(0xFF10B981),
          'icon':  Icons.check_circle_rounded,
        };
      case 'in_progress':
        return {
          'label': 'In Progress',
          'color': const Color(0xFF3B82F6),
          'icon':  Icons.sync_rounded,
        };
      case 'rejected':
        return {
          'label': 'Rejected',
          'color': const Color(0xFFEF4444),
          'icon':  Icons.cancel_rounded,
        };
      case 'pending':
      default:
        return {
          'label': 'Pending',
          'color': const Color(0xFFF59E0B),
          'icon':  Icons.hourglass_empty_rounded,
        };
    }
  }

  String _formatDate(DateTime date) {
    const months = [
      'January', 'February', 'March', 'April',
      'May', 'June', 'July', 'August',
      'September', 'October', 'November', 'December'
    ];
    const days = [
      'Monday', 'Tuesday', 'Wednesday',
      'Thursday', 'Friday', 'Saturday', 'Sunday'
    ];
    return '${days[date.weekday - 1]}, ${months[date.month - 1]} ${date.day}, ${date.year}';
  }
}