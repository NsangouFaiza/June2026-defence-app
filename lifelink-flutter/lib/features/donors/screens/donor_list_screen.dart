import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../core/providers/providers.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/localization_service.dart';
import '../../../../data/repositories/donor_repository.dart';
import '../../../../data/models/donor_model.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../widgets/lifelink_app_bar.dart';

class DonorListScreen extends ConsumerStatefulWidget {
  const DonorListScreen({super.key});

  @override
  ConsumerState<DonorListScreen> createState() => _DonorListScreenState();
}

class _DonorListScreenState extends ConsumerState<DonorListScreen> {
  String _selectedBloodGroup = 'All';
  String _selectedEligibility = 'all';

  @override
  Widget build(BuildContext context) {
    final localization = ref.watch(localizationServiceProvider);
    final donorRepo = ref.watch(donorRepositoryProvider);

    final bloodGroupItems = ['All', ...AppConstants.bloodGroups];

    return Scaffold(
      appBar: LifeLinkAppBar(
        title: localization.translate('donor_list'),
      ),
      body: Column(
        children: [
          // Filter Bar
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                // Blood Group Dropdown
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _selectedBloodGroup,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: 'Blood Group',
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 8.h),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10.r)),
                    ),
                    items: bloodGroupItems
                        .map((bg) => DropdownMenuItem(
                              value: bg,
                              child: Text(
                                bg,
                                style: TextStyle(fontSize: 13.sp),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ))
                        .toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => _selectedBloodGroup = value);
                      }
                    },
                  ),
                ),
                SizedBox(width: 12.w),
                // Eligibility Dropdown
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _selectedEligibility,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: 'Eligibility',
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 8.h),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10.r)),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'all', child: Text('All')),
                      DropdownMenuItem(value: 'eligible', child: Text('Eligible')),
                      DropdownMenuItem(value: 'ineligible', child: Text('Ineligible')),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => _selectedEligibility = value);
                      }
                    },
                  ),
                ),
              ],
            ),
          ),

          // Donor List View
          Expanded(
            child: FutureBuilder<List<DonorModel>>(
              future: donorRepo.getDonors(
                bloodGroup: _selectedBloodGroup,
                eligibility: _selectedEligibility,
              ),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: EdgeInsets.all(20.w),
                      child: Text(
                        'Error loading donors: ${snapshot.error}',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppTheme.error, fontSize: 13.sp),
                      ),
                    ),
                  );
                }

                List<DonorModel> donors = snapshot.data ?? [];

                // Combined double safety client-side filter
                if (_selectedBloodGroup != 'All') {
                  donors = donors.where((d) => (d.bloodGroup ?? '').toUpperCase() == _selectedBloodGroup.toUpperCase()).toList();
                }
                if (_selectedEligibility == 'eligible') {
                  donors = donors.where((d) => d.isEligible).toList();
                } else if (_selectedEligibility == 'ineligible') {
                  donors = donors.where((d) => !d.isEligible).toList();
                }

                if (donors.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: EdgeInsets.all(24.w),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.person_search_rounded, size: 48.w, color: Colors.grey.shade400),
                          SizedBox(height: 12.h),
                          Text(
                            localization.translate('no_donors_found'),
                            style: TextStyle(
                              fontSize: 15.sp,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.onSurfaceVariant,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  padding: EdgeInsets.all(16.w),
                  itemCount: donors.length,
                  itemBuilder: (context, index) {
                    final donor = donors[index];
                    return Card(
                      margin: EdgeInsets.only(bottom: 12.h),
                      elevation: 1,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
                      child: ListTile(
                        contentPadding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 6.h),
                        leading: CircleAvatar(
                          radius: 22.r,
                          backgroundColor: _getBloodGroupColor(donor.bloodGroup ?? 'O+'),
                          child: Text(
                            donor.bloodGroup ?? 'O+',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 13.sp,
                            ),
                          ),
                        ),
                        title: Text(
                          donor.fullName,
                          style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.bold),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(height: 2.h),
                            Text(
                              '${donor.donorIdCode} • ${donor.formattedLocation}',
                              style: TextStyle(
                                fontSize: 12.sp,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.onSurfaceVariant,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            SizedBox(height: 4.h),
                            Row(
                              children: [
                                Icon(
                                  donor.isEligible ? Icons.check_circle_rounded : Icons.cancel_rounded,
                                  size: 14.w,
                                  color: donor.isEligible ? AppTheme.success : AppTheme.error,
                                ),
                                SizedBox(width: 4.w),
                                Flexible(
                                  child: Text(
                                    donor.isEligible
                                        ? localization.translate('eligible')
                                        : localization.translate('ineligible'),
                                    style: TextStyle(
                                      fontSize: 12.sp,
                                      fontWeight: FontWeight.w600,
                                      color: donor.isEligible ? AppTheme.success : AppTheme.error,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        trailing: IconButton(
                          icon: Icon(Icons.chat_bubble_outline_rounded, color: AppTheme.primaryColor, size: 22.w),
                          onPressed: () {
                            Navigator.of(context).pushNamed(
                              '/chat',
                              arguments: {'otherUserId': donor.userId},
                            );
                          },
                        ),
                        onTap: () {
                          Navigator.of(context).pushNamed(
                            '/donor-details',
                            arguments: donor.id,
                          );
                        },
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Color _getBloodGroupColor(String? bloodGroup) {
    switch (bloodGroup?.toUpperCase()) {
      case 'A+':
        return Colors.red.shade700;
      case 'A-':
        return Colors.redAccent.shade400;
      case 'B+':
        return Colors.blue.shade700;
      case 'B-':
        return Colors.blueAccent.shade400;
      case 'AB+':
        return Colors.purple.shade700;
      case 'AB-':
        return Colors.purpleAccent.shade400;
      case 'O+':
        return Colors.green.shade700;
      case 'O-':
        return Colors.greenAccent.shade700;
      default:
        return Colors.blueGrey;
    }
  }
}
