import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/localization_service.dart';
import '../../../../core/providers/providers.dart';
import '../../../../data/repositories/community_repository.dart';

class ImpactStatisticsScreen extends ConsumerWidget {
  const ImpactStatisticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final localization = ref.watch(localizationServiceProvider);
    final communityRepo = ref.watch(communityRepositoryProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(localization.translate('impact_statistics')),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(16.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Impact Counter
              FutureBuilder<Map<String, dynamic>>(
                future: communityRepo.getImpactStatistics(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError || snapshot.data == null) {
                    return const SizedBox.shrink();
                  }

                  final stats = snapshot.data!;
                  return Column(
                    children: [
                      Container(
                        padding: EdgeInsets.all(24.w),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              AppTheme.primaryColor,
                              AppTheme.primaryColor.withOpacity(0.7),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(20.r),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              Icons.favorite,
                              size: 48.w,
                              color: Colors.white,
                            ),
                            SizedBox(height: 16.h),
                            Text(
                              '${stats['lives_saved'] ?? 0}',
                              style: TextStyle(
                                fontSize: 48.sp,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            Text(
                              localization.translate('lives_saved'),
                              style: TextStyle(
                                fontSize: 16.sp,
                                color: Colors.white.withOpacity(0.9),
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 24.h),
                      GridView.count(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisCount: 2,
                        mainAxisSpacing: 16.h,
                        crossAxisSpacing: 16.w,
                        childAspectRatio: 1.5,
                        children: [
                          _buildImpactCard(
                            context,
                            '${stats['total_donations'] ?? 0}',
                            localization.translate('total_donations'),
                            Icons.volunteer_activism,
                            AppTheme.success,
                          ),
                          _buildImpactCard(
                            context,
                            '${stats['total_units'] ?? 0}',
                            localization.translate('total_units'),
                            Icons.opacity,
                            Colors.blue,
                          ),
                          _buildImpactCard(
                            context,
                            '${stats['donation_streak'] ?? 0}',
                            localization.translate('donation_streak'),
                            Icons.local_fire_department,
                            AppTheme.warning,
                          ),
                          _buildImpactCard(
                            context,
                            '#${stats['community_rank'] ?? 'N/A'}',
                            localization.translate('community_rank'),
                            Icons.emoji_events,
                            Colors.purple,
                          ),
                        ],
                      ),
                    ],
                  );
                },
              ),
              SizedBox(height: 24.h),

              // Monthly Impact Chart
              Card(
                child: Padding(
                  padding: EdgeInsets.all(16.w),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        localization.translate('monthly_impact'),
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      SizedBox(height: 16.h),
                      SizedBox(
                        height: 200.h,
                        child: FutureBuilder<Map<String, dynamic>>(
                          future: communityRepo.getMonthlyImpact(),
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

                            return LineChart(
                              LineChartData(
                                lineBarsData: [
                                  LineChartBarData(
                                    spots: values.asMap().entries.map((entry) {
                                      return FlSpot(entry.key.toDouble(), entry.value.toDouble());
                                    }).toList(),
                                    isCurved: true,
                                    color: AppTheme.primaryColor,
                                    barWidth: 3.w,
                                    dotData: FlDotData(show: true),
                                    belowBarData: BarAreaData(
                                      show: true,
                                      color: AppTheme.primaryColor.withOpacity(0.2),
                                    ),
                                  ),
                                ],
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

              // Hospital Contributions
              FutureBuilder<List<dynamic>>(
                future: communityRepo.getHospitalContributions(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError || snapshot.data == null) {
                    return const SizedBox.shrink();
                  }

                  final hospitals = snapshot.data!;
                  return Card(
                    child: Padding(
                      padding: EdgeInsets.all(16.w),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            localization.translate('hospital_contributions'),
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          SizedBox(height: 16.h),
                          ...hospitals.map((hospital) {
                            return Padding(
                              padding: EdgeInsets.only(bottom: 12.h),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          hospital['name'] ?? 'Unknown',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                      Text(
                                        '${hospital['donations'] ?? 0} donations',
                                        style: const TextStyle(
                                          color: AppTheme.primaryColor,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: 4.h),
                                  LinearProgressIndicator(
                                    value: (hospital['donations'] ?? 0) / (hospitals.first['donations'] ?? 1),
                                    backgroundColor: Colors.grey[300],
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      AppTheme.primaryColor,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImpactCard(
    BuildContext context,
    String value,
    String label,
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
              label,
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
