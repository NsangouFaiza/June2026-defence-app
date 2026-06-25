import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/localization_service.dart';
import '../../../../core/providers/providers.dart';
import '../../../../data/repositories/report_repository.dart';

class ReportsScreen extends ConsumerWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final localization = ref.watch(localizationServiceProvider);
    final reportRepo = ref.watch(reportRepositoryProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(localization.translate('reports')),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(16.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Monthly Donations Chart
              Card(
                child: Padding(
                  padding: EdgeInsets.all(16.w),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        localization.translate('monthly_donations'),
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      SizedBox(height: 16.h),
                      SizedBox(
                        height: 200.h,
                        child: FutureBuilder<Map<String, dynamic>>(
                          future: reportRepo.getMonthlyDonations(),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState == ConnectionState.waiting) {
                              return const Center(child: CircularProgressIndicator());
                            }
                            if (snapshot.hasError || snapshot.data == null) {
                              return const Center(child: Text('No data available'));
                            }

                            final data = snapshot.data!;
                            final labels = data['labels'] as List<String>;
                            final values = data['values'] as List<int>;

                            return BarChart(
                              BarChartData(
                                alignment: BarChartAlignment.spaceAround,
                                barGroups: values.asMap().entries.map((entry) {
                                  return BarChartGroupData(
                                    x: entry.key,
                                    barRods: [
                                      BarChartRodData(
                                        toY: entry.value.toDouble(),
                                        color: AppTheme.primaryColor,
                                        width: 16.w,
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
                                        if (value.toInt() >= labels.length) return const Text('');
                                        return Padding(
                                          padding: const EdgeInsets.only(top: 8.0),
                                          child: Text(
                                            labels[value.toInt()],
                                            style: const TextStyle(fontSize: 10),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                  leftTitles: AxisTitles(
                                    sideTitles: SideTitles(showTitles: false),
                                  ),
                                  topTitles: AxisTitles(
                                    sideTitles: SideTitles(showTitles: false),
                                  ),
                                  rightTitles: AxisTitles(
                                    sideTitles: SideTitles(showTitles: false),
                                  ),
                                ),
                                gridData: FlGridData(show: false),
                                borderData: FlBorderData(show: false),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 16.h),

              // Blood Stock by Group
              Card(
                child: Padding(
                  padding: EdgeInsets.all(16.w),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        localization.translate('blood_stock_by_group'),
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      SizedBox(height: 16.h),
                      SizedBox(
                        height: 200.h,
                        child: FutureBuilder<Map<String, int>>(
                          future: reportRepo.getBloodStockByGroup(),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState == ConnectionState.waiting) {
                              return const Center(child: CircularProgressIndicator());
                            }
                            if (snapshot.hasError || snapshot.data == null) {
                              return const Center(child: Text('No data available'));
                            }

                            final stock = snapshot.data!;
                            final total = stock.values.fold(0, (sum, val) => sum + val);

                            return PieChart(
                              PieChartData(
                                sections: stock.entries.map((entry) {
                                  final percentage = (entry.value / total) * 100;
                                  return PieChartSectionData(
                                    color: _getColorForBloodGroup(entry.key),
                                    value: entry.value.toDouble(),
                                    title: '${percentage.toStringAsFixed(1)}%',
                                    radius: 60.r,
                                    titleStyle: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  );
                                }).toList(),
                                sectionsSpace: 2,
                                centerSpaceRadius: 40.r,
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 16.h),

              // Statistics Cards
              FutureBuilder<Map<String, dynamic>>(
                future: reportRepo.getStatistics(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError || snapshot.data == null) {
                    return const SizedBox.shrink();
                  }

                  final stats = snapshot.data!;
                  return GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 2,
                    mainAxisSpacing: 16.h,
                    crossAxisSpacing: 16.w,
                    childAspectRatio: 1.5,
                    children: [
                      _buildStatCard(
                        context,
                        localization.translate('total_donations'),
                        stats['total_donations']?.toString() ?? '0',
                        Icons.volunteer_activism,
                        AppTheme.primaryColor,
                      ),
                      _buildStatCard(
                        context,
                        localization.translate('total_donors'),
                        stats['total_donors']?.toString() ?? '0',
                        Icons.people,
                        AppTheme.success,
                      ),
                      _buildStatCard(
                        context,
                        localization.translate('active_requests'),
                        stats['active_requests']?.toString() ?? '0',
                        Icons.assignment,
                        AppTheme.warning,
                      ),
                      _buildStatCard(
                        context,
                        localization.translate('lives_saved'),
                        stats['lives_saved']?.toString() ?? '0',
                        Icons.favorite,
                        AppTheme.error,
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard(
    BuildContext context,
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16.w),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 32.w, color: color),
            SizedBox(height: 8.h),
            Text(
              value,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
            ),
            Text(
              title,
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Color _getColorForBloodGroup(String bloodGroup) {
    switch (bloodGroup) {
      case 'A+':
        return Colors.red;
      case 'A-':
        return Colors.redAccent;
      case 'B+':
        return Colors.blue;
      case 'B-':
        return Colors.blueAccent;
      case 'AB+':
        return Colors.purple;
      case 'AB-':
        return Colors.purpleAccent;
      case 'O+':
        return Colors.green;
      case 'O-':
        return Colors.greenAccent;
      default:
        return Colors.grey;
    }
  }
}
