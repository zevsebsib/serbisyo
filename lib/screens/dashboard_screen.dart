import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int selectedFeatureCard = 0;

  final List<Map<String, String>> recentRequests = const [
    {
      'id': '#0001234',
      'title': 'Business Permit',
      'priority': 'HIGH',
      'status': 'PROCESSING',
    },
    {
      'id': '#0001235',
      'title': 'Barangay Clearance',
      'priority': 'MEDIUM',
      'status': 'PENDING',
    },
    {
      'id': '#0001236',
      'title': 'Health Certificate',
      'priority': 'LOW',
      'status': 'COMPLETED',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildHeader(context),
            _buildContentArea(context),
          ],
        ),
      ),
      bottomNavigationBar: _buildDashboardBottomNav(),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      height: 245,
      width: double.infinity,
      decoration: BoxDecoration(color: AppColors.muted.withOpacity(0.35)),
      child: Stack(
        children: [
          Positioned(
            left: 22,
            right: 22,
            bottom: 28,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'SerbisyoAlisto',
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 46,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'HELLO, USER_NAME!',
                      style: GoogleFonts.inter(
                        color: Colors.white.withOpacity(0.8),
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.4,
                      ),
                    ),
                  ],
                ),
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.12),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withOpacity(0.18),
                      width: 1,
                    ),
                  ),
                  child: const Icon(
                    LucideIcons.bell,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContentArea(BuildContext context) {
    return Transform.translate(
      offset: const Offset(0, -22),
      child: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(34),
            topRight: Radius.circular(34),
          ),
        ),
        padding: const EdgeInsets.fromLTRB(18, 22, 18, 122),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildActivitySection(),
            const SizedBox(height: 18),
            _buildSubmitRequestCard(),
            const SizedBox(height: 16),
            _buildFeatureDots(),
            const SizedBox(height: 16),
            _buildFeatureCards(),
            const SizedBox(height: 24),
            _buildRecentHeader(),
            const SizedBox(height: 12),
            ...recentRequests.map(_buildRecentRequestCard),
          ],
        ),
      ),
    );
  }

  Widget _buildActivitySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Activity Dashboard',
          style: AppTextStyles.h2.copyWith(color: AppColors.primary),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: _buildActivityItem(
                icon: LucideIcons.clock3,
                label: 'PENDING',
                count: '0',
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildActivityItem(
                icon: LucideIcons.moreHorizontal,
                label: 'PROCESSING',
                count: '0',
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildActivityItem(
                icon: LucideIcons.checkCircle2,
                label: 'COMPLETED',
                count: '0',
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActivityItem({
    required IconData icon,
    required String label,
    required String count,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(36),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      child: Column(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.35),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Icon(icon, color: Colors.white, size: 24),
          ),
          const SizedBox(height: 12),
          Text(
            count,
            style: GoogleFonts.inter(
              color: Colors.black,
              fontSize: 40,
              fontWeight: FontWeight.w900,
              height: 1,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            textAlign: TextAlign.center,
            style: AppTextStyles.small.copyWith(
              fontSize: 9,
              letterSpacing: 2.0,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubmitRequestCard() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(46),
      ),
      padding: const EdgeInsets.fromLTRB(24, 22, 20, 20),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Submit Request',
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'File service request digitally\nwithout visiting the City Hall.',
                  style: AppTextStyles.body.copyWith(
                    color: Colors.white.withOpacity(0.9),
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 14),
                GestureDetector(
                  onTap: () => Navigator.pushNamed(context, '/services/form'),
                  child: Container(
                    width: 128,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      'REQUEST',
                      style: GoogleFonts.inter(
                        color: AppColors.primary,
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Container(
            width: 128,
            height: 128,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primaryDark.withOpacity(0.3),
            ),
            child: Center(
              child: Container(
                width: 64,
                height: 64,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  LucideIcons.clipboardList,
                  color: AppColors.primary,
                  size: 30,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureDots() {
    return Center(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(4, (index) {
          final bool active = index == selectedFeatureCard;
          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 4),
            width: active ? 26 : 8,
            height: 8,
            decoration: BoxDecoration(
              color: active
                  ? AppColors.primary
                  : AppColors.muted.withOpacity(0.35),
              borderRadius: BorderRadius.circular(999),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildFeatureCards() {
    final cards = [
      ('Track Status', 'Monitor your request in real time.'),
      ('Get Updates', 'Receive status updates as request progresses.'),
    ];

    return SizedBox(
      height: 145,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: cards.length,
        separatorBuilder: (_, __) => const SizedBox(width: 14),
        itemBuilder: (context, index) {
          return Container(
            width: 300,
            padding: const EdgeInsets.fromLTRB(22, 20, 18, 18),
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(40),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        cards[index].$1,
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 34,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -1,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        cards[index].$2,
                        style: AppTextStyles.body.copyWith(
                          color: Colors.white.withOpacity(0.9),
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: AppColors.primaryDark.withOpacity(0.35),
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: CircleAvatar(
                      radius: 22,
                      backgroundColor: Colors.white,
                      child: Icon(
                        LucideIcons.bell,
                        color: AppColors.primary,
                        size: 22,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildRecentHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text('Recent Requests', style: AppTextStyles.h1.copyWith(fontSize: 36)),
        GestureDetector(
          onTap: () => Navigator.pushNamed(context, '/history'),
          child: Container(
            padding: const EdgeInsets.only(bottom: 3),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: AppColors.primary.withOpacity(0.35),
                  width: 2,
                ),
              ),
            ),
            child: Text(
              'SEE ALL',
              style: GoogleFonts.inter(
                color: AppColors.primary,
                fontSize: 13,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.4,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRecentRequestCard(Map<String, String> item) {
    final status = item['status']!;

    Color statusBg;
    Color statusText;
    switch (status) {
      case 'PENDING':
        statusBg = AppColors.primary.withOpacity(0.2);
        statusText = AppColors.primary;
        break;
      case 'COMPLETED':
        statusBg = AppColors.success.withOpacity(0.22);
        statusText = AppColors.success;
        break;
      default:
        statusBg = AppColors.secondary.withOpacity(0.12);
        statusText = AppColors.secondary;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: AppColors.secondary.withOpacity(0.08)),
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.secondary.withOpacity(0.08)),
            ),
            child: const Icon(
              LucideIcons.clipboard,
              color: AppColors.primary,
              size: 26,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ID: ${item['id']!}',
                  style: AppTextStyles.small.copyWith(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.8,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  item['title']!,
                  style: AppTextStyles.h2.copyWith(
                    fontSize: 19,
                    color: AppColors.secondary.withOpacity(0.75),
                  ),
                ),
                const SizedBox(height: 4),
                RichText(
                  text: TextSpan(
                    style: AppTextStyles.small.copyWith(
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.5,
                    ),
                    children: [
                      const TextSpan(text: 'PRIORITY: '),
                      TextSpan(
                        text: item['priority']!,
                        style: TextStyle(
                          color: item['priority'] == 'HIGH'
                              ? AppColors.danger
                              : item['priority'] == 'MEDIUM'
                                  ? AppColors.primary
                                  : AppColors.success,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: statusBg,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              status,
              style: GoogleFonts.inter(
                color: statusText,
                fontSize: 10,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDashboardBottomNav() {
    return SizedBox(
      height: 96,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 0),
              decoration: const BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(36),
                  topRight: Radius.circular(36),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  const SizedBox(width: 62),
                  _buildNavItem(
                    icon: LucideIcons.clipboardList,
                    label: 'REQUEST',
                    onTap: () => Navigator.pushReplacementNamed(context, '/requests/track'),
                  ),
                  _buildNavItem(
                    icon: LucideIcons.bell,
                    label: 'NOTIFICATION',
                    onTap: () => Navigator.pushReplacementNamed(context, '/notifications'),
                  ),
                  _buildNavItem(
                    icon: LucideIcons.user,
                    label: 'PROFILE',
                    onTap: () => Navigator.pushReplacementNamed(context, '/profile'),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            left: 20,
            top: -18,
            child: GestureDetector(
              onTap: () => Navigator.pushReplacementNamed(context, '/'),
              child: Container(
                width: 68,
                height: 68,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: Center(
                  child: Container(
                    width: 58,
                    height: 58,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.primary,
                    ),
                    child: const Icon(
                      LucideIcons.house,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white.withOpacity(0.65), size: 22),
            const SizedBox(height: 5),
            Text(
              label,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                color: Colors.white.withOpacity(0.6),
                fontSize: 10,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
