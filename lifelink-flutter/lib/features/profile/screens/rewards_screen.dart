import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/localization_service.dart';
import '../../../../core/providers/providers.dart';
import '../../../../data/repositories/reward_repository.dart';
import '../../../../data/models/badge_model.dart';
import '../../../../data/models/donor_reward_model.dart';

class RewardsScreen extends ConsumerWidget {
  const RewardsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final localization = ref.watch(localizationServiceProvider);
    final rewardRepo = ref.watch(rewardRepositoryProvider);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(localization.translate('rewards')),
          bottom: TabBar(
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white.withOpacity(0.7),
            indicatorColor: Colors.white,
            tabs: [
              Tab(text: localization.translate('my_badges')),
              Tab(text: localization.translate('leaderboard')),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildBadgesTab(context, ref, rewardRepo, localization),
            _buildLeaderboardTab(context, ref, rewardRepo, localization),
          ],
        ),
      ),
    );
  }

  Widget _buildBadgesTab(
    BuildContext context,
    WidgetRef ref,
    RewardRepository rewardRepo,
    LocalizationService localization,
  ) {
    return FutureBuilder<DonorRewardModel?>(
      future: rewardRepo.getMyRewards(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        final rewards = snapshot.data;
        if (rewards == null) {
          return Center(
            child: Text(
              localization.translate('no_rewards_yet'),
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          );
        }

        return SingleChildScrollView(
          padding: EdgeInsets.all(16.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Points Summary
              Card(
                color: AppTheme.primaryColor,
                child: Padding(
                  padding: EdgeInsets.all(20.w),
                  child: Column(
                    children: [
                      Icon(
                        Icons.stars,
                        size: 48.w,
                        color: Colors.white,
                      ),
                      SizedBox(height: 8.h),
                      Text(
                        '${rewards.totalPoints}',
                        style: TextStyle(
                          fontSize: 36.sp,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        localization.translate('total_points'),
                        style: TextStyle(
                          fontSize: 16.sp,
                          color: Colors.white.withOpacity(0.9),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 24.h),

              // Level Progress
              Card(
                child: Padding(
                  padding: EdgeInsets.all(16.w),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            localization.translate('current_level'),
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          Text(
                            rewards.currentLevel,
                            style: TextStyle(
                              fontSize: 18.sp,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.primaryColor,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 8.h),
                      LinearProgressIndicator(
                        value: rewards.levelProgress,
                        backgroundColor: Colors.grey[300],
                        valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
                      ),
                      SizedBox(height: 4.h),
                      Text(
                        '${(rewards.levelProgress * 100).toInt()}% to next level',
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 24.h),

              // Badges
              Text(
                localization.translate('earned_badges'),
                style: Theme.of(context).textTheme.titleLarge,
              ),
              SizedBox(height: 16.h),
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 3,
                mainAxisSpacing: 16.h,
                crossAxisSpacing: 16.w,
                childAspectRatio: 0.8,
                children: rewards.badges.map((badge) {
                  return _buildBadgeCard(context, badge, localization);
                }).toList(),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBadgeCard(BuildContext context, BadgeModel badge, LocalizationService localization) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(12.w),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 60.w,
              height: 60.w,
              decoration: BoxDecoration(
                color: _getBadgeColor(badge.type).withOpacity(0.1),
                shape: BoxShape.circle,
                border: Border.all(color: _getBadgeColor(badge.type), width: 2),
              ),
              child: Icon(
                _getBadgeIcon(badge.type),
                size: 32.w,
                color: _getBadgeColor(badge.type),
              ),
            ),
            SizedBox(height: 8.h),
            Text(
              badge.name,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            if (badge.earnedAt != null)
              Text(
                'Earned ${badge.earnedAt!.day}/${badge.earnedAt!.month}/${badge.earnedAt!.year}',
                style: const TextStyle(fontSize: 10, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildLeaderboardTab(
    BuildContext context,
    WidgetRef ref,
    RewardRepository rewardRepo,
    LocalizationService localization,
  ) {
    return FutureBuilder<List<dynamic>>(
      future: rewardRepo.getLeaderboard(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        final leaders = snapshot.data ?? [];

        if (leaders.isEmpty) {
          return Center(
            child: Text(
              localization.translate('no_leaderboard_data'),
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          );
        }

        return ListView.builder(
          padding: EdgeInsets.all(16.w),
          itemCount: leaders.length,
          itemBuilder: (context, index) {
            final leader = leaders[index];
            final rank = index + 1;
            final isTopThree = rank <= 3;

            return Card(
              margin: EdgeInsets.only(bottom: 12.h),
              color: isTopThree ? AppTheme.primaryColor.withOpacity(0.05) : null,
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
                  leader['name'] ?? 'Anonymous',
                  style: TextStyle(
                    fontWeight: isTopThree ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                subtitle: Text('${leader['total_donations'] ?? 0} donations'),
                trailing: Text(
                  '${leader['points'] ?? 0} pts',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryColor,
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Color _getBadgeColor(String type) {
    switch (type.toLowerCase()) {
      case 'bronze':
        return Colors.brown;
      case 'silver':
        return Colors.grey;
      case 'gold':
        return Colors.amber;
      case 'platinum':
        return Colors.blueGrey;
      case 'life_saver':
        return AppTheme.error;
      case 'emergency_hero':
        return Colors.orange;
      case 'top_community':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  IconData _getBadgeIcon(String type) {
    switch (type.toLowerCase()) {
      case 'bronze':
        return Icons.emoji_events;
      case 'silver':
        return Icons.emoji_events;
      case 'gold':
        return Icons.emoji_events;
      case 'platinum':
        return Icons.emoji_events;
      case 'life_saver':
        return Icons.favorite;
      case 'emergency_hero':
        return Icons.volunteer_activism;
      case 'top_community':
        return Icons.people;
      default:
        return Icons.star;
    }
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
