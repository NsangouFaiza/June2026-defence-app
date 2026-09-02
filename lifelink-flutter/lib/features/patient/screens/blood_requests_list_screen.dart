import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/localization_service.dart';
import '../../../core/providers/providers.dart';
import '../../../data/models/blood_request_model.dart';
import '../../../data/repositories/request_repository.dart';
import '../../../data/models/donor_model.dart';
import '../../../data/repositories/donor_repository.dart';
import 'donor_selection_dialog.dart';
import '../../../widgets/lifelink_app_bar.dart';

class BloodRequestsListScreen extends ConsumerStatefulWidget {

  const BloodRequestsListScreen({super.key});

  @override
  ConsumerState<BloodRequestsListScreen> createState() => _BloodRequestsListScreenState();
}

class _BloodRequestsListScreenState extends ConsumerState<BloodRequestsListScreen> {
  bool _isActionLoading = false;

  Future<void> _handlePledge(int id) async {
    setState(() => _isActionLoading = true);
    try {
      await ref.read(requestRepositoryProvider).pledgeToRequest(id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Thank you! You have pledged to donate for this emergency request.'),
            backgroundColor: AppTheme.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to pledge: $e'), backgroundColor: AppTheme.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isActionLoading = false);
    }
  }

  Future<void> _handleCancelPledge(int id) async {
    setState(() => _isActionLoading = true);
    try {
      await ref.read(requestRepositoryProvider).cancelPledge(id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pledge cancelled.'), backgroundColor: AppTheme.warning),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to cancel pledge: $e'), backgroundColor: AppTheme.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isActionLoading = false);
    }
  }

