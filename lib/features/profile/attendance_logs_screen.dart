import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../core/models/models.dart';
import '../../core/services/supabase_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/bento_card.dart';
import '../../core/utils/ist_date_utils.dart';
import '../../core/widgets/dumbbell_loader.dart';

/// One consolidated day visit containing 1 or more turnstile gate scans
class DayVisitSummary {
  final String dateKey; // yyyy-MM-dd
  final DateTime date;
  final DateTime firstIn;
  final DateTime? lastOut;
  final List<AttendanceRecord> punches;
  final int totalMinutes;
  final bool isOpen;

  DayVisitSummary({
    required this.dateKey,
    required this.date,
    required this.firstIn,
    this.lastOut,
    required this.punches,
    required this.totalMinutes,
    required this.isOpen,
  });
}

/// Material 3 Luxury Turnstile Attendance Logs with Week/Month/Year Analytics
class AttendanceLogsScreen extends StatefulWidget {
  final Member? member;

  const AttendanceLogsScreen({super.key, this.member});

  @override
  State<AttendanceLogsScreen> createState() => _AttendanceLogsScreenState();
}

class _AttendanceLogsScreenState extends State<AttendanceLogsScreen> {
  List<AttendanceRecord> _records = [];
  bool _isLoading = true;
  String? _errorMessage;
  String _range = 'week'; // 'week', 'month', 'year', 'all'
  final Set<String> _expandedDays = {};

  @override
  void initState() {
    super.initState();
    _loadAttendance();
  }

