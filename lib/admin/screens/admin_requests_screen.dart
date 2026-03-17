import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../theme/app_theme.dart';

class AdminRequestsScreen extends StatefulWidget {
  const AdminRequestsScreen({super.key});

  @override
  State<AdminRequestsScreen> createState() => _AdminRequestsScreenState();
}

class _AdminRequestsScreenState extends State<AdminRequestsScreen> {
  String _role       = '';
  String _currentUid = '';
  bool   _loading    = true;

  List<Map<String, dynamic>> _allRequests      = [];
  List<Map<String, dynamic>> _filteredRequests = [];
  List<Map<String, dynamic>> _staffList        = [];
  List<String>               _departments      = [];

  String         _searchQuery      = '';
  String         _statusFilter     = 'all';
  String         _departmentFilter = 'all';
  String         _sortOrder        = 'newest';
  DateTimeRange? _dateRange;

  final _searchController = TextEditingController();

  static const int _pageSize = 10;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ── Data loading ───────────────────────────────────────────────────────────
  Future<void> _loadData() async {
    setState(() => _loading = true);
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    _currentUid = uid;

    try {
      final adminDoc = await FirebaseFirestore.instance
          .collection('admin').doc(uid).get();
      _role = adminDoc.data()?['role'] ?? '';

      final staffSnap = await FirebaseFirestore.instance
          .collection('admin')
          .where('role', isEqualTo: 'admin')
          .where('isActive', isEqualTo: true)
          .get();
      _staffList = staffSnap.docs.map((d) => {
        'uid':      d.id,
        'fullName': d.data()['fullName'] ?? 'Staff',
        'email':    d.data()['email'] ?? '',
      }).toList();

      final deptSnap = await FirebaseFirestore.instance
          .collection('departments').get();
      _departments = deptSnap.docs
          .map((d) => d.data()['name']?.toString() ?? '')
          .where((n) => n.isNotEmpty)
          .toList();

      QuerySnapshot reqSnap;
      if (_role == 'superadmin') {
        reqSnap = await FirebaseFirestore.instance
            .collection('requests')
            .orderBy('createdAt', descending: true)
            .get();
      } else {
        reqSnap = await FirebaseFirestore.instance
            .collection('requests')
            .where('assignedTo', isEqualTo: uid)
            .orderBy('createdAt', descending: true)
            .get();
      }

      final userIds = reqSnap.docs
          .map((d) =>
              (d.data() as Map<String, dynamic>)['userId']
                  ?.toString() ?? '')
          .where((id) => id.isNotEmpty)
          .toSet()
          .toList();

      final Map<String, String> userNames = {};
      for (final userId in userIds) {
        try {
          final userDoc = await FirebaseFirestore.instance
              .collection('users').doc(userId).get();
          if (userDoc.exists) {
            userNames[userId] =
                userDoc.data()?['fullName'] ?? 'Unknown';
          }
        } catch (_) {}
      }

      final Map<String, String> staffNames = {};
      for (final s in _staffList) {
        staffNames[s['uid'] as String] = s['fullName'] as String;
      }

      _allRequests = reqSnap.docs.map((d) {
        final data       = d.data() as Map<String, dynamic>;
        final userId     = data['userId']?.toString() ?? '';
        final assignedTo = data['assignedTo']?.toString() ?? '';
        return {
          'id':                 d.id,
          'trackingId':         data['trackingId'] ?? '',
          'serviceName':        data['serviceName'] ?? 'Service Request',
          'category':           data['category'] ?? '',
          'department':         data['department'] ?? '',
          'status':             data['status'] ?? 'submitted',
          'userId':             userId,
          'citizenName':        userNames[userId] ??
              data['citizenName'] ?? 'Unknown Citizen',
          'citizenEmail':       data['citizenEmail'] ?? '',
          'assignedTo':         assignedTo,
          'assignedName':       staffNames[assignedTo] ?? '',
          'createdAt':          data['createdAt'],
          'updatedAt':          data['updatedAt'],
          'rejectionReason':    data['rejectionReason'] ?? '',
          'statusHistory':      data['statusHistory'] ?? [],
          'documentUrls':       data['documentUrls'] ?? {},
          'missingDocuments':   data['missingDocuments'] ?? [],
          'verificationStatus': data['verificationStatus'] ?? 'unverified',
          'finalDocumentUrl':   data['finalDocumentUrl'] ?? '',
        };
      }).toList();

      _applyFilters();
    } catch (e) {
      debugPrint('Error: $e');
    }

    if (mounted) setState(() => _loading = false);
  }

  void _applyFilters() {
    var result = List<Map<String, dynamic>>.from(_allRequests);

    if (_statusFilter != 'all') {
      result = result
          .where((r) => r['status'] == _statusFilter)
          .toList();
    }
    if (_departmentFilter != 'all') {
      result = result
          .where((r) => r['department'] == _departmentFilter)
          .toList();
    }
    if (_dateRange != null) {
      result = result.where((r) {
        final ts = r['createdAt'] as Timestamp?;
        if (ts == null) return false;
        final date = ts.toDate();
        return date.isAfter(_dateRange!.start
                .subtract(const Duration(days: 1))) &&
            date.isBefore(
                _dateRange!.end.add(const Duration(days: 1)));
      }).toList();
    }
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      result = result
          .where((r) =>
              r['trackingId']
                  .toString().toLowerCase().contains(q) ||
              r['citizenName']
                  .toString().toLowerCase().contains(q) ||
              r['serviceName']
                  .toString().toLowerCase().contains(q))
          .toList();
    }
    result.sort((a, b) {
      final aTs = a['createdAt'] as Timestamp?;
      final bTs = b['createdAt'] as Timestamp?;
      if (aTs == null || bTs == null) return 0;
      return _sortOrder == 'newest'
          ? bTs.compareTo(aTs)
          : aTs.compareTo(bTs);
    });

