import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../widgets/bottom_nav.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  static final List<Map<String, dynamic>> _menuItems = [
    {'label': 'Personal Information', 'icon': LucideIcons.user,        'path': '/profile_info'},
    {'label': 'History',              'icon': LucideIcons.history,      'path': '/profile_history'},
    {'label': 'Help & Support',       'icon': LucideIcons.helpCircle,   'path': '/profile_help'},
    {'label': 'Settings',             'icon': LucideIcons.settings,     'path': '/profile_settings'},
  ];

  final _auth = FirebaseAuth.instance;
  final _db   = FirebaseFirestore.instance;

  // ── Firestore user data ────────────────────────────────────────────────────
  String _displayName = 'User';
  String _email       = '';
  String _phone       = '';
  bool   _loading     = true;

  // ── Request counts from Firestore ──────────────────────────────────────────
  int _pendingCount    = 0;
  int _processingCount = 0;
  int _doneCount       = 0;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _listenToRequestCounts();
  }

  // FIX: load full profile from Firestore users collection
  Future<void> _loadUserData() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      setState(() => _loading = false);
      return;
    }

    try {
      final doc = await _db.collection('users').doc(uid).get();
      if (doc.exists && mounted) {
        final data = doc.data()!;
        setState(() {
          _displayName = data['fullName']
              ?? _auth.currentUser?.displayName
              ?? 'User';
          _email = data['email']
              ?? _auth.currentUser?.email
              ?? '';
          _phone   = data['phone'] ?? '';
          _loading = false;
        });
      } else {
        // Fallback to FirebaseAuth values
        setState(() {
          _displayName = _auth.currentUser?.displayName ?? 'User';
          _email       = _auth.currentUser?.email ?? '';
          _loading     = false;
        });
      }
    } catch (_) {
      setState(() {
        _displayName = _auth.currentUser?.displayName ?? 'User';
        _email       = _auth.currentUser?.email ?? '';
        _loading     = false;
      });
    }
  }

  // FIX: real-time request counts from Firestore
  void _listenToRequestCounts() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    _db.collection('requests')
        .where('userId', isEqualTo: uid)
        .snapshots()
        .listen((snapshot) {
      int pending = 0, processing = 0, done = 0;
      for (final doc in snapshot.docs) {
        final status = (doc['status'] ?? '').toString().toLowerCase();
        if (status == 'pending') {
          pending++;
        } else if (status == 'processing') processing++;
        else if (status == 'completed')  done++;
      }
      if (mounted) {
        setState(() {
          _pendingCount    = pending;
          _processingCount = processing;
          _doneCount       = done;
        });
      }
    });
  }

  String get _initials {
    final parts = _displayName.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    }
    return _displayName.isNotEmpty ? _displayName[0].toUpperCase() : 'U';
  }

  Future<void> _handleLogout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg)),
        title: Text('Sign out?', style: AppTextStyles.h2),
        content: Text(
          'You will be returned to the login screen.',
          style: AppTextStyles.bodyMuted,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: TextStyle(color: AppColors.muted)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md)),
            ),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await FirebaseAuth.instance.signOut();
      if (context.mounted) {
        Navigator.of(context).pushReplacementNamed('/login');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Column(
                children: [
                  _buildHeader(context),
                  _buildBody(context),
                ],
              ),
            ),
      // FIX: selectedIndex was 4 — profile is index 3
      bottomNavigationBar: const BottomNav(selectedIndex: 3),
    );
  }

  // ── Header ─────────────────────────────────────────────────────────────────
  Widget _buildHeader(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: AppColors.headerGradient,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(36),
          bottomRight: Radius.circular(36),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            Positioned(
              top: -30,
              right: -30,
              child: Container(
                width: 160,
                height: 160,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.07),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 20, 22, 52),
              child: Row(
                children: [
                  const SizedBox(width: 40),
                  Expanded(
                    child: Text(
                      'My Profile',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () async {
                      await Navigator.pushNamed(context, '/profile_edit');
                      _loadUserData(); // FIX: reload after editing
                    },
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(LucideIcons.pencil,
                          color: Colors.white, size: 18),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Body ───────────────────────────────────────────────────────────────────
  Widget _buildBody(BuildContext context) {
    return Transform.translate(
      offset: const Offset(0, -48),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          children: [
            // ── Avatar card ────────────────────────────────────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppRadius.xl),
                boxShadow: AppShadows.elevated,
              ),
              child: Column(
                children: [
                  // Avatar
                  Container(
                    width: 84,
                    height: 84,
                    decoration: const BoxDecoration(
                      gradient: AppColors.primaryGradient,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        _initials,
                        style: GoogleFonts.inter(
                          fontSize: 30,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Name — from Firestore
                  Text(_displayName, style: AppTextStyles.h2),
                  const SizedBox(height: 4),

                  // Email — from Firestore
                  Text(_email,
                      style:
                          AppTextStyles.bodyMuted.copyWith(fontSize: 13)),

                  // Phone — from Firestore (only show if available)
                  if (_phone.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(_phone,
                        style: AppTextStyles.bodyMuted.copyWith(fontSize: 13)),
                  ],

                  const SizedBox(height: 20),

                  // FIX: real stats from Firestore
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildStat('Pending',    '$_pendingCount',    AppColors.warning),
                        _buildDivider(),
                        _buildStat('Processing', '$_processingCount', AppColors.primary),
                        _buildDivider(),
                        _buildStat('Completed',  '$_doneCount',       AppColors.success),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // ── Menu items ─────────────────────────────────────────
            Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppRadius.xl),
                boxShadow: AppShadows.card,
              ),
              child: Column(
                children: List.generate(_menuItems.length, (i) {
                  return _buildMenuItem(
                    context,
                    _menuItems[i],
                    showDivider: i != _menuItems.length - 1,
                  );
                }),
              ),
            ),

            const SizedBox(height: 20),

            // ── Logout ─────────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => _handleLogout(context),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  side: const BorderSide(color: AppColors.danger, width: 1.5),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.lg)),
                  foregroundColor: AppColors.danger,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(LucideIcons.logOut, size: 18),
                    const SizedBox(width: 10),
                    Text('Sign Out',
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.danger,
                        )),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 120),
          ],
        ),
      ),
    );
  }

  Widget _buildStat(String label, String value, Color color) {
    return Column(
      children: [
        Text(value,
            style: GoogleFonts.inter(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: color,
            )),
        const SizedBox(height: 4),
        Text(label,
            style: AppTextStyles.caption.copyWith(letterSpacing: 0.3)),
      ],
    );
  }

  Widget _buildDivider() {
    return Container(width: 1, height: 36, color: AppColors.divider);
  }

  Widget _buildMenuItem(BuildContext context, Map<String, dynamic> item,
      {required bool showDivider}) {
    return Column(
      children: [
        InkWell(
          onTap: () => Navigator.pushNamed(context, item['path']),
          borderRadius: BorderRadius.circular(AppRadius.xl),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: AppColors.cardBg,
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(item['icon'] as IconData,
                      color: AppColors.primary, size: 20),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(item['label'] as String,
                      style: AppTextStyles.body.copyWith(
                        color: AppColors.secondary,
                        fontWeight: FontWeight.w600,
                      )),
                ),
                const Icon(LucideIcons.chevronRight,
                    color: AppColors.muted, size: 18),
              ],
            ),
          ),
        ),
        if (showDivider)
          Divider(
              height: 1,
              indent: 20,
              endIndent: 20,
              color: AppColors.divider),
      ],
    );
  }
}