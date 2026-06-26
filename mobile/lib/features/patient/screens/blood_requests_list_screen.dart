import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/localization_service.dart';
import '../../../core/providers/providers.dart';
import '../../../data/models/blood_request_model.dart';
import '../../../data/repositories/request_repository.dart';

class BloodRequestsListScreen extends ConsumerStatefulWidget {
  const BloodRequestsListScreen({super.key});

  @override
  ConsumerState<BloodRequestsListScreen> createState() => _BloodRequestsListScreenState();
}

class _BloodRequestsListScreenState extends ConsumerState<BloodRequestsListScreen> {
  bool _isActionLoading = false;

  Future<void> _handleApprove(int id) async {
    setState(() => _isActionLoading = true);
    try {
      await ref.read(requestRepositoryProvider).approveRequest(id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Request approved successfully'), backgroundColor: AppTheme.success),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isActionLoading = false);
    }
  }

  Future<void> _handleFulfill(int id) async {
    setState(() => _isActionLoading = true);
    try {
      await ref.read(requestRepositoryProvider).fulfillRequest(id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Request fulfilled successfully'), backgroundColor: AppTheme.primaryColor),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isActionLoading = false);
    }
  }

  Future<void> _handleReject(int id) async {
    final reasonController = TextEditingController();
    final localization = ref.read(localizationServiceProvider);
    
    final confirmReject = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject Blood Request'),
        content: TextField(
          controller: reasonController,
          decoration: const InputDecoration(
            labelText: 'Reason for rejection',
            hintText: 'Enter reason...',
          ),
          maxLines: 2,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(localization.translate('cancel')),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
            child: const Text('Reject'),
          ),
        ],
      ),
    );

