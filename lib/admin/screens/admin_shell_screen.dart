import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';
import 'admin_dashboard_screen.dart';
import 'admin_requests_screen.dart';
import 'admin_citizens_screen.dart';
import 'admin_departments_screen.dart';
import 'admin_staff_screen.dart';
import 'admin_reports_screen.dart';
import 'admin_notifications_screen.dart';
import 'admin_settings_screen.dart';
import 'admin_services_screen.dart';

class AdminShellScreen extends StatefulWidget {
  const AdminShellScreen({super.key});

  @override
  State<AdminShellScreen> createState() =>
      _AdminShellScreenState();
}

class _AdminShellScreenState
    extends State<AdminShellScreen> {
  int    _selectedIndex = 0;
  bool   _isExpanded    = false;
  String _role          = '';
  String _fullName      = '';
  bool   _isLoading     = true;

  static const double _collapsedWidth = 72;
  static const double _expandedWidth  = 240;

  // ── SuperAdmin nav items ───────────────────────────────────────────────────
  final List<_NavItem> _superAdminNavItems = [
    _NavItem(icon: Icons.dashboard_rounded,     label: 'Dashboard'),
    _NavItem(icon: Icons.assignment_rounded,    label: 'Requests'),
    _NavItem(icon: Icons.design_services_rounded, label: 'Services'),
    _NavItem(icon: Icons.people_rounded,        label: 'Citizens'),
    _NavItem(icon: Icons.account_tree_rounded,  label: 'Departments'),
    _NavItem(icon: Icons.badge_rounded,         label: 'Staff'),
    _NavItem(icon: Icons.bar_chart_rounded,     label: 'Reports'),
    _NavItem(icon: Icons.notifications_rounded, label: 'Notifications'),
    _NavItem(icon: Icons.settings_rounded,      label: 'Settings'),
  ];

  // ── Staff nav items ────────────────────────────────────────────────────────
  // FIX: "Profile" nav (index 3) now maps to AdminSettingsScreen which has a
  // full Profile tab. Previously _adminPages[3] was also AdminSettingsScreen
  // but the label said "Profile" which was confusing — now both label and
  // screen are consistently "Settings" with the Profile tab pre-selected.
  // "View Available Services" added at index 2 to satisfy use case diagram.
  final List<_NavItem> _adminNavItems = [
    _NavItem(icon: Icons.dashboard_rounded,       label: 'Dashboard'),
    _NavItem(icon: Icons.assignment_rounded,      label: 'My Requests'),
    _NavItem(icon: Icons.design_services_rounded, label: 'Services'),
    _NavItem(icon: Icons.notifications_rounded,   label: 'Notifications'),
    _NavItem(icon: Icons.settings_rounded,        label: 'Settings'),
  ];

  // ── SuperAdmin pages ───────────────────────────────────────────────────────
  final List<Widget> _superAdminPages = [
    const AdminDashboardScreen(),
    const AdminRequestsScreen(),
    const AdminServicesScreen(),
    const AdminCitizensScreen(),
    const AdminDepartmentsScreen(),
    const AdminStaffScreen(),
    const AdminReportsScreen(),
    const AdminNotificationsScreen(),
    const AdminSettingsScreen(),
  ];

  // ── Staff pages ────────────────────────────────────────────────────────────
  // FIX: index 2 = AdminServicesScreen (View Available Services use case)
  // FIX: index 3 = AdminNotificationsScreen (was previously wrong)
  // FIX: index 4 = AdminSettingsScreen (Settings, contains Profile tab)
  final List<Widget> _adminPages = [
    const AdminDashboardScreen(),
    const AdminRequestsScreen(),
    const AdminServicesScreen(),
    const AdminNotificationsScreen(),
    const AdminSettingsScreen(),
  ];

  List<_NavItem> get _navItems =>
      _role == 'superadmin'
          ? _superAdminNavItems
          : _adminNavItems;

  List<Widget> get _pages =>
      _role == 'superadmin'
          ? _superAdminPages
          : _adminPages;

  @override
  void initState() {
    super.initState();
    _loadAdminData();
  }

  Future<void> _loadAdminData() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      if (mounted) {
        setState(() => _isLoading = false);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            Navigator.pushReplacementNamed(context, '/admin/login');
          }
        });
      }
      return;
    }

    try {
      final doc = await FirebaseFirestore.instance
          .collection('admin')
          .doc(uid)
          .get();

      if (doc.exists && mounted) {
        setState(() {
          _role      = doc.data()?['role'] ?? 'admin';
          _fullName  = doc.data()?['fullName'] ?? 'Admin';
          _isLoading = false;
        });
      } else if (mounted) {
        await FirebaseAuth.instance.signOut();
        setState(() => _isLoading = false);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            Navigator.pushReplacementNamed(context, '/admin/login');
          }
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleLogout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: Text('Sign Out',
            style: GoogleFonts.inter(
                fontWeight: FontWeight.w700)),
        content: Text(
            'Are you sure you want to sign out?',
            style: GoogleFonts.inter(
                color: AppColors.muted)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel',
                style: GoogleFonts.inter(
                    color: AppColors.muted)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(8)),
            ),
            child: Text('Sign Out',
                style: GoogleFonts.inter(
                    color: Colors.white,
                    fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await FirebaseAuth.instance.signOut();
      if (mounted) {
        Navigator.pushReplacementNamed(
            context, '/admin/login');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFFF5F6FA),
        body: Center(
          child: CircularProgressIndicator(
              color: AppColors.primary),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      body: Row(
        children: [
          // ── Sidebar ─────────────────────────────────
          MouseRegion(
            onEnter: (_) =>
                setState(() => _isExpanded = true),
            onExit:  (_) =>
                setState(() => _isExpanded = false),
            child: AnimatedContainer(
              duration:
                  const Duration(milliseconds: 200),
              curve: Curves.easeInOut,
              width: _isExpanded
                  ? _expandedWidth
                  : _collapsedWidth,
              child: Container(
                decoration: const BoxDecoration(
                  gradient: AppColors.headerGradient,
                  boxShadow: [
                    BoxShadow(
                      color: Color(0x33000000),
                      blurRadius: 12,
                      offset: Offset(2, 0),
                    ),
                  ],
                ),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final showExpanded = constraints.maxWidth >= 180;

                    return Column(
                      children: [
                    // Logo
                    Container(
                      height: 72,
                      padding:
                          const EdgeInsets.symmetric(
                              horizontal: 16),
                      decoration: BoxDecoration(
                        color: Colors.black
                            .withValues(alpha: 0.15),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 40, height: 40,
                            decoration:
                                const BoxDecoration(
                                    color: Colors.white,
                                    shape:
                                        BoxShape.circle),
                            child: ClipOval(
                              child: Image.asset(
                                  'assets/logo.jpg',
                                  fit: BoxFit.cover),
                            ),
                          ),
                            if (showExpanded) ...[
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                mainAxisAlignment:
                                    MainAxisAlignment
                                        .center,
                                crossAxisAlignment:
                                    CrossAxisAlignment
                                        .start,
                                children: [
                                  Text('SerbisyoAlisto',
                                      overflow:
                                          TextOverflow
                                              .ellipsis,
                                      style:
                                          GoogleFonts.inter(
                                        fontSize: 14,
                                        fontWeight:
                                            FontWeight.w800,
                                        color: Colors.white,
                                      )),
                                  Text('Admin Portal',
                                      style:
                                          GoogleFonts.inter(
                                        fontSize: 10,
                                        color: Colors.white
                                            .withValues(
                                                alpha: 0.70),
                                        fontWeight:
                                            FontWeight.w500,
                                        letterSpacing: 1.0,
                                      )),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),

                    // Role badge
                    if (showExpanded)
                      Container(
                        margin: const EdgeInsets.fromLTRB(
                            12, 12, 12, 0),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white
                              .withValues(alpha: 0.12),
                          borderRadius:
                              BorderRadius.circular(8),
                          border: Border.all(
                            color: Colors.white
                                .withValues(alpha: 0.20),
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 8, height: 8,
                              decoration:
                                  const BoxDecoration(
                                color: Color(0xFF4CAF50),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment
                                        .start,
                                children: [
                                  Text(
                                    _fullName,
                                    overflow:
                                        TextOverflow
                                            .ellipsis,
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      fontWeight:
                                          FontWeight.w700,
                                      color: Colors.white,
                                    ),
                                  ),
                                  Text(
                                    _role == 'superadmin'
                                        ? 'Super Admin'
                                        : 'Admin / Staff',
                                    style: GoogleFonts.inter(
                                      fontSize: 10,
                                      color: Colors.white
                                          .withValues(
                                              alpha: 0.70),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                    const SizedBox(height: 12),

                    // Nav items
                    Expanded(
                      child: ListView.builder(
                        padding:
                            const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                        itemCount: _navItems.length,
                        itemBuilder: (context, index) {
                          final item = _navItems[index];
                          final selected =
                              _selectedIndex == index;

                          return Padding(
                            padding: const EdgeInsets.only(
                                bottom: 4),
                            child: showExpanded
                                ? InkWell(
                                    onTap: () => setState(() =>
                                        _selectedIndex = index),
                                    borderRadius:
                                        BorderRadius.circular(10),
                                    child: AnimatedContainer(
                                      duration: const Duration(
                                          milliseconds: 150),
                                      height: 46,
                                      padding: const EdgeInsets
                                          .symmetric(
                                              horizontal: 12),
                                      decoration: BoxDecoration(
                                        color: selected
                                            ? Colors.white
                                                .withValues(
                                                    alpha: 0.20)
                                            : Colors.transparent,
                                        borderRadius:
                                            BorderRadius.circular(
                                                10),
                                        border: selected
                                            ? Border.all(
                                                color: Colors.white
                                                    .withValues(
                                                        alpha: 0.30),
                                                width: 1,
                                              )
                                            : null,
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(
                                            item.icon,
                                            size: 22,
                                            color: selected
                                                ? Colors.white
                                                : Colors.white
                                                    .withValues(
                                                        alpha: 0.60),
                                          ),
                                          if (showExpanded) ...[
                                            const SizedBox(
                                                width: 12),
                                            Expanded(
                                              child: Text(
                                                item.label,
                                                overflow:
                                                    TextOverflow
                                                        .ellipsis,
                                                style: GoogleFonts
                                                    .inter(
                                                  fontSize: 13,
                                                  fontWeight: selected
                                                      ? FontWeight
                                                          .w700
                                                      : FontWeight
                                                          .w500,
                                                  color: selected
                                                      ? Colors.white
                                                      : Colors.white
                                                          .withValues(
                                                              alpha:
                                                                  0.70),
                                                ),
                                              ),
                                            ),
                                            if (selected)
                                              Container(
                                                width: 6,
                                                height: 6,
                                                decoration:
                                                    const BoxDecoration(
                                                  color: Colors.white,
                                                  shape:
                                                      BoxShape.circle,
                                                ),
                                              ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  )
                                : Tooltip(
                                    message: item.label,
                                    preferBelow: false,
                                    child: InkWell(
                                      onTap: () => setState(() =>
                                          _selectedIndex = index),
                                      borderRadius:
                                          BorderRadius.circular(10),
                                      child: AnimatedContainer(
                                        duration: const Duration(
                                            milliseconds: 150),
                                        height: 46,
                                        padding: const EdgeInsets
                                            .symmetric(
                                                horizontal: 12),
                                        decoration: BoxDecoration(
                                          color: selected
                                              ? Colors.white
                                                  .withValues(
                                                      alpha: 0.20)
                                              : Colors.transparent,
                                          borderRadius:
                                              BorderRadius.circular(
                                                  10),
                                          border: selected
                                              ? Border.all(
                                                  color: Colors.white
                                                      .withValues(
                                                          alpha: 0.30),
                                                  width: 1,
                                                )
                                              : null,
                                        ),
                                        child: Row(
                                          children: [
                                            Icon(
                                              item.icon,
                                              size: 22,
                                              color: selected
                                                  ? Colors.white
                                                  : Colors.white
                                                      .withValues(
                                                          alpha: 0.60),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                          );
                        },
                      ),
                    ),

                    // Logout
                    Padding(
                      padding: const EdgeInsets.all(8),
                      child: showExpanded
                          ? InkWell(
                              onTap: _handleLogout,
                              borderRadius:
                                  BorderRadius.circular(10),
                              child: AnimatedContainer(
                                duration: const Duration(
                                    milliseconds: 150),
                                height: 46,
                                padding:
                                    const EdgeInsets.symmetric(
                                        horizontal: 12),
                                decoration: BoxDecoration(
                                  color: Colors.white
                                      .withValues(alpha: 0.08),
                                  borderRadius:
                                      BorderRadius.circular(10),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.logout_rounded,
                                        size: 22,
                                        color: Colors.white
                                            .withValues(
                                                alpha: 0.70)),
                                    if (showExpanded) ...[
                                      const SizedBox(width: 12),
                                      Text('Sign Out',
                                          style:
                                              GoogleFonts.inter(
                                            fontSize: 13,
                                            fontWeight:
                                                FontWeight.w500,
                                            color: Colors.white
                                                .withValues(
                                                    alpha: 0.70),
                                          )),
                                    ],
                                  ],
                                ),
                              ),
                            )
                          : Tooltip(
                              message: 'Sign Out',
                              preferBelow: false,
                              child: InkWell(
                                onTap: _handleLogout,
                                borderRadius:
                                    BorderRadius.circular(10),
                                child: AnimatedContainer(
                                  duration: const Duration(
                                      milliseconds: 150),
                                  height: 46,
                                  padding:
                                      const EdgeInsets.symmetric(
                                          horizontal: 12),
                                  decoration: BoxDecoration(
                                    color: Colors.white
                                        .withValues(alpha: 0.08),
                                    borderRadius:
                                        BorderRadius.circular(10),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(Icons.logout_rounded,
                                          size: 22,
                                          color: Colors.white
                                              .withValues(
                                                  alpha: 0.70)),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                    ),

                    const SizedBox(height: 8),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),

          // ── Main content ─────────────────────────────
          Expanded(
            child: Column(
              children: [
                // Top header
                Container(
                  height: 72,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 24),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Color(0x0F000000),
                        blurRadius: 8,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Column(
                        mainAxisAlignment:
                            MainAxisAlignment.center,
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          Text(
                            _navItems[_selectedIndex].label,
                            style: GoogleFonts.inter(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color:
                                  const Color(0xFF1A1A1A),
                            ),
                          ),
                          Text(
                            _role == 'superadmin'
                                ? 'Super Admin View'
                                : 'Staff View',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: AppColors.muted,
                            ),
                          ),
                        ],
                      ),

                      const Spacer(),

                      // Search bar
                      Container(
                        width: 260, height: 40,
                        decoration: BoxDecoration(
                          color:
                              const Color(0xFFF5F6FA),
                          borderRadius:
                              BorderRadius.circular(10),
                          border: Border.all(
                              color: const Color(
                                  0xFFEEEEEE)),
                        ),
                        child: Row(
                          children: [
                            const SizedBox(width: 12),
                            Icon(Icons.search,
                                color: AppColors.muted,
                                size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextField(
                                decoration: InputDecoration(
                                  hintText: 'Search...',
                                  hintStyle:
                                      GoogleFonts.inter(
                                    color: AppColors.muted,
                                    fontSize: 13,
                                  ),
                                  border: InputBorder.none,
                                  isDense: true,
                                ),
                                style: GoogleFonts.inter(
                                    fontSize: 13),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(width: 16),

                      // Notification bell
                      Container(
                        width: 40, height: 40,
                        decoration: BoxDecoration(
                          color:
                              const Color(0xFFF5F6FA),
                          borderRadius:
                              BorderRadius.circular(10),
                          border: Border.all(
                              color: const Color(
                                  0xFFEEEEEE)),
                        ),
                        child: Stack(
                          children: [
                            Center(
                              child: Icon(
                                  Icons
                                      .notifications_outlined,
                                  color: AppColors.muted,
                                  size: 20),
                            ),
                            Positioned(
                              top: 8, right: 8,
                              child: Container(
                                width: 8, height: 8,
                                decoration:
                                    const BoxDecoration(
                                  color: AppColors.danger,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(width: 16),

                      // Admin avatar
                      Row(
                        children: [
                          Container(
                            width: 40, height: 40,
                            decoration:
                                const BoxDecoration(
                              gradient:
                                  AppColors.headerGradient,
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Text(
                                _fullName.isNotEmpty
                                    ? _fullName[0]
                                        .toUpperCase()
                                    : 'A',
                                style: GoogleFonts.inter(
                                  color: Colors.white,
                                  fontWeight:
                                      FontWeight.w700,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Column(
                            mainAxisAlignment:
                                MainAxisAlignment.center,
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              Text(_fullName,
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    fontWeight:
                                        FontWeight.w700,
                                    color: const Color(
                                        0xFF1A1A1A),
                                  )),
                              Container(
                                padding:
                                    const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 2),
                                decoration: BoxDecoration(
                                  color: _role == 'superadmin'
                                      ? AppColors.primary
                                          .withValues(
                                              alpha: 0.12)
                                      : const Color(
                                              0xFF2196F3)
                                          .withValues(
                                              alpha: 0.12),
                                  borderRadius:
                                      BorderRadius.circular(
                                          20),
                                ),
                                child: Text(
                                  _role == 'superadmin'
                                      ? 'Super Admin'
                                      : 'Admin / Staff',
                                  style: GoogleFonts.inter(
                                    fontSize: 10,
                                    fontWeight:
                                        FontWeight.w700,
                                    color:
                                        _role == 'superadmin'
                                            ? AppColors.primary
                                            : const Color(
                                                0xFF2196F3),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Page content
                Expanded(
                  child: _selectedIndex < _pages.length
                      ? _pages[_selectedIndex]
                      : const Center(
                          child: Text('Page not found')),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final String   label;
  const _NavItem({required this.icon, required this.label});
}