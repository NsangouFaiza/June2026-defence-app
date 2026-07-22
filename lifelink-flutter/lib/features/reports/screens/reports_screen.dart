import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/localization_service.dart';
import '../../../../core/providers/providers.dart';
import '../../../../data/repositories/report_repository.dart';
import '../../../../data/models/donor_model.dart';

class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  String _selectedReportType = 'SUMMARY';
  DateTimeRange? _dateRange;
  final TextEditingController _searchController = TextEditingController();
  Map<String, dynamic>? _reportData;
  bool _isLoading = false;

  final List<Map<String, String>> _reportTypes = [
    {'value': 'SUMMARY', 'label': 'Monthly/Annual Summary'},
    {'value': 'INVENTORY', 'label': 'Blood Inventory Report'},
    {'value': 'EXPIRATION', 'label': 'Blood Expiration Report'},
    {'value': 'DONATION', 'label': 'Donation Report'},
    {'value': 'USAGE', 'label': 'Blood Usage Report'},
    {'value': 'DONOR', 'label': 'Donor Activity Report'},
    {'value': 'REQUEST', 'label': 'Blood Request Report'},
    {'value': 'WASTAGE', 'label': 'Discard/Wastage Report'},
    {'value': 'EMERGENCY', 'label': 'Emergency Request Report'},
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadReportData();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadReportData() async {
    setState(() => _isLoading = true);
    try {
      final repo = ref.read(reportRepositoryProvider);
      final startDateStr = _dateRange != null
          ? "${_dateRange!.start.year}-${_dateRange!.start.month.toString().padLeft(2, '0')}-${_dateRange!.start.day.toString().padLeft(2, '0')}"
          : null;
      final endDateStr = _dateRange != null
          ? "${_dateRange!.end.year}-${_dateRange!.end.month.toString().padLeft(2, '0')}-${_dateRange!.end.day.toString().padLeft(2, '0')}"
          : null;

      final data = await repo.getExplorerReport(
        type: _selectedReportType,
        startDate: startDateStr,
        endDate: endDateStr,
        search: _searchController.text.trim().isNotEmpty ? _searchController.text.trim() : null,
      );

      setState(() {
        _reportData = data;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading report: $e'), backgroundColor: AppTheme.error),
      );
    }
  }

  Future<void> _pickDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now().subtract(const Duration(days: 365 * 2)),
      lastDate: DateTime.now().add(const Duration(days: 90)),
      initialDateRange: _dateRange,
    );
    if (picked != null) {
      setState(() {
        _dateRange = picked;
      });
      _loadReportData();
    }
  }

  String _formatDate(DateTime date) {
    return "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
  }

  @override
  Widget build(BuildContext context) {
    final localization = ref.watch(localizationServiceProvider);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(localization.translate('reports')),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadReportData,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Controls Panel
            Card(
              margin: EdgeInsets.all(12.w),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15.r)),
              child: Padding(
                padding: EdgeInsets.all(12.w),
                child: Column(
                  children: [
                    DropdownButtonFormField<String>(
                      value: _selectedReportType,
                      decoration: const InputDecoration(
                        labelText: 'Report Category',
                        border: OutlineInputBorder(),
                      ),
                      items: _reportTypes
                          .map((type) => DropdownMenuItem(
                                value: type['value'],
                                child: Text(type['label']!),
                              ))
                          .toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setState(() {
                            _selectedReportType = val;
                            _reportData = null;
                          });
                          _loadReportData();
                        }
                      },
                    ),
                    SizedBox(height: 12.h),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _pickDateRange,
                            icon: const Icon(Icons.date_range),
                            label: Text(_dateRange == null
                                ? 'Filter by Date Range'
                                : "${_formatDate(_dateRange!.start)} to ${_formatDate(_dateRange!.end)}"),
                          ),
                        ),
                        if (_dateRange != null)
                          IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              setState(() => _dateRange = null);
                              _loadReportData();
                            },
                          ),
                      ],
                    ),
                    SizedBox(height: 12.h),
                    TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        labelText: 'Search key metrics',
                        hintText: 'e.g. O+, Patient, Hospital',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                            _loadReportData();
                          },
                        ),
                        border: const OutlineInputBorder(),
                      ),
                      onSubmitted: (_) => _loadReportData(),
                    ),
                  ],
                ),
              ),
            ),
            // Results Panel
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _reportData == null
                      ? const Center(child: Text('No data loaded. Use reload to fetch.'))
                      : SingleChildScrollView(
                          padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 4.h),
                          child: _buildReportContent(_reportData!),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReportContent(Map<String, dynamic> data) {
    switch (_selectedReportType) {
      case 'SUMMARY':
        return _buildSummaryReport(data);
      case 'INVENTORY':
        return _buildInventoryReport(data);
      case 'EXPIRATION':
        return _buildExpirationReport(data);
      case 'DONATION':
        return _buildDonationReport(data);
      case 'USAGE':
        return _buildUsageReport(data);
      case 'DONOR':
        return _buildDonorReport(data);
      case 'REQUEST':
        return _buildRequestReport(data);
      case 'WASTAGE':
        return _buildWastageReport(data);
      case 'EMERGENCY':
        return _buildEmergencyReport(data);
      default:
        return const Center(child: Text('Unknown report type'));
    }
  }

  // 1. SUMMARY REPORT VIEW
  Widget _buildSummaryReport(Map<String, dynamic> data) {
    final summary = data['summary'] as Map<String, dynamic>? ?? {};
    final totalDonations = summary['total_donations']?.toString() ?? '0';
    final unitsCollected = summary['units_collected']?.toString() ?? '0';
    final unitsIssued = summary['units_issued']?.toString() ?? '0';
    final currentStock = summary['current_stock']?.toString() ?? '0';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildSectionHeader('Overall Blood Bank Summary'),
        SizedBox(height: 12.h),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          crossAxisSpacing: 12.w,
          mainAxisSpacing: 12.h,
          childAspectRatio: 1.3,
          children: [
            _buildQuickStatCard('Total Donations', totalDonations, Icons.volunteer_activism, AppTheme.primaryColor),
            _buildQuickStatCard('Units Collected', unitsCollected, Icons.opacity, AppTheme.accentColor),
            _buildQuickStatCard('Units Issued', unitsIssued, Icons.done_all, AppTheme.success),
            _buildQuickStatCard('Current Stock', currentStock, Icons.inventory_2_outlined, Colors.amber),
          ],
        ),
        SizedBox(height: 20.h),
        Card(
          child: Padding(
            padding: EdgeInsets.all(16.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Stock Level Health Indicator', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                SizedBox(height: 16.h),
                LinearProgressIndicator(
                  value: (double.tryParse(currentStock) ?? 0) / 100.clamp(1, 1000000),
                  color: AppTheme.success,
                  backgroundColor: Colors.grey.shade200,
                  minHeight: 12.h,
                ),
                SizedBox(height: 8.h),
                Text('Indicator scales up to 100 units total. Stock is currently at $currentStock units.',
                    style: TextStyle(fontSize: 11.sp, color: AppTheme.onSurfaceVariant)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // 2. INVENTORY REPORT VIEW
  Widget _buildInventoryReport(Map<String, dynamic> data) {
    final rows = data['rows'] as List<dynamic>? ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildSectionHeader('Stock by Blood Type & Status'),
        SizedBox(height: 12.h),
        if (rows.isEmpty)
          _buildEmptyRowState()
        else ...[
          _buildBarChart(
            rows.map((r) => r['blood_group'] as String).toList(),
            rows.map((r) => (r['total'] as num).toDouble()).toList(),
          ),
          SizedBox(height: 16.h),
          _buildTable([
            'Blood Group',
            'Status',
            'Total Quantity'
          ], [
            ...rows.map((r) => [
                  r['blood_group']?.toString() ?? 'N/A',
                  r['status']?.toString().toUpperCase() ?? 'N/A',
                  "${r['total']?.toString() ?? '0'} unit(s)",
                ])
          ]),
        ],
      ],
    );
  }

  // 3. EXPIRATION REPORT VIEW
  Widget _buildExpirationReport(Map<String, dynamic> data) {
    final expired = data['expired'] as List<dynamic>? ?? [];
    final expiringSoon = data['expiring_soon'] as List<dynamic>? ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildSectionHeader('Already Expired Units'),
        SizedBox(height: 12.h),
        if (expired.isEmpty)
          const Card(child: Padding(padding: EdgeInsets.all(12), child: Text('No expired units found.')))
        else
          _buildTable([
            'ID',
            'Hospital',
            'Group',
            'Qty',
            'Exp. Date'
          ], [
            ...expired.map((r) => [
                  r['id']?.toString() ?? 'N/A',
                  r['hospital']?.toString() ?? 'N/A',
                  r['blood_group']?.toString() ?? 'N/A',
                  r['quantity']?.toString() ?? '0',
                  r['expiration_date']?.toString() ?? 'N/A',
                ])
          ]),
        SizedBox(height: 20.h),
        _buildSectionHeader('Expiring Soon (Next 30 Days)'),
        SizedBox(height: 12.h),
        if (expiringSoon.isEmpty)
          const Card(child: Padding(padding: EdgeInsets.all(12), child: Text('No units expiring soon.')))
        else
          _buildTable([
            'ID',
            'Hospital',
            'Group',
            'Qty',
            'Timeline'
          ], [
            ...expiringSoon.map((r) => [
                  r['id']?.toString() ?? 'N/A',
                  r['hospital']?.toString() ?? 'N/A',
                  r['blood_group']?.toString() ?? 'N/A',
                  r['quantity']?.toString() ?? '0',
                  r['status']?.toString() ?? 'N/A',
                ])
          ]),
      ],
    );
  }

  // 4. DONATION REPORT VIEW
  Widget _buildDonationReport(Map<String, dynamic> data) {
    final rows = data['rows'] as List<dynamic>? ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildSectionHeader('Completed Donations by Date'),
        SizedBox(height: 12.h),
        if (rows.isEmpty)
          _buildEmptyRowState()
        else ...[
          _buildBarChart(
            rows.map((r) => r['created_at__date']?.toString() ?? '').toList(),
            rows.map((r) => (r['count'] as num).toDouble()).toList(),
          ),
          SizedBox(height: 16.h),
          _buildTable([
            'Date',
            'Total Donations',
            'Total Volume (mL)'
          ], [
            ...rows.map((r) => [
                  r['created_at__date']?.toString() ?? 'N/A',
                  r['count']?.toString() ?? '0',
                  "${r['total_ml']?.toString() ?? '0'} mL",
                ])
          ]),
        ]
      ],
    );
  }

  // 5. BLOOD USAGE REPORT VIEW
  Widget _buildUsageReport(Map<String, dynamic> data) {
    final rows = data['rows'] as List<dynamic>? ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildSectionHeader('Blood Issued to Hospitals / Patients'),
        SizedBox(height: 12.h),
        if (rows.isEmpty)
          _buildEmptyRowState()
        else ...[
          _buildBarChart(
            rows.map((r) => "${r['hospital__name']} (${r['blood_group']})").toList(),
            rows.map((r) => (r['total_issued'] as num).toDouble()).toList(),
          ),
          SizedBox(height: 16.h),
          _buildTable([
            'Hospital / Destination',
            'Blood Group',
            'Issued Quantity'
          ], [
            ...rows.map((r) => [
                  r['hospital__name']?.toString() ?? 'N/A',
                  r['blood_group']?.toString() ?? 'N/A',
                  "${r['total_issued']?.toString() ?? '0'} unit(s)",
                ])
          ]),
        ]
      ],
    );
  }

  // 6. DONOR ACTIVITY REPORT VIEW
  Widget _buildDonorReport(Map<String, dynamic> data) {
    final summary = data['summary'] as Map<String, dynamic>? ?? {};
    final donors = data['donors'] as List<dynamic>? ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildSectionHeader('Donor Metrics Overview'),
        SizedBox(height: 12.h),
        Row(
          children: [
            Expanded(
              child: _buildQuickStatCard('Total Registered', summary['total']?.toString() ?? '0', Icons.people, AppTheme.primaryColor),
            ),
            SizedBox(width: 8.w),
            Expanded(
              child: _buildQuickStatCard('Eligible Donors', summary['eligible']?.toString() ?? '0', Icons.check_circle_outline, AppTheme.success),
            ),
          ],
        ),
        SizedBox(height: 16.h),
        _buildSectionHeader('Registered Donors Directory'),
        SizedBox(height: 12.h),
        if (donors.isEmpty)
          _buildEmptyRowState()
        else
          _buildTable([
            'Name',
            'Group',
            'Contact',
            'Eligible',
            'Donations'
          ], [
            ...donors.map((r) => [
                  r['name']?.toString() ?? 'N/A',
                  r['blood_group']?.toString() ?? 'N/A',
                  r['phone']?.toString() ?? 'N/A',
                  r['is_eligible'] == true ? 'Yes' : 'No',
                  r['total_donations']?.toString() ?? '0',
                ])
          ]),
      ],
    );
  }

  // 7. BLOOD REQUEST REPORT VIEW
  Widget _buildRequestReport(Map<String, dynamic> data) {
    final rows = data['rows'] as List<dynamic>? ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildSectionHeader('Blood Request Overview'),
        SizedBox(height: 12.h),
        if (rows.isEmpty)
          _buildEmptyRowState()
        else ...[
          _buildBarChart(
            rows.map((r) => r['status']?.toString() ?? '').toList(),
            rows.map((r) => (r['count'] as num).toDouble()).toList(),
          ),
          SizedBox(height: 16.h),
          _buildTable([
            'Status',
            'Total Requests',
            'Total Requested Units'
          ], [
            ...rows.map((r) => [
                  r['status']?.toString().toUpperCase() ?? 'N/A',
                  r['count']?.toString() ?? '0',
                  "${r['total_qty']?.toString() ?? '0'} unit(s)",
                ])
          ]),
        ]
      ],
    );
  }

  // 8. DISCARD/WASTAGE REPORT VIEW
  Widget _buildWastageReport(Map<String, dynamic> data) {
    final rows = data['rows'] as List<dynamic>? ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildSectionHeader('Discarded / Wasted Blood Units'),
        SizedBox(height: 12.h),
        if (rows.isEmpty)
          _buildEmptyRowState()
        else
          _buildTable([
            'ID',
            'Hospital',
            'Group',
            'Qty',
            'Wastage Reason'
          ], [
            ...rows.map((r) => [
                  r['id']?.toString() ?? 'N/A',
                  r['hospital']?.toString() ?? 'N/A',
                  r['blood_group']?.toString() ?? 'N/A',
                  r['quantity']?.toString() ?? '0',
                  r['status']?.toString().toUpperCase() ?? 'N/A',
                ])
          ]),
      ],
    );
  }

  // 9. EMERGENCY REQUEST REPORT VIEW
  Widget _buildEmergencyReport(Map<String, dynamic> data) {
    final rows = data['rows'] as List<dynamic>? ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildSectionHeader('Emergency Request Directory'),
        SizedBox(height: 12.h),
        if (rows.isEmpty)
          _buildEmptyRowState()
        else
          _buildTable([
            'ID',
            'Patient',
            'Hospital',
            'Group',
            'Qty',
            'Status'
          ], [
            ...rows.map((r) => [
                  r['id']?.toString() ?? 'N/A',
                  r['patient']?.toString() ?? 'N/A',
                  r['hospital']?.toString() ?? 'N/A',
                  r['blood_group']?.toString() ?? 'N/A',
                  r['quantity']?.toString() ?? '0',
                  r['status']?.toString() ?? 'N/A',
                ])
          ]),
      ],
    );
  }

  // HELPER WIDGETS
  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 4.w),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 16.sp,
          fontWeight: FontWeight.bold,
          color: AppTheme.onSurface,
        ),
      ),
    );
  }

  Widget _buildEmptyRowState() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(24.w),
        child: const Center(
          child: Text('No data found matching date range or search query.'),
        ),
      ),
    );
  }

  Widget _buildQuickStatCard(String label, String value, IconData icon, Color color) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
      child: Padding(
        padding: EdgeInsets.all(12.w),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 24.sp, color: color),
            SizedBox(height: 6.h),
            Text(
              value,
              style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold, color: color),
            ),
            SizedBox(height: 2.h),
            Text(
              label,
              style: TextStyle(fontSize: 10.sp, color: AppTheme.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTable(List<String> headers, List<List<String>> rows) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowColor: MaterialStateProperty.all(AppTheme.primaryColor.withOpacity(0.05)),
          columns: headers
              .map((h) => DataColumn(
                    label: Text(
                      h,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ))
              .toList(),
          rows: rows
              .map((row) => DataRow(
                    cells: row.map((cell) => DataCell(Text(cell))).toList(),
                  ))
              .toList(),
        ),
      ),
    );
  }

  Widget _buildBarChart(List<String> labels, List<double> values) {
    if (labels.isEmpty || values.isEmpty) return const SizedBox.shrink();

    // Map to BarChart rods
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
      child: Padding(
        padding: EdgeInsets.all(16.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Graph Overview', style: TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(height: 16.h),
            SizedBox(
              height: 180.h,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  barGroups: values.asMap().entries.map((entry) {
                    return BarChartGroupData(
                      x: entry.key,
                      barRods: [
                        BarChartRodData(
                          toY: entry.value,
                          color: AppTheme.primaryColor,
                          width: 14.w,
                          borderRadius: BorderRadius.circular(4.r),
                        ),
                      ],
                    );
                  }).toList(),
                  titlesData: FlTitlesData(
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          final index = value.toInt();
                          if (index < 0 || index >= labels.length) return const Text('');
                          // Truncate long labels
                          final lbl = labels[index];
                          final displayLbl = lbl.length > 8 ? "${lbl.substring(0, 6)}.." : lbl;
                          return Padding(
                            padding: const EdgeInsets.only(top: 6.0),
                            child: Text(
                              displayLbl,
                              style: const TextStyle(fontSize: 8),
                            ),
                          );
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  gridData: FlGridData(show: false),
                  borderData: FlBorderData(show: false),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