    if (confirmReject == true && reasonController.text.trim().isNotEmpty) {
      setState(() => _isActionLoading = true);
      try {
        await ref.read(requestRepositoryProvider).rejectRequest(id, reasonController.text.trim());
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Request rejected'), backgroundColor: AppTheme.error),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.error),
          );
        }
      } finally {
        if (mounted) setState(() => _isActionLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final localization = ref.watch(localizationServiceProvider);
    final userAsync = ref.watch(currentUserProvider);
    final requestRepo = ref.watch(requestRepositoryProvider);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(localization.translate('blood_request')),
      ),
      body: userAsync.when(
        data: (user) {
          if (user == null) {
            return const Center(child: Text('User details not found. Please log in again.'));
          }

          final role = user.role.toLowerCase();
          final isPatient = role == 'patient';
          final isStaff = role == 'hospital_staff' || role == 'blood_bank_staff' || role == 'system_admin';

          return RefreshIndicator(
            onRefresh: () async {
              setState(() {});
            },
            child: FutureBuilder<List<BloodRequestModel>>(
              future: isPatient ? requestRepo.getMyRequests() : requestRepo.getRequests(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting || _isActionLoading) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: EdgeInsets.all(24.w),
                      child: Text('Error: ${snapshot.error}', textAlign: TextAlign.center),
                    ),
                  );
                }

                var requests = snapshot.data ?? [];

                // Donors only see active pending or approved requests to donate
                if (!isPatient && !isStaff) {
                  requests = requests.where((r) => r.status == 'PENDING' || r.status == 'APPROVED').toList();
                }

                if (requests.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.inbox_outlined, size: 64.w, color: Colors.grey[400]),
                        SizedBox(height: 16.h),
                        Text(
                          localization.translate('no_requests'),
                          style: TextStyle(fontSize: 16.sp, color: AppTheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: EdgeInsets.all(16.w),
                  itemCount: requests.length,
                  itemBuilder: (context, index) {
                    final request = requests[index];
                    return _buildRequestItem(context, request, role);
                  },
                );
              },
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error loading profile: $err')),
      ),
    );
  }

  Widget _buildRequestItem(BuildContext context, BloodRequestModel request, String role) {
    final isPatient = role == 'patient';
    final isStaff = role == 'hospital_staff' || role == 'blood_bank_staff' || role == 'system_admin';
    final isDonor = !isPatient && !isStaff;
    final localization = ref.watch(localizationServiceProvider);

    final showPayButton = isPatient && request.status.toUpperCase() == 'APPROVED' && request.paymentStatus.toUpperCase() == 'PENDING';
    final showStaffActions = isStaff && request.status.toUpperCase() == 'PENDING';
    final showFulfillAction = isStaff && request.status.toUpperCase() == 'APPROVED';
    final showDonateAction = isDonor && request.status.toUpperCase() == 'PENDING';

    return Container(
      margin: EdgeInsets.only(bottom: 16.h),
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Row
          Row(
            children: [
              Container(
                width: 48.w,
                height: 48.w,
                decoration: BoxDecoration(
                  color: _getStatusColor(request.status).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: Icon(
                  _getStatusIcon(request.status),
                  color: _getStatusColor(request.status),
                  size: 24.w,
                ),
              ),
              SizedBox(width: 16.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${request.bloodGroup} • ${request.quantity} unit(s)',
                      style: TextStyle(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.onSurface,
                      ),
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      request.hospitalName ?? 'Unknown hospital',
                      style: TextStyle(
                        fontSize: 12.sp,
                        color: AppTheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              // Status Tag
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                decoration: BoxDecoration(
                  color: _getStatusColor(request.status).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20.r),
                ),
                child: Text(
                  request.status.toUpperCase(),
                  style: TextStyle(
                    fontSize: 10.sp,
                    fontWeight: FontWeight.bold,
                    color: _getStatusColor(request.status),
                  ),
                ),
              ),
            ],
          ),
          
          if (request.reason != null && request.reason!.isNotEmpty) ...[
            SizedBox(height: 12.h),
            Text(
              'Reason: ${request.reason}',
              style: TextStyle(
                fontSize: 13.sp,
                color: AppTheme.onSurfaceVariant,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],

          // Actions Divider
          if (showPayButton || showStaffActions || showFulfillAction || showDonateAction) ...[
            const Divider(height: 24, thickness: 1),
          ],

          // Patient Pay Now
          if (showPayButton) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Payment: PENDING',
                  style: TextStyle(
                    fontSize: 12.sp,
                    color: AppTheme.warning,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pushNamed(
                      '/payment',
                      arguments: {
                        'requestId': request.id,
                        'amount': request.quantity * 15000.0,
                      },
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.success,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10.r),
                    ),
                  ),
                  child: Text(localization.translate('pay_now')),
                ),
              ],
            ),
          ] else if (isPatient && request.status.toUpperCase() == 'APPROVED' && request.paymentStatus.toUpperCase() == 'PAID') ...[
            const Divider(height: 24, thickness: 1),
            Row(
              children: [
                const Icon(Icons.check_circle, color: AppTheme.success, size: 16),
                SizedBox(width: 6.w),
                Text(
                  'Paid - Ref: ${request.paymentReference ?? "N/A"}',
                  style: TextStyle(fontSize: 12.sp, color: AppTheme.success, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ],

          // Staff Actions (Approve/Reject)
          if (showStaffActions) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => _handleReject(request.id),
                  style: TextButton.styleFrom(foregroundColor: AppTheme.error),
                  child: const Text('Reject'),
                ),
                SizedBox(width: 12.w),
                ElevatedButton(
                  onPressed: () => _handleApprove(request.id),
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.success),
                  child: const Text('Approve'),
                ),
              ],
            ),
          ],

          // Staff Fulfill Action
          if (showFulfillAction) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  request.paymentStatus.toUpperCase() == 'PAID' ? 'Paid & Approved' : 'Payment: PENDING',
                  style: TextStyle(
                    fontSize: 12.sp,
                    color: request.paymentStatus.toUpperCase() == 'PAID' ? AppTheme.success : AppTheme.warning,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () => _handleFulfill(request.id),
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor),
                  icon: const Icon(Icons.done_all, size: 16),
                  label: const Text('Fulfill Request'),
                ),
              ],
            ),
          ],

          // Donor Donate Action
          if (showDonateAction) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Expanded(
                  child: Text(
                    'Need matching blood donors nearby!',
                    style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(context).pushNamed('/book-appointment');
                  },
                  icon: const Icon(Icons.favorite, size: 16),
                  label: const Text('Donate Now'),
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return AppTheme.warning;
      case 'approved':
        return AppTheme.success;
      case 'rejected':
        return AppTheme.error;
      case 'fulfilled':
        return AppTheme.primaryColor;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Icons.pending_actions_outlined;
      case 'approved':
        return Icons.verified_user_outlined;
      case 'rejected':
        return Icons.cancel_outlined;
      case 'fulfilled':
        return Icons.check_circle_outlined;
      default:
        return Icons.help_outline;
    }
  }
}
