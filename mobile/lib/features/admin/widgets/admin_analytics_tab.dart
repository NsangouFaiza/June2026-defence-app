import 'dart:math' as math;
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/providers/providers.dart';
import '../../../data/repositories/admin_repository.dart';
import 'admin_user_common.dart';

/// Categorical series colors (validated reference palette, fixed order — never cycled).
/// Light and dark steps of the same hues.
const _seriesLight = [Color(0xFF2A78D6), Color(0xFFEB6834), Color(0xFF1BAF7A), Color(0xFFEDA100), Color(0xFFE87BA4)];
const _seriesDark = [Color(0xFF3987E5), Color(0xFFD95926), Color(0xFF199E70), Color(0xFFC98500), Color(0xFFD55181)];

/// Role order is fixed so a role keeps its color whatever the counts are.
const _roleOrder = ['donor', 'patient', 'hospital_staff', 'blood_bank_admin', 'system_admin'];

const _lowStockThreshold = 5;

class AdminAnalyticsTab extends ConsumerStatefulWidget {
  const AdminAnalyticsTab({super.key});

  @override
  ConsumerState<AdminAnalyticsTab> createState() => _AdminAnalyticsTabState();
}

class _AdminAnalyticsTabState extends ConsumerState<AdminAnalyticsTab> with AutomaticKeepAliveClientMixin {
  Map<String, dynamic>? _stats;
  String? _error;
  bool _loading = true;
  DateTime? _updatedAt;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final stats = await ref.read(adminRepositoryProvider).getSystemStatistics();
      if (!mounted) return;
      setState(() {
        _stats = stats;
        _loading = false;
        _updatedAt = DateTime.now();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = AdminRepository.errorMessage(e);
        _loading = false;
      });
    }
  }

  bool get _dark => Theme.of(context).brightness == Brightness.dark;
  List<Color> get _series => _dark ? _seriesDark : _seriesLight;
  Color get _textPrimary => Theme.of(context).colorScheme.onSurface;
  Color get _textMuted => Theme.of(context).colorScheme.onSurfaceVariant;
  Color get _gridColor => Theme.of(context).dividerColor.withOpacity(0.5);

  int _int(dynamic v) => (v as num?)?.toInt() ?? 0;
  double _num(dynamic v) => (v as num?)?.toDouble() ?? 0;
  String _compact(num v) => NumberFormat.compact().format(v);
  String _money(num v) => '${NumberFormat.decimalPattern().format(v.round())} FCFA';

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final stats = _stats;

    if (stats == null) {
      if (_error != null) {
        return Center(
          child: Padding(
            padding: EdgeInsets.all(24.w),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.error_outline, size: 48.w, color: AppTheme.error),
                SizedBox(height: 8.h),
                Text(_error!, textAlign: TextAlign.center),
                SizedBox(height: 12.h),
                ElevatedButton.icon(onPressed: _load, icon: const Icon(Icons.refresh), label: const Text('Retry')),
              ],
            ),
          ),
        );
      }
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 96.h),
        children: [
          _header(),
          if (_loading) Padding(padding: EdgeInsets.only(top: 6.h), child: LinearProgressIndicator(minHeight: 2.h)),
          SizedBox(height: 12.h),
          _kpiGrid(stats),
          _activityCard(stats),
          _registrationsCard(stats),
          _bloodStockCard(stats),
          _usersByRoleCard(stats),
          _requestsCard(stats),
          _hospitalsCard(stats),
          _revenueCard(stats),
          if (((stats['top_hospitals'] as List?) ?? []).isNotEmpty) _topHospitalsCard(stats),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------- Header

  Widget _header() {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Platform Overview', style: TextStyle(fontSize: 20.sp, fontWeight: FontWeight.w800, color: _textPrimary)),
              SizedBox(height: 2.h),
              Text(
                _updatedAt == null ? '' : 'Updated ${DateFormat('d MMM, HH:mm').format(_updatedAt!)}',
                style: TextStyle(fontSize: 12.sp, color: _textMuted),
              ),
            ],
          ),
        ),
        IconButton.outlined(tooltip: 'Refresh', onPressed: _loading ? null : _load, icon: const Icon(Icons.refresh)),
      ],
    );
  }

  // ------------------------------------------------------------------ KPIs

  Widget _kpiGrid(Map<String, dynamic> s) {
    final hospitalStatus = (s['hospital_status'] as Map?) ?? {};
    final tiles = [
      _Kpi(
        icon: Icons.people_alt_outlined,
        label: 'Users',
        value: _compact(_int(s['total_users'])),
        detail: '+${_int(s['new_users_this_month'])} this month',
        trendUp: _int(s['new_users_this_month']) > 0,
      ),
      _Kpi(
        icon: Icons.local_hospital_outlined,
        label: 'Hospitals',
        value: _compact(_int(s['total_hospitals'])),
        detail: '${_int(hospitalStatus['active'] ?? s['active_hospitals'])} with active subscription',
      ),
      _Kpi(
        icon: Icons.volunteer_activism_outlined,
        label: 'Donations',
        value: _compact(_int(s['total_donations'])),
        detail: '+${_int(s['donations_this_month'])} this month',
        trendUp: _int(s['donations_this_month']) > 0,
      ),
      _Kpi(
        icon: Icons.bloodtype_outlined,
        label: 'Blood units in stock',
        value: _compact(_int(s['total_blood_units'])),
        detail: '${_int(s['available_donors'])} donors available',
      ),
      _Kpi(
        icon: Icons.assignment_late_outlined,
        label: 'Pending requests',
        value: _compact(_int(s['pending_requests'])),
        detail: _int(s['emergency_requests']) > 0 ? '${_int(s['emergency_requests'])} emergency' : 'No emergencies',
        alert: _int(s['emergency_requests']) > 0,
      ),
      _Kpi(
        icon: Icons.account_balance_wallet_outlined,
        label: 'Revenue',
        value: _compact(_num(s['total_revenue'])),
        unit: 'FCFA',
        detail: '${_int(s['total_campaigns'])} campaigns • ${_int(s['total_appointments'])} appts',
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth > 700 ? 3 : 2;
        final spacing = 10.w;
        final width = (constraints.maxWidth - spacing * (columns - 1)) / columns;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: tiles.map((t) => SizedBox(width: width, child: _kpiTile(t))).toList(),
        );
      },
    );
  }

  Widget _kpiTile(_Kpi k) {
    final accent = k.alert ? AppTheme.error : AppTheme.primaryColor;
    return Container(
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: Theme.of(context).dividerColor.withOpacity(0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(6.w),
                decoration: BoxDecoration(color: accent.withOpacity(0.1), borderRadius: BorderRadius.circular(10.r)),
                child: Icon(k.icon, size: 18.w, color: accent),
              ),
              SizedBox(width: 8.w),
              Expanded(
                child: Text(
                  k.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w600, color: _textMuted),
                ),
              ),
            ],
          ),
          SizedBox(height: 10.h),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(k.value, style: TextStyle(fontSize: 24.sp, fontWeight: FontWeight.w800, color: _textPrimary)),
              if (k.unit != null) ...[
                SizedBox(width: 4.w),
                Text(k.unit!, style: TextStyle(fontSize: 11.sp, fontWeight: FontWeight.w600, color: _textMuted)),
              ],
            ],
          ),
          SizedBox(height: 4.h),
          Row(
            children: [
              if (k.trendUp) Icon(Icons.trending_up, size: 14.sp, color: AppTheme.success),
              if (k.alert) Icon(Icons.warning_amber_rounded, size: 14.sp, color: AppTheme.error),
              if (k.trendUp || k.alert) SizedBox(width: 3.w),
              Expanded(
                child: Text(
                  k.detail,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11.sp,
                    color: k.alert ? AppTheme.error : (k.trendUp ? AppTheme.success : _textMuted),
                    fontWeight: (k.alert || k.trendUp) ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------ Chart card

  Widget _card({required String title, String? subtitle, Widget? trailing, required Widget child}) {
    return Container(
      margin: EdgeInsets.only(top: 14.h),
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: Theme.of(context).dividerColor.withOpacity(0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.w700, color: _textPrimary)),
                    if (subtitle != null) ...[
                      SizedBox(height: 2.h),
                      Text(subtitle, style: TextStyle(fontSize: 12.sp, color: _textMuted)),
                    ],
                  ],
                ),
              ),
              if (trailing != null) trailing,
            ],
          ),
          SizedBox(height: 14.h),
          child,
        ],
      ),
    );
  }

  Widget _legendItem(Color color, String label, {String? value, bool line = false}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: line ? 14.w : 10.w,
          height: line ? 3.h : 10.w,
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(line ? 2.r : 3.r)),
        ),
        SizedBox(width: 6.w),
        Text(label, style: TextStyle(fontSize: 12.sp, color: _textMuted)),
        if (value != null) ...[
          SizedBox(width: 4.w),
          Text(value, style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w700, color: _textPrimary)),
        ],
      ],
    );
  }

  List<String> _monthLabels(Map<String, dynamic> s) {
    final months = ((s['months'] as List?) ?? []).cast<String>();
    return months.map((m) {
      final d = DateTime.tryParse('$m-01');
      return d == null ? m : DateFormat.MMM().format(d);
    }).toList();
  }

  double _niceMax(double maxValue) {
    if (maxValue <= 4) return 4;
    final magnitude = math.pow(10, (math.log(maxValue) / math.ln10).floor()).toDouble();
    final step = magnitude / 2;
    return (maxValue / step).ceil() * step;
  }

  FlTitlesData _titles(List<String> labels, double maxY, {bool money = false}) {
    return FlTitlesData(
      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      leftTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 36.w,
          interval: maxY / 4,
          getTitlesWidget: (value, meta) => SideTitleWidget(
            axisSide: meta.axisSide,
            child: Text(_compact(value), style: TextStyle(fontSize: 10.sp, color: _textMuted)),
          ),
        ),
      ),
      bottomTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          interval: 1,
          reservedSize: 24.h,
          getTitlesWidget: (value, meta) {
            final i = value.toInt();
            if (i < 0 || i >= labels.length || value != i.toDouble()) return const SizedBox.shrink();
            return SideTitleWidget(
              axisSide: meta.axisSide,
              child: Text(labels[i], style: TextStyle(fontSize: 10.sp, color: _textMuted)),
            );
          },
        ),
      ),
    );
  }

  FlGridData get _grid => FlGridData(
        drawVerticalLine: false,
        getDrawingHorizontalLine: (_) => FlLine(color: _gridColor, strokeWidth: 1, dashArray: [4, 4]),
      );

  Color get _tooltipBg => _dark ? const Color(0xFF2D2D2D) : const Color(0xFF212121);

  // -------------------------------------------------------- Activity chart

  Widget _activityCard(Map<String, dynamic> s) {
    final labels = _monthLabels(s);
    final donations = ((s['monthly_donations'] as List?) ?? []).map(_num).toList();
    final requests = ((s['monthly_requests'] as List?) ?? []).map(_num).toList();
    if (labels.isEmpty) return const SizedBox.shrink();

    final maxY = _niceMax([...donations, ...requests].fold<double>(0, math.max));
    final donationColor = _series[0];
    final requestColor = _series[1];

    LineChartBarData line(List<double> values, Color color) => LineChartBarData(
          spots: [for (var i = 0; i < values.length; i++) FlSpot(i.toDouble(), values[i])],
          isCurved: true,
          preventCurveOverShooting: true,
          color: color,
          barWidth: 2,
          dotData: FlDotData(
            getDotPainter: (spot, _, __, ___) => FlDotCirclePainter(
              radius: 4,
              color: color,
              strokeWidth: 2,
              strokeColor: Theme.of(context).cardColor,
            ),
          ),
          belowBarData: BarAreaData(show: true, color: color.withOpacity(0.08)),
        );

    return _card(
      title: 'Donations vs. blood requests',
      subtitle: 'Last 6 months',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 16.w,
            children: [
              _legendItem(donationColor, 'Donations', value: '${donations.fold<double>(0, (a, b) => a + b).toInt()}', line: true),
              _legendItem(requestColor, 'Requests', value: '${requests.fold<double>(0, (a, b) => a + b).toInt()}', line: true),
            ],
          ),
          SizedBox(height: 16.h),
          SizedBox(
            height: 190.h,
            child: LineChart(
              LineChartData(
                minY: 0,
                maxY: maxY,
                gridData: _grid,
                borderData: FlBorderData(show: false),
                titlesData: _titles(labels, maxY),
                lineBarsData: [line(donations, donationColor), line(requests, requestColor)],
                lineTouchData: LineTouchData(
                  getTouchedSpotIndicator: (bar, indexes) => indexes
                      .map((_) => TouchedSpotIndicatorData(
                            FlLine(color: _textMuted.withOpacity(0.4), strokeWidth: 1),
                            FlDotData(
                              getDotPainter: (spot, _, b, __) => FlDotCirclePainter(
                                radius: 5,
                                color: b.color ?? donationColor,
                                strokeWidth: 2,
                                strokeColor: Theme.of(context).cardColor,
                              ),
                            ),
                          ),)
                      .toList(),
                  touchTooltipData: LineTouchTooltipData(
                    tooltipBgColor: _tooltipBg,
                    tooltipRoundedRadius: 8,
                    fitInsideHorizontally: true,
                    getTooltipItems: (spots) => spots.map((spot) {
                      final isDonation = spot.barIndex == 0;
                      return LineTooltipItem(
                        spot.barIndex == 0 ? '${labels[spot.x.toInt()]}\n' : '',
                        TextStyle(color: Colors.white70, fontSize: 11.sp),
                        children: [
                          TextSpan(
                            text: '${isDonation ? 'Donations' : 'Requests'}: ${spot.y.toInt()}',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12.sp),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ----------------------------------------------------- Registrations bars

  Widget _registrationsCard(Map<String, dynamic> s) {
    final labels = _monthLabels(s);
    final values = ((s['monthly_new_users'] as List?) ?? []).map(_num).toList();
    if (labels.isEmpty) return const SizedBox.shrink();
    final maxY = _niceMax(values.fold<double>(0, math.max));
    final color = _series[0];
    final total = values.fold<double>(0, (a, b) => a + b).toInt();

    return _card(
      title: 'New registrations',
      subtitle: '$total new users in the last 6 months',
      child: SizedBox(
        height: 170.h,
        child: BarChart(
          BarChartData(
            minY: 0,
            maxY: maxY,
            gridData: _grid,
            borderData: FlBorderData(show: false),
            titlesData: _titles(labels, maxY),
            barGroups: [
              for (var i = 0; i < values.length; i++)
                BarChartGroupData(
                  x: i,
                  barRods: [
                    BarChartRodData(
                      toY: values[i],
                      width: 18.w,
                      color: i == values.length - 1 ? color : color.withOpacity(0.55),
                      borderRadius: BorderRadius.vertical(top: Radius.circular(4.r)),
                    ),
                  ],
                ),
            ],
            barTouchData: BarTouchData(
              touchTooltipData: BarTouchTooltipData(
                tooltipBgColor: _tooltipBg,
                tooltipRoundedRadius: 8,
                getTooltipItem: (group, _, rod, __) => BarTooltipItem(
                  '${labels[group.x]}\n',
                  TextStyle(color: Colors.white70, fontSize: 11.sp),
                  children: [
                    TextSpan(
                      text: '${rod.toY.toInt()} new users',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12.sp),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ----------------------------------------------------------- Blood stock

  Widget _bloodStockCard(Map<String, dynamic> s) {
    final stock = ((s['blood_stock'] as List?) ?? []).cast<Map<String, dynamic>>();
    if (stock.isEmpty) return const SizedBox.shrink();
    final maxUnits = stock.map((e) => _int(e['units'])).fold<int>(1, math.max);
    final lowCount = stock.where((e) => _int(e['units']) < _lowStockThreshold).length;
    final barColor = _series[0];

    return _card(
      title: 'Blood stock by group',
      subtitle: 'Available units across all hospitals',
      trailing: lowCount > 0
          ? AdminChip(label: '$lowCount low', color: AppTheme.warning, icon: Icons.warning_amber_rounded)
          : const AdminChip(label: 'Healthy', color: AppTheme.success, icon: Icons.check_circle),
      child: Column(
        children: stock.map((e) {
          final units = _int(e['units']);
          final low = units < _lowStockThreshold;
          final color = low ? AppTheme.warning : barColor;
          return Padding(
            padding: EdgeInsets.symmetric(vertical: 5.h),
            child: Row(
              children: [
                SizedBox(
                  width: 38.w,
                  child: Text(e['blood_group'] ?? '',
                      style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w700, color: _textPrimary),),
                ),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, c) => Stack(
                      children: [
                        Container(
                          height: 12.h,
                          decoration: BoxDecoration(
                            color: _gridColor.withOpacity(0.35),
                            borderRadius: BorderRadius.circular(4.r),
                          ),
                        ),
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 500),
                          height: 12.h,
                          width: units == 0 ? 0 : math.max(4, c.maxWidth * units / maxUnits),
                          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4.r)),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(width: 10.w),
                SizedBox(
                  width: 62.w,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (low) ...[
                        Icon(Icons.warning_amber_rounded, size: 13.sp, color: AppTheme.warning),
                        SizedBox(width: 3.w),
                      ],
                      Text('$units',
                          style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w700, color: _textPrimary),),
                      Text(' u', style: TextStyle(fontSize: 11.sp, color: _textMuted)),
                    ],
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  // ---------------------------------------------------------- Users by role

  Widget _usersByRoleCard(Map<String, dynamic> s) {
    final byRole = Map<String, dynamic>.from((s['users_by_role'] as Map?) ?? {});
    final total = byRole.values.fold<int>(0, (a, b) => a + _int(b));
    if (total == 0) return const SizedBox.shrink();
    final roles = _roleOrder.where((r) => _int(byRole[r]) > 0).toList();

    return _card(
      title: 'Users by role',
      subtitle: '$total registered accounts',
      child: Column(
        children: [
          // 100% stacked bar; segments separated by a 2px surface gap.
          ClipRRect(
            borderRadius: BorderRadius.circular(6.r),
            child: SizedBox(
              height: 16.h,
              child: Row(
                children: [
                  for (var i = 0; i < roles.length; i++) ...[
                    if (i > 0) Container(width: 2, color: Theme.of(context).cardColor),
                    Expanded(
                      flex: math.max(1, (_int(byRole[roles[i]]) * 1000 / total).round()),
                      child: Container(color: _series[_roleOrder.indexOf(roles[i])]),
                    ),
                  ],
                ],
              ),
            ),
          ),
          SizedBox(height: 12.h),
          ...roles.map((r) {
            final count = _int(byRole[r]);
            return Padding(
              padding: EdgeInsets.symmetric(vertical: 4.h),
              child: Row(
                children: [
                  Container(
                    width: 10.w,
                    height: 10.w,
                    decoration: BoxDecoration(
                      color: _series[_roleOrder.indexOf(r)],
                      borderRadius: BorderRadius.circular(3.r),
                    ),
                  ),
                  SizedBox(width: 8.w),
                  Expanded(child: Text(kAdminRoleLabels[r] ?? r, style: TextStyle(fontSize: 13.sp, color: _textPrimary))),
                  Text('$count', style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w700, color: _textPrimary)),
                  SizedBox(
                    width: 52.w,
                    child: Text(
                      '${(count * 100 / total).toStringAsFixed(0)}%',
                      textAlign: TextAlign.right,
                      style: TextStyle(fontSize: 12.sp, color: _textMuted),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  // ------------------------------------------------------- Request statuses

  Widget _requestsCard(Map<String, dynamic> s) {
    final byStatus = Map<String, dynamic>.from((s['requests_by_status'] as Map?) ?? {});
    final total = _int(s['total_blood_requests']);
    const statuses = [
      ('PENDING', 'Pending', Icons.hourglass_top, AppTheme.warning),
      ('APPROVED', 'Approved', Icons.thumb_up_alt_outlined, AppTheme.accentColor),
      ('CONFIRMED', 'Confirmed', Icons.verified_outlined, AppTheme.accentColor),
      ('FULFILLED', 'Fulfilled', Icons.check_circle_outline, AppTheme.success),
      ('REJECTED', 'Rejected', Icons.cancel_outlined, AppTheme.error),
      ('CANCELLED', 'Cancelled', Icons.block, Colors.blueGrey),
    ];
    final fulfilled = _int(byStatus['FULFILLED']);

    return _card(
      title: 'Blood requests',
      subtitle: total == 0
          ? 'No requests yet'
          : '$total total • ${(fulfilled * 100 / total).toStringAsFixed(0)}% fulfilled',
      child: total == 0
          ? _empty('Requests will appear here once patients submit them.')
          : Column(
              children: statuses.map((st) {
                final count = _int(byStatus[st.$1]);
                return Padding(
                  padding: EdgeInsets.symmetric(vertical: 5.h),
                  child: Row(
                    children: [
                      Icon(st.$3, size: 16.sp, color: st.$4),
                      SizedBox(width: 8.w),
                      SizedBox(width: 78.w, child: Text(st.$2, style: TextStyle(fontSize: 13.sp, color: _textPrimary))),
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4.r),
                          child: LinearProgressIndicator(
                            value: count / total,
                            minHeight: 8.h,
                            color: st.$4,
                            backgroundColor: _gridColor.withOpacity(0.35),
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 36.w,
                        child: Text('$count',
                            textAlign: TextAlign.right,
                            style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w700, color: _textPrimary),),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
    );
  }

  // ------------------------------------------------- Hospital subscriptions

  Widget _hospitalsCard(Map<String, dynamic> s) {
    final st = (s['hospital_status'] as Map?) ?? {};
    final active = _int(st['active']);
    final expired = _int(st['expired']);
    final deactivated = _int(st['deactivated']);
    final total = active + expired + deactivated;

    Widget cell(String label, int value, Color color, IconData icon) => Expanded(
          child: Container(
            padding: EdgeInsets.symmetric(vertical: 10.h),
            margin: EdgeInsets.symmetric(horizontal: 3.w),
            decoration: BoxDecoration(color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(12.r)),
            child: Column(
              children: [
                Icon(icon, size: 18.sp, color: color),
                SizedBox(height: 4.h),
                Text('$value', style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.w800, color: _textPrimary)),
                Text(label, style: TextStyle(fontSize: 11.sp, color: _textMuted)),
              ],
            ),
          ),
        );

    return _card(
      title: 'Hospital subscriptions',
      subtitle: total == 0 ? 'No hospitals registered' : '$active of $total hospitals currently active',
      child: Column(
        children: [
          if (total > 0) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(6.r),
              child: LinearProgressIndicator(
                value: active / total,
                minHeight: 10.h,
                color: AppTheme.success,
                backgroundColor: _gridColor.withOpacity(0.35),
              ),
            ),
            SizedBox(height: 12.h),
          ],
          Row(
            children: [
              cell('Active', active, AppTheme.success, Icons.check_circle_outline),
              cell('Expired', expired, AppTheme.warning, Icons.schedule),
              cell('Deactivated', deactivated, AppTheme.error, Icons.block),
            ],
          ),
        ],
      ),
    );
  }

  // --------------------------------------------------------------- Revenue

  Widget _revenueCard(Map<String, dynamic> s) {
    final total = _num(s['total_revenue']);
    final subs = _num(s['subscription_revenue']);
    final reqs = _num(s['request_revenue']);
    final labels = _monthLabels(s);
    final monthly = ((s['monthly_revenue'] as List?) ?? []).map(_num).toList();
    final subColor = _series[0];
    final reqColor = _series[1];
    final maxY = _niceMax(monthly.fold<double>(0, math.max));

    return _card(
      title: 'Revenue',
      subtitle: 'Successful payments only',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_money(total), style: TextStyle(fontSize: 26.sp, fontWeight: FontWeight.w800, color: _textPrimary)),
          SizedBox(height: 12.h),
          if (total > 0)
            ClipRRect(
              borderRadius: BorderRadius.circular(6.r),
              child: SizedBox(
                height: 12.h,
                child: Row(
                  children: [
                    if (subs > 0) Expanded(flex: math.max(1, (subs * 1000 / total).round()), child: Container(color: subColor)),
                    if (subs > 0 && reqs > 0) Container(width: 2, color: Theme.of(context).cardColor),
                    if (reqs > 0) Expanded(flex: math.max(1, (reqs * 1000 / total).round()), child: Container(color: reqColor)),
                  ],
                ),
              ),
            ),
          SizedBox(height: 10.h),
          Wrap(
            spacing: 16.w,
            runSpacing: 6.h,
            children: [
              _legendItem(subColor, 'Subscriptions', value: _money(subs)),
              _legendItem(reqColor, 'Blood requests', value: _money(reqs)),
            ],
          ),
          if (labels.isNotEmpty && monthly.any((v) => v > 0)) ...[
            SizedBox(height: 18.h),
            Text('Monthly', style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w600, color: _textMuted)),
            SizedBox(height: 8.h),
            SizedBox(
              height: 140.h,
              child: BarChart(
                BarChartData(
                  minY: 0,
                  maxY: maxY,
                  gridData: _grid,
                  borderData: FlBorderData(show: false),
                  titlesData: _titles(labels, maxY, money: true),
                  barGroups: [
                    for (var i = 0; i < monthly.length; i++)
                      BarChartGroupData(
                        x: i,
                        barRods: [
                          BarChartRodData(
                            toY: monthly[i],
                            width: 18.w,
                            color: _series[2],
                            borderRadius: BorderRadius.vertical(top: Radius.circular(4.r)),
                          ),
                        ],
                      ),
                  ],
                  barTouchData: BarTouchData(
                    touchTooltipData: BarTouchTooltipData(
                      tooltipBgColor: _tooltipBg,
                      tooltipRoundedRadius: 8,
                      getTooltipItem: (group, _, rod, __) => BarTooltipItem(
                        '${labels[group.x]}\n',
                        TextStyle(color: Colors.white70, fontSize: 11.sp),
                        children: [
                          TextSpan(
                            text: _money(rod.toY),
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12.sp),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // --------------------------------------------------------- Top hospitals

  Widget _topHospitalsCard(Map<String, dynamic> s) {
    final top = ((s['top_hospitals'] as List?) ?? []).cast<Map<String, dynamic>>();
    final max = top.map((e) => _int(e['donations'])).fold<int>(1, math.max);
    return _card(
      title: 'Top hospitals',
      subtitle: 'By number of donations collected',
      child: Column(
        children: [
          for (var i = 0; i < top.length; i++)
            Padding(
              padding: EdgeInsets.symmetric(vertical: 6.h),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 12.r,
                    backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
                    child: Text('${i + 1}',
                        style: TextStyle(fontSize: 11.sp, fontWeight: FontWeight.w700, color: AppTheme.primaryColor),),
                  ),
                  SizedBox(width: 10.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(top[i]['name'] ?? '',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w600, color: _textPrimary),),
                        SizedBox(height: 4.h),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4.r),
                          child: LinearProgressIndicator(
                            value: _int(top[i]['donations']) / max,
                            minHeight: 6.h,
                            color: _series[0],
                            backgroundColor: _gridColor.withOpacity(0.35),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: 12.w),
                  Text('${_int(top[i]['donations'])}',
                      style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w700, color: _textPrimary),),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _empty(String text) => Padding(
        padding: EdgeInsets.symmetric(vertical: 12.h),
        child: Center(child: Text(text, textAlign: TextAlign.center, style: TextStyle(fontSize: 12.sp, color: _textMuted))),
      );
}

class _Kpi {
  final IconData icon;
  final String label;
  final String value;
  final String? unit;
  final String detail;
  final bool trendUp;
  final bool alert;

  const _Kpi({
    required this.icon,
    required this.label,
    required this.value,
    required this.detail,
    this.unit,
    this.trendUp = false,
    this.alert = false,
  });
}
