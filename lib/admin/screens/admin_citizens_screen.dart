import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';

class AdminCitizensScreen extends StatefulWidget {
  const AdminCitizensScreen({super.key});

  @override
  State<AdminCitizensScreen> createState() => _AdminCitizensScreenState();
}

class _AdminCitizensScreenState extends State<AdminCitizensScreen> {
  bool   _loading     = true;
  String _searchQuery = '';

  List<Map<String, dynamic>> _allCitizens      = [];
  List<Map<String, dynamic>> _filteredCitizens = [];

  final _searchController = TextEditingController();

  static const int _pageSize = 10;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _loadCitizens();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ── Data loading ───────────────────────────────────────────────────────────
  Future<void> _loadCitizens() async {
    setState(() => _loading = true);
    try {
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .orderBy('fullName')
          .get();

      _allCitizens = snap.docs.map((d) {
        final data = d.data();
        return {
          'uid':             d.id,
          'fullName':        data['fullName'] ?? 'Unknown',
          'email':           data['email'] ?? '',
          'phone':           data['phone'] ?? '',
          'profileImageUrl': data['profileImageUrl'] ?? '',
          'isActive':        data['isActive'] ?? true,
          'createdAt':       data['createdAt'],
          'role':            data['role'] ?? 'citizen',
        };
      }).toList();

      _applySearch();
    } catch (e) {
      debugPrint('Error loading citizens: $e');
    }
    if (mounted) setState(() => _loading = false);
  }

  void _applySearch() {
    if (_searchQuery.isEmpty) {
      _filteredCitizens = List.from(_allCitizens);
    } else {
      final q = _searchQuery.toLowerCase();
      _filteredCitizens = _allCitizens.where((c) =>
          c['fullName'].toString().toLowerCase().contains(q) ||
          c['email'].toString().toLowerCase().contains(q) ||
          c['phone'].toString().toLowerCase().contains(q)).toList();
    }
    setState(() => _currentPage = 0);
  }

  // ── Pagination ─────────────────────────────────────────────────────────────
  List<Map<String, dynamic>> get _paged {
    final start = _currentPage * _pageSize;
    final end   = (start + _pageSize).clamp(0, _filteredCitizens.length);
    if (start >= _filteredCitizens.length) return [];
    return _filteredCitizens.sublist(start, end);
  }

  int get _totalPages =>
      (_filteredCitizens.length / _pageSize).ceil();

