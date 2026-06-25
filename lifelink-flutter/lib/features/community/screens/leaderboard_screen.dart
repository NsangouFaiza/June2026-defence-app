import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/localization_service.dart';
import '../../../../core/providers/providers.dart';
import '../../../../data/repositories/community_repository.dart';
import '../../../../data/models/leaderboard_model.dart';

class LeaderboardScreen extends ConsumerWidget {
  const LeaderboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final localization = ref.watch(localizationServiceProvider);
    final communityRepo = ref.watch(communityRepositoryProvider);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(localization.translate('leaderboard')),
          bottom: TabBar(
            tabs: [
              Tab(text: localization.translate('top_donors')),
              Tab(text: localization.translate('top_regions')),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildTopDonorsTab(context, ref, communityRepo, localization),
            _buildTopRegionsTab(context, ref, communityRepo, localization),
          ],
        ),
      ),
    );
  }

  Widget _buildTopDonorsTab(
    BuildContext context,
    WidgetRef ref,
    CommunityRepository communityRepo,
    LocalizationService localization,
  ) {
    return FutureBuilder<List<LeaderboardModel>>(
      future: communityRepo.getTopDonors(),
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
              localization.translate('no_data_available'),
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          );
        }

        return ListView.builder(
          padding: EdgeInsets.all(16.w),
          itemCount: donors.length,
          itemBuilder: (context, index) {
            final donor = donors[index];
            final rank = index + 1;
            final isTopThree = rank <= 3;

            return Card(
              margin: EdgeInsets.only(bottom: 12.h),
              color: isTopThree
                  ? AppTheme.primaryColor.withOpacity(0.05)
                  : null,
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: _getRankColor(rank),
                  child: Text(
                    '#$rank',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                title: Text(
                  donor.name,
                  style: TextStyle(
                    fontWeight: isTopThree ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                subtitle: Text('${donor.donations} donations'),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${donor.points} pts',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                    if (donor.badge != null)
                      Container(
                        margin: EdgeInsets.only(top: 4.h),
                        padding: EdgeInsets.symmetric(
                          horizontal: 6.w,
                          vertical: 2.h,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.warning.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4.r),
                        ),
                        child: Text(
                          donor.badge!,
                          style: TextStyle(
                            fontSize: 10.sp,
                            color: AppTheme.warning,
                          ),
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

  Widget _buildTopRegionsTab(
    BuildContext context,
    WidgetRef ref,
    CommunityRepository communityRepo,
    LocalizationService localization,
  ) {
    return FutureBuilder<List<LeaderboardModel>>(
      future: communityRepo.getTopRegions(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        final regions = snapshot.data ?? [];

        if (regions.isEmpty) {
          return Center(
            child: Text(
              localization.translate('no_data_available'),
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          );
        }

        return ListView.builder(
          padding: EdgeInsets.all(16.w),
          itemCount: regions.length,
          itemBuilder: (context, index) {
            final region = regions[index];
            final rank = index + 1;

            return Card(
              margin: EdgeInsets.only(bottom: 12.h),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: _getRankColor(rank),
                  child: Text(
                    '#$rank',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                title: Text(region.name),
                subtitle: Text('${region.donations} donations'),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${region.donors} donors',
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                    Text(
                      '${region.points} pts',
                      style: TextStyle(
                        color: AppTheme.primaryColor,
                        fontWeight: FontWeight.bold,
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

  Color _getRankColor(int rank) {
    switch (rank) {
      case 1:
        return Colors.amber;
      case 2:
        return Colors.grey;
      case 3:
        return Colors.brown;
      default:
        return AppTheme.primaryColor;
    }
  }
}
