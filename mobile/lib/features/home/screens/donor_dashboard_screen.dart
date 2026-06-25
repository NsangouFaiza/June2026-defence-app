import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/providers.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/localization_service.dart';
import '../../../../data/repositories/auth_repository.dart';
import '../../../../data/repositories/donation_repository.dart';
import '../../../../data/repositories/appointment_repository.dart';
import '../../../../data/repositories/reward_repository.dart';
import '../../../../data/models/user_model.dart';
import '../../../../data/models/donation_model.dart';
import '../../../../data/models/appointment_model.dart';
import '../../../../data/models/badge_model.dart';
import '../../../../core/constants/app_constants.dart';

class DonorDashboardScreen extends ConsumerWidget {
  const DonorDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final localization = ref.watch(localizationServiceProvider);
    final authRepo = ref.watch(authRepositoryProvider);
    final donationRepo = ref.watch(donationRepositoryProvider);
    final appointmentRepo = ref.watch(appointmentRepositoryProvider);
    final rewardRepo = ref.watch(rewardRepositoryProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(localization.translate('donor_dashboard')),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () {
              // Navigate to notifications
            },
          ),
        ],
      ),
      body: FutureBuilder<UserModel>(
        future: authRepo.getProfile(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final user = snapshot.data!;
          return RefreshIndicator(
            onRefresh: () async {
              // Refresh data
            },
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.all(16.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Welcome Card
                  Card(
                    child: Padding(
                      padding: EdgeInsets.all(20.w),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 30.r,
                                backgroundColor: AppTheme.primaryColor,
                                child: Text(
                                  user.fullName[0].toUpperCase(),
                                  style: TextStyle(
                                    fontSize: 24.sp,
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
                                      'Welcome, ${user.fullName.split(' ')[0]}!',
                                      style: TextStyle(
                                        fontSize: 20.sp,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(
                                      user.bloodGroup ?? 'Blood Group: Not set',
                                      style: TextStyle(
                                        fontSize: 14.sp,
                                        color: AppTheme.grey600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: 24.h),

                  // Stats Grid
                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 2,
                    mainAxisSpacing: 16.h,
                    crossAxisSpacing: 16.w,
                    childAspectRatio: 1.5,
                    children: [
                      _StatCard(
                        title: localization.translate('total_donations'),
                        value: '0',
                        icon: Icons.volunteer_activism,
                        color: AppTheme.primaryColor,
                      ),
                      _StatCard(
                        title: localization.translate('lives_saved'),
                        value: '0',
                        icon: Icons.favorite,
                        color: AppTheme.accentColor,
                      ),
                      _StatCard(
                        title: localization.translate('points'),
                        value: '0',
                        icon: Icons.stars,
                        color: AppTheme.secondaryColor,
                      ),
                      _StatCard(
                        title: localization.translate('badges'),
                        value: '0',
                        icon: Icons.emoji_events,
                        color: AppTheme.warning,
                      ),
                    ],
                  ),
                  SizedBox(height: 24.h),

                  // Quick Actions
                  Text(
                    'Quick Actions',
                    style: TextStyle(
                      fontSize: 20.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 16.h),
                  Row(
                    children: [
                      Expanded(
                        child: _ActionCard(
                          title: 'Book Appointment',
                          icon: Icons.calendar_today,
                          onTap: () {
                            // Navigate to appointment booking
                          },
                        ),
                      ),
                      SizedBox(width: 16.w),
                      Expanded(
                        child: _ActionCard(
                          title: 'Check Eligibility',
                          icon: Icons.check_circle_outline,
                          onTap: () {
                            // Navigate to eligibility check
                          },
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 24.h),

                  // Upcoming Appointments
                  Text(
                    localization.translate('upcoming_appointments'),
                    style: TextStyle(
                      fontSize: 20.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 16.h),
                  FutureBuilder<List<AppointmentModel>>(
                    future: appointmentRepo.getAppointments(donorId: user.id),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (!snapshot.hasData || snapshot.data!.isEmpty) {
                        return Card(
                          child: Padding(
                            padding: EdgeInsets.all(20.w),
                            child: Center(
                              child: Text(
                                'No upcoming appointments',
                                style: TextStyle(color: AppTheme.grey600),
                              ),
                            ),
                          ),
                        );
                      }
                      return ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: snapshot.data!.length,
                        itemBuilder: (context, index) {
                          final appointment = snapshot.data![index];
                          return Card(
                            margin: EdgeInsets.only(bottom: 12.h),
                            child: ListTile(
                              leading: const Icon(Icons.calendar_today),
                              title: Text('Hospital #${appointment.hospitalId}'),
                              subtitle: Text(
                                '${appointment.scheduledDate.day}/${appointment.scheduledDate.month}/${appointment.scheduledDate.year} at ${appointment.scheduledTime}',
                              ),
                              trailing: Chip(
                                label: Text(appointment.status),
                                backgroundColor: _getStatusColor(appointment.status),
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case AppConstants.appointmentScheduled:
        return AppTheme.info;
      case AppConstants.appointmentConfirmed:
        return AppTheme.success;
      case AppConstants.appointmentCompleted:
        return AppTheme.grey500;
      case AppConstants.appointmentCancelled:
        return AppTheme.error;
      default:
        return AppTheme.grey300;
    }
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 32.sp),
            SizedBox(height: 8.h),
            Text(
              value,
              style: TextStyle(
                fontSize: 24.sp,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              title,
              style: TextStyle(
                fontSize: 12.sp,
                color: AppTheme.grey600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final VoidCallback onTap;

  const _ActionCard({
    required this.title,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16.r),
        child: Padding(
          padding: EdgeInsets.all(20.w),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 40.sp, color: AppTheme.primaryColor),
              SizedBox(height: 12.h),
              Text(
                title,
                style: TextStyle(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
