import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  Seed data — written to Firestore on first load if the services collection
//  is empty. Mirrors the hardcoded data previously in services_screen.dart and
//  service_category_detail_screen.dart so citizens don't lose access.
// ─────────────────────────────────────────────────────────────────────────────
const List<Map<String, dynamic>> _seedServices = [
  // ── City Mayor's Office ───────────────────────────────────────────────────
  {
    'name':         'Provision of Consumer Assistance',
    'categoryId':   'mayor',
    'categoryName': "City Administration Office",
    'department':   'City Administration Office',
    'isActive':     true,
  },
  {
    'name':         'Issuance of Certificate of Good Moral Character',
    'categoryId':   'mayor',
    'categoryName': "City Administration Office",
    'department':   'City Administration Office',
    'isActive':     true,
  },
  {
    'name':         'Permit for Use of Government Facilities and Equipment',
    'categoryId':   'mayor',
    'categoryName': "City Administration Office",
    'department':   'City Administration Office',
    'isActive':     true,
  },
  {
    'name':         'Receipt of Complaints',
    'categoryId':   'mayor',
    'categoryName': "City Administration Office",
    'department':   'City Administration Office',
    'isActive':     true,
  },

  // ── Civil Registry ────────────────────────────────────────────────────────
  {
    'name':         'Registration of Live Birth, Death and Marriage',
    'categoryId':   'civil',
    'categoryName': 'Civil Registry',
    'department':   'Office of the City Civil Registrar',
    'isActive':     true,
  },
  {
    'name':         'Late Registration of Birth, Death or Marriage',
    'categoryId':   'civil',
    'categoryName': 'Civil Registry',
    'department':   'Office of the City Civil Registrar',
    'isActive':     true,
  },
  {
    'name':         'Application for Marriage License',
    'categoryId':   'civil',
    'categoryName': 'Civil Registry',
    'department':   'Office of the City Civil Registrar',
    'isActive':     true,
  },
  {
    'name':         'Out-of-Town Registration / Reporting',
    'categoryId':   'civil',
    'categoryName': 'Civil Registry',
    'department':   'Office of the City Civil Registrar',
    'isActive':     true,
  },
  {
    'name':         'Registration of Legal Instruments',
    'categoryId':   'civil',
    'categoryName': 'Civil Registry',
    'department':   'Office of the City Civil Registrar',
    'isActive':     true,
  },
  {
    'name':         'Issuance of Certified Machine Copy',
    'categoryId':   'civil',
    'categoryName': 'Civil Registry',
    'department':   'Office of the City Civil Registrar',
    'isActive':     true,
  },

  // ── Community Affairs ─────────────────────────────────────────────────────
  {
    'name':         'Local Employment Referral (Applicants)',
    'categoryId':   'community',
    'categoryName': 'Community Affairs',
    'department':   'Office of the City Community Affairs',
    'isActive':     true,
  },
  {
    'name':         'Local Employment Referral (Employers)',
    'categoryId':   'community',
    'categoryName': 'Community Affairs',
    'department':   'Office of the City Community Affairs',
    'isActive':     true,
  },
  {
    'name':         'SPES Program',
    'categoryId':   'community',
    'categoryName': 'Community Affairs',
    'department':   'Office of the City Community Affairs',
    'isActive':     true,
  },
  {
    'name':         'Livelihood Assistance (Animal Dispersal)',
    'categoryId':   'community',
    'categoryName': 'Community Affairs',
    'department':   'Office of the City Community Affairs',
    'isActive':     true,
  },
  {
    'name':         'Sama-Summer Together Program',
    'categoryId':   'community',
    'categoryName': 'Community Affairs',
    'department':   'Office of the City Community Affairs',
    'isActive':     true,
  },
];

// ─────────────────────────────────────────────────────────────────────────────
class AdminServicesScreen extends StatefulWidget {
  const AdminServicesScreen({super.key});

