import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/providers.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/localization_service.dart';
import '../../../../data/repositories/donor_repository.dart';
import '../../../../data/models/donor_model.dart';
import 'package:url_launcher/url_launcher.dart';

class DonorDetailsScreen extends ConsumerStatefulWidget {
  final int donorId;

  const DonorDetailsScreen({super.key, required this.donorId});

  @override
  ConsumerState<DonorDetailsScreen> createState() => _DonorDetailsScreenState();
}

class _DonorDetailsScreenState extends ConsumerState<DonorDetailsScreen> {
  DonorModel? _donor;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadDonor();
    });
  }

  Future<void> _loadDonor() async {
    setState(() => _isLoading = true);
    try {
      final repo = ref.read(donorRepositoryProvider);
      final fetched = await repo.getDonorById(widget.donorId);
      setState(() {
        _donor = fetched;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.error),
      );
    }
  }

  bool _hasSystemicConstraint(DonorModel donor) {
    final today = DateTime.now();
    
    // 1. Last donation within 60 days
    if (donor.lastDonationDate != null) {
      final difference = today.difference(donor.lastDonationDate!).inDays;
      if (difference < 60) return true;
    }
    
    // 2. Age < 18
    if (donor.dateOfBirth != null) {
      final age = today.year - donor.dateOfBirth!.year;
      if (age < 18) return true;
    }
    
    // 3. Keywords in eligibilityReason
    final reason = (donor.eligibilityReason ?? '').toLowerCase();
    if (reason.contains('surgery') || reason.contains('age') || reason.contains('last donation') || reason.contains('recent donation')) {
      return true;
    }
    
    return false;
  }

  String _getSystemicReason(DonorModel donor) {
    final today = DateTime.now();
    final List<String> reasons = [];
    
    if (donor.lastDonationDate != null) {
      final difference = today.difference(donor.lastDonationDate!).inDays;
      if (difference < 60) {
        reasons.add("Recent donation within 60 days (${60 - difference} days remaining)");
      }
    }
    
    if (donor.dateOfBirth != null) {
      final age = today.year - donor.dateOfBirth!.year;
      if (age < 18) {
        reasons.add("Donor is underage (age: $age, minimum is 18)");
      }
    }
    
    final reason = donor.eligibilityReason ?? '';
    if (reason.isNotEmpty) {
      final lower = reason.toLowerCase();
      if (lower.contains('surgery') || lower.contains('age') || lower.contains('last donation') || lower.contains('recent donation')) {
        reasons.add("Systemic medical constraint: $reason");
      }
    }
    
    return reasons.join(", ");
  }

  Future<void> _showUpdateEligibilityDialog(DonorModel donor) async {
    final hasConstraint = _hasSystemicConstraint(donor);
    if (hasConstraint) {
      final systemicReason = _getSystemicReason(donor);
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: AppTheme.warning),
              SizedBox(width: 8.w),
              const Text('System Constraint'),
            ],
          ),
          content: Text(
            'This donor\'s eligibility status cannot be modified due to systemic health or safety constraints:\n\n'
            '• $systemicReason\n\n'
            'Age requirements, recent surgeries, and donation intervals are calculated automatically and cannot be manually overridden.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    // Editable status dialog
    String tempStatus = donor.eligibilityStatus ?? (donor.isEligible ? 'eligible' : 'temporarily_ineligible');
    final reasonController = TextEditingController(text: donor.eligibilityReason ?? '');

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Update Eligibility Status'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: tempStatus,
                decoration: const InputDecoration(labelText: 'Status'),
                items: const [
                  DropdownMenuItem(value: 'eligible', child: Text('Eligible')),
                  DropdownMenuItem(value: 'temporarily_ineligible', child: Text('Temporarily Ineligible')),
                  DropdownMenuItem(value: 'permanently_ineligible', child: Text('Permanently Ineligible')),
                ],
                onChanged: (val) {
                  if (val != null) {
                    setDialogState(() {
                      tempStatus = val;
                    });
                  }
                },
              ),
              if (tempStatus != 'eligible') ...[
                SizedBox(height: 12.h),
                TextField(
                  controller: reasonController,
                  decoration: const InputDecoration(
                    labelText: 'Reason for Ineligibility',
                    hintText: 'e.g. Low hemoglobin, travel history',
                  ),
                  maxLines: 2,
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(context).pop();
                setState(() => _isLoading = true);
                try {
                  final repo = ref.read(donorRepositoryProvider);
                  final updated = await repo.updateEligibility(
                    donor.id,
                    tempStatus,
                    reasonController.text.trim(),
                  );
                  setState(() {
                    _donor = updated;
                    _isLoading = false;
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Eligibility status updated successfully!')),
                  );
                } catch (e) {
                  setState(() => _isLoading = false);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error updating eligibility: $e'), backgroundColor: AppTheme.error),
                  );
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final localization = ref.watch(localizationServiceProvider);

    if (_isLoading && _donor == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_donor == null) {
      return Scaffold(
        appBar: AppBar(title: Text(localization.translate('donor_details'))),
        body: const Center(child: Text('Donor details not found.')),
      );
    }

    final donor = _donor!;
    final isSystemic = _hasSystemicConstraint(donor);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(localization.translate('donor_details')),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadDonor,
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(16.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Profile Header
              Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15.r)),
                child: Padding(
                  padding: EdgeInsets.all(20.w),
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 50.r,
                        backgroundColor: _getBloodGroupColor(donor.bloodGroup ?? 'O+'),
                        child: Text(
                          donor.bloodGroup ?? 'O+',
                          style: TextStyle(
                            fontSize: 32.sp,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      SizedBox(height: 16.h),
                      Text(
                        donor.fullName,
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 6.h),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 4.h),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(12.r),
                        ),
                        child: Text(
                          'Donor ID: ${donor.donorIdCode}',
                          style: TextStyle(
                            fontSize: 14.sp,
                            color: AppTheme.primaryColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      SizedBox(height: 8.h),
                      Text(
                        donor.bloodGroup ?? 'O+',
                        style: TextStyle(
                          fontSize: 18.sp,
                          color: _getBloodGroupColor(donor.bloodGroup ?? 'O+'),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 12.h),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            donor.isEligible ? Icons.check_circle : Icons.cancel,
                            color: donor.isEligible ? AppTheme.success : AppTheme.error,
                          ),
                          SizedBox(width: 6.w),
                          Text(
                            donor.isEligible
                                ? localization.translate('eligible').toUpperCase()
                                : (donor.eligibilityStatus?.replaceAll('_', ' ').toUpperCase() ??
                                    localization.translate('ineligible').toUpperCase()),
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: donor.isEligible ? AppTheme.success : AppTheme.error,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 16.h),

              // Eligibility Reason and Status Details
              Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15.r)),
                child: Padding(
                  padding: EdgeInsets.all(16.w),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Eligibility Status Details',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 12.h),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Eligibility Type: ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.sp)),
                          Expanded(
                            child: Text(
                              donor.eligibilityStatus?.replaceAll('_', ' ').toUpperCase() ??
                                  (donor.isEligible ? 'ELIGIBLE' : 'INELIGIBLE'),
                              style: TextStyle(fontSize: 13.sp),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 8.h),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Ineligibility Reason: ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.sp)),
                          Expanded(
                            child: Text(
                              donor.isEligible
                                  ? 'N/A (Donor is eligible to donate)'
                                  : (donor.eligibilityReason ?? 'No reason provided.'),
                              style: TextStyle(
                                fontSize: 13.sp,
                                color: donor.isEligible ? AppTheme.onSurfaceVariant : AppTheme.error,
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 8.h),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Last Donation Date: ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.sp)),
                          Expanded(
                            child: Text(
                              donor.lastDonationDate != null
                                  ? "${donor.lastDonationDate!.year}-${donor.lastDonationDate!.month.toString().padLeft(2, '0')}-${donor.lastDonationDate!.day.toString().padLeft(2, '0')}"
                                  : 'No previous donations logged',
                              style: TextStyle(fontSize: 13.sp),
                            ),
                          ),
                        ],
                      ),
                      if (donor.lastDonationDate != null) ...[
                        SizedBox(height: 8.h),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Eligibility Countdown: ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.sp)),
                            Expanded(
                              child: Builder(
                                builder: (context) {
                                  final today = DateTime.now();
                                  final lastDonation = DateTime(donor.lastDonationDate!.year, donor.lastDonationDate!.month, donor.lastDonationDate!.day);
                                  final current = DateTime(today.year, today.month, today.day);
                                  final daysPassed = current.difference(lastDonation).inDays;
                                  final daysRemaining = 60 - daysPassed;

                                  if (daysRemaining <= 0) {
                                    return Text(
                                      '✓ Eligible (60-day period completed)',
                                      style: TextStyle(fontSize: 13.sp, color: AppTheme.success, fontWeight: FontWeight.bold),
                                    );
                                  } else {
                                    return Text(
                                      '⏳ $daysRemaining day(s) remaining until next donation',
                                      style: TextStyle(fontSize: 13.sp, color: AppTheme.warning, fontWeight: FontWeight.bold),
                                    );
                                  }
                                },
                              ),
                            ),
                          ],
                        ),
                      ],
                      if (isSystemic) ...[
                        SizedBox(height: 12.h),
                        Container(
                          padding: EdgeInsets.all(8.w),
                          decoration: BoxDecoration(
                            color: AppTheme.warning.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(8.r),
                            border: Border.all(color: AppTheme.warning.withOpacity(0.3)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.info_outline, color: AppTheme.warning),
                              SizedBox(width: 8.w),
                              Expanded(
                                child: Text(
                                  'System Constraint:\n• ${_getSystemicReason(donor)}',
                                  style: TextStyle(fontSize: 11.sp, color: Colors.amber.shade900),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      SizedBox(height: 16.h),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isSystemic ? Colors.grey.shade400 : AppTheme.primaryColor,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: () => _showUpdateEligibilityDialog(donor),
                        icon: const Icon(Icons.edit_note),
                        label: Text(isSystemic ? 'Eligibility (System Restricted)' : 'Modify Eligibility Status'),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 16.h),

              // Contact Information
              Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15.r)),
                child: Padding(
                  padding: EdgeInsets.all(16.w),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        localization.translate('contact_information'),
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 12.h),
                      _buildInfoRow(Icons.phone, donor.phoneNumber),
                      _buildInfoRow(Icons.email, donor.email),
                      _buildInfoRow(Icons.location_on, '${donor.city}, ${donor.region}'),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 16.h),

              // Donation Statistics
              Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15.r)),
                child: Padding(
                  padding: EdgeInsets.all(16.w),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        localization.translate('donation_statistics'),
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 16.h),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildStatItem(
                            context,
                            donor.totalDonations.toString(),
                            localization.translate('total_donations'),
                          ),
                          _buildStatItem(
                            context,
                            donor.totalUnits.toString(),
                            localization.translate('total_units'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 16.h),

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(elevation: 2),
                      onPressed: () {
                        Navigator.of(context).pushNamed(
                          '/chat',
                          arguments: {'otherUserId': donor.userId},
                        );
                      },
                      icon: const Icon(Icons.chat_outlined),
                      label: Text(localization.translate('chat')),
                    ),
                  ),
                  SizedBox(width: 16.w),
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(elevation: 2),
                      onPressed: () async {
                        final url = Uri.parse('tel:${donor.phoneNumber}');
                        try {
                          if (await canLaunchUrl(url)) {
                            await launchUrl(url);
                          } else {
                            throw 'Could not launch dialer';
                          }
                        } catch (_) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Calling ${donor.fullName} at ${donor.phoneNumber}...')),
                            );
                          }
                        }
                      },
                      icon: const Icon(Icons.phone_outlined),
                      label: Text(localization.translate('call')),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8.h),
      child: Row(
        children: [
          Icon(icon, size: 20.w, color: AppTheme.primaryColor),
          SizedBox(width: 12.w),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(BuildContext context, String value, String label) {
    return Column(
      children: [
        Text(
          value,
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: AppTheme.primaryColor,
                fontWeight: FontWeight.bold,
              ),
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }

  Color _getBloodGroupColor(String bloodGroup) {
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