  Future<void> _loadAttendance() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final memberId = widget.member?.id ??
          SupabaseService.instance.cachedMember?.id ??
          SupabaseService.instance.currentUser?.id ??
          '';
      final data = await SupabaseService.instance.fetchAttendanceHistory(memberId);
      if (mounted) {
        setState(() {
          _records = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Unable to connect to turnstile access stream. Please check your network and retry.';
          _isLoading = false;
        });
      }
    }
  }

  /// Consolidates raw turnstile records by calendar day (IST)
  List<DayVisitSummary> get _consolidatedDays {
    final Map<String, List<AttendanceRecord>> byDay = {};
    for (final r in _records) {
      final key = ISTDateUtils.formatDateKey(r.checkInTime);
      byDay.putIfAbsent(key, () => []).add(r);
    }

    final List<DayVisitSummary> list = [];
    byDay.forEach((key, punches) {
      punches.sort((a, b) => a.checkInTime.compareTo(b.checkInTime));
      final firstIn = punches.first.checkInTime;
      final outs = punches.where((p) => p.checkOutTime != null).map((p) => p.checkOutTime!).toList();
      final isOpen = punches.any((p) => p.checkOutTime == null);
      final lastOut = outs.isNotEmpty
          ? outs.reduce((a, b) => a.isAfter(b) ? a : b)
          : null;

      final end = isOpen
          ? punches.last.checkInTime
          : (lastOut ?? firstIn);
      final minutes = (end.difference(firstIn).inMinutes).clamp(0, 480);

      list.add(DayVisitSummary(
        dateKey: key,
        date: firstIn,
        firstIn: firstIn,
        lastOut: lastOut,
        punches: punches,
        totalMinutes: minutes,
        isOpen: isOpen,
      ));
    });

    list.sort((a, b) => b.firstIn.compareTo(a.firstIn));
    return list;
  }

  /// Filters consolidated days based on selected range
  List<DayVisitSummary> get _filteredDays {
    final now = DateTime.now();
    final all = _consolidatedDays;

    if (_range == 'week') {
      final weekAgo = now.subtract(const Duration(days: 7));
      return all.where((d) => d.date.isAfter(weekAgo)).toList();
    } else if (_range == 'month') {
      return all.where((d) => d.date.year == now.year && d.date.month == now.month).toList();
    } else if (_range == 'year') {
      return all.where((d) => d.date.year == now.year).toList();
    }
    return all;
  }

  /// Compute current streak, best streak, and metrics
  Map<String, dynamic> get _streakMetrics {
    final all = _consolidatedDays;
    final Set<String> uniqueKeys = all.map((d) => d.dateKey).toSet();
    final now = ISTDateUtils.toIST(DateTime.now());
    final todayKey = ISTDateUtils.formatDateKey(now);
    final yestKey = ISTDateUtils.formatDateKey(now.subtract(const Duration(days: 1)));

    final hasToday = uniqueKeys.contains(todayKey);
    final hasYest = uniqueKeys.contains(yestKey);

    int currentStreak = 0;
    if (hasToday || hasYest) {
      DateTime check = hasToday ? now : now.subtract(const Duration(days: 1));
      while (uniqueKeys.contains(ISTDateUtils.formatDateKey(check))) {
        currentStreak++;
        check = check.subtract(const Duration(days: 1));
      }
    }

    // Best streak calculation
    final sortedKeys = uniqueKeys.toList()..sort();
    int bestStreak = sortedKeys.isNotEmpty ? 1 : 0;
    int run = 1;
    for (int i = 1; i < sortedKeys.length; i++) {
      final d1 = DateTime.tryParse(sortedKeys[i - 1]);
      final d2 = DateTime.tryParse(sortedKeys[i]);
      if (d1 != null && d2 != null && d2.difference(d1).inDays == 1) {
        run++;
        if (run > bestStreak) bestStreak = run;
      } else {
        run = 1;
      }
    }

    // Average duration in minutes
    final completed = all.where((d) => !d.isOpen && d.totalMinutes > 15).toList();
    final avgMinutes = completed.isNotEmpty
        ? (completed.fold(0, (sum, d) => sum + d.totalMinutes) / completed.length).round()
        : 75;

    return {
      'currentStreak': currentStreak,
      'bestStreak': bestStreak,
      'totalVisits': uniqueKeys.length,
      'avgMinutes': avgMinutes,
      'hasToday': hasToday,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.bg,
      appBar: AppBar(
        backgroundColor: context.bg,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Turnstile Attendance Logs',
              style: GoogleFonts.outfit(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: context.textPrimary,
              ),
            ),
            Text(
              'Smart Turnstile Access • Calibrated to IST (UTC+05:30)',
              style: GoogleFonts.outfit(
                fontSize: 11,
                color: context.textMuted,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh_rounded, color: context.brandAccent),
            onPressed: _loadAttendance,
            tooltip: 'Refresh attendance',
          ),
        ],
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(
                child: DumbbellLoader(
                  text: 'Fetching Turnstile Access Logs...',
                  size: DumbbellLoaderSize.md,
                ),
              )
            : _errorMessage != null
                ? _buildErrorState()
                : RefreshIndicator(
                onRefresh: _loadAttendance,
                color: context.brandAccent,
                backgroundColor: context.cardBg,
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  children: [
                    // 1. STATS HERO BANNER
                    _buildStatsGrid(),

                    const SizedBox(height: 16),

                    // 2. RANGE SELECTOR TABS (Week, Month, Year, All)
                    _buildRangeSelector(),

                    const SizedBox(height: 14),

                    // 3. ATTENDANCE TREND BARS
                    _buildTrendBarChart(),

                    const SizedBox(height: 18),

                    // 4. SMART OPTICAL TURNSTILE STATUS BADGE
                    _buildTurnstileBanner(),

                    const SizedBox(height: 18),

                    // 5. CONSOLIDATED DAY LOGS HEADER
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'SESSION HISTORY',
                          style: GoogleFonts.outfit(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.2,
                            color: context.textMuted,
                          ),
                        ),
                        Text(
                          '${_filteredDays.length} days recorded',
                          style: GoogleFonts.outfit(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: context.brandAccent,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 10),

                    // 6. SESSION CARDS LIST
                    if (_filteredDays.isEmpty)
                      _buildEmptyState()
                    else
                      ..._filteredDays.map((day) => _buildDayVisitCard(day)),

                    const SizedBox(height: 24),
                  ],
                ),
              ),
      ),
    );
  }

  /// 4-Metric Grid (Streak, Best Streak, Total Sessions, Avg Duration)
  Widget _buildStatsGrid() {
    final m = _streakMetrics;
    return BentoCard(
      padding: const EdgeInsets.all(16),
      backgroundColor: context.cardElevated,
      border: Border.all(color: context.borderCol),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _buildMetricTile(
                  icon: Icons.local_fire_department_rounded,
                  iconColor: AppTheme.amber,
                  label: 'Current Streak',
                  value: '${m['currentStreak']}d',
                  badge: m['hasToday'] == true ? 'PROTECTED' : 'ACTIVE',
                  badgeColor: AppTheme.emerald,
                ),
              ),
              Container(width: 1, height: 48, color: context.borderCol),
              Expanded(
                child: _buildMetricTile(
                  icon: Icons.emoji_events_rounded,
                  iconColor: context.brandAccent,
                  label: 'Best Streak',
                  value: '${m['bestStreak']}d',
                  badge: 'RECORD',
                  badgeColor: context.brandAccent,
                ),
              ),
            ],
          ),
          const Divider(height: 20),
          Row(
            children: [
              Expanded(
                child: _buildMetricTile(
                  icon: Icons.calendar_today_rounded,
                  iconColor: AppTheme.cyan,
                  label: 'Total Sessions',
                  value: '${m['totalVisits']} days',
                  subtitle: '${_records.length} gate scans',
                ),
              ),
              Container(width: 1, height: 48, color: context.borderCol),
              Expanded(
                child: _buildMetricTile(
                  icon: Icons.timer_outlined,
                  iconColor: AppTheme.emerald,
                  label: 'Avg Duration',
                  value: '${m['avgMinutes']} min',
                  subtitle: 'per gym workout',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricTile({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
    String? badge,
    Color? badgeColor,
    String? subtitle,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: iconColor),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w600, color: context.textMuted),
                ),
              ),
              if (badge != null) ...[
                const SizedBox(width: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                  decoration: BoxDecoration(
                    color: (badgeColor ?? iconColor).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    badge,
                    style: GoogleFonts.outfit(fontSize: 8, fontWeight: FontWeight.w800, color: badgeColor ?? iconColor),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w800, color: context.textPrimary),
          ),
          if (subtitle != null)
            Text(
              subtitle,
              style: GoogleFonts.outfit(fontSize: 10, color: context.textMuted),
            ),
        ],
      ),
    );
  }

  /// Segmented Range Selector (Week, Month, Year, All)
  Widget _buildRangeSelector() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: context.cardElevated,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.borderCol),
      ),
      child: Row(
        children: [
          _buildRangeTab('week', 'Week'),
          _buildRangeTab('month', 'Month'),
          _buildRangeTab('year', 'Year'),
          _buildRangeTab('all', 'All time'),
        ],
      ),
    );
  }

  Widget _buildRangeTab(String key, String title) {
    final isSelected = _range == key;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _range = key),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? context.brandAccent : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: context.brandAccent.withValues(alpha: 0.25),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Center(
            child: Text(
              title,
              style: GoogleFonts.outfit(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color: isSelected
                    ? (Theme.of(context).brightness == Brightness.dark ? Colors.black : Colors.white)
                    : context.textMuted,
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Interactive Bar Chart of Visits for Week / Month / Year
  Widget _buildTrendBarChart() {
    final now = ISTDateUtils.toIST(DateTime.now());
    final List<Map<String, dynamic>> barPoints = [];

    if (_range == 'week') {
      // Last 7 days
      for (int i = 6; i >= 0; i--) {
        final d = now.subtract(Duration(days: i));
        final key = ISTDateUtils.formatDateKey(d);
        final punches = _records.where((r) => ISTDateUtils.formatDateKey(r.checkInTime) == key).length;
        barPoints.add({
          'label': DateFormat('E').format(d).substring(0, 3), // Mon, Tue...
          'count': punches,
          'isToday': i == 0,
        });
      }
    } else if (_range == 'month') {
      // Days of current month (sampled or daily)
      final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
      for (int day = 1; day <= daysInMonth; day++) {
        final d = DateTime(now.year, now.month, day);
        final key = ISTDateUtils.formatDateKey(d);
        final punches = _records.where((r) => ISTDateUtils.formatDateKey(r.checkInTime) == key).length;
        barPoints.add({
          'label': '$day',
          'count': punches,
          'isToday': day == now.day,
        });
      }
    } else {
      // 12 Months of current year
      for (int m = 1; m <= 12; m++) {
        final mStr = m.toString().padLeft(2, '0');
        final prefix = '${now.year}-$mStr';
        final punches = _records.where((r) => ISTDateUtils.formatDateKey(r.checkInTime).startsWith(prefix)).length;
        barPoints.add({
          'label': DateFormat('MMM').format(DateTime(now.year, m, 1)),
          'count': punches,
          'isToday': m == now.month,
        });
      }
    }

    final maxVal = barPoints.fold(1, (max, p) => (p['count'] as int) > max ? p['count'] as int : max);

    return BentoCard(
      padding: const EdgeInsets.all(16),
      backgroundColor: context.cardElevated,
      border: Border.all(color: context.borderCol),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.bar_chart_rounded, size: 16, color: context.brandAccent),
                  const SizedBox(width: 6),
                  Text(
                    _range == 'week'
                        ? 'LAST 7 DAYS ACTIVITY'
                        : (_range == 'month' ? 'MONTHLY ACTIVITY (${DateFormat('MMMM yyyy').format(now)})' : 'YEARLY FREQUENCY (${now.year})'),
                    style: GoogleFonts.outfit(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.0,
                      color: context.textMuted,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.emerald.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${barPoints.where((p) => (p['count'] as int) > 0).length} active',
                  style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w700, color: AppTheme.emerald),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 100,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: barPoints.map((p) {
                final count = p['count'] as int;
                final isToday = p['isToday'] as bool;
                final pct = (count / maxVal).clamp(0.0, 1.0);
                final hasVisit = count > 0;

                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 1.5),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (count > 0)
                          Text(
                            '$count',
                            style: GoogleFonts.outfit(
                              fontSize: 8,
                              fontWeight: FontWeight.w700,
                              color: context.brandAccent,
                            ),
                          ),
                        const SizedBox(height: 3),
                        Container(
                          height: hasVisit ? (pct * 65).clamp(8.0, 65.0) : 4.0,
                          decoration: BoxDecoration(
                            color: hasVisit
                                ? (isToday ? AppTheme.amber : context.brandAccent)
                                : context.cardBg,
                            borderRadius: BorderRadius.circular(3),
                            border: Border.all(
                              color: hasVisit
                                  ? Colors.transparent
                                  : context.borderCol.withValues(alpha: 0.4),
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          p['label'] as String,
                          style: GoogleFonts.outfit(
                            fontSize: 8.5,
                            fontWeight: isToday ? FontWeight.w800 : FontWeight.w600,
                            color: isToday ? context.brandAccent : context.textMuted,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.clip,
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  /// Clean Smart Optical Turnstile Banner
  Widget _buildTurnstileBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: context.cardElevated,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.borderCol),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.emerald.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.qr_code_scanner_rounded, color: AppTheme.emerald, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Smart Optical Turnstile System',
                      style: GoogleFonts.outfit(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: context.textPrimary,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: AppTheme.emerald,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  'Encrypted gate access • MIPS optical scanner active',
                  style: GoogleFonts.outfit(fontSize: 11, color: context.textMuted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Consolidated Day Visit Card with expandable multi-punch details
  Widget _buildDayVisitCard(DayVisitSummary day) {
    final isExpanded = _expandedDays.contains(day.dateKey);
    final hasMultiplePunches = day.punches.length > 1;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: context.cardElevated,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: day.isOpen ? AppTheme.emerald.withValues(alpha: 0.4) : context.borderCol,
          width: day.isOpen ? 1.2 : 1.0,
        ),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () {
              setState(() {
                if (isExpanded) {
                  _expandedDays.remove(day.dateKey);
                } else {
                  _expandedDays.add(day.dateKey);
                }
              });
            },
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: day.isOpen
                          ? AppTheme.emerald.withValues(alpha: 0.15)
                          : context.brandAccent.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      day.isOpen ? Icons.door_sliding_rounded : Icons.check_circle_outline_rounded,
                      color: day.isOpen ? AppTheme.emerald : context.brandAccent,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          DateFormat('EEEE, dd MMM yyyy').format(day.date),
                          style: GoogleFonts.outfit(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: context.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          day.isOpen
                              ? 'In ${DateFormat('hh:mm a').format(day.firstIn)} • Active Workout Session'
                              : 'In ${DateFormat('hh:mm a').format(day.firstIn)}${day.lastOut != null ? ' • Out ${DateFormat('hh:mm a').format(day.lastOut!)}' : ''}${hasMultiplePunches ? ' • ${day.punches.length} scans' : ''}',
                          style: GoogleFonts.outfit(fontSize: 11, color: context.textMuted),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: day.isOpen
                              ? AppTheme.emerald.withValues(alpha: 0.15)
                              : context.cardBg,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: day.isOpen
                                ? AppTheme.emerald.withValues(alpha: 0.4)
                                : context.borderCol,
                          ),
                        ),
                        child: Text(
                          day.isOpen ? 'IN CLUB' : '${day.totalMinutes} min',
                          style: GoogleFonts.outfit(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: day.isOpen ? AppTheme.emerald : context.brandAccent,
                          ),
                        ),
                      ),
                      if (hasMultiplePunches) ...[
                        const SizedBox(height: 4),
                        Icon(
                          isExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                          size: 16,
                          color: context.textMuted,
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Expanded Multi-Punch Detail Trail
          if (isExpanded)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: context.cardBg.withValues(alpha: 0.5),
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(14)),
                border: Border(top: BorderSide(color: context.borderCol.withValues(alpha: 0.5))),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'TURNSTILE SCANS DETAIL',
                    style: GoogleFonts.outfit(fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 0.8, color: context.textMuted),
                  ),
                  const SizedBox(height: 6),
                  ...day.punches.map((p) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.arrow_forward_rounded, size: 12, color: AppTheme.emerald),
                                const SizedBox(width: 6),
                                Text(
                                  'In ${DateFormat('hh:mm:ss a').format(p.checkInTime)}',
                                  style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w600, color: context.textPrimary),
                                ),
                              ],
                            ),
                            Text(
                              p.checkOutTime != null
                                  ? 'Out ${DateFormat('hh:mm:ss a').format(p.checkOutTime!)}'
                                  : 'Open Session',
                              style: GoogleFonts.outfit(
                                fontSize: 11,
                                color: p.checkOutTime != null ? context.textMuted : AppTheme.emerald,
                                fontWeight: p.checkOutTime == null ? FontWeight.w700 : FontWeight.w400,
                              ),
                            ),
                          ],
                        ),
                      )),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: context.cardElevated,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.borderCol),
      ),
      child: Column(
        children: [
          Icon(Icons.calendar_month_outlined, size: 36, color: context.textMuted),
          const SizedBox(height: 12),
          Text(
            'No Visits Recorded in this Period',
            style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w700, color: context.textPrimary),
          ),
          const SizedBox(height: 4),
          Text(
            'Incline gates are open 24/7. Hold your optical gate pass to log your next session.',
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(fontSize: 12, color: context.textMuted),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.redAccent.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.cloud_off_rounded, size: 40, color: Colors.redAccent),
            ),
            const SizedBox(height: 16),
            Text(
              'Attendance Sync Failed',
              style: GoogleFonts.outfit(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: context.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage ?? 'Unable to connect to turnstile access stream.',
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(fontSize: 13, color: context.textMuted),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _loadAttendance,
              style: ElevatedButton.styleFrom(
                backgroundColor: context.brandAccent,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: Text(
                'Retry Connection',
                style: GoogleFonts.outfit(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
