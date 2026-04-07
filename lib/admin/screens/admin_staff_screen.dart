import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';

class AdminStaffScreen extends StatefulWidget {
  const AdminStaffScreen({super.key});

  @override
  State<AdminStaffScreen> createState() =>
      _AdminStaffScreenState();
}

class _AdminStaffScreenState extends State<AdminStaffScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  bool   _loading     = true;
  String _searchQuery = '';

  List<Map<String, dynamic>> _allStaff      = [];
  List<Map<String, dynamic>> _activeStaff   = [];
  List<Map<String, dynamic>> _pendingStaff  = [];
  List<Map<String, dynamic>> _filteredStaff = [];
  List<Map<String, dynamic>> _departments   = [];

  final _searchController = TextEditingController();

  static const int _pageSize = 10;
  int _currentPage = 0;
  int _tabIndex    = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      setState(() {
        _tabIndex    = _tabController.index;
        _currentPage = 0;
        _applySearch();
      });
    });
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final deptSnap = await FirebaseFirestore.instance
          .collection('departments')
          .where('isActive', isEqualTo: true)
          .get();
      _departments = deptSnap.docs.map((d) => {
        'id':   d.id,
        'name': d.data()['name'] ?? '',
      }).toList();

      final staffSnap = await FirebaseFirestore.instance
          .collection('admin')
          .where('role', isEqualTo: 'admin')
          .get();

      final Map<String, String> deptNames = {};
      for (final d in _departments) {
        deptNames[d['id'] as String] =
            d['name'] as String;
      }

      _allStaff = await Future.wait(
        staffSnap.docs.map((d) async {
          final data   = d.data();
          final deptId =
              data['departmentId']?.toString() ?? '';
          int assignedCount = 0;
          try {
            final reqSnap =
                await FirebaseFirestore.instance
                    .collection('requests')
                    .where('assignedTo', isEqualTo: d.id)
                    .get();
            assignedCount = reqSnap.docs.length;
          } catch (_) {}

          return {
            'uid':           d.id,
            'fullName':      data['fullName'] ?? 'Unknown',
            'email':         data['email'] ?? '',
            'phone':         data['phone'] ?? '',
            'department':    deptNames[deptId] ?? '—',
            'departmentId':  deptId,
            'isActive':      data['isActive'] ?? false,
            'createdAt':     data['createdAt'],
            'assignedCount': assignedCount,
          };
        }),
      );

      _allStaff.sort((a, b) =>
          (a['fullName'] as String)
              .compareTo(b['fullName'] as String));

      _activeStaff  =
          _allStaff.where((s) => s['isActive'] == true).toList();
      _pendingStaff =
          _allStaff.where((s) => s['isActive'] == false).toList();

      _applySearch();
    } catch (e) {
      debugPrint('Error: $e');
    }
    if (mounted) setState(() => _loading = false);
  }

  void _applySearch() {
    final source =
        _tabIndex == 0 ? _activeStaff : _pendingStaff;

    if (_searchQuery.isEmpty) {
      _filteredStaff = List.from(source);
    } else {
      final q = _searchQuery.toLowerCase();
      _filteredStaff = source.where((s) =>
          s['fullName']
              .toString()
              .toLowerCase()
              .contains(q) ||
          s['email']
              .toString()
              .toLowerCase()
              .contains(q) ||
          s['department']
              .toString()
              .toLowerCase()
              .contains(q)).toList();
    }
    setState(() => _currentPage = 0);
  }

  List<Map<String, dynamic>> get _paged {
    final start = _currentPage * _pageSize;
    final end   = (start + _pageSize)
        .clamp(0, _filteredStaff.length);
    if (start >= _filteredStaff.length) return [];
    return _filteredStaff.sublist(start, end);
  }

  int get _totalPages =>
      (_filteredStaff.length / _pageSize).ceil();

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
          _buildStatsRow(),
          const SizedBox(height: 16),
          _buildSearchAndTabs(),
          const SizedBox(height: 16),
          Expanded(child: _buildTable()),
          const SizedBox(height: 12),
          _buildPagination(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Staff Management',
                  style: GoogleFonts.inter(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF111111),
                    letterSpacing: -0.5,
                  )),
              const SizedBox(height: 4),
              Text(
                '${_activeStaff.length} active · '
                '${_pendingStaff.length} pending approval',
                style: GoogleFonts.inter(
                    fontSize: 13, color: AppColors.muted),
              ),
            ],
          ),
        ),
        Container(
          width: 40, height: 40,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
                color: const Color(0xFFEEEEEE)),
          ),
          child: IconButton(
            icon: const Icon(Icons.refresh_rounded,
                size: 18, color: AppColors.muted),
            onPressed: _loadData,
          ),
        ),
        const SizedBox(width: 10),

        // ── FIX: "Add Staff" now shows an informational dialog ──────────────
        // Previously this created a Firestore record with isActive: true but
        // no Firebase Auth account — resulting in a broken account that could
        // never log in. Staff must register themselves via the login page and
        // wait for superadmin approval. Direct creation is removed.
        ElevatedButton.icon(
          onPressed: _showAddStaffInfoDialog,
          icon: const Icon(Icons.info_outline_rounded, size: 16),
          label: Text('How to Add Staff',
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              )),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            elevation: 0,
            padding: const EdgeInsets.symmetric(
                horizontal: 18, vertical: 10),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
          ),
        ),
      ],
    );
  }

  // ── FIX: Replaces the broken _addStaff() direct-create dialog ─────────────
  // Explains the correct registration flow to superadmins so they don't
  // accidentally create broken accounts.
  void _showAddStaffInfoDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: Row(children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.10),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.badge_rounded,
                color: AppColors.primary, size: 18),
          ),
          const SizedBox(width: 12),
          Text('Adding New Staff',
              style: GoogleFonts.inter(
                  fontWeight: FontWeight.w700,
                  fontSize: 16)),
        ]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Staff members must register their own accounts using the correct flow:',
              style: GoogleFonts.inter(
                  fontSize: 13, color: AppColors.muted),
            ),
            const SizedBox(height: 16),
            _infoStep('01', 'Staff visits the admin login page'),
            const SizedBox(height: 10),
            _infoStep('02',
                'Clicks "Request Access" to register their account'),
            const SizedBox(height: 10),
            _infoStep('03',
                'Their account appears here under "Pending Approval"'),
            const SizedBox(height: 10),
            _infoStep('04',
                'You approve it by clicking the green checkmark'),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color:
                        AppColors.primary.withValues(alpha: 0.15)),
              ),
              child: Row(children: [
                const Icon(Icons.info_outline_rounded,
                    color: AppColors.primary, size: 15),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'This ensures each staff member has their own Firebase Auth account and can actually log in.',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: AppColors.primary,
                      height: 1.5,
                    ),
                  ),
                ),
              ]),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: Text('Got it',
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                )),
          ),
        ],
      ),
    );
  }

  Widget _infoStep(String num, String text) {
    return Row(children: [
      Container(
        width: 26, height: 26,
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
              color: AppColors.primary.withValues(alpha: 0.25)),
        ),
        child: Center(
          child: Text(num,
              style: GoogleFonts.inter(
                fontSize: 9,
                fontWeight: FontWeight.w800,
                color: AppColors.primary,
              )),
        ),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: Text(text,
            style: GoogleFonts.inter(
              fontSize: 13,
              color: const Color(0xFF333333),
            )),
      ),
    ]);
  }

  Widget _buildStatsRow() {
    final total    = _allStaff.length;
    final active   = _activeStaff.length;
    final pending  = _pendingStaff.length;
    final withDept = _allStaff
        .where((s) =>
            (s['departmentId'] as String?)?.isNotEmpty ==
            true)
        .length;

    final stats = <Map<String, dynamic>>[
      {
        'label': 'Total Staff',
        'value': total,
        'icon':  Icons.badge_rounded,
        'color': const Color(0xFF5C6BC0),
        'bg':    const Color(0xFFEDE7F6),
      },
      {
        'label': 'Active',
        'value': active,
        'icon':  Icons.check_circle_rounded,
        'color': const Color(0xFF10B981),
        'bg':    const Color(0xFFECFDF5),
      },
      {
        'label': 'Pending Approval',
        'value': pending,
        'icon':  Icons.pending_rounded,
        'color': const Color(0xFFF59E0B),
        'bg':    const Color(0xFFFFFBEB),
      },
      {
        'label': 'With Department',
        'value': withDept,
        'icon':  Icons.account_tree_rounded,
        'color': AppColors.primary,
        'bg':    const Color(0xFFFFF7ED),
      },
    ];

    return Row(
      children: stats.asMap().entries.map((entry) {
        final i      = entry.key;
        final s      = entry.value;
        final color  = s['color'] as Color;
        final isLast = i == stats.length - 1;
        return Expanded(
          child: Container(
            margin: EdgeInsets.only(right: isLast ? 0 : 16),
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: Colors.black
                      .withValues(alpha: 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    color: s['bg'] as Color,
                    borderRadius:
                        BorderRadius.circular(10),
                  ),
                  child: Icon(s['icon'] as IconData,
                      color: color, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Text('${s['value']}',
                          style: GoogleFonts.inter(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: const Color(0xFF111111),
                            letterSpacing: -0.5,
                          )),
                      Text(s['label'] as String,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: AppColors.muted,
                            fontWeight: FontWeight.w500,
                          )),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSearchAndTabs() {
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
            child: SizedBox(
              height: 40,
              child: TextField(
                controller: _searchController,
                onChanged: (v) {
                  _searchQuery = v;
                  _applySearch();
                },
                style: GoogleFonts.inter(fontSize: 13),
                decoration: InputDecoration(
                  hintText:
                      'Search by name, email, or department...',
                  hintStyle: GoogleFonts.inter(
                      color: AppColors.muted, fontSize: 12),
                  prefixIcon: const Icon(Icons.search,
                      size: 16, color: AppColors.muted),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear,
                              size: 14,
                              color: AppColors.muted),
                          onPressed: () {
                            _searchController.clear();
                            _searchQuery = '';
                            _applySearch();
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: const Color(0xFFF7F8FC),
                  contentPadding:
                      const EdgeInsets.symmetric(
                          horizontal: 12),
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
            ),
          ),
          const SizedBox(width: 16),
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF7F8FC),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                  color: const Color(0xFFEEEEEE)),
            ),
            child: TabBar(
              controller: _tabController,
              isScrollable: true,
              padding: const EdgeInsets.all(4),
              indicatorSize: TabBarIndicatorSize.tab,
              indicator: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(8),
              ),
              labelColor: Colors.white,
              unselectedLabelColor: AppColors.muted,
              labelStyle: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600),
              unselectedLabelStyle:
                  GoogleFonts.inter(fontSize: 12),
              dividerColor: Colors.transparent,
              tabs: [
                Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Active Staff'),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: _tabIndex == 0
                              ? Colors.white
                                  .withValues(alpha: 0.25)
                              : AppColors.primary
                                  .withValues(alpha: 0.12),
                          borderRadius:
                              BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${_activeStaff.length}',
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: _tabIndex == 0
                                ? Colors.white
                                : AppColors.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Pending Approval'),
                      const SizedBox(width: 6),
                      if (_pendingStaff.isNotEmpty)
                        Container(
                          padding:
                              const EdgeInsets.symmetric(
                                  horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: _tabIndex == 1
                                ? Colors.white
                                    .withValues(alpha: 0.25)
                                : const Color(0xFFF59E0B)
                                    .withValues(alpha: 0.15),
                            borderRadius:
                                BorderRadius.circular(10),
                          ),
                          child: Text(
                            '${_pendingStaff.length}',
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: _tabIndex == 1
                                  ? Colors.white
                                  : const Color(0xFFF59E0B),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

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
                _hCell('Staff Member', flex: 3),
                _hCell('Email',        flex: 3),
                _hCell('Department',   flex: 2),
                _hCell('Assigned',     flex: 2),
                _hCell('Date Joined',  flex: 2),
                _hCell('Status',       flex: 2),
                _hCell('Actions',      flex: 3,
                    align: TextAlign.center),
              ],
            ),
          ),
          const Divider(
              height: 1, color: Color(0xFFF0F0F0)),
          Expanded(
            child: _paged.isEmpty
                ? _buildEmpty()
                : ListView.separated(
                    itemCount: _paged.length,
                    separatorBuilder: (_, __) =>
                        const Divider(
                            height: 1,
                            color: Color(0xFFF5F5F5)),
                    itemBuilder: (_, i) =>
                        _buildRow(_paged[i]),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _hCell(String label,
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

  Widget _buildRow(Map<String, dynamic> s) {
    final isActive =
        s['isActive'] as bool? ?? false;
    final initials =
        _initials(s['fullName'] as String);
    final assigned = s['assignedCount'] as int? ?? 0;

    return InkWell(
      onTap: () => _showStaffDetailDialog(s),
      hoverColor: const Color(0xFFFFF7ED),
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: 20, vertical: 12),
        child: Row(
          children: [
            Expanded(
              flex: 3,
              child: Row(
                children: [
                  Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.primary
                          .withValues(alpha: 0.10),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(initials,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                          )),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                        s['fullName'] as String,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF222222),
                        )),
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 3,
              child: Text(s['email'] as String,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                      fontSize: 12,
                      color: const Color(0xFF555555))),
            ),
            Expanded(
              flex: 2,
              child: Text(s['department'] as String,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                      fontSize: 12,
                      color: const Color(0xFF555555))),
            ),
            Expanded(
              flex: 2,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: assigned > 0
                      ? const Color(0xFF3B82F6)
                          .withValues(alpha: 0.10)
                      : const Color(0xFFF5F5F5),
                  borderRadius:
                      BorderRadius.circular(20),
                ),
                child: Text(
                  '$assigned request${assigned != 1 ? 's' : ''}',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: assigned > 0
                        ? const Color(0xFF3B82F6)
                        : AppColors.muted,
                  ),
                ),
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                _fmtTs(s['createdAt'] as Timestamp?),
                style: GoogleFonts.inter(
                    fontSize: 11,
                    color: AppColors.muted),
              ),
            ),
            Expanded(
              flex: 2,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isActive
                      ? const Color(0xFF10B981)
                          .withValues(alpha: 0.10)
                      : const Color(0xFFF59E0B)
                          .withValues(alpha: 0.10),
                  borderRadius:
                      BorderRadius.circular(20),
                ),
                child: Text(
                  isActive ? 'Active' : 'Pending',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: isActive
                        ? const Color(0xFF10B981)
                        : const Color(0xFFF59E0B),
                  ),
                ),
              ),
            ),
            Expanded(
              flex: 3,
              child: Row(
                mainAxisAlignment:
                    MainAxisAlignment.center,
                children: [
                  _actionBtn(
                    icon: Icons.visibility_rounded,
                    color: const Color(0xFF3B82F6),
                    tooltip: 'View Details',
                    onTap: () =>
                        _showStaffDetailDialog(s),
                  ),
                  const SizedBox(width: 6),
                  _actionBtn(
                    icon: Icons.edit_rounded,
                    color: const Color(0xFF8B5CF6),
                    tooltip: 'Edit Department',
                    onTap: () => _showEditDeptDialog(s),
                  ),
                  if (!isActive) ...[
                    const SizedBox(width: 6),
                    _actionBtn(
                      icon: Icons.check_circle_rounded,
                      color: const Color(0xFF10B981),
                      tooltip: 'Approve Access',
                      onTap: () => _approveAccess(
                          s['uid'] as String,
                          s['fullName'] as String),
                    ),
                  ],
                  if (isActive) ...[
                    const SizedBox(width: 6),
                    _actionBtn(
                      icon: Icons.block_rounded,
                      color: const Color(0xFFF59E0B),
                      tooltip: 'Deactivate',
                      onTap: () => _toggleActive(
                          s['uid'] as String, true),
                    ),
                  ],
                  const SizedBox(width: 6),
                  _actionBtn(
                    icon: Icons.delete_rounded,
                    color: const Color(0xFFEF4444),
                    tooltip: 'Delete',
                    onTap: () => _confirmDelete(
                        s['uid'] as String,
                        s['fullName'] as String),
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

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.badge_outlined,
              size: 48,
              color: AppColors.muted
                  .withValues(alpha: 0.3)),
          const SizedBox(height: 12),
          Text(
            _tabIndex == 0
                ? 'No active staff found'
                : 'No pending approvals',
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.muted,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _tabIndex == 0
                ? 'Staff will appear here once approved'
                : 'Staff register via the login page and appear here',
            style: GoogleFonts.inter(
                fontSize: 12, color: AppColors.muted),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildPagination() {
    if (_totalPages <= 1) return const SizedBox.shrink();
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'Showing ${_currentPage * _pageSize + 1}–'
          '${(_currentPage * _pageSize + _paged.length)} '
          'of ${_filteredStaff.length}',
          style: GoogleFonts.inter(
              fontSize: 12, color: AppColors.muted),
        ),
        const SizedBox(width: 20),
        _pageBtn(
          icon: Icons.chevron_left_rounded,
          enabled: _currentPage > 0,
          onTap: () =>
              setState(() => _currentPage--),
        ),
        const SizedBox(width: 8),
        ...List.generate(_totalPages, (i) {
          final sel = i == _currentPage;
          return GestureDetector(
            onTap: () =>
                setState(() => _currentPage = i),
            child: AnimatedContainer(
              duration:
                  const Duration(milliseconds: 150),
              width: 32, height: 32,
              margin: const EdgeInsets.only(right: 4),
              decoration: BoxDecoration(
                color: sel
                    ? AppColors.primary
                    : Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: sel
                      ? AppColors.primary
                      : const Color(0xFFEEEEEE),
                ),
              ),
              child: Center(
                child: Text('${i + 1}',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: sel
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
          onTap: () =>
              setState(() => _currentPage++),
        ),
      ],
    );
  }

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
          border: Border.all(
              color: const Color(0xFFEEEEEE)),
        ),
        child: Icon(icon,
            size: 18,
            color: enabled
                ? const Color(0xFF444444)
                : AppColors.muted),
      ),
    );
  }

  // ── Staff detail dialog ────────────────────────────────────────────────────
  void _showStaffDetailDialog(
      Map<String, dynamic> s) async {
    List<Map<String, dynamic>> requests = [];
    try {
      final snap = await FirebaseFirestore.instance
          .collection('requests')
          .where('assignedTo', isEqualTo: s['uid'])
          .orderBy('createdAt', descending: true)
          .get();
      requests = snap.docs.map((d) {
        final data = d.data();
        return {
          'id':          d.id,
          'trackingId':  data['trackingId'] ?? '',
          'serviceName': data['serviceName'] ?? 'Request',
          'status':      data['status'] ?? 'pending',
          'createdAt':   data['createdAt'],
        };
      }).toList();
    } catch (_) {}

    if (!mounted) return;

    final isActive = s['isActive'] as bool? ?? false;
    final initials =
        _initials(s['fullName'] as String);

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        insetPadding: const EdgeInsets.symmetric(
            horizontal: 40, vertical: 24),
        child: Container(
          width: 680,
          constraints: BoxConstraints(
            maxHeight:
                MediaQuery.of(context).size.height *
                    0.85,
          ),
          child: Column(
            children: [
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
                    Container(
                      width: 52, height: 52,
                      decoration: BoxDecoration(
                        color: Colors.white
                            .withValues(alpha: 0.20),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(initials,
                            style: GoogleFonts.inter(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            )),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          Text(
                              s['fullName'] as String,
                              style: GoogleFonts.inter(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              )),
                          Text(s['email'] as String,
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
                        isActive ? 'Active' : 'Pending',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    IconButton(
                      onPressed: () =>
                          Navigator.pop(ctx),
                      icon: const Icon(Icons.close,
                          color: Colors.white, size: 20),
                    ),
                  ],
                ),
              ),
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
                            child: _infoCard(
                              'Staff Information',
                              [
                                _detailRow('Full Name',
                                    s['fullName'] as String),
                                _detailRow('Email',
                                    s['email'] as String),
                                _detailRow(
                                  'Phone',
                                  (s['phone'] as String?)
                                              ?.isNotEmpty ==
                                          true
                                      ? s['phone'] as String
                                      : '—',
                                ),
                                _detailRow('Department',
                                    s['department'] as String),
                                _detailRow('Date Joined',
                                    _fmtTs(s['createdAt']
                                        as Timestamp?)),
                                _detailRow('Status',
                                    isActive
                                        ? 'Active'
                                        : 'Pending Approval'),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _infoCard(
                              'Request Summary',
                              [],
                              child: Column(
                                children: [
                                  _summaryItem('Total',
                                      requests.length,
                                      const Color(0xFF5C6BC0)),
                                  _summaryItem('Pending',
                                      requests.where((r) => r['status'] == 'pending').length,
                                      const Color(0xFFF59E0B)),
                                  _summaryItem('In Progress',
                                      requests.where((r) => r['status'] == 'in_progress').length,
                                      const Color(0xFF3B82F6)),
                                  _summaryItem('Completed',
                                      requests.where((r) => r['status'] == 'completed').length,
                                      const Color(0xFF10B981)),
                                  _summaryItem('Rejected',
                                      requests.where((r) => r['status'] == 'rejected').length,
                                      const Color(0xFFEF4444)),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      _infoCard(
                        'Assigned Requests',
                        [],
                        child: requests.isEmpty
                            ? Padding(
                                padding:
                                    const EdgeInsets.symmetric(
                                        vertical: 16),
                                child: Center(
                                  child: Text(
                                    'No requests assigned yet',
                                    style: GoogleFonts.inter(
                                      fontSize: 13,
                                      color: AppColors.muted,
                                    ),
                                  ),
                                ),
                              )
                            : Column(
                                children: requests
                                    .take(8)
                                    .map(_requestItem)
                                    .toList(),
                              ),
                      ),
                    ],
                  ),
                ),
              ),
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
                  mainAxisAlignment:
                      MainAxisAlignment.end,
                  children: [
                    OutlinedButton(
                      onPressed: () =>
                          Navigator.pop(ctx),
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
                    if (!isActive) ...[
                      const SizedBox(width: 10),
                      ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(ctx);
                          _approveAccess(
                              s['uid'] as String,
                              s['fullName'] as String);
                        },
                        icon: const Icon(
                            Icons.check_circle_rounded,
                            size: 15),
                        label: Text('Approve Access',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            )),
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              const Color(0xFF10B981),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(10)),
                          padding:
                              const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 10),
                        ),
                      ),
                    ],
                    const SizedBox(width: 10),
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _showEditDeptDialog(s);
                      },
                      icon: const Icon(Icons.edit_rounded,
                          size: 15),
                      label: Text('Edit Department',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          )),
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
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Edit Department dialog (replaces full edit dialog) ─────────────────────
  void _showEditDeptDialog(Map<String, dynamic> s) {
    String? selectedDept =
        (s['departmentId'] as String?)?.isNotEmpty == true
            ? s['departmentId'] as String
            : null;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setInner) => AlertDialog(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16)),
          title: Text('Assign Department',
              style: GoogleFonts.inter(
                  fontWeight: FontWeight.w700,
                  fontSize: 16)),
          content: SizedBox(
            width: 360,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  'Staff: ${s['fullName']}',
                  style: GoogleFonts.inter(
                      fontSize: 13,
                      color: AppColors.muted),
                ),
                const SizedBox(height: 16),
                Text('Department',
                    style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12),
                  decoration: BoxDecoration(
                    border: Border.all(
                        color:
                            const Color(0xFFEEEEEE)),
                    borderRadius:
                        BorderRadius.circular(10),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: selectedDept,
                      isExpanded: true,
                      hint: Text('Choose department...',
                          style: GoogleFonts.inter(
                              fontSize: 13,
                              color: AppColors.muted)),
                      items: [
                        DropdownMenuItem<String>(
                          value: null,
                          child: Text('None',
                              style: GoogleFonts.inter(
                                  fontSize: 13,
                                  color: AppColors.muted)),
                        ),
                        ..._departments.map(
                          (d) => DropdownMenuItem<String>(
                            value: d['id'] as String,
                            child: Text(
                                d['name'] as String,
                                style: GoogleFonts.inter(
                                    fontSize: 13)),
                          ),
                        ),
                      ],
                      onChanged: (v) => setInner(
                          () => selectedDept = v),
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
              onPressed: () async {
                Navigator.pop(ctx);
                await _updateStaffDept(
                    s['uid'] as String, selectedDept);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(8)),
              ),
              child: Text('Save',
                  style: GoogleFonts.inter(
                      color: Colors.white,
                      fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }

  // ── Firestore actions ──────────────────────────────────────────────────────
  Future<void> _updateStaffDept(
      String uid, String? deptId) async {
    try {
      String deptName = '';
      if (deptId != null && deptId.isNotEmpty) {
        final d = _departments.firstWhere(
            (d) => d['id'] == deptId,
            orElse: () => {'name': ''});
        deptName = d['name'] as String? ?? '';
      }
      await FirebaseFirestore.instance
          .collection('admin')
          .doc(uid)
          .update({
        'departmentId': deptId ?? '',
        'department':   deptName,
        'updatedAt':    FieldValue.serverTimestamp(),
      });
      if (mounted) {
        _showSnack('Department updated ✓',
            AppColors.success);
        _loadData();
      }
    } catch (e) {
      if (mounted) {
        _showSnack('Failed: $e', AppColors.danger);
      }
    }
  }

  Future<void> _approveAccess(
      String uid, String name) async {
    try {
      await FirebaseFirestore.instance
          .collection('admin')
          .doc(uid)
          .update({
        'isActive':   true,
        'approvedAt': FieldValue.serverTimestamp(),
      });
      if (mounted) {
        _showSnack(
            '$name\'s access approved ✓',
            AppColors.success);
        _loadData();
      }
    } catch (e) {
      if (mounted) {
        _showSnack('Failed: $e', AppColors.danger);
      }
    }
  }

  Future<void> _toggleActive(
      String uid, bool current) async {
    try {
      await FirebaseFirestore.instance
          .collection('admin')
          .doc(uid)
          .update({'isActive': !current});
      if (mounted) {
        _showSnack(
          current
              ? 'Account deactivated'
              : 'Account activated ✓',
          current
              ? AppColors.warning
              : AppColors.success,
        );
        _loadData();
      }
    } catch (e) {
      if (mounted) {
        _showSnack('Failed: $e', AppColors.danger);
      }
    }
  }

  void _confirmDelete(String uid, String name) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444)
                    .withValues(alpha: 0.10),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.warning_rounded,
                  color: Color(0xFFEF4444), size: 18),
            ),
            const SizedBox(width: 12),
            Text('Delete Staff Account',
                style: GoogleFonts.inter(
                    fontWeight: FontWeight.w700,
                    fontSize: 16)),
          ],
        ),
        content: Text(
          'Are you sure you want to delete $name\'s account? '
          'This action cannot be undone.',
          style: GoogleFonts.inter(
              fontSize: 13, color: AppColors.muted),
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
              Navigator.pop(ctx);
              await _deleteStaff(uid);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(8)),
            ),
            child: Text('Delete',
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                )),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteStaff(String uid) async {
    try {
      await FirebaseFirestore.instance
          .collection('admin')
          .doc(uid)
          .delete();
      if (mounted) {
        _showSnack('Staff deleted', AppColors.danger);
        _loadData();
      }
    } catch (e) {
      if (mounted) {
        _showSnack(
            'Failed to delete: $e', AppColors.danger);
      }
    }
  }

  // ── Shared widgets ─────────────────────────────────────────────────────────
  Widget _infoCard(String title, List<Widget> rows,
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
            width: 110,
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

  Widget _summaryItem(
      String label, int value, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Container(
            width: 8, height: 8,
            decoration: BoxDecoration(
                color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(label,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: const Color(0xFF555555),
                  fontWeight: FontWeight.w500,
                )),
          ),
          Text('$value',
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: color,
              )),
        ],
      ),
    );
  }

  Widget _requestItem(Map<String, dynamic> r) {
    final status = r['status'] as String;
    final color  = _statusColor(status);
    final label  = _statusLabel(status);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
            color: const Color(0xFFEEEEEE)),
      ),
      child: Row(
        children: [
          Container(
            width: 32, height: 32,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.assignment_rounded,
                color: color, size: 15),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(r['serviceName'] as String,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF222222),
                    )),
                Text(r['trackingId'] as String,
                    style: GoogleFonts.inter(
                        fontSize: 11,
                        color: AppColors.muted)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.10),
                  borderRadius:
                      BorderRadius.circular(20),
                ),
                child: Text(label,
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: color,
                    )),
              ),
              const SizedBox(height: 3),
              Text(_fmtTs(r['createdAt'] as Timestamp?),
                  style: GoogleFonts.inter(
                      fontSize: 10,
                      color: AppColors.muted)),
            ],
          ),
        ],
      ),
    );
  }

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

  String _initials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'completed':   return const Color(0xFF10B981);
      case 'in_progress': return const Color(0xFF3B82F6);
      case 'rejected':    return const Color(0xFFEF4444);
      default:            return const Color(0xFFF59E0B);
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'completed':   return 'Completed';
      case 'in_progress': return 'In Progress';
      case 'rejected':    return 'Rejected';
      default:            return 'Pending';
    }
  }

  String _fmtTs(Timestamp? ts) {
    if (ts == null) return '—';
    final d = ts.toDate();
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[d.month - 1]} ${d.day}, ${d.year}';
  }
}