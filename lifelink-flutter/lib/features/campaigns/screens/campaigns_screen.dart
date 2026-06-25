import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/localization_service.dart';
import '../../../../core/providers/providers.dart';
import '../../../../data/repositories/campaign_repository.dart';
import '../../../../data/models/campaign_model.dart';

class CampaignsScreen extends ConsumerWidget {
  const CampaignsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final localization = ref.watch(localizationServiceProvider);
    final campaignRepo = ref.watch(campaignRepositoryProvider);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(localization.translate('campaigns')),
          bottom: TabBar(
            tabs: [
              Tab(text: localization.translate('active_campaigns')),
              Tab(text: localization.translate('all_campaigns')),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildCampaignsTab(context, ref, campaignRepo, localization, activeOnly: true),
            _buildCampaignsTab(context, ref, campaignRepo, localization, activeOnly: false),
          ],
        ),
      ),
    );
  }

  Widget _buildCampaignsTab(
    BuildContext context,
    WidgetRef ref,
    CampaignRepository campaignRepo,
    LocalizationService localization, {
    required bool activeOnly,
  }) {
    return FutureBuilder<List<CampaignModel>>(
      future: campaignRepo.getCampaigns(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        var campaigns = snapshot.data ?? [];
        if (activeOnly) {
          campaigns = campaigns.where((c) => c.isActive).toList();
        }

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
                  Navigator.of(context).pushNamed(
                    '/campaign-details',
                    arguments: campaign.id,
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
                                  color: _getCampaignTypeColor(campaign.type).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8.r),
                                  border: Border.all(
                                    color: _getCampaignTypeColor(campaign.type),
                                  ),
                                ),
                                child: Text(
                                  campaign.type.toUpperCase(),
                                  style: TextStyle(
                                    fontSize: 10.sp,
                                    color: _getCampaignTypeColor(campaign.type),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const Spacer(),
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
                          SizedBox(height: 12.h),
                          Text(
                            campaign.title,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          SizedBox(height: 8.h),
                          Text(
                            campaign.description,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          SizedBox(height: 12.h),
                          Row(
                            children: [
                              Icon(
                                Icons.calendar_today_outlined,
                                size: 16.w,
                                color: Colors.grey,
                              ),
                              SizedBox(width: 4.w),
                              Text(
                                '${campaign.startDate.day}/${campaign.startDate.month}/${campaign.startDate.year}',
                                style: const TextStyle(fontSize: 12, color: Colors.grey),
                              ),
                              const Spacer(),
                              Icon(
                                Icons.people_outlined,
                                size: 16.w,
                                color: Colors.grey,
                              ),
                              SizedBox(width: 4.w),
                              Text(
                                '${campaign.participantsCount ?? 0}',
                                style: const TextStyle(fontSize: 12, color: Colors.grey),
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
