import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/localization_service.dart';
import '../../../../core/providers/providers.dart';
import '../../../../data/repositories/campaign_repository.dart';
import '../../../../data/models/campaign_model.dart';
import 'campaign_details_screen.dart';

class CampaignFeedScreen extends ConsumerWidget {
  const CampaignFeedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final localization = ref.watch(localizationServiceProvider);
    final campaignRepo = ref.watch(campaignRepositoryProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(localization.translate('campaigns')),
      ),
      body: FutureBuilder<List<CampaignModel>>(
        future: campaignRepo.getCampaigns(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final campaigns = snapshot.data ?? [];

          if (campaigns.isEmpty) {
            return Center(
              child: Text(
                localization.translate('no_campaigns'),
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            );
          }

          return ListView.builder(
            padding: EdgeInsets.all(16.w),
            itemCount: campaigns.length,
            itemBuilder: (context, index) {
              final campaign = campaigns[index];
              return Card(
                margin: EdgeInsets.only(bottom: 16.h),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (ctx) => CampaignDetailsScreen(campaignId: campaign.id),
                      ),
                    );
                  },
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (campaign.imageUrl != null)
                        Image.network(
                          campaign.imageUrl!,
                          width: double.infinity,
                          height: 180.h,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              height: 180.h,
                              color: AppTheme.primaryColor.withOpacity(0.1),
                              child: Icon(
                                Icons.campaign,
                                size: 64.w,
                                color: AppTheme.primaryColor,
                              ),
                            );
                          },
                        ),
                      Padding(
                        padding: EdgeInsets.all(16.w),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 8.w,
                                    vertical: 4.h,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _getCampaignTypeColor(campaign.category).withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8.r),
                                    border: Border.all(
                                      color: _getCampaignTypeColor(campaign.category),
                                    ),
                                  ),
                                  child: Text(
                                    campaign.category,
                                    style: TextStyle(
                                      fontSize: 10.sp,
                                      color: _getCampaignTypeColor(campaign.category),
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  '${campaign.startDate.day}/${campaign.startDate.month}/${campaign.startDate.year}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 12.h),
                            Text(
                              campaign.title,
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            SizedBox(height: 8.h),
                            Text(
                              campaign.description,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                            SizedBox(height: 16.h),
                            Row(
                              children: [
                                Icon(
                                  Icons.location_on_outlined,
                                  size: 16.w,
                                  color: Colors.grey,
                                ),
                                SizedBox(width: 4.w),
                                Expanded(
                                  child: Text(
                                    campaign.location ?? 'Multiple locations',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (campaign.isActive)
                                  Container(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 8.w,
                                      vertical: 4.h,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppTheme.success.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8.r),
                                    ),
                                    child: Text(
                                      localization.translate('active'),
                                      style: TextStyle(
                                        fontSize: 10.sp,
                                        color: AppTheme.success,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Color _getCampaignTypeColor(String cat) {
    switch (cat.toUpperCase()) {
      case 'EMERGENCY BLOOD DRIVE':
      case 'EMERGENCY_APPEAL':
        return AppTheme.error;
      case 'AWARENESS':
      case 'DONATION_AWARENESS':
      case 'HEALTH_EDUCATION':
        return AppTheme.success;
      case 'MOBILE COLLECTION':
      case 'MOBILE_COLLECTION':
        return AppTheme.primaryColor;
      case 'HOSPITAL EVENT':
      case 'HOSPITAL_EVENT':
      case 'COMMUNITY_EVENT':
        return AppTheme.warning;
      default:
        return Colors.teal;
    }
  }
}
