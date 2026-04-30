import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';

class AdminDepartmentsScreen extends StatefulWidget {
  const AdminDepartmentsScreen({super.key});

  @override
  State<AdminDepartmentsScreen> createState() =>
      _AdminDepartmentsScreenState();
}

class _AdminDepartmentsScreenState
    extends State<AdminDepartmentsScreen> {
  bool   _loading     = true;
  String _searchQuery = '';

  List<Map<String, dynamic>> _allDepartments      = [];
  List<Map<String, dynamic>> _filteredDepartments = [];
  List<Map<String, dynamic>> _staffList           = [];

  final _searchController = TextEditingController();

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

  // ── Data loading ──────────────────────────────────────────────────────────
  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
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
          .collection('departments')
          .orderBy('name')
          .get();

      final staffDeptSnap = await FirebaseFirestore.instance
          .collection('admin')
          .get();

      final Map<String, List<Map<String, dynamic>>> deptStaffMap = {};
      for (final s in staffDeptSnap.docs) {
        final data   = s.data();
        final deptId = data['departmentId']?.toString() ?? '';
        if (deptId.isEmpty) continue;
        deptStaffMap.putIfAbsent(deptId, () => []);
        deptStaffMap[deptId]!.add({
          'uid':      s.id,
          'fullName': data['fullName'] ?? 'Staff',
          'email':    data['email'] ?? '',
          'role':     data['role'] ?? 'admin',
        });
      }

      final Map<String, String> headNames = {};
      for (final s in _staffList) {
        headNames[s['uid'] as String] = s['fullName'] as String;
      }

      _allDepartments = deptSnap.docs.map((d) {
        final data   = d.data();
        final headId = data['headId']?.toString() ?? '';
        return {
          'id':          d.id,
          'name':        data['name'] ?? '',
          'description': data['description'] ?? '',
          'headId':      headId,
          'headName':    headNames[headId] ?? '—',
          'isActive':    data['isActive'] ?? true,
          'createdAt':   data['createdAt'],
          'staffList':   deptStaffMap[d.id] ?? [],
        };
      }).toList();

      _applySearch();
    } catch (e) {
      debugPrint('Error: $e');
    }
    if (mounted) setState(() => _loading = false);
  }

  void _applySearch() {
    if (_searchQuery.isEmpty) {
      _filteredDepartments = List.from(_allDepartments);
    } else {
      final q = _searchQuery.toLowerCase();
      _filteredDepartments = _allDepartments.where((d) =>
          d['name'].toString().toLowerCase().contains(q) ||
          d['description'].toString().toLowerCase().contains(q))
          .toList();
    }
    setState(() {});
  }

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
          _buildSearchBar(),
          const SizedBox(height: 16),
          _buildStatsRow(),
          const SizedBox(height: 16),
          Expanded(child: _buildGrid()),
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
              Text('Departments',
                  style: GoogleFonts.inter(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF111111),
                    letterSpacing: -0.5,
                  )),
              const SizedBox(height: 4),
              Text(
                '${_filteredDepartments.length} department${_filteredDepartments.length != 1 ? 's' : ''}',
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
            onPressed: _loadData,
          ),
        ),
        const SizedBox(width: 10),
        ElevatedButton.icon(
          onPressed: () => _showDeptDialog(),
          icon: const Icon(Icons.add_rounded, size: 16),
          label: Text('Add Department',
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
            hintText: 'Search departments...',
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
    final total    = _allDepartments.length;
    final active   = _allDepartments
        .where((d) => d['isActive'] == true).length;
    final inactive = total - active;
    final withHead = _allDepartments
        .where((d) =>
            (d['headId'] as String?)?.isNotEmpty == true)
        .length;

    final stats = <Map<String, dynamic>>[
      {
        'label': 'Total',
        'value': total,
        'icon':  Icons.account_tree_rounded,
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
      {
        'label': 'With Head',
        'value': withHead,
        'icon':  Icons.manage_accounts_rounded,
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
                  color: Colors.black.withValues(alpha: 0.04),
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
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(s['icon'] as IconData,
                      color: color, size: 20),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${s['value']}',
                        style: GoogleFonts.inter(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: const Color(0xFF111111),
                          letterSpacing: -0.5,
                        )),
                    Text(s['label'] as String,
                        style: GoogleFonts.inter(
                          fontSize: 11,
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

  // ── Department grid ────────────────────────────────────────────────────────
  Widget _buildGrid() {
    if (_filteredDepartments.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.account_tree_outlined,
                size: 48,
                color: AppColors.muted.withValues(alpha: 0.3)),
            const SizedBox(height: 12),
            Text('No departments found',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.muted,
                )),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: () => _showDeptDialog(),
              icon: const Icon(Icons.add_rounded, size: 15),
              label: Text('Add First Department',
                  style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      gridDelegate:
          const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        crossAxisSpacing: 14,
        mainAxisSpacing: 14,
        childAspectRatio: 2.4,
      ),
      itemCount: _filteredDepartments.length,
      itemBuilder: (_, i) =>
          _buildDeptCard(_filteredDepartments[i]),
    );
  }

  // ── Compact clickable department card ─────────────────────────────────────
  Widget _buildDeptCard(Map<String, dynamic> dept) {
    final isActive   = dept['isActive'] as bool? ?? true;
    final staffCount = (dept['staffList'] as List).length;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _showCardActions(dept),
        borderRadius: BorderRadius.circular(12),
        hoverColor: AppColors.primary.withValues(alpha: 0.03),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isActive
                  ? const Color(0xFFEEEEEE)
                  : const Color(0xFFEF4444).withValues(alpha: 0.20),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(
              horizontal: 14, vertical: 12),
          child: Row(
            children: [
              // Icon
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color: isActive
                      ? AppColors.primary.withValues(alpha: 0.10)
                      : const Color(0xFFEEEEEE),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.account_tree_rounded,
                  color: isActive
                      ? AppColors.primary
                      : AppColors.muted,
                  size: 17,
                ),
              ),
              const SizedBox(width: 10),

              // Name + status
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      dept['name'] as String,
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF111111),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: isActive
                                ? const Color(0xFF10B981)
                                    .withValues(alpha: 0.10)
                                : const Color(0xFFEF4444)
                                    .withValues(alpha: 0.10),
                            borderRadius:
                                BorderRadius.circular(20),
                          ),
                          child: Text(
                            isActive ? 'Active' : 'Inactive',
                            style: GoogleFonts.inter(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: isActive
                                  ? const Color(0xFF10B981)
                                  : const Color(0xFFEF4444),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Icon(Icons.badge_rounded,
                            size: 11, color: AppColors.muted),
                        const SizedBox(width: 3),
                        Text(
                          '$staffCount staff',
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            color: AppColors.muted,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Tap hint chevron
              Icon(Icons.chevron_right_rounded,
                  size: 16, color: AppColors.muted.withValues(alpha: 0.5)),
            ],
          ),
        ),
      ),
    );
  }

  // ── Card action bottom sheet ───────────────────────────────────────────────
  void _showCardActions(Map<String, dynamic> dept) {
    final isActive = dept['isActive'] as bool? ?? true;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft:  Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFDDDDDD),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),

            // Dept info header
            Row(
              children: [
                Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.account_tree_rounded,
                      color: AppColors.primary, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(dept['name'] as String,
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF111111),
                          )),
                      Text(
                        isActive ? 'Active Department' : 'Inactive Department',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: isActive
                              ? const Color(0xFF10B981)
                              : const Color(0xFFEF4444),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(height: 1, color: Color(0xFFF0F0F0)),
            const SizedBox(height: 8),

            // Actions
            _actionTile(
              icon: Icons.edit_rounded,
              iconColor: const Color(0xFF5C6BC0),
              iconBg: const Color(0xFFEDE7F6),
              label: 'Edit',
              subtitle: 'Update department details',
              onTap: () {
                Navigator.pop(ctx);
                _showDeptDialog(dept: dept);
              },
            ),
            _actionTile(
              icon: Icons.people_rounded,
              iconColor: const Color(0xFF3B82F6),
              iconBg: const Color(0xFFEFF6FF),
              label: 'View Staff',
              subtitle: 'See assigned staff members',
              onTap: () {
                Navigator.pop(ctx);
                _showStaffDialog(dept);
              },
            ),
            _actionTile(
              icon: isActive
                  ? Icons.block_rounded
                  : Icons.check_circle_rounded,
              iconColor: isActive
                  ? const Color(0xFFF59E0B)
                  : const Color(0xFF10B981),
              iconBg: isActive
                  ? const Color(0xFFFFFBEB)
                  : const Color(0xFFECFDF5),
              label: isActive ? 'Deactivate' : 'Activate',
              subtitle: isActive
                  ? 'Disable this department'
                  : 'Re-enable this department',
              onTap: () {
                Navigator.pop(ctx);
                _toggleActive(
                    dept['id'] as String,
                    dept['isActive'] as bool? ?? true);
              },
            ),
            _actionTile(
              icon: Icons.delete_rounded,
              iconColor: const Color(0xFFEF4444),
              iconBg: const Color(0xFFFEF2F2),
              label: 'Delete',
              subtitle: 'Permanently remove department',
              onTap: () {
                Navigator.pop(ctx);
                _confirmDelete(
                    dept['id'] as String,
                    dept['name'] as String);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _actionTile({
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required String label,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: 4, vertical: 10),
        child: Row(
          children: [
            Container(
              width: 38, height: 38,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: iconColor, size: 18),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF111111),
                      )),
                  Text(subtitle,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: AppColors.muted,
                      )),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded,
                size: 16, color: AppColors.muted),
          ],
        ),
      ),
    );
  }

  // ── Add / Edit dialog ──────────────────────────────────────────────────────
  void _showDeptDialog({Map<String, dynamic>? dept}) {
    final isEdit   = dept != null;
    final nameCtrl = TextEditingController(
        text: isEdit ? dept['name'] as String : '');
    final descCtrl = TextEditingController(
        text: isEdit ? dept['description'] as String : '');
    String? selectedHead = isEdit &&
            (dept['headId'] as String?)?.isNotEmpty == true
        ? dept['headId'] as String
        : null;
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setInner) {
          final screenWidth = MediaQuery.of(ctx).size.width;
          final isNarrow = screenWidth < 720;
          final dialogMaxWidth = isNarrow ? screenWidth - 32 : 500.0;

          return Dialog(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20)),
            insetPadding: EdgeInsets.symmetric(
                horizontal: isNarrow ? 16 : 40, vertical: 24),
            child: Container(
              width: double.infinity,
              constraints: BoxConstraints(maxWidth: dialogMaxWidth),
              padding: EdgeInsets.all(isNarrow ? 20 : 28),
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 40, height: 40,
                          decoration: BoxDecoration(
                            color: AppColors.primary
                                .withValues(alpha: 0.10),
                            borderRadius:
                                BorderRadius.circular(10),
                          ),
                          child: const Icon(
                              Icons.account_tree_rounded,
                              color: AppColors.primary,
                              size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            isEdit
                                ? 'Edit Department'
                                : 'Add Department',
                            style: GoogleFonts.inter(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF111111),
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(ctx),
                          icon: const Icon(Icons.close,
                              size: 18,
                              color: AppColors.muted),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Text('Department Name',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF333333),
                        )),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: nameCtrl,
                      style: GoogleFonts.inter(fontSize: 13),
                      validator: (v) => v == null || v.isEmpty
                          ? 'Name is required'
                          : null,
                      decoration: _inputDeco(
                          'e.g. Civil Registry Office'),
                    ),
                    const SizedBox(height: 16),
                    Text('Description',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF333333),
                        )),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: descCtrl,
                      maxLines: 3,
                      style: GoogleFonts.inter(fontSize: 13),
                      decoration: _inputDeco(
                          'Brief description of this department...'),
                    ),
                    const SizedBox(height: 16),
                    Text('Department Head',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF333333),
                        )),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF7F8FC),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: const Color(0xFFEEEEEE)),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: selectedHead,
                          isExpanded: true,
                          hint: Text('Select department head...',
                              style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: AppColors.muted)),
                          icon: const Icon(
                              Icons.keyboard_arrow_down_rounded,
                              size: 16,
                              color: AppColors.muted),
                          style: GoogleFonts.inter(
                              fontSize: 13,
                              color: const Color(0xFF333333)),
                          items: [
                            DropdownMenuItem<String>(
                              value: null,
                              child: Text('None',
                                  style: GoogleFonts.inter(
                                      fontSize: 13,
                                      color: AppColors.muted)),
                            ),
                            ..._staffList.map(
                              (s) => DropdownMenuItem<String>(
                                value: s['uid'] as String,
                                child: Text(
                                    s['fullName'] as String,
                                    style: GoogleFonts.inter(
                                        fontSize: 13)),
                              ),
                            ),
                          ],
                          onChanged: (v) =>
                              setInner(() => selectedHead = v),
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),
                    Wrap(
                      alignment: WrapAlignment.end,
                      spacing: 10,
                      runSpacing: 10,
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
                                horizontal: 20, vertical: 12),
                          ),
                          child: Text('Cancel',
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppColors.muted,
                              )),
                        ),
                        ElevatedButton.icon(
                          onPressed: () async {
                            if (!formKey.currentState!.validate()) {
                              return;
                            }
                            Navigator.pop(ctx);
                            if (isEdit) {
                              await _updateDept(
                                dept['id'] as String,
                                nameCtrl.text.trim(),
                                descCtrl.text.trim(),
                                selectedHead,
                              );
                            } else {
                              await _addDept(
                                nameCtrl.text.trim(),
                                descCtrl.text.trim(),
                                selectedHead,
                              );
                            }
                          },
                          icon: Icon(
                              isEdit
                                  ? Icons.save_rounded
                                  : Icons.add_rounded,
                              size: 16),
                          label: Text(
                              isEdit ? 'Save Changes' : 'Add',
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
                                horizontal: 20, vertical: 12),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  InputDecoration _inputDeco(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.inter(
          color: AppColors.muted, fontSize: 12),
      filled: true,
      fillColor: const Color(0xFFF7F8FC),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide:
            const BorderSide(color: Color(0xFFEF4444)),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(
            color: Color(0xFFEF4444), width: 1.5),
      ),
    );
  }

  // ── Staff list dialog ──────────────────────────────────────────────────────
  void _showStaffDialog(Map<String, dynamic> dept) {
    final staffList = dept['staffList'] as List;

    showDialog(
      context: context,
      builder: (ctx) {
        final screenWidth = MediaQuery.of(ctx).size.width;
        final dialogMaxWidth = screenWidth < 720 ? screenWidth - 32 : 480.0;

        return Dialog(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20)),
          insetPadding: EdgeInsets.symmetric(
              horizontal: screenWidth < 720 ? 16 : 40,
              vertical: 24),
          child: Container(
            width: double.infinity,
            constraints: BoxConstraints(
                maxWidth: dialogMaxWidth, maxHeight: 500),
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
                      const Icon(Icons.people_rounded,
                          color: Colors.white, size: 22),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            Text(
                              dept['name'] as String,
                              style: GoogleFonts.inter(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                            Text(
                              '${staffList.length} staff member${staffList.length != 1 ? 's' : ''}',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: Colors.white
                                    .withValues(alpha: 0.80),
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(ctx),
                        icon: const Icon(Icons.close,
                            color: Colors.white, size: 20),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: staffList.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment:
                                MainAxisAlignment.center,
                            children: [
                              Icon(Icons.badge_outlined,
                                  size: 40,
                                  color: AppColors.muted
                                      .withValues(alpha: 0.3)),
                              const SizedBox(height: 10),
                              Text('No staff assigned',
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    color: AppColors.muted,
                                  )),
                            ],
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: staffList.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 8),
                          itemBuilder: (_, i) {
                            final s = staffList[i]
                                as Map<String, dynamic>;
                            final initials =
                                _initials(s['fullName'] as String);
                            final isHead =
                                s['uid'] == dept['headId'];
                            return Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF7F8FC),
                                borderRadius:
                                    BorderRadius.circular(10),
                                border: Border.all(
                                    color: const Color(
                                        0xFFEEEEEE)),
                              ),
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
                                            fontWeight:
                                                FontWeight.w700,
                                            color:
                                                AppColors.primary,
                                          )),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                            s['fullName'] as String,
                                            style: GoogleFonts.inter(
                                              fontSize: 13,
                                              fontWeight:
                                                  FontWeight.w600,
                                              color: const Color(
                                                  0xFF222222),
                                            )),
                                        Text(s['email'] as String,
                                            style: GoogleFonts.inter(
                                              fontSize: 11,
                                              color: AppColors.muted,
                                            )),
                                      ],
                                    ),
                                  ),
                                  if (isHead)
                                    Container(
                                      padding:
                                          const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 3),
                                      decoration: BoxDecoration(
                                        color: AppColors.primary
                                            .withValues(alpha: 0.10),
                                        borderRadius:
                                            BorderRadius.circular(20),
                                      ),
                                      child: Text('Head',
                                          style: GoogleFonts.inter(
                                            fontSize: 10,
                                            fontWeight:
                                                FontWeight.w700,
                                            color: AppColors.primary,
                                          )),
                                    ),
                                ],
                              ),
                            );
                          },
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
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      ElevatedButton(
                        onPressed: () => Navigator.pop(ctx),
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
                        child: Text('Close',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            )),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ── Firestore actions ──────────────────────────────────────────────────────
  Future<void> _addDept(
    String name,
    String description,
    String? headId,
  ) async {
    try {
      final docRef = FirebaseFirestore.instance
          .collection('departments')
          .doc();
      await FirebaseFirestore.instance
          .collection('departments')
          .doc(docRef.id)
          .set({
        'name':        name,
        'description': description,
        'headId':      headId ?? '',
        'isActive':    true,
        'createdAt':   FieldValue.serverTimestamp(),
      });
      if (mounted) {
        _allDepartments.insert(0, {
          'id': docRef.id,
          'name': name,
          'description': description,
          'headId': headId ?? '',
          'headName': _resolveHeadName(headId),
          'isActive': true,
          'createdAt': Timestamp.now(),
          'staffList': <Map<String, dynamic>>[],
        });
        _applySearch();
        _showSnack('Department added ✓', AppColors.success);
      }
    } catch (e) {
      if (mounted) {
        _showSnack('Failed to add: $e', AppColors.danger);
      }
    }
  }

  Future<void> _updateDept(
    String id,
    String name,
    String description,
    String? headId,
  ) async {
    try {
      await FirebaseFirestore.instance
          .collection('departments')
          .doc(id)
          .update({
        'name':        name,
        'description': description,
        'headId':      headId ?? '',
        'updatedAt':   FieldValue.serverTimestamp(),
      });
      if (mounted) {
        _patchDepartmentLocal(id, {
          'name': name,
          'description': description,
          'headId': headId ?? '',
          'headName': _resolveHeadName(headId),
        });
        _showSnack('Department updated ✓', AppColors.success);
      }
    } catch (e) {
      if (mounted) {
        _showSnack('Failed to update: $e', AppColors.danger);
      }
    }
  }

  Future<void> _toggleActive(String id, bool current) async {
    try {
      final next = !current;
      await FirebaseFirestore.instance
          .collection('departments')
          .doc(id)
          .update({'isActive': next});
      if (mounted) {
        _patchDepartmentLocal(id, {'isActive': next});
        _showSnack(
          current ? 'Department deactivated' : 'Department activated ✓',
          current ? AppColors.warning : AppColors.success,
        );
      }
    } catch (e) {
      if (mounted) {
        _showSnack('Failed: $e', AppColors.danger);
      }
    }
  }

  void _confirmDelete(String id, String name) {
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
            Text('Delete Department',
                style: GoogleFonts.inter(
                    fontWeight: FontWeight.w700,
                    fontSize: 16)),
          ],
        ),
        content: Text(
          'Are you sure you want to delete "$name"? '
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
              await _deleteDept(id);
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

  Future<void> _deleteDept(String id) async {
    try {
      await FirebaseFirestore.instance
          .collection('departments')
          .doc(id)
          .delete();
      if (mounted) {
        _allDepartments.removeWhere((d) => d['id'] == id);
        _applySearch();
        _showSnack('Department deleted', AppColors.danger);
      }
    } catch (e) {
      if (mounted) {
        _showSnack('Failed: $e', AppColors.danger);
      }
    }
  }

  // ── Helpers ────────────────────────────────────────────────────────────────
  String _resolveHeadName(String? headId) {
    if (headId == null || headId.isEmpty) return '—';
    final match = _staffList.where((s) => s['uid'] == headId);
    if (match.isEmpty) return '—';
    return match.first['fullName'] as String? ?? '—';
  }

  void _patchDepartmentLocal(String id, Map<String, dynamic> patch) {
    final idx = _allDepartments.indexWhere((d) => d['id'] == id);
    if (idx == -1) return;
    _allDepartments[idx] = {
      ..._allDepartments[idx],
      ...patch,
    };
    _applySearch();
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
}