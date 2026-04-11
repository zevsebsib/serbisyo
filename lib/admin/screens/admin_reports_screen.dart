import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../theme/app_theme.dart';

class AdminReportsScreen extends StatefulWidget {
  const AdminReportsScreen({super.key});

  @override
  State<AdminReportsScreen> createState() => _AdminReportsScreenState();
}

class _AdminReportsScreenState extends State<AdminReportsScreen> {
  // ── Filters ─────────────────────────────────────────────────────
  String _preset      = '30D';
  String _granularity = 'Daily';
  DateTimeRange? _customRange;
  int _touchedPieIndex = -1;

  DateTime get _fromDate {
    if (_customRange != null) return _customRange!.start;
    final now = DateTime.now();
    switch (_preset) {
      case '7D':  return now.subtract(const Duration(days: 7));
      case '3M':  return now.subtract(const Duration(days: 90));
      case 'All': return DateTime(2020);
      default:    return now.subtract(const Duration(days: 30));
    }
  }

  // ── Data ────────────────────────────────────────────────────────
  bool   _loading     = true;
  int    _total       = 0;
  int    _completed   = 0;
  int    _pending     = 0;
  int    _processing  = 0;
  int    _rejected    = 0;

  List<Map<String, dynamic>> _timeSeries  = [];
  List<Map<String, dynamic>> _topServices = [];
  List<Map<String, dynamic>> _staffPerf   = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final from = Timestamp.fromDate(_fromDate);
      final snap = await FirebaseFirestore.instance
          .collection('requests')
          .where('createdAt', isGreaterThanOrEqualTo: from)
          .get();

      final docs = snap.docs;
      int total = docs.length, completed = 0, pending = 0,
          processing = 0, rejected = 0;

      final Map<String, int>              buckets      = {};
      final Map<String, int>              serviceCount = {};
      final Map<String, Map<String, int>> staffMap     = {};

      for (final doc in docs) {
        final data   = doc.data();
        final status = (data['status'] ?? '').toString().toLowerCase();

        if (status == 'completed')  completed++;
        if (status == 'submitted' ||
            status == 'pending' ||
            status == 'pending_review') {
          pending++;
        }
        if (status == 'processing' ||
            status == 'in_progress' ||
            status == 'approved' ||
            status == 'ready' ||
            status == 'ready_for_pickup') {
          processing++;
        }
        if (status == 'rejected' || status == 'returned') {
          rejected++;
        }

        final ts = data['createdAt'];
        if (ts is Timestamp) {
          final key = _bucketKey(ts.toDate());
          buckets[key] = (buckets[key] ?? 0) + 1;
        }

        final svc = (data['serviceName'] ?? 'Unknown').toString();
        serviceCount[svc] = (serviceCount[svc] ?? 0) + 1;

        final staff = (data['assignedTo'] ?? '').toString();
        if (staff.isNotEmpty) {
          staffMap[staff] ??= {'total': 0, 'completed': 0};
          staffMap[staff]!['total']     = staffMap[staff]!['total']!     + 1;
          if (status == 'completed') {
            staffMap[staff]!['completed'] = staffMap[staff]!['completed']! + 1;
          }
        }
      }

      final sortedBuckets = buckets.entries.toList()
        ..sort((a, b) => a.key.compareTo(b.key));
      final maxBucket = sortedBuckets.isEmpty
          ? 1
          : sortedBuckets.map((e) => e.value).reduce((a, b) => a > b ? a : b);

      final sortedServices = serviceCount.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      final maxService =
          sortedServices.isEmpty ? 1 : sortedServices.first.value;

      final staffList = staffMap.entries.map((e) {
        final t = e.value['total']!;
        final c = e.value['completed']!;
        return {
          'name':      e.key,
          'total':     t,
          'completed': c,
          'rate':      t == 0 ? 0.0 : c / t,
        };
      }).toList()
        ..sort((a, b) =>
            (b['rate'] as double).compareTo(a['rate'] as double));

