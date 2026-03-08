import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';

class AdminReportsScreen extends StatefulWidget {
  const AdminReportsScreen({super.key});

  @override
  State<AdminReportsScreen> createState() =>
      _AdminReportsScreenState();
}

class _AdminReportsScreenState
    extends State<AdminReportsScreen> {
  bool _loading = true;

  // Date range
  DateTimeRange _dateRange = DateTimeRange(
    start: DateTime.now().subtract(const Duration(days: 30)),
    end:   DateTime.now(),
  );
  String _selectedPreset = '30d';

  // Raw data
  List<Map<String, dynamic>> _requests  = [];
  List<Map<String, dynamic>> _staffList = [];

  // Processed chart data
  List<Map<String, dynamic>> _timeSeriesData   = [];
  Map<String, int>            _statusData       = {};
  Map<String, int>            _departmentData   = {};
  Map<String, int>            _serviceTypeData  = {};
  List<Map<String, dynamic>>  _staffPerformance = [];

  // Granularity
  String _granularity = 'daily';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  // ── Data loading ───────────────────────────────────────────────────────────
  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final startTs = Timestamp.fromDate(_dateRange.start);
      final endTs   = Timestamp.fromDate(
          _dateRange.end.add(const Duration(days: 1)));

      final reqSnap = await FirebaseFirestore.instance
          .collection('requests')
          .where('createdAt', isGreaterThanOrEqualTo: startTs)
          .where('createdAt', isLessThan: endTs)
          .get();

      _requests = reqSnap.docs.map((d) {
        final data = d.data();
        return {
          'id':          d.id,
          'status':      data['status'] ?? 'pending',
          'department':  data['department'] ?? 'Unknown',
          'serviceName': data['serviceName'] ?? 'Unknown',
          'assignedTo':  data['assignedTo'] ?? '',
          'createdAt':   data['createdAt'],
        };
      }).toList();

      // Load staff
      final staffSnap = await FirebaseFirestore.instance
          .collection('admin')
          .where('role', isEqualTo: 'admin')
          .get();
      _staffList = staffSnap.docs.map((d) => {
        'uid':      d.id,
        'fullName': d.data()['fullName'] ?? 'Staff',
      }).toList();

      _processData();
    } catch (e) {
      debugPrint('Reports error: $e');
    }
    if (mounted) setState(() => _loading = false);
  }

  void _processData() {
    // ── Time series ──
    final Map<String, int> timeMap = {};
    final diff = _dateRange.end.difference(_dateRange.start).inDays;

    if (_granularity == 'daily' || diff <= 31) {
      // Fill all days in range
      for (int i = 0; i <= diff; i++) {
        final d = _dateRange.start.add(Duration(days: i));
        final key = '${d.month}/${d.day}';
        timeMap[key] = 0;
      }
      for (final r in _requests) {
        final ts = r['createdAt'] as Timestamp?;
        if (ts == null) continue;
        final d   = ts.toDate();
        final key = '${d.month}/${d.day}';
        timeMap[key] = (timeMap[key] ?? 0) + 1;
      }
    } else if (_granularity == 'weekly') {
      for (final r in _requests) {
        final ts = r['createdAt'] as Timestamp?;
        if (ts == null) continue;
        final d    = ts.toDate();
        final week = _weekLabel(d);
        timeMap[week] = (timeMap[week] ?? 0) + 1;
      }
    } else {
      for (final r in _requests) {
        final ts = r['createdAt'] as Timestamp?;
        if (ts == null) continue;
        final d   = ts.toDate();
        final key = _monthLabel(d);
        timeMap[key] = (timeMap[key] ?? 0) + 1;
      }
    }

    _timeSeriesData = timeMap.entries
        .map((e) => {'label': e.key, 'value': e.value})
        .toList();

    // ── Status breakdown ──
    _statusData = {};
    for (final r in _requests) {
      final s = r['status'] as String;
      _statusData[s] = (_statusData[s] ?? 0) + 1;
    }

    // ── By department ──
    _departmentData = {};
    for (final r in _requests) {
      final dept = r['department'] as String;
      if (dept.isEmpty || dept == 'Unknown') continue;
      _departmentData[dept] =
          (_departmentData[dept] ?? 0) + 1;
    }

    // ── By service type ──
    final serviceCount = <String, int>{};
    for (final r in _requests) {
      final svc = r['serviceName'] as String;
      serviceCount[svc] = (serviceCount[svc] ?? 0) + 1;
    }
    // Top 6
    final sorted = serviceCount.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    _serviceTypeData = Map.fromEntries(sorted.take(6));

    // ── Staff performance ──
    final Map<String, int> staffCompleted = {};
    final Map<String, int> staffTotal     = {};
    for (final r in _requests) {
      final uid = r['assignedTo'] as String;
      if (uid.isEmpty) continue;
      staffTotal[uid] = (staffTotal[uid] ?? 0) + 1;
      if (r['status'] == 'completed') {
        staffCompleted[uid] =
            (staffCompleted[uid] ?? 0) + 1;
      }
    }
    _staffPerformance = _staffList.map((s) {
      final uid   = s['uid'] as String;
      final total = staffTotal[uid] ?? 0;
      final done  = staffCompleted[uid] ?? 0;
      return {
        'name':      s['fullName'] as String,
        'total':     total,
        'completed': done,
        'rate':      total == 0 ? 0.0 : done / total,
      };
    }).where((s) => (s['total'] as int) > 0).toList()
      ..sort((a, b) =>
          (b['completed'] as int)
              .compareTo(a['completed'] as int));

    setState(() {});
  }

  // ── BUILD ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const SizedBox(height: 20),
          _buildFilterBar(),
          const SizedBox(height: 20),
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(
                        color: AppColors.primary))
                : _buildCharts(),
          ),
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
              Text('Reports & Analytics',
                  style: GoogleFonts.inter(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF111111),
                    letterSpacing: -0.5,
                  )),
              const SizedBox(height: 4),
              Text(
                '${_requests.length} requests in selected period',
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
      ],
    );
  }

  // ── Filter bar ─────────────────────────────────────────────────────────────
  Widget _buildFilterBar() {
    final presets = <Map<String, dynamic>>[
      {'label': '7D',   'key': '7d',   'days': 7},
      {'label': '30D',  'key': '30d',  'days': 30},
      {'label': '3M',   'key': '3m',   'days': 90},
      {'label': 'All',  'key': 'all',  'days': 365},
    ];

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
          // Preset buttons
          ...presets.map((p) {
            final sel = _selectedPreset == p['key'];
            return GestureDetector(
              onTap: () {
                final days = p['days'] as int;
                setState(() {
                  _selectedPreset = p['key'] as String;
                  _dateRange = DateTimeRange(
                    start: DateTime.now()
                        .subtract(Duration(days: days)),
                    end: DateTime.now(),
                  );
                });
                _loadData();
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: sel
                      ? AppColors.primary
                      : const Color(0xFFF7F8FC),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: sel
                        ? AppColors.primary
                        : const Color(0xFFEEEEEE),
                  ),
                ),
                child: Text(p['label'] as String,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: sel
                          ? Colors.white
                          : AppColors.muted,
                    )),
              ),
            );
          }),

          // Custom date range
          GestureDetector(
            onTap: _pickDateRange,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              margin: const EdgeInsets.only(right: 16),
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: _selectedPreset == 'custom'
                    ? AppColors.primary
                        .withValues(alpha: 0.08)
                    : const Color(0xFFF7F8FC),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _selectedPreset == 'custom'
                      ? AppColors.primary
                          .withValues(alpha: 0.40)
                      : const Color(0xFFEEEEEE),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.date_range_rounded,
                      size: 14,
                      color: _selectedPreset == 'custom'
                          ? AppColors.primary
                          : AppColors.muted),
                  const SizedBox(width: 6),
                  Text(
                    _selectedPreset == 'custom'
                        ? '${_fmtShort(_dateRange.start)} – ${_fmtShort(_dateRange.end)}'
                        : 'Custom Range',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _selectedPreset == 'custom'
                          ? AppColors.primary
                          : AppColors.muted,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const Spacer(),

          // Granularity
          Text('View by:',
              style: GoogleFonts.inter(
                  fontSize: 12, color: AppColors.muted)),
          const SizedBox(width: 10),
          ...['daily', 'weekly', 'monthly'].map((g) {
            final sel = _granularity == g;
            return GestureDetector(
              onTap: () {
                setState(() => _granularity = g);
                _processData();
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                margin: const EdgeInsets.only(left: 6),
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: sel
                      ? AppColors.primary
                      : const Color(0xFFF7F8FC),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: sel
                        ? AppColors.primary
                        : const Color(0xFFEEEEEE),
                  ),
                ),
                child: Text(
                  g[0].toUpperCase() + g.substring(1),
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: sel
                        ? Colors.white
                        : AppColors.muted,
                  ),
                ),
              ),
            );
          }),
        ],
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
      setState(() {
        _dateRange       = picked;
        _selectedPreset  = 'custom';
      });
      _loadData();
    }
  }

  // ── Charts layout ──────────────────────────────────────────────────────────
  Widget _buildCharts() {
    if (_requests.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.bar_chart_rounded,
                size: 56,
                color: AppColors.muted
                    .withValues(alpha: 0.25)),
            const SizedBox(height: 16),
            Text('No data for selected period',
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.muted,
                )),
            const SizedBox(height: 6),
            Text('Try selecting a wider date range',
                style: GoogleFonts.inter(
                    fontSize: 13, color: AppColors.muted)),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      child: Column(
        children: [
          // Row 1: Summary cards
          _buildSummaryCards(),
          const SizedBox(height: 20),

          // Row 2: Line chart + Donut chart
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 6,
                child: _buildLineChart(),
              ),
              const SizedBox(width: 20),
              Expanded(
                flex: 4,
                child: _buildDonutChart(),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Row 3: Department bar + Service type bar
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _buildDepartmentBar(),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: _buildServiceTypeBar(),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Row 4: Staff performance
          _buildStaffPerformance(),
          const SizedBox(height: 28),
        ],
      ),
    );
  }

  // ── Summary cards ──────────────────────────────────────────────────────────
  Widget _buildSummaryCards() {
    final total     = _requests.length;
    final completed = _statusData['completed'] ?? 0;
    final pending   = _statusData['pending'] ?? 0;
    final rate      = total == 0
        ? 0.0
        : (completed / total * 100);

    final cards = <Map<String, dynamic>>[
      {
        'label': 'Total Requests',
        'value': '$total',
        'icon':  Icons.assignment_rounded,
        'color': const Color(0xFF5C6BC0),
        'bg':    const Color(0xFFEDE7F6),
      },
      {
        'label': 'Completed',
        'value': '$completed',
        'icon':  Icons.check_circle_rounded,
        'color': const Color(0xFF10B981),
        'bg':    const Color(0xFFECFDF5),
      },
      {
        'label': 'Pending',
        'value': '$pending',
        'icon':  Icons.hourglass_empty_rounded,
        'color': const Color(0xFFF59E0B),
        'bg':    const Color(0xFFFFFBEB),
      },
      {
        'label': 'Completion Rate',
        'value': '${rate.toStringAsFixed(1)}%',
        'icon':  Icons.trending_up_rounded,
        'color': AppColors.primary,
        'bg':    const Color(0xFFFFF7ED),
      },
    ];

    return Row(
      children: cards.asMap().entries.map((entry) {
        final i      = entry.key;
        final c      = entry.value;
        final color  = c['color'] as Color;
        final isLast = i == cards.length - 1;
        return Expanded(
          child: Container(
            margin: EdgeInsets.only(right: isLast ? 0 : 16),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color:
                      Colors.black.withValues(alpha: 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(
                    color: c['bg'] as Color,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(c['icon'] as IconData,
                      color: color, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Text(c['value'] as String,
                          style: GoogleFonts.inter(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: const Color(0xFF111111),
                            letterSpacing: -0.5,
                          )),
                      Text(c['label'] as String,
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

  // ── Line chart ─────────────────────────────────────────────────────────────
  Widget _buildLineChart() {
    if (_timeSeriesData.isEmpty) {
      return _chartCard('Requests Over Time', 280,
          child: _emptyChart());
    }

    final spots = _timeSeriesData.asMap().entries.map((e) {
      return FlSpot(
          e.key.toDouble(),
          (e.value['value'] as int).toDouble());
    }).toList();

    final maxY = spots.isEmpty
        ? 5.0
        : spots.map((s) => s.y).reduce(
                (a, b) => a > b ? a : b) +
            2;

    return _chartCard('Requests Over Time', 280,
        child: LineChart(
          LineChartData(
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              horizontalInterval: (maxY / 4).ceilToDouble(),
              getDrawingHorizontalLine: (_) => FlLine(
                color: const Color(0xFFF0F0F0),
                strokeWidth: 1,
              ),
            ),
            titlesData: FlTitlesData(
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 32,
                  interval: (maxY / 4).ceilToDouble(),
                  getTitlesWidget: (v, _) => Text(
                    v.toInt().toString(),
                    style: GoogleFonts.inter(
                        fontSize: 10,
                        color: AppColors.muted),
                  ),
                ),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 28,
                  interval: (_timeSeriesData.length / 6)
                      .ceilToDouble()
                      .clamp(1, 999),
                  getTitlesWidget: (v, _) {
                    final i = v.toInt();
                    if (i < 0 ||
                        i >= _timeSeriesData.length) {
                      return const SizedBox.shrink();
                    }
                    return Padding(
                      padding:
                          const EdgeInsets.only(top: 4),
                      child: Text(
                        _timeSeriesData[i]['label']
                            as String,
                        style: GoogleFonts.inter(
                            fontSize: 9,
                            color: AppColors.muted),
                      ),
                    );
                  },
                ),
              ),
              rightTitles: const AxisTitles(
                  sideTitles:
                      SideTitles(showTitles: false)),
              topTitles: const AxisTitles(
                  sideTitles:
                      SideTitles(showTitles: false)),
            ),
            borderData: FlBorderData(show: false),
            minX: 0,
            maxX: (_timeSeriesData.length - 1).toDouble(),
            minY: 0,
            maxY: maxY,
            lineBarsData: [
              LineChartBarData(
                spots: spots,
                isCurved: true,
                color: AppColors.primary,
                barWidth: 2.5,
                isStrokeCapRound: true,
                dotData: FlDotData(
                  show: true,
                  getDotPainter: (_, __, ___, ____) =>
                      FlDotCirclePainter(
                    radius: 3,
                    color: AppColors.primary,
                    strokeWidth: 1.5,
                    strokeColor: Colors.white,
                  ),
                ),
                belowBarData: BarAreaData(
                  show: true,
                  color: AppColors.primary
                      .withValues(alpha: 0.08),
                ),
              ),
            ],
          ),
        ));
  }

  // ── Donut chart ────────────────────────────────────────────────────────────
  Widget _buildDonutChart() {
    if (_statusData.isEmpty) {
      return _chartCard('Requests by Status', 280,
          child: _emptyChart());
    }

    final statusColors = <String, Color>{
      'pending':     const Color(0xFFF59E0B),
      'in_progress': const Color(0xFF3B82F6),
      'completed':   const Color(0xFF10B981),
      'rejected':    const Color(0xFFEF4444),
    };
    final statusLabels = <String, String>{
      'pending':     'Pending',
      'in_progress': 'In Progress',
      'completed':   'Completed',
      'rejected':    'Rejected',
    };

    final sections = _statusData.entries.map((e) {
      final color =
          statusColors[e.key] ?? const Color(0xFF9CA3AF);
      return PieChartSectionData(
        value: e.value.toDouble(),
        color: color,
        title: '${e.value}',
        radius: 60,
        titleStyle: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      );
    }).toList();

    return _chartCard('Requests by Status', 280,
        child: Row(
          children: [
            Expanded(
              child: PieChart(
                PieChartData(
                  sections: sections,
                  centerSpaceRadius: 50,
                  sectionsSpace: 2,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: _statusData.entries.map((e) {
                final color = statusColors[e.key] ??
                    const Color(0xFF9CA3AF);
                final label = statusLabels[e.key] ?? e.key;
                final total = _requests.length;
                final pct = total == 0
                    ? 0
                    : (e.value / total * 100).round();
                return Padding(
                  padding:
                      const EdgeInsets.only(bottom: 10),
                  child: Row(
                    children: [
                      Container(
                        width: 10, height: 10,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          Text(label,
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: const Color(
                                    0xFF333333),
                              )),
                          Text('$pct%',
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                color: AppColors.muted,
                              )),
                        ],
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],
        ));
  }

  // ── Department bar chart ───────────────────────────────────────────────────
  Widget _buildDepartmentBar() {
    if (_departmentData.isEmpty) {
      return _chartCard('Requests by Department', 260,
          child: _emptyChart());
    }

    final entries = _departmentData.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final top     = entries.take(6).toList();
    final maxVal  = top.isEmpty
        ? 1
        : top.map((e) => e.value).reduce(
                (a, b) => a > b ? a : b);

    final groups = top.asMap().entries.map((entry) {
      return BarChartGroupData(
        x: entry.key,
        barRods: [
          BarChartRodData(
            toY: entry.value.value.toDouble(),
            color: AppColors.primary,
            width: 22,
            borderRadius: const BorderRadius.only(
              topLeft:  Radius.circular(4),
              topRight: Radius.circular(4),
            ),
          ),
        ],
      );
    }).toList();

    return _chartCard('Requests by Department', 260,
        child: BarChart(
          BarChartData(
            alignment: BarChartAlignment.spaceAround,
            maxY: maxVal.toDouble() + 2,
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              horizontalInterval:
                  (maxVal / 4).ceilToDouble(),
              getDrawingHorizontalLine: (_) => FlLine(
                color: const Color(0xFFF0F0F0),
                strokeWidth: 1,
              ),
            ),
            titlesData: FlTitlesData(
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 30,
                  interval: (maxVal / 4).ceilToDouble(),
                  getTitlesWidget: (v, _) => Text(
                    v.toInt().toString(),
                    style: GoogleFonts.inter(
                        fontSize: 10,
                        color: AppColors.muted),
                  ),
                ),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 36,
                  getTitlesWidget: (v, _) {
                    final i = v.toInt();
                    if (i < 0 || i >= top.length) {
                      return const SizedBox.shrink();
                    }
                    final name = top[i].key;
                    final short = name.length > 10
                        ? '${name.substring(0, 9)}…'
                        : name;
                    return Padding(
                      padding:
                          const EdgeInsets.only(top: 4),
                      child: Text(short,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(
                              fontSize: 9,
                              color: AppColors.muted)),
                    );
                  },
                ),
              ),
              rightTitles: const AxisTitles(
                  sideTitles:
                      SideTitles(showTitles: false)),
              topTitles: const AxisTitles(
                  sideTitles:
                      SideTitles(showTitles: false)),
            ),
            borderData: FlBorderData(show: false),
            barGroups: groups,
            barTouchData: BarTouchData(
              touchTooltipData: BarTouchTooltipData(
                getTooltipItem: (group, _, rod, __) =>
                    BarTooltipItem(
                  '${top[group.x].key}\n${rod.toY.toInt()}',
                  GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ));
  }

  // ── Service type bar chart ─────────────────────────────────────────────────
  Widget _buildServiceTypeBar() {
    if (_serviceTypeData.isEmpty) {
      return _chartCard('Top Services', 260,
          child: _emptyChart());
    }

    final entries = _serviceTypeData.entries.toList();
    final colors  = [
      const Color(0xFF5C6BC0),
      const Color(0xFF3B82F6),
      AppColors.primary,
      const Color(0xFF10B981),
      const Color(0xFF8B5CF6),
      const Color(0xFFF59E0B),
    ];
    final maxVal = entries.isEmpty
        ? 1
        : entries
            .map((e) => e.value)
            .reduce((a, b) => a > b ? a : b);

    final groups = entries.asMap().entries.map((entry) {
      return BarChartGroupData(
        x: entry.key,
        barRods: [
          BarChartRodData(
            toY: entry.value.value.toDouble(),
            color: colors[entry.key % colors.length],
            width: 22,
            borderRadius: const BorderRadius.only(
              topLeft:  Radius.circular(4),
              topRight: Radius.circular(4),
            ),
          ),
        ],
      );
    }).toList();

    return _chartCard('Top Services', 260,
        child: BarChart(
          BarChartData(
            alignment: BarChartAlignment.spaceAround,
            maxY: maxVal.toDouble() + 2,
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              horizontalInterval:
                  (maxVal / 4).ceilToDouble(),
              getDrawingHorizontalLine: (_) => FlLine(
                color: const Color(0xFFF0F0F0),
                strokeWidth: 1,
              ),
            ),
            titlesData: FlTitlesData(
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 30,
                  interval: (maxVal / 4).ceilToDouble(),
                  getTitlesWidget: (v, _) => Text(
                    v.toInt().toString(),
                    style: GoogleFonts.inter(
                        fontSize: 10,
                        color: AppColors.muted),
                  ),
                ),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 36,
                  getTitlesWidget: (v, _) {
                    final i = v.toInt();
                    if (i < 0 || i >= entries.length) {
                      return const SizedBox.shrink();
                    }
                    final name = entries[i].key;
                    final short = name.length > 10
                        ? '${name.substring(0, 9)}…'
                        : name;
                    return Padding(
                      padding:
                          const EdgeInsets.only(top: 4),
                      child: Text(short,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(
                              fontSize: 9,
                              color: AppColors.muted)),
                    );
                  },
                ),
              ),
              rightTitles: const AxisTitles(
                  sideTitles:
                      SideTitles(showTitles: false)),
              topTitles: const AxisTitles(
                  sideTitles:
                      SideTitles(showTitles: false)),
            ),
            borderData: FlBorderData(show: false),
            barGroups: groups,
            barTouchData: BarTouchData(
              touchTooltipData: BarTouchTooltipData(
                getTooltipItem: (group, _, rod, __) =>
                    BarTooltipItem(
                  '${entries[group.x].key}\n${rod.toY.toInt()}',
                  GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ));
  }

  // ── Staff performance ──────────────────────────────────────────────────────
  Widget _buildStaffPerformance() {
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
          Text('Staff Performance',
              style: GoogleFonts.inter(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF111111),
              )),
          const SizedBox(height: 4),
          Text('Requests assigned vs completed per staff',
              style: GoogleFonts.inter(
                  fontSize: 12, color: AppColors.muted)),
          const SizedBox(height: 20),
          if (_staffPerformance.isEmpty)
            Center(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(vertical: 24),
                child: Text('No staff data available',
                    style: GoogleFonts.inter(
                        fontSize: 13,
                        color: AppColors.muted)),
              ),
            )
          else
            ...(_staffPerformance.take(8).toList())
                .map((s) => _staffRow(s)),
        ],
      ),
    );
  }

  Widget _staffRow(Map<String, dynamic> s) {
    final total     = s['total'] as int;
    final completed = s['completed'] as int;
    final rate      = s['rate'] as double;
    final name      = s['name'] as String;
    final initials  = _initials(name);

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color:
                  AppColors.primary.withValues(alpha: 0.10),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(initials,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  )),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 3,
            child: Text(name,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF222222),
                )),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 5,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment:
                      MainAxisAlignment.spaceBetween,
                  children: [
                    Text('$completed / $total completed',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: AppColors.muted,
                        )),
                    Text(
                      '${(rate * 100).toStringAsFixed(0)}%',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: rate >= 0.7
                            ? const Color(0xFF10B981)
                            : rate >= 0.4
                                ? const Color(0xFFF59E0B)
                                : const Color(0xFFEF4444),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: rate.clamp(0.0, 1.0),
                    backgroundColor:
                        const Color(0xFFF0F0F0),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      rate >= 0.7
                          ? const Color(0xFF10B981)
                          : rate >= 0.4
                              ? const Color(0xFFF59E0B)
                              : const Color(0xFFEF4444),
                    ),
                    minHeight: 6,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Shared chart card wrapper ──────────────────────────────────────────────
  Widget _chartCard(String title, double height,
      {required Widget child}) {
    return Container(
      height: height,
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
          Text(title,
              style: GoogleFonts.inter(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF111111),
              )),
          const SizedBox(height: 16),
          Expanded(child: child),
        ],
      ),
    );
  }

  Widget _emptyChart() {
    return Center(
      child: Text('No data available',
          style: GoogleFonts.inter(
              fontSize: 12, color: AppColors.muted)),
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────────
  String _weekLabel(DateTime d) {
    final monday =
        d.subtract(Duration(days: d.weekday - 1));
    return 'W${monday.month}/${monday.day}';
  }

  String _monthLabel(DateTime d) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[d.month - 1]} ${d.year}';
  }

  String _fmtShort(DateTime d) =>
      '${d.month}/${d.day}/${d.year}';

  String _initials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }
}