  // ── BUILD ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
          child: CircularProgressIndicator(color: AppColors.primary));
    }
    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const SizedBox(height: 20),
          _buildSearchBar(),
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
              Text('Citizens',
                  style: GoogleFonts.inter(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF111111),
                    letterSpacing: -0.5,
                  )),
              const SizedBox(height: 4),
              Text(
                '${_filteredCitizens.length} citizen${_filteredCitizens.length != 1 ? 's' : ''} found',
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
            border: Border.all(color: const Color(0xFFEEEEEE)),
          ),
          child: IconButton(
            icon: const Icon(Icons.refresh_rounded,
                size: 18, color: AppColors.muted),
            onPressed: _loadCitizens,
          ),
        ),
      ],
    );
  }

  // ── Search bar ─────────────────────────────────────────────────────────────
  Widget _buildSearchBar() {
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
            hintText: 'Search by name, email, or phone...',
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
                      _applySearch();
                    },
                  )
                : null,
            filled: true,
            fillColor: const Color(0xFFF7F8FC),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide:
                  const BorderSide(color: Color(0xFFEEEEEE)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide:
                  const BorderSide(color: Color(0xFFEEEEEE)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(
                  color: AppColors.primary, width: 1.5),
            ),
          ),
        ),
      ),
    );
  }

  // ── Stats row ──────────────────────────────────────────────────────────────
  Widget _buildStatsRow() {
    final total    = _allCitizens.length;
    final active   = _allCitizens.where((c) => c['isActive'] == true).length;
    final inactive = total - active;

    final stats = <Map<String, dynamic>>[
      {
        'label': 'Total Citizens',
        'value': total,
        'icon':  Icons.people_rounded,
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
        'label': 'Inactive',
        'value': inactive,
        'icon':  Icons.block_rounded,
        'color': const Color(0xFFEF4444),
        'bg':    const Color(0xFFFEF2F2),
      },
    ];

    return Row(
      children: stats.asMap().entries.map((entry) {
        final i     = entry.key;
        final s     = entry.value;
        final color = s['color'] as Color;
        final bg    = s['bg'] as Color;
        final isLast = i == stats.length - 1;

        return Expanded(
          child: Container(
            margin: EdgeInsets.only(right: isLast ? 0 : 16),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
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
                Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(
                    color: bg,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(s['icon'] as IconData,
                      color: color, size: 22),
                ),
                const SizedBox(width: 14),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${s['value']}',
                        style: GoogleFonts.inter(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          color: const Color(0xFF111111),
                          letterSpacing: -0.5,
                        )),
                    Text(s['label'] as String,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: AppColors.muted,
                          fontWeight: FontWeight.w500,
                        )),
                  ],
                ),
              ],
            ),
          ),
        );
      }).toList(),
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
                _hCell('Citizen',     flex: 3),
                _hCell('Email',       flex: 3),
                _hCell('Phone',       flex: 2),
                _hCell('Date Joined', flex: 2),
                _hCell('Status',      flex: 2),
                _hCell('Actions',     flex: 2,
                    align: TextAlign.center),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFF0F0F0)),
          Expanded(
            child: _paged.isEmpty
                ? _buildEmpty()
                : ListView.separated(
                    itemCount: _paged.length,
                    separatorBuilder: (_, __) => const Divider(
                        height: 1, color: Color(0xFFF5F5F5)),
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

  Widget _buildRow(Map<String, dynamic> c) {
    final isActive = c['isActive'] as bool? ?? true;
    final initials = _initials(c['fullName'] as String);

    return InkWell(
      onTap: () => _showCitizenDialog(c),
      hoverColor: const Color(0xFFFFF7ED),
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: 20, vertical: 12),
        child: Row(
          children: [
            // Avatar + name
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
                    child: Text(c['fullName'] as String,
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
            // Email
            Expanded(
              flex: 3,
              child: Text(c['email'] as String,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                      fontSize: 12,
                      color: const Color(0xFF555555))),
            ),
            // Phone
            Expanded(
              flex: 2,
              child: Text(
                (c['phone'] as String?)?.isNotEmpty == true
                    ? c['phone'] as String
                    : '—',
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                    fontSize: 12,
                    color: const Color(0xFF555555)),
              ),
            ),
            // Date joined
            Expanded(
              flex: 2,
              child: Text(
                _fmtTs(c['createdAt'] as Timestamp?),
                style: GoogleFonts.inter(
                    fontSize: 11, color: AppColors.muted),
              ),
            ),
            // Status badge
            Expanded(
              flex: 2,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isActive
                      ? const Color(0xFF10B981)
                          .withValues(alpha: 0.10)
                      : const Color(0xFFEF4444)
                          .withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  isActive ? 'Active' : 'Inactive',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: isActive
                        ? const Color(0xFF10B981)
                        : const Color(0xFFEF4444),
                  ),
                ),
              ),
            ),
            // Actions
            Expanded(
              flex: 2,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _actionBtn(
                    icon: Icons.visibility_rounded,
                    color: const Color(0xFF3B82F6),
                    tooltip: 'View Profile',
                    onTap: () => _showCitizenDialog(c),
                  ),
                  const SizedBox(width: 6),
                  _actionBtn(
                    icon: isActive
                        ? Icons.block_rounded
                        : Icons.check_circle_rounded,
                    color: isActive
                        ? const Color(0xFFF59E0B)
                        : const Color(0xFF10B981),
                    tooltip: isActive ? 'Deactivate' : 'Activate',
                    onTap: () => _toggleActive(
                        c['uid'] as String, isActive),
                  ),
                  const SizedBox(width: 6),
                  _actionBtn(
                    icon: Icons.delete_rounded,
                    color: const Color(0xFFEF4444),
                    tooltip: 'Delete Account',
                    onTap: () => _confirmDelete(
                        c['uid'] as String,
                        c['fullName'] as String),
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
          Icon(Icons.people_outline_rounded,
              size: 48,
              color: AppColors.muted.withValues(alpha: 0.3)),
          const SizedBox(height: 12),
          Text('No citizens found',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.muted,
              )),
          const SizedBox(height: 4),
          Text('Try adjusting your search',
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
          '${(_currentPage * _pageSize + _paged.length)} '
          'of ${_filteredCitizens.length}',
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
          final sel = i == _currentPage;
          return GestureDetector(
            onTap: () => setState(() => _currentPage = i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 32, height: 32,
              margin: const EdgeInsets.only(right: 4),
              decoration: BoxDecoration(
                color: sel ? AppColors.primary : Colors.white,
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
          onTap: () => setState(() => _currentPage++),
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

  // ── Citizen detail dialog ──────────────────────────────────────────────────
  void _showCitizenDialog(Map<String, dynamic> c) async {
    List<Map<String, dynamic>> requests = [];
    try {
      final snap = await FirebaseFirestore.instance
          .collection('requests')
          .where('userId', isEqualTo: c['uid'])
          .orderBy('createdAt', descending: true)
          .get();
      requests = snap.docs.map((d) {
        final data = d.data();
        return {
          'id':          d.id,
          'trackingId':  data['trackingId'] ?? '',
          'serviceName': data['serviceName'] ?? 'Service Request',
          'status':      data['status'] ?? 'pending',
          'createdAt':   data['createdAt'],
        };
      }).toList();
    } catch (_) {}

    if (!mounted) return;

    final isActive = c['isActive'] as bool? ?? true;
    final initials = _initials(c['fullName'] as String);

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialog) {
          final screenWidth = MediaQuery.of(ctx).size.width;
          final isNarrow = screenWidth < 860;
          final dialogMaxWidth = isNarrow ? screenWidth - 32 : 680.0;

          return Dialog(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20)),
            insetPadding: EdgeInsets.symmetric(
                horizontal: isNarrow ? 16 : 40, vertical: 24),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: dialogMaxWidth,
                maxHeight: MediaQuery.of(context).size.height * 0.85,
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFFFF9200), Color(0xFFFF5E00)],
                      ),
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(20),
                        topRight: Radius.circular(20),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.20),
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              initials,
                              style: GoogleFonts.inter(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                c['fullName'] as String,
                                style: GoogleFonts.inter(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                              Text(
                                c['email'] as String,
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: Colors.white.withValues(alpha: 0.80),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.20),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color: Colors.white.withValues(alpha: 0.30)),
                          ),
                          child: Text(
                            isActive ? 'Active' : 'Inactive',
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
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (isNarrow)
                            Column(
                              children: [
                                _infoCard(
                                  'Profile Information',
                                  [
                                    _detailRow('Full Name', c['fullName'] as String),
                                    _detailRow('Email', c['email'] as String),
                                    _detailRow(
                                      'Phone',
                                      (c['phone'] as String?)?.isNotEmpty == true
                                          ? c['phone'] as String
                                          : '—',
                                    ),
                                    _detailRow('Date Joined', _fmtTs(c['createdAt'] as Timestamp?)),
                                    _detailRow('Status', isActive ? 'Active' : 'Inactive'),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                _infoCard(
                                  'Request Summary',
                                  [],
                                  child: Column(
                                    children: [
                                      _summaryItem('Total', requests.length, const Color(0xFF5C6BC0)),
                                      _summaryItem('Pending', requests.where((r) => r['status'] == 'pending').length, const Color(0xFFF59E0B)),
                                      _summaryItem('In Progress', requests.where((r) => r['status'] == 'in_progress').length, const Color(0xFF3B82F6)),
                                      _summaryItem('Completed', requests.where((r) => r['status'] == 'completed').length, const Color(0xFF10B981)),
                                      _summaryItem('Rejected', requests.where((r) => r['status'] == 'rejected').length, const Color(0xFFEF4444)),
                                    ],
                                  ),
                                ),
                              ],
                            )
                          else
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: _infoCard(
                                    'Profile Information',
                                    [
                                      _detailRow('Full Name', c['fullName'] as String),
                                      _detailRow('Email', c['email'] as String),
                                      _detailRow(
                                        'Phone',
                                        (c['phone'] as String?)?.isNotEmpty == true
                                            ? c['phone'] as String
                                            : '—',
                                      ),
                                      _detailRow('Date Joined', _fmtTs(c['createdAt'] as Timestamp?)),
                                      _detailRow('Status', isActive ? 'Active' : 'Inactive'),
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
                                        _summaryItem('Total', requests.length, const Color(0xFF5C6BC0)),
                                        _summaryItem('Pending', requests.where((r) => r['status'] == 'pending').length, const Color(0xFFF59E0B)),
                                        _summaryItem('In Progress', requests.where((r) => r['status'] == 'in_progress').length, const Color(0xFF3B82F6)),
                                        _summaryItem('Completed', requests.where((r) => r['status'] == 'completed').length, const Color(0xFF10B981)),
                                        _summaryItem('Rejected', requests.where((r) => r['status'] == 'rejected').length, const Color(0xFFEF4444)),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          const SizedBox(height: 20),
                          _infoCard(
                            'Request History',
                            [],
                            child: requests.isEmpty
                                ? Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                    child: Center(
                                      child: Text(
                                        'No requests submitted yet',
                                        style: GoogleFonts.inter(fontSize: 13, color: AppColors.muted),
                                      ),
                                    ),
                                  )
                                : Column(
                                    children: requests.take(8).map(_requestHistoryItem).toList(),
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    decoration: const BoxDecoration(
                      color: Color(0xFFF7F8FC),
                      borderRadius: BorderRadius.only(
                        bottomLeft: Radius.circular(20),
                        bottomRight: Radius.circular(20),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        OutlinedButton(
                          onPressed: () => Navigator.pop(ctx),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Color(0xFFEEEEEE)),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
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
                            _toggleActive(c['uid'] as String, isActive);
                          },
                          icon: Icon(
                            isActive ? Icons.block_rounded : Icons.check_circle_rounded,
                            size: 15,
                          ),
                          label: Text(
                            isActive ? 'Deactivate' : 'Activate',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                isActive ? const Color(0xFFF59E0B) : const Color(0xFF10B981),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                          ),
                        ),
                        const SizedBox(width: 10),
                        ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pop(ctx);
                            _confirmDelete(c['uid'] as String, c['fullName'] as String);
                          },
                          icon: const Icon(Icons.delete_rounded, size: 15),
                          label: Text('Delete',
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              )),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFEF4444),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

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

  Widget _summaryItem(String label, int value, Color color) {
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

  Widget _requestHistoryItem(Map<String, dynamic> r) {
    final status = r['status'] as String;
    final color  = _statusColor(status);
    final label  = _statusLabel(status);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFEEEEEE)),
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
              crossAxisAlignment: CrossAxisAlignment.start,
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
                      color: AppColors.muted,
                    )),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(label,
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: color,
                    )),
              ),
              const SizedBox(height: 3),
              Text(
                _fmtTs(r['createdAt'] as Timestamp?),
                style: GoogleFonts.inter(
                    fontSize: 10, color: AppColors.muted),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Actions ────────────────────────────────────────────────────────────────
  Future<void> _toggleActive(
      String uid, bool currentlyActive) async {
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .update({'isActive': !currentlyActive});
      if (mounted) {
        _showSnack(
          currentlyActive
              ? 'Account deactivated'
              : 'Account activated ✓',
          currentlyActive
              ? AppColors.warning
              : AppColors.success,
        );
        _loadCitizens();
      }
    } catch (e) {
      if (mounted) _showSnack('Failed: $e', AppColors.danger);
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
            Text('Delete Account',
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
              await _deleteCitizen(uid);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
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

  Future<void> _deleteCitizen(String uid) async {
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .delete();
      if (mounted) {
        _showSnack('Account deleted', AppColors.danger);
        _loadCitizens();
      }
    } catch (e) {
      if (mounted) {
        _showSnack('Failed to delete: $e', AppColors.danger);
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