      if (mounted) {
        setState(() {
          _total      = total;
          _completed  = completed;
          _pending    = pending;
          _processing = processing;
          _rejected   = rejected;
          _timeSeries = sortedBuckets
              .map((e) => {
                    'label': e.key,
                    'count': e.value,
                    'ratio': maxBucket == 0 ? 0.0 : e.value / maxBucket,
                  })
              .toList();
          _topServices = sortedServices
              .take(6)
              .map((e) => {
                    'name':  e.key,
                    'count': e.value,
                    'ratio': maxService == 0 ? 0.0 : e.value / maxService,
                  })
              .toList();
          _staffPerf = staffList.take(8).toList();
          _loading   = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _bucketKey(DateTime dt) {
    switch (_granularity) {
      case 'Weekly':
        final week = (dt.day / 7).ceil();
        return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-W$week';
      case 'Monthly':
        return '${dt.year}-${dt.month.toString().padLeft(2, '0')}';
      default:
        return '${dt.year}-'
            '${dt.month.toString().padLeft(2, '0')}-'
            '${dt.day.toString().padLeft(2, '0')}';
    }
  }

  // ── Build ────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _loadData,
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildFilterBar(),
                          const SizedBox(height: 20),
                          _buildSummaryCards(),
                          const SizedBox(height: 24),
                          _buildLineChart(),
                          const SizedBox(height: 24),
                          _buildStatusPieChart(),
                          const SizedBox(height: 24),
                          _buildTopServices(),
                          const SizedBox(height: 24),
                          _buildStaffPerformance(),
                          const SizedBox(height: 40),
                        ],
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  // ── Header ───────────────────────────────────────────────────────
  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFEEEEEE))),
      ),
      child: Row(
        children: [
          const Icon(LucideIcons.barChart2,
              color: AppColors.primary, size: 22),
          const SizedBox(width: 10),
          Text('Reports & Analytics',
              style: GoogleFonts.inter(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF1A1A2E))),
          const Spacer(),
          OutlinedButton.icon(
            onPressed: _loadData,
            icon: const Icon(LucideIcons.refreshCw, size: 14),
            label: const Text('Refresh'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primary,
              side: const BorderSide(color: AppColors.primary),
              textStyle: GoogleFonts.inter(
                  fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  // ── Filter Bar ───────────────────────────────────────────────────
  Widget _buildFilterBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [_cardShadow()],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Period:',
                  style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF666666))),
              const SizedBox(width: 10),
              Expanded(
                child: Wrap(
                  spacing: 6,
                  children: ['7D', '30D', '3M', 'All', 'Custom']
                      .map(_presetChip)
                      .toList(),
                ),
              ),
            ],
          ),
          if (_customRange != null) ...[
            const SizedBox(height: 6),
            Text(
              'Custom: ${_fmt(_customRange!.start)} → ${_fmt(_customRange!.end)}',
              style: GoogleFonts.inter(
                  fontSize: 12,
                  color: AppColors.primary,
                  fontWeight: FontWeight.w500),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Text('View by:',
                  style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF666666))),
              const SizedBox(width: 10),
              ...['Daily', 'Weekly', 'Monthly'].map((g) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(g),
                      selected: _granularity == g,
                      onSelected: (_) {
                        setState(() => _granularity = g);
                        _loadData();
                      },
                      selectedColor:
                          AppColors.primary.withValues(alpha: 0.15),
                      labelStyle: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _granularity == g
                            ? AppColors.primary
                            : const Color(0xFF666666),
                      ),
                    ),
                  )),
            ],
          ),
        ],
      ),
    );
  }

  Widget _presetChip(String label) {
    final selected = label == _preset;
    return GestureDetector(
      onTap: () async {
        if (label == 'Custom') {
          final range = await showDateRangePicker(
            context: context,
            firstDate: DateTime(2020),
            lastDate: DateTime.now(),
            builder: (ctx, child) => Theme(
              data: Theme.of(ctx).copyWith(
                colorScheme: const ColorScheme.light(
                    primary: AppColors.primary),
              ),
              child: child!,
            ),
          );
          if (range != null) {
            setState(() {
              _preset      = 'Custom';
              _customRange = range;
            });
            _loadData();
          }
        } else {
          setState(() {
            _preset      = label;
            _customRange = null;
          });
          _loadData();
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        margin: const EdgeInsets.only(right: 4, bottom: 4),
        decoration: BoxDecoration(
          color:  selected ? AppColors.primary : const Color(0xFFF0F0F0),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(label,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: selected ? Colors.white : const Color(0xFF666666),
            )),
      ),
    );
  }

  // ── Summary Cards ────────────────────────────────────────────────
  Widget _buildSummaryCards() {
    final rate = _total == 0 ? 0.0 : (_completed / _total * 100);
    final cards = [
      {'label': 'Total',     'value': '$_total',     'icon': LucideIcons.clipboardList, 'color': const Color(0xFF6C63FF)},
      {'label': 'Completed', 'value': '$_completed', 'icon': LucideIcons.checkCircle2,  'color': AppColors.success},
      {'label': 'Pending',   'value': '$_pending',   'icon': LucideIcons.clock3,         'color': AppColors.warning},
      {'label': 'Rate',      'value': '${rate.toStringAsFixed(1)}%', 'icon': LucideIcons.trendingUp, 'color': AppColors.primary},
    ];

    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.6,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: cards.map((c) {
        final color = c['color'] as Color;
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [_cardShadow()],
          ),
          child: Row(
            children: [
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(c['icon'] as IconData, color: color, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(c['value'] as String,
                        style: GoogleFonts.inter(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF1A1A2E))),
                    Text(c['label'] as String,
                        style: GoogleFonts.inter(
                            fontSize: 12,
                            color: const Color(0xFF888888),
                            fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  // ── Line Chart — Requests Over Time ─────────────────────────────
  Widget _buildLineChart() {
    if (_timeSeries.isEmpty) {
      return _buildCard(
        title: 'Requests Over Time',
        icon: LucideIcons.trendingUp,
        child: _emptyChart(),
      );
    }

    final spots = _timeSeries.asMap().entries.map((e) {
      return FlSpot(e.key.toDouble(), (e.value['count'] as int).toDouble());
    }).toList();

    final maxY = spots.map((s) => s.y).reduce((a, b) => a > b ? a : b);

    return _buildCard(
      title: 'Requests Over Time',
      icon: LucideIcons.trendingUp,
      child: SizedBox(
        height: 220,
        child: LineChart(
          LineChartData(
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              getDrawingHorizontalLine: (_) => FlLine(
                color: const Color(0xFFEEEEEE),
                strokeWidth: 1,
              ),
            ),
            titlesData: FlTitlesData(
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 32,
                  getTitlesWidget: (value, meta) => Text(
                    value.toInt().toString(),
                    style: GoogleFonts.inter(
                        fontSize: 10, color: const Color(0xFF888888)),
                  ),
                ),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 28,
                  interval: (_timeSeries.length / 5).ceilToDouble().clamp(1, double.infinity),
                  getTitlesWidget: (value, meta) {
                    final idx = value.toInt();
                    if (idx < 0 || idx >= _timeSeries.length) {
                      return const SizedBox.shrink();
                    }
                    return Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        _shortLabel(_timeSeries[idx]['label'] as String),
                        style: GoogleFonts.inter(
                            fontSize: 9, color: const Color(0xFF888888)),
                      ),
                    );
                  },
                ),
              ),
              rightTitles:  const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              topTitles:    const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            ),
            borderData: FlBorderData(
              show: true,
              border: const Border(
                bottom: BorderSide(color: Color(0xFFEEEEEE)),
                left:   BorderSide(color: Color(0xFFEEEEEE)),
              ),
            ),
            minX: 0,
            maxX: (_timeSeries.length - 1).toDouble().clamp(0, double.infinity),
            minY: 0,
            maxY: (maxY * 1.2).ceilToDouble(),
            lineBarsData: [
              LineChartBarData(
                spots: spots,
                isCurved: true,
                curveSmoothness: 0.3,
                color: AppColors.primary,
                barWidth: 3,
                dotData: FlDotData(
                  show: true,
                  getDotPainter: (spot, _, __, ___) => FlDotCirclePainter(
                    radius: 4,
                    color: Colors.white,
                    strokeWidth: 2,
                    strokeColor: AppColors.primary,
                  ),
                ),
                belowBarData: BarAreaData(
                  show: true,
                  color: AppColors.primary.withValues(alpha: 0.08),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Pie Chart — Status Breakdown ─────────────────────────────────
  Widget _buildStatusPieChart() {
    if (_total == 0) {
      return _buildCard(
        title: 'Status Breakdown',
        icon: LucideIcons.pieChart,
        child: _emptyChart(),
      );
    }

    final sections = <PieChartSectionData>[];
    final statusData = [
      {'label': 'Completed',  'count': _completed,  'color': AppColors.success},
      {'label': 'Pending',    'count': _pending,    'color': AppColors.warning},
      {'label': 'Processing', 'count': _processing, 'color': AppColors.primary},
      {'label': 'Rejected',   'count': _rejected,   'color': AppColors.danger},
    ];

    for (int i = 0; i < statusData.length; i++) {
      final item  = statusData[i];
      final count = item['count'] as int;
      if (count == 0) continue;
      final pct     = count / _total * 100;
      final isTouched = i == _touchedPieIndex;
      sections.add(PieChartSectionData(
        value:      count.toDouble(),
        color:      item['color'] as Color,
        radius:     isTouched ? 72 : 60,
        title:      '${pct.toStringAsFixed(1)}%',
        titleStyle: GoogleFonts.inter(
          fontSize: isTouched ? 14 : 11,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ));
    }

    return _buildCard(
      title: 'Status Breakdown',
      icon: LucideIcons.pieChart,
      child: Row(
        children: [
          SizedBox(
            height: 200,
            width: 200,
            child: PieChart(
              PieChartData(
                sections: sections,
                centerSpaceRadius: 40,
                sectionsSpace: 3,
                pieTouchData: PieTouchData(
                  touchCallback: (event, response) {
                    setState(() {
                      if (!event.isInterestedForInteractions ||
                          response == null ||
                          response.touchedSection == null) {
                        _touchedPieIndex = -1;
                        return;
                      }
                      _touchedPieIndex =
                          response.touchedSection!.touchedSectionIndex;
                    });
                  },
                ),
              ),
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: statusData.map((item) {
                final count = item['count'] as int;
                final color = item['color'] as Color;
                final pct   = _total == 0 ? 0.0 : count / _total * 100;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: [
                      Container(
                        width: 12, height: 12,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(item['label'] as String,
                            style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: const Color(0xFF444444))),
                      ),
                      Text(
                        '$count (${pct.toStringAsFixed(0)}%)',
                        style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF1A1A2E)),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  // ── Top Services — Horizontal Bar Chart ─────────────────────────
  Widget _buildTopServices() {
    if (_topServices.isEmpty) {
      return _buildCard(
        title: 'Top Services',
        icon: LucideIcons.star,
        child: _emptyChart(),
      );
    }

    final groups = _topServices.asMap().entries.map((e) {
      return BarChartGroupData(
        x: e.key,
        barRods: [
          BarChartRodData(
            toY: (e.value['count'] as int).toDouble(),
            color: AppColors.primary,
            width: 18,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
          ),
        ],
      );
    }).toList();

    final maxY = _topServices
        .map((e) => (e['count'] as int).toDouble())
        .reduce((a, b) => a > b ? a : b);

    return _buildCard(
      title: 'Top Services',
      icon: LucideIcons.star,
      child: SizedBox(
        height: 220,
        child: BarChart(
          BarChartData(
            alignment: BarChartAlignment.spaceAround,
            maxY: (maxY * 1.25).ceilToDouble(),
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              getDrawingHorizontalLine: (_) => FlLine(
                color: const Color(0xFFEEEEEE),
                strokeWidth: 1,
              ),
            ),
            titlesData: FlTitlesData(
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 28,
                  getTitlesWidget: (value, meta) => Text(
                    value.toInt().toString(),
                    style: GoogleFonts.inter(
                        fontSize: 10, color: const Color(0xFF888888)),
                  ),
                ),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 36,
                  getTitlesWidget: (value, meta) {
                    final idx = value.toInt();
                    if (idx < 0 || idx >= _topServices.length) {
                      return const SizedBox.shrink();
                    }
                    final name = (_topServices[idx]['name'] as String);
                    final short = name.length > 10
                        ? '${name.substring(0, 9)}…'
                        : name;
                    return Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(short,
                          style: GoogleFonts.inter(
                              fontSize: 9,
                              color: const Color(0xFF666666)),
                          textAlign: TextAlign.center),
                    );
                  },
                ),
              ),
              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              topTitles:   const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            ),
            borderData: FlBorderData(
              show: true,
              border: const Border(
                bottom: BorderSide(color: Color(0xFFEEEEEE)),
                left:   BorderSide(color: Color(0xFFEEEEEE)),
              ),
            ),
            barGroups: groups,
            barTouchData: BarTouchData(
              touchTooltipData: BarTouchTooltipData(
                getTooltipItem: (group, _, rod, __) => BarTooltipItem(
                  '${_topServices[group.x]['name']}\n${rod.toY.toInt()} requests',
                  GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.white),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Staff Performance ────────────────────────────────────────────
  Widget _buildStaffPerformance() {
    return _buildCard(
      title: 'Staff Performance',
      icon: LucideIcons.users,
      child: _staffPerf.isEmpty
          ? _emptyChart('No assigned requests in this period')
          : Column(
              children: _staffPerf.map((s) {
                final rate  = (s['rate'] as double).clamp(0.0, 1.0);
                final pct   = (rate * 100).toStringAsFixed(0);
                final Color color;
                if (rate >= 0.7) {
                  color = AppColors.success;
                } else if (rate >= 0.4) color = AppColors.warning;
                else                  color = AppColors.danger;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(children: [
                            CircleAvatar(
                              radius: 14,
                              backgroundColor: color.withValues(alpha: 0.15),
                              child: Text(
                                (s['name'] as String)
                                    .substring(0, 1)
                                    .toUpperCase(),
                                style: GoogleFonts.inter(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: color),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(s['name'] as String,
                                style: GoogleFonts.inter(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    color: const Color(0xFF444444))),
                          ]),
                          Row(children: [
                            Text('${s['completed']}/${s['total']}',
                                style: GoogleFonts.inter(
                                    fontSize: 12,
                                    color: const Color(0xFF888888))),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: color.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text('$pct%',
                                  style: GoogleFonts.inter(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: color)),
                            ),
                          ]),
                        ],
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: rate,
                          minHeight: 6,
                          backgroundColor: color.withValues(alpha: 0.12),
                          valueColor: AlwaysStoppedAnimation<Color>(color),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
    );
  }

  // ── Helpers ──────────────────────────────────────────────────────
  Widget _buildCard({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [_cardShadow()],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, size: 18, color: AppColors.primary),
            const SizedBox(width: 8),
            Text(title,
                style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF1A1A2E))),
          ]),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  Widget _emptyChart([String msg = 'No data for this period']) {
    return SizedBox(
      height: 80,
      child: Center(
        child: Text(msg,
            style: GoogleFonts.inter(
                fontSize: 13, color: const Color(0xFFAAAAAA))),
      ),
    );
  }

  BoxShadow _cardShadow() => BoxShadow(
        color: Colors.black.withValues(alpha: 0.05),
        blurRadius: 8,
        offset: const Offset(0, 2),
      );

  String _shortLabel(String key) {
    final parts = key.split('-');
    if (parts.length == 3) {
      return '${parts[1]}/${parts[2].replaceAll('W', '')}';
    }
    if (parts.length == 2) {
      return '${parts[1]}/${parts[0].substring(2)}';
    }
    return key;
  }

  String _fmt(DateTime d) =>
      '${d.month.toString().padLeft(2, '0')}/'
      '${d.day.toString().padLeft(2, '0')}/'
      '${d.year}';
}