    setState(() {
      _filteredRequests = result;
      _currentPage      = 0;
    });
  }

  List<Map<String, dynamic>> get _pagedRequests {
    final start = _currentPage * _pageSize;
    final end =
        (start + _pageSize).clamp(0, _filteredRequests.length);
    if (start >= _filteredRequests.length) return [];
    return _filteredRequests.sublist(start, end);
  }

  int get _totalPages =>
      (_filteredRequests.length / _pageSize).ceil();

  // ── BUILD ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
          child: CircularProgressIndicator(
              color: AppColors.primary));
    }
    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const SizedBox(height: 20),
          _buildFilterBar(),
          const SizedBox(height: 16),
          _buildStatsRow(),
          const SizedBox(height: 16),
          Expanded(child: _buildTable()),
          const SizedBox(height: 12),
          _buildPagination(),
        ],
      ),
    );
  }

  // ── Header ─────────────────────────────────────────────────────────────────
  Widget _buildHeader() {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _role == 'superadmin'
                    ? 'All Requests'
                    : 'My Assigned Requests',
                style: GoogleFonts.inter(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF111111),
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${_filteredRequests.length} request${_filteredRequests.length != 1 ? 's' : ''} found',
                style: GoogleFonts.inter(
                    fontSize: 13, color: AppColors.muted),
              ),
            ],
          ),
        ),
        _iconBtn(Icons.refresh_rounded, _loadData),
      ],
    );
  }

  Widget _iconBtn(IconData icon, VoidCallback onTap) {
    return Container(
      width: 40, height: 40,
      margin: const EdgeInsets.only(left: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFEEEEEE)),
      ),
      child: IconButton(
        icon: Icon(icon, size: 18, color: AppColors.muted),
        onPressed: onTap,
      ),
    );
  }

  // ── Filter bar ─────────────────────────────────────────────────────────────
  Widget _buildFilterBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: SizedBox(
              height: 40,
              child: TextField(
                controller: _searchController,
                onChanged: (v) {
                  _searchQuery = v;
                  _applyFilters();
                },
                style: GoogleFonts.inter(fontSize: 13),
                decoration: InputDecoration(
                  hintText:
                      'Search by tracking ID or citizen name...',
                  hintStyle: GoogleFonts.inter(
                      color: AppColors.muted, fontSize: 12),
                  prefixIcon: const Icon(Icons.search,
                      size: 16, color: AppColors.muted),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear,
                              size: 14, color: AppColors.muted),
                          onPressed: () {
                            _searchController.clear();
                            _searchQuery = '';
                            _applyFilters();
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: const Color(0xFFF7F8FC),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(
                        color: Color(0xFFEEEEEE)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(
                        color: Color(0xFFEEEEEE)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(
                        color: AppColors.primary, width: 1.5),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: _buildDropdown(
              value: _statusFilter,
              items: {
                'all':              'All Status',
                'submitted':        'Submitted',
                'pending_review':   'Pending Review',
                'processing':       'Processing',
                'approved':         'Approved',
                'ready_for_pickup': 'Ready for Pick Up',
                'completed':        'Completed',
                'rejected':         'Rejected',
              },
              onChanged: (v) {
                _statusFilter = v!;
                _applyFilters();
              },
            ),
          ),
          const SizedBox(width: 12),
          if (_departments.isNotEmpty) ...[
            Expanded(
              flex: 2,
              child: _buildDropdown(
                value: _departmentFilter,
                items: {
                  'all': 'All Departments',
                  ..._departments.asMap().map(
                      (_, d) => MapEntry(d, d)),
                },
                onChanged: (v) {
                  _departmentFilter = v!;
                  _applyFilters();
                },
              ),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            flex: 2,
            child: _buildDropdown(
              value: _sortOrder,
              items: {
                'newest': 'Newest First',
                'oldest': 'Oldest First',
              },
              onChanged: (v) {
                _sortOrder = v!;
                _applyFilters();
              },
            ),
          ),
          const SizedBox(width: 12),
          InkWell(
            onTap: _pickDateRange,
            borderRadius: BorderRadius.circular(10),
            child: Container(
              height: 40,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: _dateRange != null
                    ? AppColors.primary.withValues(alpha: 0.08)
                    : const Color(0xFFF7F8FC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: _dateRange != null
                      ? AppColors.primary.withValues(alpha: 0.30)
                      : const Color(0xFFEEEEEE),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.date_range_rounded,
                      size: 15,
                      color: _dateRange != null
                          ? AppColors.primary
                          : AppColors.muted),
                  const SizedBox(width: 6),
                  Text(
                    _dateRange != null
                        ? '${_fmtShort(_dateRange!.start)} – ${_fmtShort(_dateRange!.end)}'
                        : 'Date Range',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: _dateRange != null
                          ? AppColors.primary
                          : AppColors.muted,
                      fontWeight: _dateRange != null
                          ? FontWeight.w600
                          : FontWeight.w400,
                    ),
                  ),
                  if (_dateRange != null) ...[
                    const SizedBox(width: 6),
                    GestureDetector(
                      onTap: () {
                        setState(() => _dateRange = null);
                        _applyFilters();
                      },
                      child: const Icon(Icons.close,
                          size: 13, color: AppColors.primary),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDropdown({
    required String value,
    required Map<String, String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F8FC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFEEEEEE)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down_rounded,
              size: 16, color: AppColors.muted),
          style: GoogleFonts.inter(
              fontSize: 12,
              color: const Color(0xFF333333),
              fontWeight: FontWeight.w500),
          items: items.entries
              .map((e) => DropdownMenuItem(
                  value: e.key, child: Text(e.value)))
              .toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Future<void> _pickDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
      initialDateRange: _dateRange,
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(
              primary: AppColors.primary),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() => _dateRange = picked);
      _applyFilters();
    }
  }

  // ── Stats row ──────────────────────────────────────────────────────────────
  Widget _buildStatsRow() {
    final stats = <Map<String, dynamic>>[
      {
        'key':   'all',
        'label': 'Total',
        'value': _allRequests.length,
        'color': const Color(0xFF5C6BC0),
      },
      {
        'key':   'submitted',
        'label': 'Submitted',
        'value': _allRequests
            .where((r) => r['status'] == 'submitted')
            .length,
        'color': const Color(0xFF5C6BC0),
      },
      {
        'key':   'pending_review',
        'label': 'Pending Review',
        'value': _allRequests
            .where((r) =>
                r['status'] == 'pending_review' ||
                r['status'] == 'pending')
            .length,
        'color': const Color(0xFFF59E0B),
      },
      {
        'key':   'processing',
        'label': 'Processing',
        'value': _allRequests
            .where((r) =>
                r['status'] == 'processing' ||
                r['status'] == 'in_progress')
            .length,
        'color': const Color(0xFF3B82F6),
      },
      {
        'key':   'completed',
        'label': 'Completed',
        'value': _allRequests
            .where((r) => r['status'] == 'completed')
            .length,
        'color': const Color(0xFF10B981),
      },
      {
        'key':   'rejected',
        'label': 'Rejected',
        'value': _allRequests
            .where((r) => r['status'] == 'rejected')
            .length,
        'color': const Color(0xFFEF4444),
      },
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: stats.map((s) {
          final selected = _statusFilter == s['key'];
          final color    = s['color'] as Color;
          return GestureDetector(
            onTap: () {
              _statusFilter = s['key'] as String;
              _applyFilters();
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              margin: const EdgeInsets.only(right: 10),
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: selected
                    ? color.withValues(alpha: 0.10)
                    : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: selected
                      ? color.withValues(alpha: 0.40)
                      : const Color(0xFFEEEEEE),
                  width: selected ? 1.5 : 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 8, height: 8,
                    decoration: BoxDecoration(
                        color: color, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    s['label'] as String,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: selected
                          ? FontWeight.w700
                          : FontWeight.w500,
                      color: selected
                          ? color
                          : const Color(0xFF666666),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${s['value']}',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: selected
                          ? color
                          : const Color(0xFF111111),
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ── Table ──────────────────────────────────────────────────────────────────
  Widget _buildTable() {
    return Container(
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
        children: [
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 20, vertical: 14),
            decoration: const BoxDecoration(
              color: Color(0xFFF7F8FC),
              borderRadius: BorderRadius.only(
                topLeft:  Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                _headerCell('Tracking ID',   flex: 2),
                _headerCell('Citizen',        flex: 2),
                _headerCell('Service',        flex: 3),
                _headerCell('Department',     flex: 2),
                _headerCell('Status',         flex: 2),
                _headerCell('Assigned Staff', flex: 2),
                _headerCell('Date Submitted', flex: 2),
                _headerCell('Actions',        flex: 2,
                    align: TextAlign.center),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFF0F0F0)),
          Expanded(
            child: _pagedRequests.isEmpty
                ? _buildEmptyTable()
                : ListView.separated(
                    itemCount: _pagedRequests.length,
                    separatorBuilder: (_, __) => const Divider(
                        height: 1, color: Color(0xFFF5F5F5)),
                    itemBuilder: (_, i) =>
                        _buildRow(_pagedRequests[i]),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _headerCell(String label,
      {int flex = 1, TextAlign align = TextAlign.left}) {
    return Expanded(
      flex: flex,
      child: Text(label,
          textAlign: align,
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF888888),
            letterSpacing: 0.5,
          )),
    );
  }

  Widget _buildRow(Map<String, dynamic> r) {
    final statusStyle = _getStatusStyle(r['status'] as String);
    final color       = statusStyle['color'] as Color;
    final label       = statusStyle['label'] as String;
    final docUrls     =
        r['documentUrls'] as Map<String, dynamic>? ?? {};
    final missing     = r['missingDocuments'] as List? ?? [];
    final hasDocs     = docUrls.isNotEmpty;

    return InkWell(
      onTap: () => _showRequestDialog(r),
      hoverColor: const Color(0xFFFFF7ED),
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: 20, vertical: 14),
        child: Row(
          children: [
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(r['trackingId'] as String,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      )),
                  if (hasDocs)
                    Row(children: [
                      Icon(
                        missing.isNotEmpty
                            ? Icons.warning_amber_rounded
                            : Icons.attach_file_rounded,
                        size: 10,
                        color: missing.isNotEmpty
                            ? const Color(0xFFF59E0B)
                            : const Color(0xFF10B981),
                      ),
                      const SizedBox(width: 3),
                      Text(
                        missing.isNotEmpty
                            ? '${missing.length} missing'
                            : '${docUrls.length} docs',
                        style: GoogleFonts.inter(
                          fontSize: 9,
                          color: missing.isNotEmpty
                              ? const Color(0xFFF59E0B)
                              : const Color(0xFF10B981),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ]),
                ],
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(r['citizenName'] as String,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF222222))),
            ),
            Expanded(
              flex: 3,
              child: Text(r['serviceName'] as String,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                      fontSize: 12,
                      color: const Color(0xFF444444))),
            ),
            Expanded(
              flex: 2,
              child: Text(
                (r['department'] as String?)?.isNotEmpty == true
                    ? r['department'] as String : '—',
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                    fontSize: 12, color: const Color(0xFF666666)),
              ),
            ),
            Expanded(
              flex: 2,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(label,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: color,
                    )),
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                (r['assignedName'] as String?)?.isNotEmpty == true
                    ? r['assignedName'] as String : '—',
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                    fontSize: 12, color: const Color(0xFF666666)),
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                _fmtTs(r['createdAt'] as Timestamp?),
                style: GoogleFonts.inter(
                    fontSize: 11, color: AppColors.muted),
              ),
            ),
            Expanded(
              flex: 2,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _actionBtn(
                    icon: Icons.visibility_rounded,
                    color: const Color(0xFF3B82F6),
                    tooltip: 'View Details',
                    onTap: () => _showRequestDialog(r),
                  ),
                  if (_role == 'superadmin') ...[
                    const SizedBox(width: 6),
                    _actionBtn(
                      icon: Icons.person_add_rounded,
                      color: AppColors.primary,
                      tooltip: 'Assign Staff',
                      onTap: () => _showAssignDialog(r),
                    ),
                  ],
                  const SizedBox(width: 6),
                  _actionBtn(
                    icon: Icons.edit_rounded,
                    color: const Color(0xFF8B5CF6),
                    tooltip: 'Update Status',
                    onTap: () => _showUpdateStatusDialog(r),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _actionBtn({
    required IconData icon,
    required Color color,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          width: 28, height: 28,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(icon, size: 14, color: color),
        ),
      ),
    );
  }

  Widget _buildEmptyTable() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inbox_rounded,
              size: 48,
              color: AppColors.muted.withValues(alpha: 0.3)),
          const SizedBox(height: 12),
          Text('No requests found',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.muted,
              )),
          const SizedBox(height: 4),
          Text('Try adjusting your filters',
              style: GoogleFonts.inter(
                  fontSize: 12, color: AppColors.muted)),
        ],
      ),
    );
  }

  // ── Pagination ─────────────────────────────────────────────────────────────
  Widget _buildPagination() {
    if (_totalPages <= 1) return const SizedBox.shrink();
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'Showing ${_currentPage * _pageSize + 1}–'
          '${(_currentPage * _pageSize + _pagedRequests.length)} '
          'of ${_filteredRequests.length}',
          style: GoogleFonts.inter(
              fontSize: 12, color: AppColors.muted),
        ),
        const SizedBox(width: 20),
        _pageBtn(
          icon: Icons.chevron_left_rounded,
          enabled: _currentPage > 0,
          onTap: () => setState(() => _currentPage--),
        ),
        const SizedBox(width: 8),
        ...List.generate(_totalPages, (i) {
          final selected = i == _currentPage;
          return GestureDetector(
            onTap: () => setState(() => _currentPage = i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 32, height: 32,
              margin: const EdgeInsets.only(right: 4),
              decoration: BoxDecoration(
                color: selected ? AppColors.primary : Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: selected
                      ? AppColors.primary
                      : const Color(0xFFEEEEEE),
                ),
              ),
              child: Center(
                child: Text('${i + 1}',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: selected
                          ? Colors.white
                          : const Color(0xFF555555),
                    )),
              ),
            ),
          );
        }),
        const SizedBox(width: 4),
        _pageBtn(
          icon: Icons.chevron_right_rounded,
          enabled: _currentPage < _totalPages - 1,
          onTap: () => setState(() => _currentPage++),
        ),
      ],
    );
  }

  // ── FIX: Added missing _pageBtn method ────────────────────────────────────
  Widget _pageBtn({
    required IconData icon,
    required bool enabled,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 32, height: 32,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFEEEEEE)),
        ),
        child: Icon(icon,
            size: 18,
            color: enabled
                ? const Color(0xFF444444)
                : AppColors.muted),
      ),
    );
  }

  // ── Request detail dialog ──────────────────────────────────────────────────
  void _showRequestDialog(Map<String, dynamic> r) {
    final statusStyle = _getStatusStyle(r['status'] as String);
    final docUrls     =
        r['documentUrls'] as Map<String, dynamic>? ?? {};
    final missing     = List<String>.from(
        r['missingDocuments'] as List? ?? []);
    final verStatus   =
        r['verificationStatus']?.toString() ?? 'unverified';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialog) => Dialog(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20)),
          insetPadding: const EdgeInsets.symmetric(
              horizontal: 40, vertical: 24),
          child: Container(
            width: 760,
            constraints: BoxConstraints(
              maxHeight:
                  MediaQuery.of(context).size.height * 0.88,
            ),
            child: Column(
              children: [
                // ── Header ──────────────────────────────────
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Color(0xFFFF9200),
                        Color(0xFFFF5E00)
                      ],
                    ),
                    borderRadius: BorderRadius.only(
                      topLeft:  Radius.circular(20),
                      topRight: Radius.circular(20),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.assignment_rounded,
                          color: Colors.white, size: 22),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            Text(r['serviceName'] as String,
                                style: GoogleFonts.inter(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                )),
                            Text(r['trackingId'] as String,
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: Colors.white
                                      .withValues(alpha: 0.80),
                                )),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white
                              .withValues(alpha: 0.20),
                          borderRadius:
                              BorderRadius.circular(20),
                          border: Border.all(
                              color: Colors.white
                                  .withValues(alpha: 0.30)),
                        ),
                        child: Text(
                          statusStyle['label'] as String,
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      IconButton(
                        onPressed: () => Navigator.pop(ctx),
                        icon: const Icon(Icons.close,
                            color: Colors.white, size: 20),
                      ),
                    ],
                  ),
                ),

                // ── Body ────────────────────────────────────
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: _buildDetailSection(
                                'Request Information',
                                [
                                  _detailRow('Tracking ID',
                                      r['trackingId'] as String),
                                  _detailRow('Service',
                                      r['serviceName'] as String),
                                  _detailRow('Category',
                                      (r['category'] as String?)
                                                  ?.isNotEmpty ==
                                              true
                                          ? r['category'] as String
                                          : '—'),
                                  _detailRow('Department',
                                      (r['department'] as String?)
                                                  ?.isNotEmpty ==
                                              true
                                          ? r['department'] as String
                                          : '—'),
                                  _detailRow('Date Submitted',
                                      _fmtTs(r['createdAt']
                                          as Timestamp?)),
                                  _detailRow('Last Updated',
                                      _fmtTs(r['updatedAt']
                                          as Timestamp?)),
                                ],
                              ),
                            ),
                            const SizedBox(width: 20),
                            Expanded(
                              child: _buildDetailSection(
                                'Citizen & Assignment',
                                [
                                  _detailRow('Citizen',
                                      r['citizenName'] as String),
                                  _detailRow('Email',
                                      (r['citizenEmail']
                                                      as String?)
                                                  ?.isNotEmpty ==
                                              true
                                          ? r['citizenEmail'] as String
                                          : '—'),
                                  _detailRow('Assigned To',
                                      (r['assignedName']
                                                      as String?)
                                                  ?.isNotEmpty ==
                                              true
                                          ? r['assignedName'] as String
                                          : 'Unassigned'),
                                  _detailRow('Current Status',
                                      statusStyle['label'] as String),
                                  if ((r['rejectionReason'] as String)
                                      .isNotEmpty)
                                    _detailRow('Rejection Reason',
                                        r['rejectionReason'] as String),
                                ],
                              ),
                            ),
                          ],
                        ),

                        // Documents
                        if (docUrls.isNotEmpty) ...[
                          const SizedBox(height: 20),
                          _buildDetailSection(
                            'Submitted Documents',
                            [],
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding:
                                          const EdgeInsets.symmetric(
                                              horizontal: 10,
                                              vertical: 4),
                                      decoration: BoxDecoration(
                                        color: verStatus == 'verified'
                                            ? const Color(0xFF10B981)
                                                .withValues(alpha: 0.10)
                                            : const Color(0xFFF59E0B)
                                                .withValues(alpha: 0.10),
                                        borderRadius:
                                            BorderRadius.circular(20),
                                      ),
                                      child: Text(
                                        verStatus == 'verified'
                                            ? '✓ Documents Verified'
                                            : '⏳ Pending Verification',
                                        style: GoogleFonts.inter(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          color: verStatus == 'verified'
                                              ? const Color(0xFF10B981)
                                              : const Color(0xFFF59E0B),
                                        ),
                                      ),
                                    ),
                                    const Spacer(),
                                    if (verStatus != 'verified')
                                      TextButton.icon(
                                        onPressed: () async {
                                          await FirebaseFirestore
                                              .instance
                                              .collection('requests')
                                              .doc(r['id'] as String)
                                              .update({
                                            'verificationStatus':
                                                'verified',
                                            'updatedAt': FieldValue
                                                .serverTimestamp(),
                                          });
                                          // FIX: capture nav before async gap
                                          if (mounted) {
                                            final nav =
                                                Navigator.of(ctx);
                                            nav.pop();
                                            _showSnack(
                                                'Documents marked as verified ✓',
                                                const Color(0xFF10B981));
                                            _loadData();
                                          }
                                        },
                                        icon: const Icon(
                                            Icons.verified_rounded,
                                            size: 14),
                                        label: Text('Mark Verified',
                                            style: GoogleFonts.inter(
                                                fontSize: 12,
                                                fontWeight:
                                                    FontWeight.w600)),
                                        style: TextButton.styleFrom(
                                          foregroundColor:
                                              const Color(0xFF10B981),
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                ...docUrls.entries.map((entry) {
                                  final docName = entry.key;
                                  final docUrl =
                                      entry.value.toString();
                                  final isMissing =
                                      missing.contains(docName);
                                  return Container(
                                    margin: const EdgeInsets.only(
                                        bottom: 8),
                                    padding:
                                        const EdgeInsets.symmetric(
                                            horizontal: 14,
                                            vertical: 10),
                                    decoration: BoxDecoration(
                                      color: isMissing
                                          ? const Color(0xFFEF4444)
                                              .withValues(alpha: 0.05)
                                          : const Color(0xFF10B981)
                                              .withValues(alpha: 0.05),
                                      borderRadius:
                                          BorderRadius.circular(10),
                                      border: Border.all(
                                        color: isMissing
                                            ? const Color(0xFFEF4444)
                                                .withValues(alpha: 0.20)
                                            : const Color(0xFF10B981)
                                                .withValues(alpha: 0.20),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          isMissing
                                              ? Icons
                                                  .warning_amber_rounded
                                              : Icons
                                                  .description_rounded,
                                          size: 16,
                                          color: isMissing
                                              ? const Color(0xFFEF4444)
                                              : const Color(0xFF10B981),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment
                                                    .start,
                                            children: [
                                              Text(docName,
                                                  style:
                                                      GoogleFonts.inter(
                                                    fontSize: 12,
                                                    fontWeight:
                                                        FontWeight.w600,
                                                    color: const Color(
                                                        0xFF333333),
                                                  )),
                                              if (isMissing)
                                                Text(
                                                    'Flagged as missing',
                                                    style: GoogleFonts
                                                        .inter(
                                                            fontSize: 10,
                                                            color: const Color(
                                                                0xFFEF4444))),
                                            ],
                                          ),
                                        ),
                                        TextButton.icon(
                                          onPressed: () async {
                                            final uri =
                                                Uri.parse(docUrl);
                                            if (await canLaunchUrl(
                                                uri)) {
                                              await launchUrl(uri,
                                                  mode: LaunchMode
                                                      .externalApplication);
                                            }
                                          },
                                          icon: const Icon(
                                              Icons.open_in_new_rounded,
                                              size: 13),
                                          label: Text('View',
                                              style: GoogleFonts.inter(
                                                fontSize: 12,
                                                fontWeight:
                                                    FontWeight.w600,
                                              )),
                                          style: TextButton.styleFrom(
                                            foregroundColor:
                                                AppColors.primary,
                                            padding:
                                                const EdgeInsets
                                                    .symmetric(
                                                    horizontal: 10,
                                                    vertical: 6),
                                          ),
                                        ),
                                        TextButton.icon(
                                          onPressed: () async {
                                            final requestId =
                                                r['id'] as String;
                                            if (isMissing) {
                                              await FirebaseFirestore
                                                  .instance
                                                  .collection('requests')
                                                  .doc(requestId)
                                                  .update({
                                                'missingDocuments':
                                                    FieldValue.arrayRemove(
                                                        [docName]),
                                                'updatedAt': FieldValue
                                                    .serverTimestamp(),
                                              });
                                              // FIX: capture nav before async gap
                                              if (mounted) {
                                                final nav =
                                                    Navigator.of(ctx);
                                                nav.pop();
                                                _showSnack(
                                                    '$docName unflagged',
                                                    const Color(
                                                        0xFF10B981));
                                                _loadData();
                                              }
                                            } else {
                                              await FirebaseFirestore
                                                  .instance
                                                  .collection('requests')
                                                  .doc(requestId)
                                                  .update({
                                                'missingDocuments':
                                                    FieldValue.arrayUnion(
                                                        [docName]),
                                                'updatedAt': FieldValue
                                                    .serverTimestamp(),
                                              });
                                              // FIX: capture nav before async gap
                                              if (mounted) {
                                                final nav =
                                                    Navigator.of(ctx);
                                                nav.pop();
                                                _showSnack(
                                                    '$docName flagged as missing',
                                                    const Color(
                                                        0xFFF59E0B));
                                                _loadData();
                                              }
                                            }
                                          },
                                          icon: Icon(
                                            isMissing
                                                ? Icons
                                                    .check_circle_outline_rounded
                                                : Icons.flag_rounded,
                                            size: 13,
                                          ),
                                          label: Text(
                                            isMissing
                                                ? 'Unflag'
                                                : 'Flag Missing',
                                            style: GoogleFonts.inter(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          style: TextButton.styleFrom(
                                            foregroundColor: isMissing
                                                ? const Color(0xFF10B981)
                                                : const Color(0xFFF59E0B),
                                            padding:
                                                const EdgeInsets.symmetric(
                                                    horizontal: 10,
                                                    vertical: 6),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }),
                              ],
                            ),
                          ),
                        ] else ...[
                          const SizedBox(height: 20),
                          _buildDetailSection(
                            'Submitted Documents',
                            [],
                            child: Center(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                    vertical: 16),
                                child: Text(
                                  'No documents uploaded yet.',
                                  style: GoogleFonts.inter(
                                      fontSize: 13,
                                      color: AppColors.muted),
                                ),
                              ),
                            ),
                          ),
                        ],

                        // Status history
                        if ((r['statusHistory'] as List)
                            .isNotEmpty) ...[
                          const SizedBox(height: 20),
                          _buildDetailSection(
                            'Status History',
                            [],
                            child: Column(
                              children:
                                  (r['statusHistory'] as List)
                                      .map((h) {
                                final hMap =
                                    h as Map<String, dynamic>;
                                final hStyle = _getStatusStyle(
                                    hMap['status']?.toString() ??
                                        'submitted');
                                return Padding(
                                  padding: const EdgeInsets.only(
                                      bottom: 10),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 8, height: 8,
                                        decoration: BoxDecoration(
                                          color: hStyle['color']
                                              as Color,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          hStyle['label'] as String,
                                          style: GoogleFonts.inter(
                                            fontSize: 12,
                                            fontWeight:
                                                FontWeight.w600,
                                            color: const Color(
                                                0xFF333333),
                                          ),
                                        ),
                                      ),
                                      if (hMap['note'] != null &&
                                          hMap['note']
                                              .toString()
                                              .isNotEmpty)
                                        Text(
                                          hMap['note'].toString(),
                                          style: GoogleFonts.inter(
                                              fontSize: 11,
                                              color: AppColors.muted),
                                        ),
                                      const SizedBox(width: 8),
                                      Text(
                                        _fmtTs(hMap['timestamp']
                                            as Timestamp?),
                                        style: GoogleFonts.inter(
                                            fontSize: 11,
                                            color: AppColors.muted),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),

                // ── Footer ──────────────────────────────────
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 24, vertical: 16),
                  decoration: const BoxDecoration(
                    color: Color(0xFFF7F8FC),
                    borderRadius: BorderRadius.only(
                      bottomLeft:  Radius.circular(20),
                      bottomRight: Radius.circular(20),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      OutlinedButton(
                        onPressed: () => Navigator.pop(ctx),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(
                              color: Color(0xFFEEEEEE)),
                          shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 10),
                        ),
                        child: Text('Close',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.muted,
                            )),
                      ),
                      const SizedBox(width: 10),
                      ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(ctx);
                          _showUpdateStatusDialog(r);
                        },
                        icon: const Icon(Icons.edit_rounded,
                            size: 15),
                        label: Text('Update Status',
                            style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w600)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 10),
                        ),
                      ),
                      if (_role == 'superadmin') ...[
                        const SizedBox(width: 10),
                        ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pop(ctx);
                            _showAssignDialog(r);
                          },
                          icon: const Icon(
                              Icons.person_add_rounded, size: 15),
                          label: Text('Assign Staff',
                              style: GoogleFonts.inter(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                const Color(0xFF5C6BC0),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.circular(10)),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 10),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetailSection(String title, List<Widget> rows,
      {Widget? child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F8FC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFEEEEEE)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF888888),
                letterSpacing: 0.5,
              )),
          const SizedBox(height: 12),
          ...rows,
          if (child != null) child,
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(label,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: AppColors.muted,
                  fontWeight: FontWeight.w500,
                )),
          ),
          Expanded(
            child: Text(value,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF222222),
                )),
          ),
        ],
      ),
    );
  }

  // ── Assign dialog ──────────────────────────────────────────────────────────
  void _showAssignDialog(Map<String, dynamic> r) {
    String? selectedStaff =
        (r['assignedTo'] as String?)?.isNotEmpty == true
            ? r['assignedTo'] as String
            : null;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setInner) => AlertDialog(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16)),
          title: Text('Assign Staff',
              style: GoogleFonts.inter(
                  fontWeight: FontWeight.w700, fontSize: 16)),
          content: SizedBox(
            width: 360,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Request: ${r['serviceName']}',
                    style: GoogleFonts.inter(
                        fontSize: 13, color: AppColors.muted)),
                const SizedBox(height: 16),
                Text('Select Staff Member',
                    style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                if (_staffList.isEmpty)
                  Text('No staff available.',
                      style: GoogleFonts.inter(
                          color: AppColors.muted, fontSize: 13))
                else
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12),
                    decoration: BoxDecoration(
                      border: Border.all(
                          color: const Color(0xFFEEEEEE)),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: selectedStaff,
                        isExpanded: true,
                        hint: Text('Choose staff...',
                            style: GoogleFonts.inter(
                                fontSize: 13,
                                color: AppColors.muted)),
                        items: _staffList
                            .map((s) => DropdownMenuItem<String>(
                                  value: s['uid'] as String,
                                  child: Text(
                                      s['fullName'] as String,
                                      style: GoogleFonts.inter(
                                          fontSize: 13)),
                                ))
                            .toList(),
                        onChanged: (v) =>
                            setInner(() => selectedStaff = v),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancel',
                  style: GoogleFonts.inter(
                      color: AppColors.muted)),
            ),
            ElevatedButton(
              onPressed: selectedStaff == null
                  ? null
                  : () async {
                      Navigator.pop(ctx);
                      await _assignStaff(
                          r['id'] as String, selectedStaff!);
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              child: Text('Assign',
                  style: GoogleFonts.inter(
                      color: Colors.white,
                      fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _assignStaff(
      String requestId, String staffUid) async {
    try {
      final staffName = _staffList.firstWhere(
        (s) => s['uid'] == staffUid,
        orElse: () => {'fullName': 'Staff'},
      )['fullName'] as String;

      await FirebaseFirestore.instance
          .collection('requests')
          .doc(requestId)
          .update({
        'assignedTo': staffUid,
        'assignedBy': _currentUid,
        'assignedAt': FieldValue.serverTimestamp(),
        'status':     'pending_review',
        'updatedAt':  FieldValue.serverTimestamp(),
        'statusHistory': FieldValue.arrayUnion([
          {
            'status':    'pending_review',
            'timestamp': Timestamp.now(),
            'note':      'Assigned to $staffName',
          }
        ]),
      });

      if (mounted) {
        _showSnack('Request assigned to $staffName ✓',
            AppColors.success);
        _loadData();
      }
    } catch (e) {
      if (mounted) {
        _showSnack('Failed to assign: $e', AppColors.danger);
      }
    }
  }

  // ── Update Status dialog ───────────────────────────────────────────────────
  void _showUpdateStatusDialog(Map<String, dynamic> r) {
    String selectedStatus    = r['status'] as String;
    final noteController     = TextEditingController();
    final finalDocController = TextEditingController(
        text: r['finalDocumentUrl']?.toString() ?? '');

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setInner) => AlertDialog(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16)),
          title: Text('Update Status',
              style: GoogleFonts.inter(
                  fontWeight: FontWeight.w700, fontSize: 16)),
          content: SizedBox(
            width: 400,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Request: ${r['serviceName']}',
                      style: GoogleFonts.inter(
                          fontSize: 13, color: AppColors.muted)),
                  const SizedBox(height: 16),
                  Text('New Status',
                      style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  // ✅ Full unified pipeline
                  ...[
                    'submitted',
                    'pending_review',
                    'processing',
                    'approved',
                    'ready_for_pickup',
                    'completed',
                    'rejected',
                  ].map((s) {
                    final style      = _getStatusStyle(s);
                    final sColor     = style['color'] as Color;
                    final sLabel     = style['label'] as String;
                    final isSelected = selectedStatus == s;
                    return GestureDetector(
                      onTap: () =>
                          setInner(() => selectedStatus = s),
                      child: AnimatedContainer(
                        duration:
                            const Duration(milliseconds: 150),
                        margin:
                            const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? sColor.withValues(alpha: 0.10)
                              : const Color(0xFFF7F8FC),
                          borderRadius:
                              BorderRadius.circular(10),
                          border: Border.all(
                            color: isSelected
                                ? sColor.withValues(alpha: 0.40)
                                : const Color(0xFFEEEEEE),
                            width: isSelected ? 1.5 : 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 8, height: 8,
                              decoration: BoxDecoration(
                                  color: sColor,
                                  shape: BoxShape.circle),
                            ),
                            const SizedBox(width: 10),
                            Text(sLabel,
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  fontWeight: isSelected
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                  color: isSelected
                                      ? sColor
                                      : const Color(0xFF444444),
                                )),
                            if (isSelected) ...[
                              const Spacer(),
                              Icon(Icons.check_circle_rounded,
                                  color: sColor, size: 16),
                            ],
                          ],
                        ),
                      ),
                    );
                  }),
                  const SizedBox(height: 8),
                  if (selectedStatus == 'completed') ...[
                    Text('Final Document URL (optional)',
                        style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: finalDocController,
                      style: GoogleFonts.inter(fontSize: 13),
                      decoration: InputDecoration(
                        hintText: 'https://...',
                        hintStyle: GoogleFonts.inter(
                            color: AppColors.muted, fontSize: 12),
                        filled: true,
                        fillColor: const Color(0xFFF7F8FC),
                        contentPadding:
                            const EdgeInsets.all(12),
                        border: OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(10),
                          borderSide: const BorderSide(
                              color: Color(0xFFEEEEEE)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(10),
                          borderSide: const BorderSide(
                              color: Color(0xFFEEEEEE)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(10),
                          borderSide: const BorderSide(
                              color: AppColors.primary,
                              width: 1.5),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                  Text('Note (optional)',
                      style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: noteController,
                    maxLines: 2,
                    style: GoogleFonts.inter(fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'Add a note...',
                      hintStyle: GoogleFonts.inter(
                          color: AppColors.muted, fontSize: 12),
                      filled: true,
                      fillColor: const Color(0xFFF7F8FC),
                      contentPadding: const EdgeInsets.all(12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(
                            color: Color(0xFFEEEEEE)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(
                            color: Color(0xFFEEEEEE)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(
                            color: AppColors.primary, width: 1.5),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancel',
                  style: GoogleFonts.inter(
                      color: AppColors.muted)),
            ),
            ElevatedButton(
              onPressed: () async {
                final note     = noteController.text.trim();
                final finalDoc = finalDocController.text.trim();
                Navigator.pop(ctx);
                await _updateStatus(r['id'] as String,
                    selectedStatus, note, finalDoc);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              child: Text('Update',
                  style: GoogleFonts.inter(
                      color: Colors.white,
                      fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _updateStatus(String requestId, String status,
      String note, String finalDocUrl) async {
    try {
      final Map<String, dynamic> updateData = {
        'status':    status,
        'updatedAt': FieldValue.serverTimestamp(),
        'statusHistory': FieldValue.arrayUnion([
          {
            'status':    status,
            'timestamp': Timestamp.now(),
            'note':      note.isNotEmpty ? note : null,
            'updatedBy': _currentUid,
          }
        ]),
      };

      if (status == 'completed' && finalDocUrl.isNotEmpty) {
        updateData['finalDocumentUrl'] = finalDocUrl;
      }

      await FirebaseFirestore.instance
          .collection('requests')
          .doc(requestId)
          .update(updateData);

      if (mounted) {
        _showSnack('Status updated successfully ✓',
            AppColors.success);
        _loadData();
      }
    } catch (e) {
      if (mounted) {
        _showSnack('Failed to update: $e', AppColors.danger);
      }
    }
  }

  // ── Helpers ────────────────────────────────────────────────────────────────
  void _showSnack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg,
            style: GoogleFonts.inter(
                color: Colors.white,
                fontWeight: FontWeight.w600)),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  // ── Status styles — full unified pipeline ─────────────────────────────────
  Map<String, dynamic> _getStatusStyle(String status) {
    switch (status) {
      case 'submitted':
        return {
          'label': 'Submitted',
          'color': const Color(0xFF5C6BC0),
          'icon':  Icons.send_rounded,
        };
      case 'pending_review':
      case 'pending':
        return {
          'label': 'Pending Review',
          'color': const Color(0xFFF59E0B),
          'icon':  Icons.hourglass_empty_rounded,
        };
      case 'processing':
      case 'in_progress':
        return {
          'label': 'Processing',
          'color': const Color(0xFF3B82F6),
          'icon':  Icons.sync_rounded,
        };
      case 'approved':
        return {
          'label': 'Approved',
          'color': const Color(0xFF8B5CF6),
          'icon':  Icons.thumb_up_rounded,
        };
      case 'ready_for_pickup':
      case 'ready':
        return {
          'label': 'Ready for Pick Up',
          'color': AppColors.primary,
          'icon':  Icons.inventory_rounded,
        };
      case 'completed':
        return {
          'label': 'Completed',
          'color': const Color(0xFF10B981),
          'icon':  Icons.check_circle_rounded,
        };
      case 'rejected':
        return {
          'label': 'Rejected',
          'color': const Color(0xFFEF4444),
          'icon':  Icons.cancel_rounded,
        };
      default:
        return {
          'label': 'Submitted',
          'color': const Color(0xFF5C6BC0),
          'icon':  Icons.send_rounded,
        };
    }
  }

  String _fmtTs(Timestamp? ts) {
    if (ts == null) return '—';
    final d = ts.toDate();
    const months = [
      'Jan','Feb','Mar','Apr','May','Jun',
      'Jul','Aug','Sep','Oct','Nov','Dec'
    ];
    return '${months[d.month - 1]} ${d.day}, ${d.year}';
  }

  String _fmtShort(DateTime d) =>
      '${d.month}/${d.day}/${d.year}';
}