import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';

class _FeatureCard {
  final IconData icon;
  final String title;
  final String desc;
  _FeatureCard(this.icon, this.title, this.desc);
}

class _NavItem {
  final IconData icon;
  final String label;
  final String route;
  _NavItem(this.icon, this.label, this.route);
}

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _selectedNavIndex = 0;

  final PageController _featurePageController = PageController();
  int _currentFeaturePage = 0;

  int _pendingCount    = 0;
  int _processingCount = 0;
  int _doneCount       = 0;
  List<Map<String, dynamic>> _recentRequests = [];
  bool _loadingRequests = true;

  String get _displayName {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return 'there';
    final name      = user.displayName ?? user.email ?? '';
    final firstName = name.split(' ').first.split('@').first;
    return firstName.isNotEmpty ? firstName : 'there';
  }

  final List<_FeatureCard> _features = [
    _FeatureCard(
      LucideIcons.searchCheck,
      'Track Status',
      'Monitor your request in real time as it moves through the process.',
    ),
    _FeatureCard(
      LucideIcons.bellRing,
      'Get Updates',
      'Receive status updates as your request progresses.',
    ),
    _FeatureCard(
      LucideIcons.history,
      'View History',
      'Access your complete request history anytime.',
    ),
  ];

  final List<_NavItem> _navItems = [
    _NavItem(LucideIcons.home,          'Home',     '/'),
    _NavItem(LucideIcons.clipboardList, 'Requests', '/requests/track'),
    _NavItem(LucideIcons.bell,          'Alerts',   '/notifications'),
    _NavItem(LucideIcons.user,          'Profile',  '/profile'),
  ];

  @override
  void initState() {
    super.initState();
    _listenToRequests();
  }

  void _listenToRequests() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      setState(() => _loadingRequests = false);
      return;
    }

    FirebaseFirestore.instance
        .collection('requests')
        .where('userId', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .listen((snapshot) {
      final docs = snapshot.docs;
      int pending = 0, processing = 0, done = 0;

      for (final doc in docs) {
        final status =
            (doc['status'] ?? '').toString().toLowerCase();
        if (status == 'pending') {
          pending++;
        } else if (status == 'processing') {
          processing++;
        } else if (status == 'completed') {
          done++;
        }
      }

      if (mounted) {
        setState(() {
          _pendingCount    = pending;
          _processingCount = processing;
          _doneCount       = done;
          _recentRequests  = docs
              .take(3)
              .map((d) => {'id': d.id, ...d.data()})
              .toList();
          _loadingRequests = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _featurePageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      backgroundColor: AppColors.background,
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildHeader(context),
            _buildContent(context),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  // ── Header ─────────────────────────────────────────────────────────────────
  Widget _buildHeader(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration:
          const BoxDecoration(gradient: AppColors.headerGradient),
      child: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            Positioned(
              top: -40,
              right: -40,
              child: Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.07),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 20, 22, 32),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Hello, $_displayName 👋',
                          style: GoogleFonts.inter(
                            color:
                                Colors.white.withValues(alpha: 0.90),
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'SerbisyoAlisto',
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontSize: 36,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _buildNotificationBell(context),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationBell(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const SizedBox.shrink();

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('notifications')
          .doc(uid)
          .collection('items')
          .where('isRead', isEqualTo: false)
          .snapshots(),
      builder: (context, snapshot) {
        final unread = snapshot.data?.docs.length ?? 0;

        return GestureDetector(
          onTap: () =>
              Navigator.pushNamed(context, '/notifications'),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.20),
                    width: 1,
                  ),
                ),
                child: const Icon(LucideIcons.bell,
                    color: Colors.white, size: 22),
              ),
              if (unread > 0)
                Positioned(
                  right: -2,
                  top: -2,
                  child: Container(
                    width: 20,
                    height: 20,
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        unread > 9 ? '9+' : '$unread',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  // ── Content ────────────────────────────────────────────────────────────────
  Widget _buildContent(BuildContext context) {
    return Transform.translate(
      offset: const Offset(0, -24),
      child: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.only(
            topLeft:  Radius.circular(28),
            topRight: Radius.circular(28),
          ),
        ),
        padding: const EdgeInsets.fromLTRB(18, 24, 18, 120),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildActivitySection(),
            const SizedBox(height: 20),
            _buildSubmitRequestCard(context),
            const SizedBox(height: 20),
            _buildFeatureSection(),
            const SizedBox(height: 24),
            _buildRecentRequestsSection(),
          ],
        ),
      ),
    );
  }

  // ── Activity Stats ─────────────────────────────────────────────────────────
  Widget _buildActivitySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('My Activity', style: AppTextStyles.h2),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                icon:      LucideIcons.clock3,
                label:     'Pending',
                count:     '$_pendingCount',
                iconColor: AppColors.warning,
                bgColor:   AppColors.warningLight,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildStatCard(
                icon:      LucideIcons.loader,
                label:     'Processing',
                count:     '$_processingCount',
                iconColor: AppColors.primary,
                bgColor:   AppColors.cardBg,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildStatCard(
                icon:      LucideIcons.checkCircle2,
                label:     'Done',
                count:     '$_doneCount',
                iconColor: AppColors.success,
                bgColor:   AppColors.successLight,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String label,
    required String count,
    required Color iconColor,
    required Color bgColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: 12, vertical: 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(height: 12),
          _loadingRequests
              ? Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: AppColors.muted
                        .withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                )
              : Text(
                  count,
                  style: GoogleFonts.inter(
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    color: AppColors.secondary,
                    height: 1,
                  ),
                ),
          const SizedBox(height: 6),
          Text(
            label,
            style: AppTextStyles.caption.copyWith(
              color: AppColors.muted,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    );
  }

  // ── Submit Request Card ────────────────────────────────────────────────────
  Widget _buildSubmitRequestCard(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        boxShadow: AppShadows.primary,
      ),
      padding: const EdgeInsets.fromLTRB(22, 22, 18, 22),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Submit a Request',
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'File service requests digitally\nwithout visiting City Hall.',
                  style: GoogleFonts.inter(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 16),
                GestureDetector(
                  onTap: () =>
                      Navigator.pushNamed(context, '/services'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 11),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius:
                          BorderRadius.circular(AppRadius.pill),
                    ),
                    child: Text(
                      'Request now',
                      style: GoogleFonts.inter(
                        color: AppColors.primary,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Container(
                width: 54,
                height: 54,
                decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle),
                child: const Icon(LucideIcons.clipboardList,
                    color: AppColors.primary, size: 28),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Feature Cards ──────────────────────────────────────────────────────────
  Widget _buildFeatureSection() {
    return Column(
      children: [
        SizedBox(
          height: 140,
          child: PageView.builder(
            controller: _featurePageController,
            itemCount: _features.length,
            onPageChanged: (i) =>
                setState(() => _currentFeaturePage = i),
            itemBuilder: (context, index) {
              final feature = _features[index];
              return Container(
                margin:
                    const EdgeInsets.symmetric(horizontal: 2),
                padding:
                    const EdgeInsets.fromLTRB(22, 20, 18, 20),
                decoration: BoxDecoration(
                  color: AppColors.secondary,
                  borderRadius:
                      BorderRadius.circular(AppRadius.xl),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        mainAxisAlignment:
                            MainAxisAlignment.center,
                        children: [
                          Text(
                            feature.title,
                            style: GoogleFonts.inter(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.8,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            feature.desc,
                            style: GoogleFonts.inter(
                              color: Colors.white
                                  .withValues(alpha: 0.70),
                              fontSize: 12,
                              fontWeight: FontWeight.w400,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: Colors.white
                            .withValues(alpha: 0.10),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(feature.icon,
                          color: Colors.white, size: 26),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(_features.length, (i) {
            final active = i == _currentFeaturePage;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOut,
              margin:
                  const EdgeInsets.symmetric(horizontal: 4),
              width:  active ? 24 : 7,
              height: 7,
              decoration: BoxDecoration(
                color: active
                    ? AppColors.primary
                    : AppColors.muted.withValues(alpha: 0.30),
                borderRadius:
                    BorderRadius.circular(AppRadius.pill),
              ),
            );
          }),
        ),
      ],
    );
  }

  // ── Recent Requests ────────────────────────────────────────────────────────
  Widget _buildRecentRequestsSection() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Recent Requests', style: AppTextStyles.h2),
            TextButton(
              onPressed: () => Navigator.pushNamed(
                  context, '/profile_history'),
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: Size.zero,
                tapTargetSize:
                    MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                'See all',
                style: AppTextStyles.small.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_loadingRequests)
          const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: CircularProgressIndicator(),
            ),
          )
        else if (_recentRequests.isEmpty)
          _buildEmptyState()
        else
          ..._recentRequests.map((item) {
            // ── pass rawId for navigation ──────────────────────
            final rawId  = item['id']?.toString() ?? '';
            final shortId =
                '#${rawId.length > 7 ? rawId.substring(0, 7).toUpperCase() : rawId.toUpperCase()}';
            return _buildRequestCard({
              'rawId':    rawId,
              'id':       shortId,
              'title':    item['serviceName']?.toString() ?? 'Request',
              'priority': item['priority']?.toString() ?? 'MEDIUM',
              'status':   (item['status']?.toString() ?? 'pending')
                  .toUpperCase(),
            });
          }),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 40),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Column(
        children: [
          Icon(LucideIcons.clipboardX,
              size: 40,
              color: AppColors.muted.withValues(alpha: 0.5)),
          const SizedBox(height: 12),
          Text('No requests yet', style: AppTextStyles.body),
          const SizedBox(height: 4),
          Text('Your submitted requests will appear here.',
              style: AppTextStyles.small),
        ],
      ),
    );
  }

  // ── Request Card — tappable, navigates to tracking screen ─────────────────
  Widget _buildRequestCard(Map<String, String> item) {
    final status   = item['status']!;
    final priority = item['priority']!;
    final rawId    = item['rawId'] ?? '';

    Color statusBg;
    Color statusFg;
    switch (status) {
      case 'PENDING':
        statusBg = AppColors.warningLight;
        statusFg = AppColors.warning;
        break;
      case 'COMPLETED':
        statusBg = AppColors.successLight;
        statusFg = AppColors.success;
        break;
      default:
        statusBg = AppColors.cardBg;
        statusFg = AppColors.primary;
    }

    Color priorityColor;
    switch (priority) {
      case 'HIGH':   priorityColor = AppColors.danger;  break;
      case 'MEDIUM': priorityColor = AppColors.primary; break;
      default:       priorityColor = AppColors.success;
    }

    return GestureDetector(
      onTap: () {
        if (rawId.isNotEmpty) {
          Navigator.pushNamed(
            context,
            '/requests/track',
            arguments: {'requestId': rawId},
          );
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          boxShadow: AppShadows.card,
        ),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: AppColors.cardBg,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(LucideIcons.clipboard,
                  color: AppColors.primary, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item['title']!,
                      style: AppTextStyles.h3
                          .copyWith(fontSize: 15)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(item['id']!,
                          style: AppTextStyles.caption
                              .copyWith(letterSpacing: 0.5)),
                      const SizedBox(width: 8),
                      Container(
                        width: 4,
                        height: 4,
                        decoration: BoxDecoration(
                          color: AppColors.muted
                              .withValues(alpha: 0.4),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        priority,
                        style: AppTextStyles.caption.copyWith(
                          color: priorityColor,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // ── Status chip + chevron arrow ────────────────────────
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: statusBg,
                    borderRadius:
                        BorderRadius.circular(AppRadius.pill),
                  ),
                  child: Text(
                    status,
                    style: GoogleFonts.inter(
                      color: statusFg,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Icon(
                  LucideIcons.chevronRight,
                  size: 14,
                  color: AppColors.muted.withValues(alpha: 0.5),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── Bottom Navigation ──────────────────────────────────────────────────────
  Widget _buildBottomNav() {
    return Container(
      height: 80,
      decoration: BoxDecoration(
        color: AppColors.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
        borderRadius: const BorderRadius.only(
          topLeft:  Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: List.generate(_navItems.length, (i) {
            final item     = _navItems[i];
            final isActive = _selectedNavIndex == i;

            return Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  setState(() => _selectedNavIndex = i);
                  if (i == 0) return;
                  Navigator.pushReplacementNamed(
                      context, item.route);
                },
                child: Column(
                  mainAxisAlignment:
                      MainAxisAlignment.center,
                  children: [
                    AnimatedContainer(
                      duration:
                          const Duration(milliseconds: 200),
                      width: 42,
                      height: 32,
                      decoration: BoxDecoration(
                        color: isActive
                            ? AppColors.primary
                                .withValues(alpha: 0.12)
                            : Colors.transparent,
                        borderRadius:
                            BorderRadius.circular(10),
                      ),
                      child: Icon(
                        item.icon,
                        size: 20,
                        color: isActive
                            ? AppColors.primary
                            : AppColors.muted,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.label,
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: isActive
                            ? FontWeight.w700
                            : FontWeight.w500,
                        color: isActive
                            ? AppColors.primary
                            : AppColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}