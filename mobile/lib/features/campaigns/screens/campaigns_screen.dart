import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/localization_service.dart';
import '../../../../core/providers/providers.dart';
import '../../../../data/repositories/campaign_repository.dart';
import '../../../../data/models/campaign_model.dart';

class CampaignsScreen extends ConsumerStatefulWidget {
  const CampaignsScreen({super.key});

  @override
  ConsumerState<CampaignsScreen> createState() => _CampaignsScreenState();
}

class _CampaignsScreenState extends ConsumerState<CampaignsScreen> {
  final Set<int> _registeringIds = {};
  final Set<int> _registeredCampaignIds = {};

  void _refresh() {
    setState(() {});
  }

  Future<void> _toggleRegister(CampaignModel campaign) async {
    final campaignRepo = ref.read(campaignRepositoryProvider);
    final isRegistered = _registeredCampaignIds.contains(campaign.id);

    setState(() {
      _registeringIds.add(campaign.id);
    });

    try {
      if (isRegistered) {
        await campaignRepo.unregisterFromCampaign(campaign.id);
        _registeredCampaignIds.remove(campaign.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Unregistered from campaign.')),
          );
        }
      } else {
        await campaignRepo.registerForCampaign(campaign.id);
        _registeredCampaignIds.add(campaign.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Registered for "${campaign.title}" successfully!'),
              backgroundColor: AppTheme.success,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Action failed: $e'), backgroundColor: AppTheme.error),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _registeringIds.remove(campaign.id);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final localization = ref.watch(localizationServiceProvider);
    final campaignRepo = ref.watch(campaignRepositoryProvider);

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Text(localization.translate('campaigns')),
          actions: [
            IconButton(
              icon: const Icon(Icons.map_outlined),
              tooltip: 'Nearby Blood Banks',
              onPressed: () => Navigator.of(context).pushNamed('/hospital-locator'),
            ),
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _refresh,
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Active Drives'),
              Tab(text: 'My Registered'),
              Tab(text: 'All Campaigns'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildCampaignsTab(context, campaignRepo, localization, mode: 'active'),
            _buildCampaignsTab(context, campaignRepo, localization, mode: 'my'),
            _buildCampaignsTab(context, campaignRepo, localization, mode: 'all'),
          ],
        ),
      ),
    );
  }

  Widget _buildCampaignsTab(
    BuildContext context,
    CampaignRepository campaignRepo,
    LocalizationService localization, {
    required String mode,
  }) {
    return FutureBuilder<List<CampaignModel>>(
      future: mode == 'my' ? campaignRepo.getMyCampaigns() : campaignRepo.getCampaigns(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        var campaigns = snapshot.data ?? [];
        if (mode == 'active') {
          campaigns = campaigns.where((c) => c.isActive).toList();
        }

        if (campaigns.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.campaign_outlined,
                  size: 64.w,
                  color: Colors.grey,
                ),
                SizedBox(height: 16.h),
                Text(
                  mode == 'my' ? 'No registered campaigns yet.' : localization.translate('no_campaigns'),
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                SizedBox(height: 16.h),
                ElevatedButton.icon(
                  onPressed: () => Navigator.of(context).pushNamed('/hospital-locator'),
                  icon: const Icon(Icons.location_on),
                  label: const Text('Find Nearby Blood Banks'),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: EdgeInsets.all(16.w),
          itemCount: campaigns.length,
          itemBuilder: (context, index) {
            final campaign = campaigns[index];
            final isLoading = _registeringIds.contains(campaign.id);
            final isRegistered = _registeredCampaignIds.contains(campaign.id) || mode == 'my';

            return Card(
              margin: EdgeInsets.only(bottom: 16.h),
              elevation: 3,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
              clipBehavior: Clip.antiAlias,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: 140.h,
                    width: double.infinity,
                    color: _getCampaignTypeColor(campaign.type).withOpacity(0.85),
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: Icon(
                            Icons.campaign,
                            size: 80.w,
                            color: Colors.white.withOpacity(0.25),
                          ),
                        ),
                        Positioned(
                          top: 12.h,
                          left: 12.w,
                          child: Container(
                            padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.9),
                              borderRadius: BorderRadius.circular(12.r),
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
                        ),
                        if (campaign.isActive)
                          Positioned(
                            top: 12.h,
                            right: 12.w,
                            child: Container(
                              padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                              decoration: BoxDecoration(
                                color: AppTheme.success,
                                borderRadius: BorderRadius.circular(12.r),
                              ),
                              child: Text(
                                'ACTIVE DRIVE',
                                style: TextStyle(
                                  fontSize: 10.sp,
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.all(16.w),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          campaign.title,
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        SizedBox(height: 8.h),
                        Text(
                          campaign.description,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        SizedBox(height: 12.h),
                        Row(
                          children: [
                            Icon(Icons.event, size: 16.w, color: AppTheme.onSurfaceVariant),
                            SizedBox(width: 4.w),
                            Text(
                              '${campaign.startDate.day}/${campaign.startDate.month}/${campaign.startDate.year} - ${campaign.endDate.day}/${campaign.endDate.month}/${campaign.endDate.year}',
                              style: TextStyle(fontSize: 12.sp, color: AppTheme.onSurfaceVariant),
                            ),
                          ],
                        ),
                        SizedBox(height: 16.h),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            TextButton.icon(
                              onPressed: () {
                                Navigator.of(context).pushNamed(
                                  '/campaign-details',
                                  arguments: campaign.id,
                                );
                              },
                              icon: const Icon(Icons.info_outline, size: 18),
                              label: const Text('Details'),
                            ),
                            ElevatedButton.icon(
                              onPressed: isLoading ? null : () => _toggleRegister(campaign),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: isRegistered ? Colors.grey : AppTheme.primaryColor,
                                foregroundColor: Colors.white,
                              ),
                              icon: isLoading
                                  ? SizedBox(
                                      width: 14.w,
                                      height: 14.w,
                                      child: const CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                    )
                                  : Icon(isRegistered ? Icons.check_circle : Icons.how_to_reg, size: 18),
                              label: Text(isRegistered ? 'RSVP\'d (Unregister)' : 'RSVP / Register'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
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
      case 'donation_awareness':
        return AppTheme.primaryColor;
      case 'emergency':
      case 'emergency_appeal':
        return AppTheme.error;
      case 'education':
      case 'health_education':
        return AppTheme.success;
      case 'event':
      case 'community_event':
        return AppTheme.warning;
      default:
        return Colors.indigo;
    }
  }
}
