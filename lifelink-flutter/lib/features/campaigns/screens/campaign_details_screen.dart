import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/localization_service.dart';
import '../../../../core/providers/providers.dart';
import '../../../../data/repositories/campaign_repository.dart';
import '../../../../data/models/campaign_model.dart';

class CampaignDetailsScreen extends ConsumerWidget {
  final int campaignId;

  const CampaignDetailsScreen({super.key, required this.campaignId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final localization = ref.watch(localizationServiceProvider);
    final campaignRepo = ref.watch(campaignRepositoryProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(localization.translate('campaign_details')),
      ),
      body: FutureBuilder<CampaignModel>(
        future: campaignRepo.getCampaignById(campaignId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final campaign = snapshot.data!;
          return SingleChildScrollView(
            padding: EdgeInsets.all(16.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (campaign.imageUrl != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16.r),
                    child: Image.network(
                      campaign.imageUrl!,
                      width: double.infinity,
                      height: 200.h,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          height: 200.h,
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(16.r),
                          ),
                          child: Icon(
                            Icons.campaign,
                            size: 64.w,
                            color: AppTheme.primaryColor,
                          ),
                        );
                      },
                    ),
                  ),
                SizedBox(height: 24.h),

                // Title and Type
                Text(
                  campaign.title,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                SizedBox(height: 8.h),
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 12.w,
                        vertical: 6.h,
                      ),
                      decoration: BoxDecoration(
                        color: _getCampaignTypeColor(campaign.type).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8.r),
                        border: Border.all(
                          color: _getCampaignTypeColor(campaign.type),
                        ),
                      ),
                      child: Text(
                        campaign.type.toUpperCase(),
                        style: TextStyle(
                          fontSize: 12.sp,
                          color: _getCampaignTypeColor(campaign.type),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const Spacer(),
                    if (campaign.isActive)
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 12.w,
                          vertical: 6.h,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.success.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8.r),
                        ),
                        child: Text(
                          localization.translate('active'),
                          style: TextStyle(
                            fontSize: 12.sp,
                            color: AppTheme.success,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
                SizedBox(height: 24.h),

                // Description
                Card(
                  child: Padding(
                    padding: EdgeInsets.all(16.w),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          localization.translate('description'),
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        SizedBox(height: 8.h),
                        Text(
                          campaign.description,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: 16.h),

                // Details
                Card(
                  child: Padding(
                    padding: EdgeInsets.all(16.w),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          localization.translate('details'),
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        SizedBox(height: 16.h),
                        _buildDetailRow(
                          context,
                          Icons.calendar_today,
                          localization.translate('start_date'),
                          '${campaign.startDate.day}/${campaign.startDate.month}/${campaign.startDate.year}',
                        ),
                        _buildDetailRow(
                          context,
                          Icons.event,
                          localization.translate('end_date'),
                          '${campaign.endDate.day}/${campaign.endDate.month}/${campaign.endDate.year}',
                        ),
                        if (campaign.location != null)
                          _buildDetailRow(
                            context,
                            Icons.location_on,
                            localization.translate('location'),
                            campaign.location!,
                          ),
                        _buildDetailRow(
                          context,
                          Icons.people,
                          localization.translate('participants'),
                          '${campaign.participantsCount ?? 0}',
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: 24.h),

                // Action Buttons
                if (campaign.isActive)
                  ElevatedButton(
                    onPressed: () {
                      // Register for campaign
                    },
                    style: ElevatedButton.styleFrom(
                      padding: EdgeInsets.symmetric(vertical: 16.h),
                    ),
                    child: Text(localization.translate('register_now')),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildDetailRow(
    BuildContext context,
    IconData icon,
    String label,
    String value,
  ) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8.h),
      child: Row(
        children: [
          Icon(icon, size: 20.w, color: AppTheme.primaryColor),
          SizedBox(width: 12.w),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.grey,
                fontSize: 14,
              ),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Color _getCampaignTypeColor(String type) {
    switch (type.toLowerCase()) {
      case 'donation':
        return AppTheme.primaryColor;
      case 'emergency':
        return AppTheme.error;
      case 'education':
        return AppTheme.success;
      case 'event':
        return AppTheme.warning;
      default:
        return Colors.grey;
    }
  }
}
