import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/providers.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/localization_service.dart';
import '../../../../data/repositories/inventory_repository.dart';
import '../../../../data/repositories/request_repository.dart';
import '../../../../data/repositories/appointment_repository.dart';
import '../../../../data/models/blood_inventory_model.dart';
import '../../../../data/models/blood_request_model.dart';
import '../../../../data/models/appointment_model.dart';
import '../../../../core/constants/app_constants.dart';

class HospitalDashboardScreen extends ConsumerWidget {
  const HospitalDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final localization = ref.watch(localizationServiceProvider);
    final inventoryRepo = ref.watch(inventoryRepositoryProvider);
    final requestRepo = ref.watch(requestRepositoryProvider);
    final appointmentRepo = ref.watch(appointmentRepositoryProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(localization.translate('hospital_dashboard')),
      ),
      body: FutureBuilder<List<BloodInventoryModel>>(
        future: inventoryRepo.getInventory(),
        builder: (context, inventorySnapshot) {
          return FutureBuilder<List<BloodRequestModel>>(
            future: requestRepo.getRequests(),
            builder: (context, requestSnapshot) {
              return FutureBuilder<List<AppointmentModel>>(
                future: appointmentRepo.getAppointments(),
                builder: (context, appointmentSnapshot) {
                  if (inventorySnapshot.connectionState == ConnectionState.waiting &&
                      requestSnapshot.connectionState == ConnectionState.waiting &&
                      appointmentSnapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final inventory = inventorySnapshot.data ?? [];
                  final requests = requestSnapshot.data ?? [];
                  final appointments = appointmentSnapshot.data ?? [];

                  // Calculate stats
                  final totalUnits = inventory.fold<int>(0, (sum, item) => sum + item.quantity);
                  final lowStockItems = inventory.where((item) => item.quantity < 5).toList();
                  final pendingRequests = requests.where((r) => r.status == AppConstants.statusPending).toList();
                  final todayAppointments = appointments.where((a) {
                    final today = DateTime.now();
                    return a.scheduledDate.year == today.year &&
                        a.scheduledDate.month == today.month &&
                        a.scheduledDate.day == today.day;
                  }).toList();

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
                          // Stats Overview
                          GridView.count(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            crossAxisCount: 2,
                            mainAxisSpacing: 16.h,
                            crossAxisSpacing: 16.w,
                            childAspectRatio: 1.5,
                            children: [
                              _StatCard(
                                title: 'Total Units',
                                value: totalUnits.toString(),
                                icon: Icons.inventory_2,
                                color: AppTheme.primaryColor,
                              ),
                              _StatCard(
                                title: 'Pending Requests',
                                value: pendingRequests.length.toString(),
                                icon: Icons.pending_actions,
                                color: AppTheme.warning,
                              ),
                              _StatCard(
                                title: 'Today\'s Appointments',
                                value: todayAppointments.length.toString(),
                                icon: Icons.calendar_today,
                                color: AppTheme.secondaryColor,
                              ),
                              _StatCard(
                                title: 'Low Stock Alerts',
                                value: lowStockItems.length.toString(),
                                icon: Icons.warning_amber_rounded,
                                color: AppTheme.error,
                              ),
                            ],
                          ),
                          SizedBox(height: 24.h),

                          // Low Stock Alerts
                          if (lowStockItems.isNotEmpty) ...[
                            Text(
                              localization.translate('low_stock'),
                              style: TextStyle(
                                fontSize: 20.sp,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.error,
                              ),
                            ),
                            SizedBox(height: 16.h),
                            ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: lowStockItems.length,
                              itemBuilder: (context, index) {
                                final item = lowStockItems[index];
                                return Card(
                                  margin: EdgeInsets.only(bottom: 12.h),
                                  child: ListTile(
                                    leading: const Icon(Icons.warning_amber_rounded, color: AppTheme.error),
                                    title: Text('${item.bloodGroup} - ${item.quantity} units'),
                                    subtitle: Text('Expires: ${item.expirationDate.day}/${item.expirationDate.month}/${item.expirationDate.year}'),
                                  ),
                                );
                              },
                            ),
                            SizedBox(height: 16.h),
                          ],

                          // Pending Requests
                          Text(
                            'Pending Requests',
                            style: TextStyle(
                              fontSize: 20.sp,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 16.h),
                          if (pendingRequests.isEmpty)
                            Card(
                              child: Padding(
                                padding: EdgeInsets.all(20.w),
                                child: Center(
                                  child: Text(
                                    'No pending requests',
                                    style: TextStyle(color: AppTheme.grey600),
                                  ),
                                ),
                              ),
                            )
                          else
                            ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: pendingRequests.length,
                              itemBuilder: (context, index) {
                                final request = pendingRequests[index];
                                return Card(
                                  margin: EdgeInsets.only(bottom: 12.h),
                                  child: ListTile(
                                    leading: const Icon(Icons.bloodtype),
                                    title: Text('${request.bloodGroup} - ${request.quantity} units'),
                                    subtitle: Text('Patient #${request.patientId}'),
                                    trailing: Chip(
                                      label: Text(request.urgency),
                                      backgroundColor: _getUrgencyColor(request.urgency),
                                    ),
                                    onTap: () {
                                      // Process request
                                    },
                                  ),
                                );
                              },
                            ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  Color _getUrgencyColor(String urgency) {
    switch (urgency) {
      case AppConstants.urgencyLow:
        return AppTheme.success;
      case AppConstants.urgencyMedium:
        return AppTheme.warning;
      case AppConstants.urgencyHigh:
        return AppTheme.error;
      case AppConstants.urgencyCritical:
        return AppTheme.error;
      default:
        return AppTheme.grey500;
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
