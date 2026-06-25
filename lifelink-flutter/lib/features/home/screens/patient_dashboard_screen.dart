import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/providers.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/localization_service.dart';
import '../../../../data/repositories/request_repository.dart';
import '../../../../data/models/blood_request_model.dart';
import '../../../../core/constants/app_constants.dart';

class PatientDashboardScreen extends ConsumerWidget {
  const PatientDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final localization = ref.watch(localizationServiceProvider);
    final requestRepo = ref.watch(requestRepositoryProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(localization.translate('patient_dashboard')),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              // Navigate to create blood request
            },
          ),
        ],
      ),
      body: FutureBuilder<List<BloodRequestModel>>(
        future: requestRepo.getRequests(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final requests = snapshot.data ?? [];

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
                  // Search Hospitals Card
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.search),
                      title: Text(localization.translate('search_blood')),
                      trailing: const Icon(Icons.arrow_forward_ios),
                      onTap: () {
                        // Navigate to search blood
                      },
                    ),
                  ),
                  SizedBox(height: 16.h),

                  // Emergency Request Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        // Navigate to emergency request
                      },
                      icon: const Icon(Icons.emergency),
                      label: Text(localization.translate('create_emergency_request')),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.error,
                        padding: EdgeInsets.symmetric(vertical: 16.h),
                      ),
                    ),
                  ),
                  SizedBox(height: 24.h),

                  // Active Requests
                  Text(
                    localization.translate('blood_requests'),
                    style: TextStyle(
                      fontSize: 20.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 16.h),
                  if (requests.isEmpty)
                    Card(
                      child: Padding(
                        padding: EdgeInsets.all(20.w),
                        child: Center(
                          child: Text(
                            'No active requests',
                            style: TextStyle(color: AppTheme.grey600),
                          ),
                        ),
                      ),
                    )
                  else
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: requests.length,
                      itemBuilder: (context, index) {
                        final request = requests[index];
                        return Card(
                          margin: EdgeInsets.only(bottom: 12.h),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: _getUrgencyColor(request.urgency),
                              child: Icon(
                                request.isEmergency ? Icons.emergency : Icons.bloodtype,
                                color: Colors.white,
                              ),
                            ),
                            title: Text('${request.bloodGroup} - ${request.quantity} units'),
                            subtitle: Text('Hospital #${request.hospitalId}'),
                            trailing: Chip(
                              label: Text(request.status),
                              backgroundColor: _getStatusColor(request.status),
                            ),
                          ),
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

  Color _getStatusColor(String status) {
    switch (status) {
      case AppConstants.statusPending:
        return AppTheme.warning;
      case AppConstants.statusApproved:
        return AppTheme.success;
      case AppConstants.statusRejected:
        return AppTheme.error;
      case AppConstants.statusFulfilled:
        return AppTheme.info;
      default:
        return AppTheme.grey300;
    }
  }
}
