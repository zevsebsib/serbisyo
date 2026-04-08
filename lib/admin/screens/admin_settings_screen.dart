import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';

class AdminSettingsScreen extends StatefulWidget {
  const AdminSettingsScreen({super.key});

  @override
  State<AdminSettingsScreen> createState() =>
      _AdminSettingsScreenState();
}

class _AdminSettingsScreenState
    extends State<AdminSettingsScreen> {
  bool _loading = true;
  int  _tab     = 0;

  // Profile
  Map<String, dynamic> _adminData = {};
  final _nameCtrl  = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  bool  _savingProfile = false;

  // ── CHANGE 1: Removed _deptNameCtrl, _deptDescCtrl, _savingDept ──────────
  // Department info is now view-only in the Profile tab.
  // These controllers no longer exist.
  String _departmentName        = '';
  String _departmentDescription = '';

  // Password
  final _curPassCtrl  = TextEditingController();
  final _newPassCtrl  = TextEditingController();
  final _confPassCtrl = TextEditingController();
  bool  _savingPass   = false;
  bool  _showCur = false, _showNew = false, _showConf = false;

  // Templates
  List<Map<String, dynamic>> _templates = [];
  bool _savingTemplates = false;

  // Preferences
  bool   _emailNotifs = true;
  bool   _pushNotifs  = true;
  bool   _darkMode    = false;
  String _language    = 'English';

  // ── CHANGE 2: Removed 'Department' tab from the list ─────────────────────
  final _tabs = [
    {'label': 'Profile',     'icon': Icons.person_rounded},
    {'label': 'Templates',   'icon': Icons.message_rounded},
    {'label': 'Preferences', 'icon': Icons.tune_rounded},
  ];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();    _phoneCtrl.dispose();
    _emailCtrl.dispose();   _curPassCtrl.dispose();
    _newPassCtrl.dispose(); _confPassCtrl.dispose();
    _confPassCtrl.dispose();
    super.dispose();
  }

  // ── Load ──────────────────────────────────────────────────────────────────
  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;

      final adminDoc = await FirebaseFirestore.instance
          .collection('admin')
          .doc(uid)
          .get();

      if (adminDoc.exists) {
        _adminData = adminDoc.data() ?? {};
        _nameCtrl.text  = _adminData['fullName'] ?? '';
        _phoneCtrl.text = _adminData['phone'] ?? '';
        _emailCtrl.text =
            FirebaseAuth.instance.currentUser?.email ?? '';

        // ── CHANGE 3: Load department as read-only strings (no editing) ──────
        final deptId = _adminData['departmentId'] as String? ?? '';
        if (deptId.isNotEmpty) {
          final deptDoc = await FirebaseFirestore.instance
              .collection('departments')
              .doc(deptId)
              .get();
          if (deptDoc.exists) {
            _departmentName =
                deptDoc.data()?['name'] as String? ?? '';
            _departmentDescription =
                deptDoc.data()?['description'] as String? ?? '';
          }
        }
      }

      // Load notification templates
      final tmplSnap = await FirebaseFirestore.instance
          .collection('notification_templates')
          .get();
      if (tmplSnap.docs.isEmpty) {
        _templates = _defaultTemplates();
      } else {
        _templates = tmplSnap.docs.map((d) => {
          'id':    d.id,
          'type':  d.data()['type'] ?? '',
          'title': d.data()['title'] ?? '',
          'body':  d.data()['body'] ?? '',
          'titleCtrl': TextEditingController(
              text: d.data()['title'] ?? ''),
          'bodyCtrl':  TextEditingController(
              text: d.data()['body'] ?? ''),
        }).toList();
      }
    } catch (e) {
      debugPrint('Settings error: $e');
    }
    if (mounted) setState(() => _loading = false);
  }

  List<Map<String, dynamic>> _defaultTemplates() => [
    {
      'id':    '',
      'type':  'status_update',
      'title': 'Your request status has been updated',
      'body':  'Your service request ({{trackingId}}) status is now {{status}}.',
      'titleCtrl': TextEditingController(
          text: 'Your request status has been updated'),
      'bodyCtrl': TextEditingController(
          text: 'Your service request ({{trackingId}}) status is now {{status}}.'),
    },
    {
      'id':    '',
      'type':  'missing_docs',
      'title': 'Missing documents required',
      'body':  'Your request ({{trackingId}}) requires additional documents: {{documents}}.',
      'titleCtrl': TextEditingController(
          text: 'Missing documents required'),
      'bodyCtrl': TextEditingController(
          text: 'Your request ({{trackingId}}) requires additional documents: {{documents}}.'),
    },
    {
      'id':    '',
      'type':  'completed',
      'title': 'Your request has been completed',
      'body':  'Great news! Your service request ({{trackingId}}) has been completed and is ready for pickup.',
      'titleCtrl': TextEditingController(
          text: 'Your request has been completed'),
      'bodyCtrl': TextEditingController(
          text: 'Great news! Your service request ({{trackingId}}) has been completed and is ready for pickup.'),
    },
  ];

  // ── Save profile ──────────────────────────────────────────────────────────
  Future<void> _saveProfile() async {
    setState(() => _savingProfile = true);
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
      await FirebaseFirestore.instance
          .collection('admin')
          .doc(uid)
          .update({
        'fullName':  _nameCtrl.text.trim(),
        'phone':     _phoneCtrl.text.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      _showSnack('Profile updated ✓', AppColors.success);
    } catch (e) {
      _showSnack('Failed: $e', AppColors.danger);
    }
    if (mounted) setState(() => _savingProfile = false);
  }

  // ── Change password ───────────────────────────────────────────────────────
  Future<void> _changePassword() async {
    if (_newPassCtrl.text != _confPassCtrl.text) {
      _showSnack('Passwords do not match', AppColors.warning);
      return;
    }
    if (_newPassCtrl.text.length < 6) {
      _showSnack('Password must be at least 6 characters',
          AppColors.warning);
      return;
    }
    setState(() => _savingPass = true);
    try {
      final user = FirebaseAuth.instance.currentUser!;
      final cred = EmailAuthProvider.credential(
        email:    user.email!,
        password: _curPassCtrl.text,
      );
      await user.reauthenticateWithCredential(cred);
      await user.updatePassword(_newPassCtrl.text);
      _curPassCtrl.clear();
      _newPassCtrl.clear();
      _confPassCtrl.clear();
      _showSnack('Password changed ✓', AppColors.success);
    } on FirebaseAuthException catch (e) {
      _showSnack(e.message ?? 'Failed', AppColors.danger);
    }
    if (mounted) setState(() => _savingPass = false);
  }

  // ── CHANGE 4: _saveDepartment() method removed ────────────────────────────

  // ── Save templates ────────────────────────────────────────────────────────
  Future<void> _saveTemplates() async {
    setState(() => _savingTemplates = true);
    try {
      final batch = FirebaseFirestore.instance.batch();
      for (final t in _templates) {
        final id  = t['id'] as String;
        final ref = id.isEmpty
            ? FirebaseFirestore.instance
                .collection('notification_templates')
                .doc()
            : FirebaseFirestore.instance
                .collection('notification_templates')
                .doc(id);
        batch.set(ref, {
          'type':  t['type'],
          'title': (t['titleCtrl'] as TextEditingController)
              .text.trim(),
          'body':  (t['bodyCtrl'] as TextEditingController)
              .text.trim(),
        });
      }
      await batch.commit();
      _showSnack('Templates saved ✓', AppColors.success);
    } catch (e) {
      _showSnack('Failed: $e', AppColors.danger);
    }
    if (mounted) setState(() => _savingTemplates = false);
  }

  // ── BUILD ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const SizedBox(height: 20),
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(
                        color: AppColors.primary))
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSidebar(),
                      const SizedBox(width: 24),
                      Expanded(child: _buildTabBody()),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Settings',
            style: GoogleFonts.inter(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF111111),
              letterSpacing: -0.5,
            )),
        const SizedBox(height: 4),
        Text(
          'Manage your account and system preferences',
          style: GoogleFonts.inter(
              fontSize: 13, color: AppColors.muted),
        ),
      ],
    );
  }

  // ── Sidebar nav ───────────────────────────────────────────────────────────
  Widget _buildSidebar() {
    return Container(
      width: 220,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(children: [
              Container(
                width: 44, height: 44,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFFFF9200), Color(0xFFFF5E00)],
                  ),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    _initials(_adminData['fullName'] as String? ?? 'A'),
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _adminData['fullName'] as String? ?? 'Admin',
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF111111),
                      ),
                    ),
                    Text(
                      _adminData['role'] == 'superadmin'
                          ? 'Super Admin'
                          : 'Staff',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: AppColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
            ]),
          ),
          const Divider(color: Color(0xFFF0F0F0)),
          const SizedBox(height: 8),
          ..._tabs.asMap().entries.map((entry) {
            final i   = entry.key;
            final t   = entry.value;
            final sel = _tab == i;
            return GestureDetector(
              onTap: () => setState(() => _tab = i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                margin: const EdgeInsets.only(bottom: 4),
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: sel
                      ? AppColors.primary.withValues(alpha: 0.08)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(children: [
                  Icon(t['icon'] as IconData,
                      size: 18,
                      color: sel
                          ? AppColors.primary
                          : AppColors.muted),
                  const SizedBox(width: 10),
                  Text(t['label'] as String,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: sel
                            ? FontWeight.w700
                            : FontWeight.w500,
                        color: sel
                            ? AppColors.primary
                            : const Color(0xFF444444),
                      )),
                ]),
              ),
            );
          }),
        ],
      ),
    );
  }

  // ── Tab body ──────────────────────────────────────────────────────────────
  Widget _buildTabBody() {
    // ── CHANGE 5: Tab index shifted — Department tab removed ──────────────
    // 0 = Profile, 1 = Templates, 2 = Preferences
    switch (_tab) {
      case 0:  return _buildProfileTab();
      case 1:  return _buildTemplatesTab();
      default: return _buildPreferencesTab();
    }
  }

  // ── Profile tab ───────────────────────────────────────────────────────────
  Widget _buildProfileTab() {
    return SingleChildScrollView(
      child: Column(
        children: [
          _sectionCard(
            title: 'Personal Information',
            icon:  Icons.person_rounded,
            child: Column(children: [
              Row(children: [
                Expanded(child: _buildField(
                    'Full Name', _nameCtrl,
                    'e.g. Juan dela Cruz')),
                const SizedBox(width: 16),
                Expanded(child: _buildField(
                    'Phone', _phoneCtrl,
                    'e.g. 09XXXXXXXXX')),
              ]),
              const SizedBox(height: 14),
              _buildField(
                'Email Address', _emailCtrl,
                'Email cannot be changed',
                enabled: false,
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  _saveBtn(
                    label: 'Save Profile',
                    loading: _savingProfile,
                    onTap: _saveProfile,
                  ),
                ],
              ),
            ]),
          ),
          const SizedBox(height: 20),

          // ── CHANGE 6: Department info — view-only section in Profile ────────
          if (_departmentName.isNotEmpty)
            _sectionCard(
              title: 'Department',
              icon:  Icons.account_tree_rounded,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Info banner
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.primary
                          .withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: AppColors.primary
                            .withValues(alpha: 0.15),
                      ),
                    ),
                    child: Row(children: [
                      Icon(Icons.info_outline_rounded,
                          color: AppColors.primary, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Department information is managed by '
                          'the system administrator.',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ]),
                  ),
                  const SizedBox(height: 16),
                  _infoRow('Department', _departmentName),
                  if (_departmentDescription.isNotEmpty)
                    _infoRow('Description',
                        _departmentDescription),
                ],
              ),
            ),

          const SizedBox(height: 20),
          _sectionCard(
            title: 'Change Password',
            icon:  Icons.lock_rounded,
            child: Column(children: [
              _buildPassField(
                'Current Password',
                _curPassCtrl,
                _showCur,
                () => setState(() => _showCur = !_showCur),
              ),
              const SizedBox(height: 14),
              Row(children: [
                Expanded(child: _buildPassField(
                  'New Password',
                  _newPassCtrl,
                  _showNew,
                  () => setState(() => _showNew = !_showNew),
                )),
                const SizedBox(width: 16),
                Expanded(child: _buildPassField(
                  'Confirm New Password',
                  _confPassCtrl,
                  _showConf,
                  () => setState(() => _showConf = !_showConf),
                )),
              ]),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  _saveBtn(
                    label: 'Change Password',
                    loading: _savingPass,
                    onTap: _changePassword,
                    color: const Color(0xFF8B5CF6),
                  ),
                ],
              ),
            ]),
          ),
        ],
      ),
    );
  }

  // ── CHANGE 7: _buildDepartmentTab() method removed ────────────────────────

  // ── Templates tab ─────────────────────────────────────────────────────────
  Widget _buildTemplatesTab() {
    final typeColors = <String, Color>{
      'status_update': const Color(0xFF3B82F6),
      'missing_docs':  const Color(0xFFF59E0B),
      'completed':     const Color(0xFF10B981),
    };
    final typeLabels = <String, String>{
      'status_update': 'Status Update',
      'missing_docs':  'Missing Documents',
      'completed':     'Completed',
    };

    return SingleChildScrollView(
      child: _sectionCard(
        title: 'Notification Templates',
        icon:  Icons.message_rounded,
        subtitle:
            'Use {{trackingId}}, {{status}}, {{documents}} as dynamic placeholders.',
        child: Column(children: [
          ..._templates.asMap().entries.map((entry) {
            final i     = entry.key;
            final t     = entry.value;
            final type  = t['type'] as String;
            final color = typeColors[type] ?? AppColors.primary;
            final label = typeLabels[type] ?? type;

            return Container(
              margin: EdgeInsets.only(
                  bottom: i < _templates.length - 1 ? 20 : 0),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF7F8FC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: const Color(0xFFEEEEEE)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.10),
                        borderRadius:
                            BorderRadius.circular(20),
                      ),
                      child: Text(label,
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: color,
                          )),
                    ),
                  ]),
                  const SizedBox(height: 12),
                  _buildField('Title',
                      t['titleCtrl'] as TextEditingController,
                      ''),
                  const SizedBox(height: 10),
                  _buildField('Message Body',
                      t['bodyCtrl'] as TextEditingController,
                      '',
                      maxLines: 3),
                ],
              ),
            );
          }),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              _saveBtn(
                label: 'Save Templates',
                loading: _savingTemplates,
                onTap: _saveTemplates,
              ),
            ],
          ),
        ]),
      ),
    );
  }

  // ── Preferences tab ───────────────────────────────────────────────────────
  Widget _buildPreferencesTab() {
    return SingleChildScrollView(
      child: Column(children: [
        _sectionCard(
          title: 'Notifications',
          icon:  Icons.notifications_rounded,
          child: Column(children: [
            _prefToggle(
              'Email Notifications',
              'Receive email alerts for new requests',
              _emailNotifs,
              (v) => setState(() => _emailNotifs = v),
            ),
            const Divider(
                color: Color(0xFFF0F0F0), height: 24),
            _prefToggle(
              'Push Notifications',
              'Receive browser push notifications',
              _pushNotifs,
              (v) => setState(() => _pushNotifs = v),
            ),
          ]),
        ),
        const SizedBox(height: 20),
        _sectionCard(
          title: 'Display',
          icon:  Icons.palette_rounded,
          child: Column(children: [
            _prefToggle(
              'Dark Mode',
              'Switch to dark theme (coming soon)',
              _darkMode,
              (v) => setState(() => _darkMode = v),
              disabled: true,
            ),
            const Divider(
                color: Color(0xFFF0F0F0), height: 24),
            Row(children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Language',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF222222),
                        )),
                    const SizedBox(height: 2),
                    Text('Interface language',
                        style: GoogleFonts.inter(
                            fontSize: 12,
                            color: AppColors.muted)),
                  ],
                ),
              ),
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
                    value: _language,
                    icon: const Icon(
                        Icons.keyboard_arrow_down_rounded,
                        size: 16,
                        color: AppColors.muted),
                    style: GoogleFonts.inter(
                        fontSize: 13,
                        color: const Color(0xFF333333)),
                    items: ['English', 'Filipino']
                        .map((l) => DropdownMenuItem<String>(
                              value: l,
                              child: Text(l,
                                  style: GoogleFonts.inter(
                                      fontSize: 13)),
                            ))
                        .toList(),
                    onChanged: (v) =>
                        setState(() => _language = v!),
                  ),
                ),
              ),
            ]),
          ]),
        ),
        const SizedBox(height: 20),
        _sectionCard(
          title: 'System Info',
          icon:  Icons.info_rounded,
          child: Column(children: [
            _infoRow('App Name', 'SerbisyoAlisto Admin'),
            _infoRow('Version', '1.0.0'),
            _infoRow('City', 'City of Laoag, Ilocos Norte'),
            _infoRow('Platform', 'Web (Flutter)'),
          ]),
        ),
      ]),
    );
  }

  // ── Shared widgets ────────────────────────────────────────────────────────
  Widget _sectionCard({
    required String title,
    required IconData icon,
    required Widget child,
    String? subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon,
                  color: AppColors.primary, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF111111),
                      )),
                  if (subtitle != null)
                    Text(subtitle,
                        style: GoogleFonts.inter(
                            fontSize: 11,
                            color: AppColors.muted)),
                ],
              ),
            ),
          ]),
          const SizedBox(height: 20),
          const Divider(color: Color(0xFFF5F5F5)),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  Widget _buildField(
    String label,
    TextEditingController ctrl,
    String hint, {
    bool enabled  = true,
    int  maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF333333),
            )),
        const SizedBox(height: 8),
        TextFormField(
          controller: ctrl,
          enabled:    enabled,
          maxLines:   maxLines,
          style: GoogleFonts.inter(fontSize: 13),
          decoration: InputDecoration(
            hintText:  hint,
            hintStyle: GoogleFonts.inter(
                color: AppColors.muted, fontSize: 12),
            filled:     true,
            fillColor: enabled
                ? const Color(0xFFF7F8FC)
                : const Color(0xFFEEEEEE),
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
            disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide:
                  const BorderSide(color: Color(0xFFEEEEEE)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPassField(
    String label,
    TextEditingController ctrl,
    bool show,
    VoidCallback toggle,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF333333),
            )),
        const SizedBox(height: 8),
        TextFormField(
          controller:   ctrl,
          obscureText: !show,
          style: GoogleFonts.inter(fontSize: 13),
          decoration: InputDecoration(
            filled:    true,
            fillColor: const Color(0xFFF7F8FC),
            contentPadding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 12),
            suffixIcon: IconButton(
              icon: Icon(
                show
                    ? Icons.visibility_off_rounded
                    : Icons.visibility_rounded,
                size: 18,
                color: AppColors.muted,
              ),
              onPressed: toggle,
            ),
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
      ],
    );
  }

  Widget _prefToggle(
    String title,
    String subtitle,
    bool value,
    ValueChanged<bool> onChanged, {
    bool disabled = false,
  }) {
    return Row(children: [
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: disabled
                      ? AppColors.muted
                      : const Color(0xFF222222),
                )),
            const SizedBox(height: 2),
            Text(subtitle,
                style: GoogleFonts.inter(
                    fontSize: 12, color: AppColors.muted)),
          ],
        ),
      ),
      Switch(
        value:            value,
        onChanged:        disabled ? null : onChanged,
        activeThumbColor: AppColors.primary,
        activeTrackColor:
            AppColors.primary.withValues(alpha: 0.40),
      ),
    ]);
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(children: [
        SizedBox(
          width: 120,
          child: Text(label,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: AppColors.muted,
                fontWeight: FontWeight.w500,
              )),
        ),
        Expanded(
          child: Text(value,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF222222),
              )),
        ),
      ]),
    );
  }

  Widget _saveBtn({
    required String label,
    required bool loading,
    required VoidCallback onTap,
    Color color = AppColors.primary,
  }) {
    return ElevatedButton.icon(
      onPressed: loading ? null : onTap,
      icon: loading
          ? const SizedBox(
              width: 14, height: 14,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: Colors.white))
          : const Icon(Icons.save_rounded, size: 15),
      label: Text(
          loading ? 'Saving...' : label,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w600,
          )),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        disabledBackgroundColor: color.withValues(alpha: 0.5),
        elevation: 0,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10)),
        padding: const EdgeInsets.symmetric(
            horizontal: 20, vertical: 12),
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────
  void _showSnack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg,
          style: GoogleFonts.inter(
              color: Colors.white,
              fontWeight: FontWeight.w600)),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10)),
      margin: const EdgeInsets.all(16),
    ));
  }

  String _initials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : 'A';
  }
}