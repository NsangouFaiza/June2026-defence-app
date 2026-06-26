import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/providers.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/localization_service.dart';
import '../../../../data/repositories/donor_repository.dart';
import '../../../../data/models/donor_model.dart';
import 'package:url_launcher/url_launcher.dart';

class DonorDetailsScreen extends ConsumerWidget {
  final int donorId;

  const DonorDetailsScreen({super.key, required this.donorId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final localization = ref.watch(localizationServiceProvider);
    final donorRepo = ref.watch(donorRepositoryProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(localization.translate('donor_details')),
      ),
      body: FutureBuilder<DonorModel>(
        future: donorRepo.getDonorById(donorId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final donor = snapshot.data!;
          return SingleChildScrollView(
            padding: EdgeInsets.all(16.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Profile Header
                Card(
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
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        SizedBox(height: 4.h),
                        Text(
                          donor.bloodGroup ?? 'O+',
                          style: TextStyle(
                            fontSize: 18.sp,
                            color: _getBloodGroupColor(donor.bloodGroup ?? 'O+'),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 8.h),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              donor.isEligible ? Icons.check_circle : Icons.cancel,
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
                  ),
                ),
                SizedBox(height: 16.h),

                // Contact Information
                Card(
                  child: Padding(
                    padding: EdgeInsets.all(16.w),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          localization.translate('contact_information'),
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        SizedBox(height: 16.h),
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
                  child: Padding(
                    padding: EdgeInsets.all(16.w),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          localization.translate('donation_statistics'),
                          style: Theme.of(context).textTheme.titleLarge,
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
          );
        },
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