  @override
  State<AdminServicesScreen> createState() =>
      _AdminServicesScreenState();
}

class _AdminServicesScreenState
    extends State<AdminServicesScreen> {
  String _role        = '';
  bool   _loading     = true;
  bool   _seeding     = false;
  String _searchQuery = '';
  String _categoryFilter = 'all';

  List<Map<String, dynamic>> _allServices      = [];
  List<Map<String, dynamic>> _filteredServices = [];
  final Map<String, String>  _deptNameToId     = {};

  final _searchController = TextEditingController();

  // Category display config
  static const Map<String, Map<String, dynamic>> _categoryConfig = {
    'mayor': {
      'label': "City Administration Office",
      'color': Color(0xFF5B6AF0),
      'bg':    Color(0xFFEEF0FD),
      'icon':  Icons.account_balance_rounded,
    },
    'civil': {
      'label': 'Civil Registry',
      'color': Color(0xFF00A86B),
      'bg':    Color(0xFFE6F7F1),
      'icon':  Icons.description_rounded,
    },
    'community': {
      'label': 'Community Affairs',
      'color': Color(0xFFFF8000),
      'bg':    Color(0xFFFFF5EB),
      'icon':  Icons.people_rounded,
    },
  };

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

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      // Load role
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        final adminDoc = await FirebaseFirestore.instance
            .collection('admin')
            .doc(uid)
            .get();
        _role = adminDoc.data()?['role'] ?? 'admin';
      }

      // Build Department Name -> Department Doc ID lookup.
      final departmentsSnap = await FirebaseFirestore.instance
          .collection('departments')
          .get();
      _deptNameToId
        ..clear()
        ..addEntries(departmentsSnap.docs.map((d) {
          final name = d.data()['name']?.toString() ?? '';
          return MapEntry(name, d.id);
        }).where((e) => e.key.isNotEmpty));

      // Check if services collection is empty — seed if so
      final snap = await FirebaseFirestore.instance
          .collection('services')
          .limit(1)
          .get();

      if (snap.docs.isEmpty) {
        await _seedServicesData();
      }

      // Load all services
      final servicesSnap = await FirebaseFirestore.instance
          .collection('services')
          .orderBy('categoryId')
          .orderBy('name')
          .get();

      _allServices = servicesSnap.docs.map((d) => {
        'id':           d.id,
        'name':         d.data()['name'] ?? '',
        'categoryId':   d.data()['categoryId'] ?? '',
        'categoryName': d.data()['categoryName'] ?? '',
        'department':   d.data()['department'] ?? '',
        'departmentId': d.data()['departmentId'] ??
            _deptNameToId[d.data()['department']?.toString() ?? ''] ?? '',
        'isActive':     d.data()['isActive'] ?? true,
        'createdAt':    d.data()['createdAt'],
      }).toList();

      _applyFilters();
    } catch (e) {
      debugPrint('Services error: $e');
    }
    if (mounted) setState(() => _loading = false);
  }

  // ── Seed Firestore with existing hardcoded services ────────────────────────
  Future<void> _seedServicesData() async {
    setState(() => _seeding = true);
    try {
      final batch = FirebaseFirestore.instance.batch();
      for (final service in _seedServices) {
        final ref = FirebaseFirestore.instance
            .collection('services')
            .doc();
        final deptName = service['department']?.toString() ?? '';
        batch.set(ref, {
          ...service,
          'departmentId': _deptNameToId[deptName] ?? '',
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
      await batch.commit();
    } catch (e) {
      debugPrint('Seed error: $e');
    }
    if (mounted) setState(() => _seeding = false);
  }

  void _applyFilters() {
    var result = List<Map<String, dynamic>>.from(
        _allServices);

    if (_categoryFilter != 'all') {
      result = result
          .where((s) => s['categoryId'] == _categoryFilter)
          .toList();
    }

    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      result = result.where((s) =>
          s['name'].toString().toLowerCase().contains(q) ||
          s['department']
              .toString()
              .toLowerCase()
              .contains(q) ||
          s['categoryName']
              .toString()
              .toLowerCase()
              .contains(q)).toList();
    }

    setState(() => _filteredServices = result);
  }

  bool get _isSuperAdmin => _role == 'superadmin';

  @override
  Widget build(BuildContext context) {
    if (_loading || _seeding) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(
                color: AppColors.primary),
            if (_seeding) ...[
              const SizedBox(height: 16),
              Text(
                'Setting up services for the first time...',
                style: GoogleFonts.inter(
                    fontSize: 13, color: AppColors.muted),
              ),
            ],
          ],
        ),
      );
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
              Text('Available Services',
                  style: GoogleFonts.inter(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF111111),
                    letterSpacing: -0.5,
                  )),
              const SizedBox(height: 4),
              Text(
                '${_filteredServices.length} service${_filteredServices.length != 1 ? 's' : ''} · '
                '${_isSuperAdmin ? 'You can add, edit and remove services' : 'View only'}',
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
        if (_isSuperAdmin) ...[
          const SizedBox(width: 10),
          ElevatedButton.icon(
            onPressed: () => _showServiceDialog(),
            icon: const Icon(Icons.add_rounded, size: 16),
            label: Text('Add Service',
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
      ],
    );
  }

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
                  hintText: 'Search services or department...',
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
                            _applyFilters();
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
          const SizedBox(width: 12),
          // Category filter
          Expanded(
            flex: 2,
            child: _buildDropdown(
              value: _categoryFilter,
              items: {
                'all':       'All Categories',
                'mayor':     "City Administration Office",
                'civil':     'Civil Registry',
                'community': 'Community Affairs',
              },
              onChanged: (v) {
                _categoryFilter = v!;
                _applyFilters();
              },
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
          icon: const Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 16,
              color: AppColors.muted),
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

  Widget _buildStatsRow() {
    final total    = _allServices.length;
    final active   = _allServices
        .where((s) => s['isActive'] == true).length;
    final byCategory = <String, int>{};
    for (final s in _allServices) {
      final c = s['categoryId'] as String;
      byCategory[c] = (byCategory[c] ?? 0) + 1;
    }

    return Row(
      children: [
        _statCard('Total Services', total,
            Icons.design_services_rounded,
            const Color(0xFF5C6BC0),
            const Color(0xFFEDE7F6)),
        const SizedBox(width: 16),
        _statCard('Active', active,
            Icons.check_circle_rounded,
            const Color(0xFF10B981),
            const Color(0xFFECFDF5)),
        const SizedBox(width: 16),
        _statCard("Mayor's Office",
            byCategory['mayor'] ?? 0,
            Icons.account_balance_rounded,
            const Color(0xFF5B6AF0),
            const Color(0xFFEEF0FD)),
        const SizedBox(width: 16),
        _statCard('Civil Registry',
            byCategory['civil'] ?? 0,
            Icons.description_rounded,
            const Color(0xFF00A86B),
            const Color(0xFFE6F7F1)),
        const SizedBox(width: 16),
        _statCard('Community Affairs',
            byCategory['community'] ?? 0,
            Icons.people_rounded,
            const Color(0xFFFF8000),
            const Color(0xFFFFF5EB)),
      ],
    );
  }

  Widget _statCard(String label, int value,
      IconData icon, Color color, Color bg) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
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
              width: 36, height: 36,
              decoration: BoxDecoration(
                  color: bg,
                  borderRadius: BorderRadius.circular(9)),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Text('$value',
                      style: GoogleFonts.inter(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFF111111),
                        letterSpacing: -0.5,
                      )),
                  Text(label,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 10,
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
                _hCell('Service Name', flex: 4),
                _hCell('Category',     flex: 2),
                _hCell('Department',   flex: 3),
                _hCell('Status',       flex: 1),
                if (_isSuperAdmin)
                  _hCell('Actions', flex: 2,
                      align: TextAlign.center),
              ],
            ),
          ),
          const Divider(
              height: 1, color: Color(0xFFF0F0F0)),
          Expanded(
            child: _filteredServices.isEmpty
                ? _buildEmpty()
                : ListView.separated(
                    itemCount: _filteredServices.length,
                    separatorBuilder: (_, __) =>
                        const Divider(
                            height: 1,
                            color: Color(0xFFF5F5F5)),
                    itemBuilder: (_, i) =>
                        _buildRow(_filteredServices[i]),
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
    final catId    = s['categoryId'] as String;
    final catConf  = _categoryConfig[catId] ?? {
      'color': AppColors.muted,
      'bg':    const Color(0xFFF5F5F5),
      'label': catId,
      'icon':  Icons.folder_rounded,
    };
    final isActive = s['isActive'] as bool? ?? true;

    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: 20, vertical: 14),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: Row(
              children: [
                Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    color: (catConf['bg'] as Color),
                    borderRadius:
                        BorderRadius.circular(9),
                  ),
                  child: Icon(
                    catConf['icon'] as IconData,
                    color: catConf['color'] as Color,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    s['name'] as String,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF222222),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: (catConf['bg'] as Color),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                catConf['label'] as String,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: catConf['color'] as Color,
                ),
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              s['department'] as String,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                  fontSize: 12,
                  color: const Color(0xFF555555)),
            ),
          ),
          Expanded(
            flex: 1,
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 8, vertical: 4),
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
          if (_isSuperAdmin)
            Expanded(
              flex: 2,
              child: Row(
                mainAxisAlignment:
                    MainAxisAlignment.center,
                children: [
                  _actionBtn(
                    icon: Icons.edit_rounded,
                    color: const Color(0xFF8B5CF6),
                    tooltip: 'Edit',
                    onTap: () => _showServiceDialog(service: s),
                  ),
                  const SizedBox(width: 6),
                  _actionBtn(
                    icon: isActive
                        ? Icons.visibility_off_rounded
                        : Icons.visibility_rounded,
                    color: isActive
                        ? const Color(0xFFF59E0B)
                        : const Color(0xFF10B981),
                    tooltip: isActive
                        ? 'Deactivate'
                        : 'Activate',
                    onTap: () => _toggleActive(
                        s['id'] as String,
                        isActive),
                  ),
                  const SizedBox(width: 6),
                  _actionBtn(
                    icon: Icons.delete_rounded,
                    color: const Color(0xFFEF4444),
                    tooltip: 'Delete',
                    onTap: () => _confirmDelete(
                        s['id'] as String,
                        s['name'] as String),
                  ),
                ],
              ),
            ),
        ],
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
          Icon(Icons.design_services_outlined,
              size: 48,
              color: AppColors.muted
                  .withValues(alpha: 0.3)),
          const SizedBox(height: 12),
          Text('No services found',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.muted,
              )),
          const SizedBox(height: 4),
          Text(
            _searchQuery.isNotEmpty
                ? 'Try a different search term'
                : 'Add your first service using the button above',
            style: GoogleFonts.inter(
                fontSize: 12, color: AppColors.muted),
          ),
        ],
      ),
    );
  }

  // ── Add / Edit service dialog ──────────────────────────────────────────────
  void _showServiceDialog({Map<String, dynamic>? service}) {
    final isEdit    = service != null;
    final nameCtrl  = TextEditingController(
        text: isEdit ? service['name'] as String : '');
    String selectedCat =
        isEdit ? (service['categoryId'] as String) : 'mayor';
    final formKey = GlobalKey<FormState>();

    final categoryOptions = {
      'mayor':     "City Administration Office",
      'civil':     'Civil Registry',
      'community': 'Community Affairs',
    };

    final deptForCat = {
      'mayor':     'City Administration Office',
      'civil':     'Office of the City Civil Registrar',
      'community': 'Office of the City Community Affairs',
    };

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setInner) => Dialog(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20)),
          child: Container(
            width: 480,
            padding: const EdgeInsets.all(28),
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.primary
                            .withValues(alpha: 0.10),
                        borderRadius:
                            BorderRadius.circular(10),
                      ),
                      child: const Icon(
                          Icons.design_services_rounded,
                          color: AppColors.primary,
                          size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        isEdit
                            ? 'Edit Service'
                            : 'Add Service',
                        style: GoogleFonts.inter(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF111111),
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () =>
                          Navigator.pop(ctx),
                      icon: const Icon(Icons.close,
                          size: 18,
                          color: AppColors.muted),
                    ),
                  ]),
                  const SizedBox(height: 24),

                  // Service name
                  _fieldLabel('Service Name'),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: nameCtrl,
                    style: GoogleFonts.inter(fontSize: 13),
                    validator: (v) =>
                        v == null || v.isEmpty
                            ? 'Name is required'
                            : null,
                    decoration: _inputDeco(
                        'e.g. Issuance of Certified Copy'),
                  ),
                  const SizedBox(height: 16),

                  // Category
                  _fieldLabel('Category / Department'),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF7F8FC),
                      borderRadius:
                          BorderRadius.circular(10),
                      border: Border.all(
                          color:
                              const Color(0xFFEEEEEE)),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: selectedCat,
                        isExpanded: true,
                        icon: const Icon(
                            Icons
                                .keyboard_arrow_down_rounded,
                            size: 16,
                            color: AppColors.muted),
                        style: GoogleFonts.inter(
                            fontSize: 13,
                            color: const Color(0xFF333333)),
                        items: categoryOptions.entries
                            .map((e) =>
                                DropdownMenuItem<String>(
                                  value: e.key,
                                  child: Text(e.value,
                                      style: GoogleFonts
                                          .inter(
                                              fontSize:
                                                  13)),
                                ))
                            .toList(),
                        onChanged: (v) => setInner(
                            () => selectedCat = v!),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.primary
                          .withValues(alpha: 0.05),
                      borderRadius:
                          BorderRadius.circular(8),
                      border: Border.all(
                          color: AppColors.primary
                              .withValues(alpha: 0.12)),
                    ),
                    child: Row(children: [
                      const Icon(
                          Icons.info_outline_rounded,
                          color: AppColors.primary,
                          size: 13),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Department: ${deptForCat[selectedCat]}',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ]),
                  ),

                  const SizedBox(height: 28),

                  Row(
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
                                  BorderRadius.circular(
                                      10)),
                          padding:
                              const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 12),
                        ),
                        child: Text('Cancel',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.muted,
                            )),
                      ),
                      const SizedBox(width: 10),
                      ElevatedButton.icon(
                        onPressed: () async {
                          if (!formKey.currentState!
                              .validate()) {
                            return;
                          }
                          Navigator.pop(ctx);
                          if (isEdit) {
                            await _updateService(
                              service['id'] as String,
                              nameCtrl.text.trim(),
                              selectedCat,
                              deptForCat[selectedCat]!,
                            );
                          } else {
                            await _addService(
                              nameCtrl.text.trim(),
                              selectedCat,
                              deptForCat[selectedCat]!,
                            );
                          }
                        },
                        icon: Icon(
                            isEdit
                                ? Icons.save_rounded
                                : Icons.add_rounded,
                            size: 16),
                        label: Text(
                            isEdit ? 'Save' : 'Add',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            )),
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              AppColors.primary,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(
                                      10)),
                          padding:
                              const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 12),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Firestore actions ──────────────────────────────────────────────────────
  Future<void> _addService(
      String name, String catId, String dept) async {
    try {
      final catConf = _categoryConfig[catId];
      final docRef = FirebaseFirestore.instance
          .collection('services')
          .doc();
      await FirebaseFirestore.instance
          .collection('services')
          .doc(docRef.id)
          .set({
        'name':         name,
        'categoryId':   catId,
        'categoryName': catConf?['label'] ?? catId,
        'department':   dept,
        'departmentId': _deptNameToId[dept] ?? '',
        'isActive':     true,
        'createdAt':    FieldValue.serverTimestamp(),
        'updatedAt':    FieldValue.serverTimestamp(),
      });
      if (mounted) {
        _allServices.insert(0, {
          'id': docRef.id,
          'name': name,
          'categoryId': catId,
          'categoryName': catConf?['label'] ?? catId,
          'department': dept,
          'departmentId': _deptNameToId[dept] ?? '',
          'isActive': true,
          'createdAt': Timestamp.now(),
        });
        _applyFilters();
        _showSnack('Service added ✓', AppColors.success);
      }
    } catch (e) {
      if (mounted) {
        _showSnack('Failed: $e', AppColors.danger);
      }
    }
  }

  Future<void> _updateService(String id, String name,
      String catId, String dept) async {
    try {
      final catConf = _categoryConfig[catId];
      await FirebaseFirestore.instance
          .collection('services')
          .doc(id)
          .update({
        'name':         name,
        'categoryId':   catId,
        'categoryName': catConf?['label'] ?? catId,
        'department':   dept,
        'departmentId': _deptNameToId[dept] ?? '',
        'updatedAt':    FieldValue.serverTimestamp(),
      });
      if (mounted) {
        _patchServiceLocal(id, {
          'name': name,
          'categoryId': catId,
          'categoryName': catConf?['label'] ?? catId,
          'department': dept,
          'departmentId': _deptNameToId[dept] ?? '',
        });
        _showSnack(
            'Service updated ✓', AppColors.success);
      }
    } catch (e) {
      if (mounted) {
        _showSnack('Failed: $e', AppColors.danger);
      }
    }
  }

  Future<void> _toggleActive(
      String id, bool current) async {
    try {
      final next = !current;
      await FirebaseFirestore.instance
          .collection('services')
          .doc(id)
          .update({
        'isActive':  next,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      if (mounted) {
        _patchServiceLocal(id, {'isActive': next});
        _showSnack(
          current
              ? 'Service deactivated'
              : 'Service activated ✓',
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
        title: Row(children: [
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
          Text('Delete Service',
              style: GoogleFonts.inter(
                  fontWeight: FontWeight.w700,
                  fontSize: 16)),
        ]),
        content: Text(
          'Delete "$name"? This will also remove it from '
          'the citizen mobile app. This action cannot be undone.',
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
              await _deleteService(id);
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

  Future<void> _deleteService(String id) async {
    try {
      await FirebaseFirestore.instance
          .collection('services')
          .doc(id)
          .delete();
      if (mounted) {
        _allServices.removeWhere((s) => s['id'] == id);
        _applyFilters();
        _showSnack('Service deleted', AppColors.danger);
      }
    } catch (e) {
      if (mounted) {
        _showSnack('Failed: $e', AppColors.danger);
      }
    }
  }

  // ── Helpers ────────────────────────────────────────────────────────────────
  void _patchServiceLocal(String id, Map<String, dynamic> patch) {
    final idx = _allServices.indexWhere((s) => s['id'] == id);
    if (idx == -1) return;
    _allServices[idx] = {
      ..._allServices[idx],
      ...patch,
      'updatedAt': Timestamp.now(),
    };
    _applyFilters();
  }

  Widget _fieldLabel(String label) => Text(label,
      style: GoogleFonts.inter(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: const Color(0xFF333333),
      ));

  InputDecoration _inputDeco(String hint) =>
      InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.inter(
            color: AppColors.muted, fontSize: 12),
        filled: true,
        fillColor: const Color(0xFFF7F8FC),
        contentPadding: const EdgeInsets.symmetric(
            horizontal: 14, vertical: 12),
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
      );

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
}