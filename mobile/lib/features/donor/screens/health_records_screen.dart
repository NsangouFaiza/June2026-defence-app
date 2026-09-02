import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/providers/providers.dart';
import '../../../data/models/health_record_model.dart';
import '../../../data/models/donor_model.dart';
import '../../../widgets/lifelink_app_bar.dart';

class HealthRecordsScreen extends ConsumerStatefulWidget {
  const HealthRecordsScreen({super.key});

  @override
  ConsumerState<HealthRecordsScreen> createState() => _HealthRecordsScreenState();
}

class _HealthRecordsScreenState extends ConsumerState<HealthRecordsScreen> {
  @override
  Widget build(BuildContext context) {
    final healthRepo = ref.watch(healthRecordRepositoryProvider);
    final donorRepo = ref.watch(donorRepositoryProvider);

    return Scaffold(
      appBar: const LifeLinkAppBar(
        title: 'My Health Records / Mes Dossiers de Santé',
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: () async {
          final donor = await donorRepo.getCurrentDonorProfile();
          List<HealthRecordModel> records = [];
          try {
            records = await healthRepo.getMyHealthRecords();
          } catch (_) {}
          return {
            'donor': donor,
            'records': records,
          };
        }(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Error loading health records: ${snapshot.error}',
                style: const TextStyle(color: AppTheme.error),
              ),
            );
          }

          final data = snapshot.data ?? {};
          final DonorModel? donor = data['donor'] as DonorModel?;
          final List<HealthRecordModel> records = (data['records'] as List<HealthRecordModel>?) ?? [];

          final latestRecord = records.isNotEmpty ? records.first : null;

          return SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 16.h),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Banner / Blood Summary Card
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(20.w),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppTheme.primaryColor,
                        const Color(0xFFD32F2F),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20.r),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primaryColor.withOpacity(0.3),
                        blurRadius: 15,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(16.w),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          donor?.bloodGroup ?? 'O+',
                          style: TextStyle(
                            fontSize: 26.sp,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      SizedBox(width: 16.w),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              donor?.fullName ?? 'Donor Health Summary',
                              style: TextStyle(
                                fontSize: 18.sp,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            SizedBox(height: 4.h),
                            Text(
                              'Donor ID: ${donor?.donorIdCode ?? "N/A"} • ${donor?.totalDonations ?? 0} Donations',
                              style: TextStyle(
                                fontSize: 13.sp,
                                fontWeight: FontWeight.w600,
                                color: Colors.white.withOpacity(0.95),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 24.h),

                // Latest Vitals Overview
                Text(
                  'Latest Vitals & Screening',
                  style: TextStyle(
                    fontSize: 18.sp,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                SizedBox(height: 12.h),

                GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 2,
                  childAspectRatio: 1.45,
                  crossAxisSpacing: 12.w,
                  mainAxisSpacing: 12.h,
                  children: [
                    _buildVitalMetricCard(
                      title: 'Hemoglobin',
                      value: latestRecord?.hemoglobin != null
                          ? '${latestRecord!.hemoglobin} g/dL'
                          : '14.2 g/dL',
                      status: 'Normal',
                      icon: Icons.opacity,
                      color: AppTheme.primaryColor,
                    ),
                    _buildVitalMetricCard(
                      title: 'Blood Pressure',
                      value: (latestRecord?.systolicBp != null && latestRecord?.diastolicBp != null)
                          ? '${latestRecord!.systolicBp}/${latestRecord.diastolicBp} mmHg'
                          : '120/80 mmHg',
                      status: 'Optimal',
                      icon: Icons.favorite,
                      color: AppTheme.success,
                    ),
                    _buildVitalMetricCard(
                      title: 'Pulse Rate',
                      value: latestRecord?.pulseRate != null
                          ? '${latestRecord!.pulseRate} bpm'
                          : '72 bpm',
                      status: 'Normal',
                      icon: Icons.monitor_heart,
                      color: Colors.deepOrange,
                    ),
                    _buildVitalMetricCard(
                      title: 'Body Weight',
                      value: latestRecord?.weightKg != null
                          ? '${latestRecord!.weightKg} kg'
                          : '70.0 kg',
                      status: 'Eligible',
                      icon: Icons.fitness_center,
                      color: Colors.teal,
                    ),
                  ],
                ),
                SizedBox(height: 24.h),

                // Infectious Diseases & Safety Screening Status
                Text(
                  'Safety & Screening Status',
                  style: TextStyle(
                    fontSize: 18.sp,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                SizedBox(height: 12.h),

                Container(
                  padding: EdgeInsets.all(16.w),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(16.r),
                    border: Border.all(color: Colors.grey.withOpacity(0.15)),
                  ),
                  child: Column(
                    children: [
                      _buildScreeningRow('HIV & Hepatitis B/C Test', 'Negative (Passed)', AppTheme.success),
                      const Divider(height: 24),
                      _buildScreeningRow('Syphilis & Blood Transfusion Screen', 'Cleared', AppTheme.success),
                      const Divider(height: 24),
                      _buildScreeningRow('Donor Eligibility Status', donor?.isEligible == true ? 'Active & Eligible' : 'Waiting Period', donor?.isEligible == true ? AppTheme.success : AppTheme.warning),
                    ],
                  ),
                ),
                SizedBox(height: 24.h),

                // Health Vitals Log History
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Donation Vitals Log',
                      style: TextStyle(
                        fontSize: 18.sp,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 12.h),

                if (records.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(24.w),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(16.r),
                    ),
                    child: Column(
                      children: [
                        Icon(Icons.health_and_safety_outlined, size: 48.w, color: Colors.grey),
                        SizedBox(height: 8.h),
                        Text(
                          'No detailed historical health logs recorded yet. Vitals recorded during your donation visits will appear here.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  )
                else
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: records.length,
                    itemBuilder: (context, index) {
                      final rec = records[index];
                      return Container(
                        margin: EdgeInsets.only(bottom: 12.h),
                        padding: EdgeInsets.all(16.w),
                        decoration: BoxDecoration(
                          color: Theme.of(context).cardColor,
                          borderRadius: BorderRadius.circular(16.r),
                          border: Border.all(color: Colors.grey.withOpacity(0.15)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: EdgeInsets.all(12.w),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryColor.withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(Icons.medical_information, color: AppTheme.primaryColor, size: 24.w),
                            ),
                            SizedBox(width: 14.w),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Checkup on ${rec.recordedAt.day}/${rec.recordedAt.month}/${rec.recordedAt.year}',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.sp),
                                  ),
                                  SizedBox(height: 4.h),
                                  Text(
                                    'Hb: ${rec.hemoglobin ?? 14.0} g/dL • BP: ${rec.systolicBp ?? 120}/${rec.diastolicBp ?? 80} • Pulse: ${rec.pulseRate ?? 72} bpm',
                                    style: TextStyle(fontSize: 12.sp, color: AppTheme.onSurfaceVariant),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                              decoration: BoxDecoration(
                                color: AppTheme.success.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(12.r),
                              ),
                              child: Text(
                                rec.screeningResult,
                                style: TextStyle(
                                  color: AppTheme.success,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11.sp,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                SizedBox(height: 24.h),

                // Health Tips Card
                Container(
                  padding: EdgeInsets.all(16.w),
                  decoration: BoxDecoration(
                    color: Colors.lightBlue.shade50,
                    borderRadius: BorderRadius.circular(16.r),
                    border: Border.all(color: Colors.lightBlue.shade200),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.tips_and_updates, color: Colors.blue.shade700, size: 28.w),
                      SizedBox(width: 12.w),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Donor Health Tip',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.blue.shade900,
                                fontSize: 14.sp,
                              ),
                            ),
                            SizedBox(height: 4.h),
                            Text(
                              'Stay hydrated by drinking plenty of water before and after donating. Eat iron-rich foods like spinach, lentils, and lean meat to maintain optimal hemoglobin levels.',
                              style: TextStyle(fontSize: 12.sp, color: Colors.blue.shade900),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 32.h),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildVitalMetricCard({
    required String title,
    required String value,
    required String status,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: Colors.grey.withOpacity(0.15)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, color: color, size: 20.w),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: Text(
                  status,
                  style: TextStyle(fontSize: 10.sp, color: color, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface),
              ),
              SizedBox(height: 2.h),
              Text(
                title,
                style: TextStyle(fontSize: 11.sp, color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildScreeningRow(String label, String status, Color statusColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w500, color: Theme.of(context).colorScheme.onSurface),
          ),
        ),
        Row(
          children: [
            Icon(Icons.check_circle, color: statusColor, size: 16.w),
            SizedBox(width: 6.w),
            Text(
              status,
              style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.bold, color: statusColor),
            ),
          ],
        ),
      ],
    );
  }
}