  Future<void> _handleApprove(BloodRequestModel request) async {
    final localization = ref.read(localizationServiceProvider);
    final id = request.id;
    
    String selectedType = 'DIRECT_DONATION';
    DonorModel? selectedDonor;

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Select Blood Source'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Please specify the blood fulfillment source to approve this request:'),
                    SizedBox(height: 12.h),
                    DropdownButtonFormField<String>(
                      value: selectedType,
                      decoration: const InputDecoration(
                        labelText: 'Fulfillment Source',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'DIRECT_DONATION',
                          child: Text('Direct Donation'),
                        ),
                        DropdownMenuItem(
                          value: 'INVENTORY',
                          child: Text('From Inventory'),
                        ),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setDialogState(() {
                            selectedType = val;
                          });
                        }
                      },
                    ),
                    if (selectedType == 'DIRECT_DONATION') ...[
                      SizedBox(height: 16.h),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Assigned Donor:',
                                  style: TextStyle(
                                    fontSize: 11.sp,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.onSurfaceVariant,
                                  ),
                                ),
                                SizedBox(height: 4.h),
                                Text(
                                  selectedDonor != null
                                      ? '${selectedDonor!.fullName} (${selectedDonor!.bloodGroup})'
                                      : 'No donor assigned',
                                  style: TextStyle(
                                    fontSize: 12.sp,
                                    fontWeight: FontWeight.bold,
                                    color: selectedDonor != null ? AppTheme.primaryColor : Colors.red,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          ElevatedButton(
                            onPressed: () async {
                              try {
                                final hospitals = await ref.read(hospitalRepositoryProvider).getHospitals();
                                final requestHospital = hospitals.firstWhere(
                                  (h) => h.id == request.hospitalId || h.name == request.hospitalName,
                                  orElse: () => hospitals.first,
                                );
                                if (!context.mounted) return;
                                final chosen = await showDialog<DonorModel>(
                                  context: context,
                                  builder: (context) => DonorSelectionDialog(
                                    hospital: requestHospital,
                                    initialBloodGroup: request.bloodGroup,
                                  ),
                                );
                                if (chosen != null) {
                                  setDialogState(() {
                                    selectedDonor = chosen;
                                  });
                                }
                              } catch (e) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Failed to load hospitals: $e')),
                                );
                              }
                            },
                            child: const Text('Search'),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(null),
                  child: Text(localization.translate('cancel')),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop({
                      'fulfillment_type': selectedType,
                      'donor_id': selectedDonor?.id,
                    });
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.success,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Approve'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result == null) return;

    setState(() => _isActionLoading = true);
    try {
      await ref.read(requestRepositoryProvider).approveRequest(
            id,
            result['fulfillment_type'] as String,
            donorId: result['donor_id'] as int?,
          );
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

  Future<void> _handleManageFulfillment(BloodRequestModel request) async {
    final localization = ref.read(localizationServiceProvider);
    
    // Fetch donors
    List<DonorModel> donors = [];
    try {
      donors = await ref.read(donorRepositoryProvider).getDonors();
    } catch (_) {}

    String selectedType = request.fulfillmentType ?? 'DIRECT_DONATION';
    DonorModel? selectedDonor;
    if (request.donorId != null && donors.isNotEmpty) {
      try {
        selectedDonor = donors.firstWhere((d) => d.id == request.donorId);
      } catch (_) {}
    }

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Manage Fulfillment'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Change fulfillment source for this request:'),
                    SizedBox(height: 12.h),
                    DropdownButtonFormField<String>(
                      value: selectedType,
                      decoration: const InputDecoration(
                        labelText: 'Fulfillment Source',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'DIRECT_DONATION',
                          child: Text('Direct Donation'),
                        ),
                        DropdownMenuItem(
                          value: 'INVENTORY',
                          child: Text('From Inventory'),
                        ),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setDialogState(() {
                            selectedType = val;
                          });
                        }
                      },
                    ),
                    if (selectedType == 'DIRECT_DONATION') ...[
                      SizedBox(height: 16.h),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Assigned Donor:',
                                  style: TextStyle(
                                    fontSize: 11.sp,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.onSurfaceVariant,
                                  ),
                                ),
                                SizedBox(height: 4.h),
                                Text(
                                  selectedDonor != null
                                      ? '${selectedDonor!.fullName} (${selectedDonor!.bloodGroup})'
                                      : 'No donor assigned',
                                  style: TextStyle(
                                    fontSize: 12.sp,
                                    fontWeight: FontWeight.bold,
                                    color: selectedDonor != null ? AppTheme.primaryColor : Colors.red,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          ElevatedButton(
                            onPressed: () async {
                              try {
                                final hospitals = await ref.read(hospitalRepositoryProvider).getHospitals();
                                final requestHospital = hospitals.firstWhere(
                                  (h) => h.id == request.hospitalId || h.name == request.hospitalName,
                                  orElse: () => hospitals.first,
                                );
                                if (!context.mounted) return;
                                final chosen = await showDialog<DonorModel>(
                                  context: context,
                                  builder: (context) => DonorSelectionDialog(
                                    hospital: requestHospital,
                                    initialBloodGroup: request.bloodGroup,
                                  ),
                                );
                                if (chosen != null) {
                                  setDialogState(() {
                                    selectedDonor = chosen;
                                  });
                                }
                              } catch (e) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Failed to load hospitals: $e')),
                                );
                              }
                            },
                            child: const Text('Search'),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(null),
                  child: Text(localization.translate('cancel')),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop({
                      'fulfillment_type': selectedType,
                      'donor_id': selectedDonor?.id,
                    });
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Update'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result == null) return;

    setState(() => _isActionLoading = true);
    try {
      await ref.read(requestRepositoryProvider).updateFulfillment(
            request.id,
            result['fulfillment_type'] as String,
            donorId: result['donor_id'] as int?,
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Fulfillment source updated successfully'),
            backgroundColor: AppTheme.success,
          ),
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
      appBar: LifeLinkAppBar(
        title: localization.translate('blood_request'),
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

                // If staff, sort emergency & high priority requests to the very top
                if (isStaff) {
                  requests = List<BloodRequestModel>.from(requests);
                  requests.sort((a, b) {
                    // First sort: Emergency
                    if (a.isEmergency && !b.isEmergency) return -1;
                    if (!a.isEmergency && b.isEmergency) return 1;

                    // Second sort: Active requests first
                    final aActive = (a.status == 'PENDING' || a.status == 'APPROVED');
                    final bActive = (b.status == 'PENDING' || b.status == 'APPROVED');
                    if (aActive && !bActive) return -1;
                    if (!aActive && bActive) return 1;

                    // Third sort: Urgency level (HIGH > MEDIUM > LOW)
                    final urgencyOrder = {'HIGH': 0, 'MEDIUM': 1, 'LOW': 2};
                    final aOrder = urgencyOrder[a.urgency.toUpperCase()] ?? 3;
                    final bOrder = urgencyOrder[b.urgency.toUpperCase()] ?? 3;
                    if (aOrder != bOrder) {
                      return aOrder.compareTo(bOrder);
                    }

                    // Fourth sort: Newest requests first
                    return b.createdAt.compareTo(a.createdAt);
                  });
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

    final showPayButton = isPatient && request.paymentStatus.toUpperCase() == 'PENDING' && request.fulfillmentType == 'INVENTORY';
    final showStaffActions = isStaff && request.status.toUpperCase() == 'PENDING';
    final showFulfillAction = isStaff && (request.status.toUpperCase() == 'APPROVED' || request.status.toUpperCase() == 'CONFIRMED');
    final showDonateAction = isDonor && request.status.toUpperCase() == 'PENDING';

    return Container(
      margin: EdgeInsets.only(bottom: 16.h),
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20.r),
        border: request.isEmergency 
            ? Border.all(color: AppTheme.error, width: 2.w)
            : null,
        boxShadow: [
          BoxShadow(
            color: request.isEmergency 
                ? AppTheme.error.withOpacity(0.08) 
                : Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (request.isEmergency || request.urgency.toUpperCase() == 'HIGH') ...[
            Container(
              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
              margin: EdgeInsets.only(bottom: 12.h),
              decoration: BoxDecoration(
                color: AppTheme.error.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10.r),
                border: Border.all(color: AppTheme.error.withOpacity(0.2)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, color: AppTheme.error),
                  SizedBox(width: 8.w),
                  Expanded(
                    child: Text(
                      request.isEmergency ? '🚨 CRITICAL EMERGENCY REQUEST' : '⚠️ HIGH PRIORITY REQUEST',
                      style: TextStyle(
                        color: AppTheme.error,
                        fontWeight: FontWeight.bold,
                        fontSize: 12.sp,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
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

          if (request.fulfillmentType != null) ...[
            SizedBox(height: 12.h),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
              decoration: BoxDecoration(
                color: AppTheme.onSurfaceVariant.withOpacity(0.05),
                borderRadius: BorderRadius.circular(10.r),
              ),
              child: Row(
                children: [
                  Icon(
                    request.fulfillmentType == 'INVENTORY' ? Icons.inventory_2_outlined : Icons.volunteer_activism_outlined,
                    size: 16.sp,
                    color: AppTheme.onSurfaceVariant,
                  ),
                  SizedBox(width: 8.w),
                  Expanded(
                    child: Text(
                      request.fulfillmentType == 'INVENTORY' ? 'Fulfilled from Inventory' : 'Direct Donation',
                      style: TextStyle(
                        fontSize: 12.sp,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.onSurface,
                      ),
                    ),
                  ),
                  if (isStaff && (request.status.toUpperCase() == 'APPROVED' || request.status.toUpperCase() == 'PENDING'))
                    IconButton(
                      icon: const Icon(Icons.edit, size: 16),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () => _handleManageFulfillment(request),
                      color: AppTheme.primaryColor,
                      tooltip: 'Change Source',
                    ),
                ],
              ),
            ),
          ],

          if (request.fulfillmentType == 'INVENTORY') ...[
            SizedBox(height: 8.h),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.05),
                borderRadius: BorderRadius.circular(10.r),
                border: Border.all(color: Colors.blue.withOpacity(0.12)),
              ),
              child: Row(
                children: [
                  Icon(Icons.receipt_long_rounded, color: Colors.blue.shade700, size: 14.sp),
                  SizedBox(width: 8.w),
                  Expanded(
                    child: Text(
                      request.paymentStatus.toUpperCase() == 'PAID'
                          ? 'Invoice Paid (25 FCFA) - Ref: ${request.paymentReference ?? "N/A"}'
                          : 'Invoice Generated: 25 FCFA Fee Pending',
                      style: TextStyle(
                        fontSize: 12.sp,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue.shade800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          if (request.fulfillmentType == 'DIRECT_DONATION') ...[
            SizedBox(height: 12.h),
            Container(
              padding: EdgeInsets.all(12.w),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.03),
                borderRadius: BorderRadius.circular(12.r),
                border: Border.all(color: Colors.red.withOpacity(0.1), width: 1),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.person, color: AppTheme.primaryColor, size: 18),
                      SizedBox(width: 8.w),
                      Text(
                        'Donor Information',
                        style: TextStyle(
                          fontSize: 13.sp,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 16),
                  if (request.donorName != null) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Name:', style: TextStyle(fontSize: 12.sp, color: AppTheme.onSurfaceVariant)),
                        SizedBox(width: 8.w),
                        Flexible(
                          child: Text(
                            request.donorName!,
                            style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.bold, color: AppTheme.onSurface),
                            textAlign: TextAlign.end,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    if (request.donorPhone != null && request.donorPhone!.isNotEmpty) ...[
                      SizedBox(height: 6.h),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Phone:', style: TextStyle(fontSize: 12.sp, color: AppTheme.onSurfaceVariant)),
                          SizedBox(width: 8.w),
                          Flexible(
                            child: Text(
                              request.donorPhone!,
                              style: TextStyle(fontSize: 12.sp, color: AppTheme.onSurface),
                              textAlign: TextAlign.end,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (request.donorEmail != null && request.donorEmail!.isNotEmpty) ...[
                      SizedBox(height: 6.h),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Email:', style: TextStyle(fontSize: 12.sp, color: AppTheme.onSurfaceVariant)),
                          SizedBox(width: 8.w),
                          Flexible(
                            child: Text(
                              request.donorEmail!,
                              style: TextStyle(fontSize: 12.sp, color: AppTheme.onSurface),
                              textAlign: TextAlign.end,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ] else ...[
                    Text(
                      'No donor linked to this direct donation request yet.',
                      style: TextStyle(fontSize: 12.sp, fontStyle: FontStyle.italic, color: AppTheme.onSurfaceVariant),
                    ),
                  ],
                ],
              ),
            ),
            if (request.appointmentDetails != null && request.status.toUpperCase() != 'FULFILLED') ...[
              SizedBox(height: 12.h),
              Container(
                padding: EdgeInsets.all(12.w),
                decoration: BoxDecoration(
                  color: Colors.teal.withOpacity(0.04),
                  borderRadius: BorderRadius.circular(12.r),
                  border: Border.all(color: Colors.teal.withOpacity(0.15), width: 1),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.event_available_rounded, color: Colors.teal, size: 18),
                        SizedBox(width: 8.w),
                        Text(
                          'Blood Request Summary / Appointment Details',
                          style: TextStyle(
                            fontSize: 12.sp,
                            fontWeight: FontWeight.bold,
                            color: Colors.teal,
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Hospital:', style: TextStyle(fontSize: 11.sp, color: AppTheme.onSurfaceVariant)),
                        SizedBox(width: 8.w),
                        Flexible(
                          child: Text(
                            request.appointmentDetails!['hospital_name'] ?? 'Hospital Clinic',
                            style: TextStyle(fontSize: 11.sp, fontWeight: FontWeight.bold),
                            textAlign: TextAlign.end,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    if (request.appointmentDetails!['hospital_address'] != null && request.appointmentDetails!['hospital_address'].toString().isNotEmpty) ...[
                      SizedBox(height: 4.h),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Address:', style: TextStyle(fontSize: 11.sp, color: AppTheme.onSurfaceVariant)),
                          SizedBox(width: 8.w),
                          Flexible(
                            child: Text(
                              request.appointmentDetails!['hospital_address'],
                              style: TextStyle(fontSize: 11.sp),
                              textAlign: TextAlign.end,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                    SizedBox(height: 4.h),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Scheduled Date:', style: TextStyle(fontSize: 11.sp, color: AppTheme.onSurfaceVariant)),
                        SizedBox(width: 8.w),
                        Flexible(
                          child: Text(
                            request.appointmentDetails!['date'] ?? 'N/A',
                            style: TextStyle(fontSize: 11.sp, fontWeight: FontWeight.bold),
                            textAlign: TextAlign.end,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 4.h),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Scheduled Time:', style: TextStyle(fontSize: 11.sp, color: AppTheme.onSurfaceVariant)),
                        SizedBox(width: 8.w),
                        Flexible(
                          child: Text(
                            request.appointmentDetails!['time'] ?? '09:00 AM',
                            style: TextStyle(fontSize: 11.sp, fontWeight: FontWeight.bold),
                            textAlign: TextAlign.end,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 4.h),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Appointment Status:', style: TextStyle(fontSize: 11.sp, color: AppTheme.onSurfaceVariant)),
                        SizedBox(width: 8.w),
                        Flexible(
                          child: Text(
                            (request.appointmentDetails!['status'] ?? 'SCHEDULED').toString().toUpperCase(),
                            style: TextStyle(fontSize: 11.sp, fontWeight: FontWeight.bold, color: Colors.teal.shade800),
                            textAlign: TextAlign.end,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 12),
                    Text(
                      'Instructions: Please keep track of these appointment details. The donor will present themselves to fulfill the donation.',
                      style: TextStyle(fontSize: 10.sp, fontStyle: FontStyle.italic, color: Colors.teal.shade700),
                    ),
                  ],
                ),
              ),
            ],
          ],

          // Actions Divider
          if (showPayButton || showStaffActions || showFulfillAction || showDonateAction) ...[
            const Divider(height: 24, thickness: 1),
          ],

          // Patient Pay Now
          if (showPayButton) ...[
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Payment: PENDING (25 FCFA)',
                    style: TextStyle(
                      fontSize: 12.sp,
                      color: AppTheme.warning,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                SizedBox(width: 8.w),
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pushNamed(
                      '/payment',
                      arguments: {
                        'requestId': request.id,
                        'amount': 25.0,
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
          ] else if (isPatient && request.paymentStatus.toUpperCase() == 'PAID') ...[
            const Divider(height: 24, thickness: 1),
            Container(
              padding: EdgeInsets.all(10.w),
              decoration: BoxDecoration(
                color: AppTheme.success.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10.r),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_outline_rounded, color: AppTheme.success, size: 18),
                  SizedBox(width: 8.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Payment Status: Paid',
                          style: TextStyle(
                            fontSize: 12.sp,
                            color: AppTheme.success,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 2.h),
                        Text(
                          'Payment has been successfully received. Ref: ${request.paymentReference ?? "N/A"}',
                          style: TextStyle(
                            fontSize: 11.sp,
                            color: AppTheme.success,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
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
                  onPressed: () => _handleApprove(request),
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
                  request.status.toUpperCase() == 'CONFIRMED'
                      ? 'Paid & Confirmed'
                      : request.paymentStatus.toUpperCase() == 'PAID'
                          ? 'Approved (Free)'
                          : 'Payment: PENDING',
                  style: TextStyle(
                    fontSize: 12.sp,
                    color: (request.paymentStatus.toUpperCase() == 'PAID' || request.status.toUpperCase() == 'CONFIRMED')
                        ? AppTheme.success
                        : AppTheme.warning,
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

          // Donor Donate / Pledge Action
          if (showDonateAction) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Expanded(
                  child: Text(
                    'Urgent Emergency Blood Request',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.primaryColor),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () => _handlePledge(request.id),
                  icon: const Icon(Icons.volunteer_activism, size: 16),
                  label: const Text('Pledge to Donate'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                  ),
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
      case 'confirmed':
        return const Color(0xFF2E7D32); // Deep Green
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
      case 'confirmed':
        return Icons.check_circle_rounded;
      case 'rejected':
        return Icons.cancel_outlined;
      case 'fulfilled':
        return Icons.check_circle_outlined;
      default:
        return Icons.help_outline;
    }
  }
}
