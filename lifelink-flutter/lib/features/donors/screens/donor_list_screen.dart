import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/providers.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/localization_service.dart';
import '../../../../data/repositories/donor_repository.dart';
import '../../../../data/models/donor_model.dart';
import '../../../../core/constants/app_constants.dart';

class DonorListScreen extends ConsumerWidget {
  const DonorListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final localization = ref.watch(localizationServiceProvider);
    final donorRepo = ref.watch(donorRepositoryProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(localization.translate('donor_list')),
      ),
      body: Column(
        children: [
          // Filters
          Container(
            padding: EdgeInsets.all(16.w),
            color: Theme.of(context).colorScheme.surface,
            child: Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    decoration: const InputDecoration(
                      labelText: 'Blood Group',
                      isDense: true,
                    ),
                    items: AppConstants.bloodGroups
                        .map((bg) => DropdownMenuItem(value: bg, child: Text(bg)))
                        .toList(),
                    onChanged: (value) {
                      // Filter by blood group
                    },
                  ),
                ),
                SizedBox(width: 16.w),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    decoration: const InputDecoration(
                      labelText: 'Eligibility',
                      isDense: true,
                    ),
                    items: const [
                      DropdownMenuItem(value: 'all', child: Text('All')),
                      DropdownMenuItem(value: 'eligible', child: Text('Eligible')),
                      DropdownMenuItem(value: 'ineligible', child: Text('Ineligible')),
                    ],
                    onChanged: (value) {
                      // Filter by eligibility
                    },
                  ),
                ),
              ],
            ),
          ),
          // Donor List
          Expanded(
            child: FutureBuilder<List<DonorModel>>(
              future: donorRepo.getDonors(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                final donors = snapshot.data ?? [];

                if (donors.isEmpty) {
                  return Center(
                    child: Text(
                      localization.translate('no_donors_found'),
                      style: Theme.of(context).textTheme.bodyLarge,
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
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: _getBloodGroupColor(donor.bloodGroup ?? 'O+'),
                          child: Text(
                            donor.bloodGroup ?? 'O+',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        title: Text(donor.fullName),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${donor.donorIdCode} • ${donor.region}, ${donor.city}', style: const TextStyle(fontWeight: FontWeight.bold)),
                            Row(
                              children: [
                                Icon(
                                  donor.isEligible ? Icons.check_circle : Icons.cancel,
                                  size: 16.w,
                                  color: donor.isEligible ? AppTheme.success : AppTheme.error,
                                ),
                                SizedBox(width: 4.w),
                                Text(
                                  donor.isEligible
                                      ? localization.translate('eligible')
                                      : localization.translate('ineligible'),
                                  style: TextStyle(
                                    color: donor.isEligible ? AppTheme.success : AppTheme.error,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.contact_phone_outlined),
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
