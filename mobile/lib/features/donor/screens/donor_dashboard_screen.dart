import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/providers.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/localization_service.dart';
import '../../../../data/repositories/donor_repository.dart';
import '../../../../data/models/donor_model.dart';
import '../../../../data/repositories/auth_repository.dart';
import '../../../../features/auth/providers/auth_providers.dart';

class DonorDashboardScreen extends ConsumerWidget {
  const DonorDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final localization = ref.watch(localizationServiceProvider);
    final donorRepo = ref.watch(donorRepositoryProvider);
    final userAsync = ref.watch(currentUserProvider);
    final user = userAsync.value;

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: FutureBuilder<DonorModel?>(
        future: donorRepo.getCurrentDonorProfile(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final donor = snapshot.data;
          if (donor == null) {
            return Scaffold(
              appBar: AppBar(
                title: Text(localization.translate('donor_dashboard')),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.person_outlined),
                    onPressed: () => Navigator.of(context).pushNamed('/profile'),
                  ),
                  IconButton(
                    icon: const Icon(Icons.logout),
                    onPressed: () async {
                      await ref.read(authRepositoryProvider).logout();
                      ref.invalidate(currentUserProvider);
                      if (context.mounted) {
                        Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
                      }
                    },
                  ),
                ],
              ),
              body: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.person_outline,
                      size: 64.w,
                      color: Colors.grey,
                    ),
                    SizedBox(height: 16.h),
                    Text(
                      localization.translate('no_donor_profile'),
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    SizedBox(height: 16.h),
                    ElevatedButton(
                      onPressed: () {
                        // Create donor profile
                      },
                      child: Text(localization.translate('create_profile')),
                    ),
                  ],
                ),
              ),
            );
          }

          return CustomScrollView(
            slivers: [
              // Header
              SliverToBoxAdapter(
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 20.h),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        AppTheme.primaryColor,
                        AppTheme.secondaryColor,
                      ],
                    ),
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(30.r),
                      bottomRight: Radius.circular(30.r),
                    ),
                  ),
                  child: SafeArea(
                    bottom: false,
                    child: Row(
                      children: [
                        // Profile Avatar
                        InkWell(
                          onTap: () => Navigator.of(context).pushNamed('/profile'),
                          child: Container(
                            width: 56.w,
                            height: 56.w,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                            child: Icon(
                              Icons.person,
                              color: Colors.white,
                              size: 28.w,
                            ),
                          ),
                        ),
                        SizedBox(width: 16.w),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                user != null ? 'Welcome Back, ${user.fullName}' : 'Welcome Back',
                                style: TextStyle(
                                  fontSize: 14.sp,
                                  color: Colors.white.withOpacity(0.9),
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              Row(
                                children: [
                                  Container(
                                    decoration: const BoxDecoration(
                                      color: Colors.white,
                                      shape: BoxShape.circle,
                                    ),
                                    padding: EdgeInsets.all(4.w),
                                    child: Image.asset(
                                      'assets/images/logo.png',
                                      height: 24.w,
                                      width: 24.w,
                                      fit: BoxFit.contain,
                                    ),
                                  ),
                                  SizedBox(width: 8.w),
                                  Expanded(
                                    child: Text(
                                      'Donor Dashboard',
                                      style: TextStyle(
                                        fontSize: 20.sp,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        // Notification Icon
                        InkWell(
                          onTap: () => Navigator.of(context).pushNamed('/notifications'),
                          child: Container(
                            width: 48.w,
                            height: 48.w,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              shape: BoxShape.circle,
                            ),
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                Icon(
                                  Icons.notifications_outlined,
                                  color: Colors.white,
                                  size: 24.w,
                                ),
                                Positioned(
                                  top: 8.w,
                                  right: 8.w,
                                  child: Container(
                                    width: 8.w,
                                    height: 8.w,
                                    decoration: const BoxDecoration(
                                      color: Colors.red,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              SliverToBoxAdapter(child: SizedBox(height: 24.h)),
              
              // Donation Status Card
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24.w),
                  child: _buildDonationStatusCard(context, donor),
                ),
              ),
              SliverToBoxAdapter(child: SizedBox(height: 24.h)),
              
              // Statistics Cards
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24.w),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Your Impact',
                        style: TextStyle(
                          fontSize: 18.sp,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.onSurface,
                        ),
                      ),
                      SizedBox(height: 16.h),
                      Row(
                        children: [
                          Expanded(
                            child: _buildStatCard(
                              donor.totalDonations.toString(),
                              'Donations Made',
                              Icons.volunteer_activism,
                              AppTheme.primaryColor,
                            ),
                          ),
                          SizedBox(width: 12.w),
                          Expanded(
                            child: _buildStatCard(
                              '${(donor.totalDonations * 3).toString()}',
                              'Lives Saved',
                              Icons.favorite,
                              AppTheme.success,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 12.h),
                      Row(
                        children: [
                          Expanded(
                            child: _buildStatCard(
                              donor.totalUnits.toString(),
                              'Units Donated',
                              Icons.opacity,
                              AppTheme.accentColor,
                            ),
                          ),
                          SizedBox(width: 12.w),
                          Expanded(
                            child: _buildStatCard(
                              '${(donor.totalDonations * 50).toString()}',
                              'Rewards Points',
                              Icons.emoji_events,
                              Colors.amber,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(child: SizedBox(height: 32.h)),
              
              // Quick Actions
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24.w),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Quick Actions',
                        style: TextStyle(
                          fontSize: 18.sp,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.onSurface,
                        ),
                      ),
                      SizedBox(height: 16.h),
                      GridView.count(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisCount: 2,
                        mainAxisSpacing: 12.w,
                        crossAxisSpacing: 12.w,
                        childAspectRatio: 1.1,
                        children: [
                          _buildActionCard(
                            'Donate Now',
                            Icons.bloodtype,
                            AppTheme.primaryColor,
                            () => Navigator.of(context).pushNamed('/eligibility-check'),
                          ),
                          _buildActionCard(
                            'Schedule',
                            Icons.calendar_today,
                            AppTheme.accentColor,
                            () => Navigator.of(context).pushNamed('/book-appointment'),
                          ),
                          _buildActionCard(
                            'Nearby Requests',
                            Icons.location_on,
                            AppTheme.success,
                            () => Navigator.of(context).pushNamed('/blood-requests'),
                          ),
                          _buildActionCard(
                            'History',
                            Icons.history,
                            AppTheme.warning,
                            () => Navigator.of(context).pushNamed('/donation-history'),
                          ),
                          _buildActionCard(
                            localization.translate('chat'),
                            Icons.chat_bubble,
                            Colors.indigo,
                            () => Navigator.of(context).pushNamed('/chat-list'),
                          ),
                          _buildActionCard(
                            localization.translate('rewards'),
                            Icons.emoji_events,
                            Colors.amber[800]!,
                            () => Navigator.of(context).pushNamed('/rewards'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(child: SizedBox(height: 32.h)),
              
              // Achievements Section
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24.w),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Achievements',
                            style: TextStyle(
                              fontSize: 18.sp,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.onSurface,
                            ),
                          ),
                          TextButton(
                            onPressed: () => Navigator.of(context).pushNamed('/rewards'),
                            child: Text('View All'),
                          ),
                        ],
                      ),
                      SizedBox(height: 16.h),
                      SizedBox(
                        height: 130.h,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          children: [
                            _buildAchievementBadge(
                              'Bronze Level',
                              '3+ Donations',
                              Icons.military_tech,
                              Colors.brown,
                              donor.totalDonations >= 3,
                            ),
                            SizedBox(width: 12.w),
                            _buildAchievementBadge(
                              'Silver Level',
                              '5+ Donations',
                              Icons.workspace_premium,
                              Colors.blueGrey,
                              donor.totalDonations >= 5,
                            ),
                            SizedBox(width: 12.w),
                            _buildAchievementBadge(
                              'Gold Level',
                              '8+ Donations',
                              Icons.emoji_events,
                              Colors.amber,
                              donor.totalDonations >= 8,
                            ),
                            SizedBox(width: 12.w),
                            _buildAchievementBadge(
                              'Platinum Level',
                              '10+ Donations',
                              Icons.stars,
                              Colors.teal,
                              donor.totalDonations >= 10,
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 12.h),
                      _buildAchievementProgress(donor),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(child: SizedBox(height: 100.h)),
            ],
          );
        },
      ),
    );
  }

  Widget _buildDonationStatusCard(BuildContext context, DonorModel donor) {
    final today = DateTime.now();
    int? daysRemaining;
    String lastDonationText = 'No previous donations logged';

    if (donor.lastDonationDate != null) {
      final lastDonation = DateTime(donor.lastDonationDate!.year, donor.lastDonationDate!.month, donor.lastDonationDate!.day);
      final current = DateTime(today.year, today.month, today.day);
      final daysPassed = current.difference(lastDonation).inDays;
      daysRemaining = 60 - daysPassed;
      lastDonationText = 'Last Donation: ${donor.lastDonationDate!.year}-${donor.lastDonationDate!.month.toString().padLeft(2, '0')}-${donor.lastDonationDate!.day.toString().padLeft(2, '0')}';
    }

    final isSystemicEligible = (daysRemaining == null || daysRemaining <= 0);
    final overallEligible = donor.isEligible && isSystemicEligible;

    String eligibilityMessage = 'You can donate blood today!';
    if (!donor.isEligible) {
      eligibilityMessage = donor.eligibilityReason ?? 'Temporary exclusion active';
    } else if (daysRemaining != null && daysRemaining > 0) {
      eligibilityMessage = '⏳ $daysRemaining day(s) until next eligible donation';
    }

    return Container(
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: overallEligible
              ? [AppTheme.success, AppTheme.successDark]
              : [AppTheme.warning, AppTheme.warningDark],
        ),
        borderRadius: BorderRadius.circular(20.r),
        boxShadow: [
          BoxShadow(
            color: (overallEligible ? AppTheme.success : AppTheme.warning).withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 56.w,
            height: 56.w,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(16.r),
            ),
            child: Icon(
              overallEligible ? Icons.check_circle : Icons.schedule,
              color: Colors.white,
              size: 32.w,
            ),
          ),
          SizedBox(width: 16.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  overallEligible ? 'Eligible to Donate' : 'Waiting / Restrained Period',
                  style: TextStyle(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  lastDonationText,
                  style: TextStyle(
                    fontSize: 11.sp,
                    color: Colors.white.withOpacity(0.85),
                  ),
                ),
                SizedBox(height: 2.h),
                Text(
                  eligibilityMessage,
                  style: TextStyle(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          if (overallEligible)
            InkWell(
              onTap: () => Navigator.of(context).pushNamed('/book-appointment'),
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20.r),
                ),
                child: Text(
                  'Donate',
                  style: TextStyle(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.success,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
    String value,
    String label,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, size: 32.w, color: color),
          SizedBox(height: 8.h),
          Text(
            value,
            style: TextStyle(
              fontSize: 24.sp,
              fontWeight: FontWeight.bold,
              color: AppTheme.onSurface,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 12.sp,
              color: AppTheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildActionCard(
    String title,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20.r),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20.r),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 56.w,
              height: 56.w,
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16.r),
              ),
              child: Icon(icon, color: color, size: 28.w),
            ),
            SizedBox(height: 12.h),
            Text(
              title,
              style: TextStyle(
                fontSize: 14.sp,
                fontWeight: FontWeight.w600,
                color: AppTheme.onSurface,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAchievementBadge(
    String title,
    String subtitle,
    IconData icon,
    Color color,
    bool unlocked,
  ) {
    return Container(
      width: 108.w,
      padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 8.h),
      decoration: BoxDecoration(
        color: unlocked ? color.withOpacity(0.1) : Colors.grey[200],
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(
          color: unlocked ? color : Colors.grey[300]!,
          width: 2,
        ),
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: unlocked ? color : Colors.grey[400],
              size: 32.w,
            ),
            SizedBox(height: 4.h),
            Text(
              title,
              style: TextStyle(
                fontSize: 11.sp,
                fontWeight: FontWeight.bold,
                color: unlocked ? AppTheme.onSurface : Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 2.h),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 9.sp,
                color: unlocked ? color : Colors.grey[500],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAchievementProgress(DonorModel donor) {
    int nextThreshold = 3;
    String nextLevel = 'Bronze';
    if (donor.totalDonations >= 8) {
      nextThreshold = 10;
      nextLevel = 'Platinum';
    } else if (donor.totalDonations >= 5) {
      nextThreshold = 8;
      nextLevel = 'Gold';
    } else if (donor.totalDonations >= 3) {
      nextThreshold = 5;
      nextLevel = 'Silver';
    }

    final double progress = (donor.totalDonations / nextThreshold).clamp(0.0, 1.0);
    final int remaining = nextThreshold - donor.totalDonations;

    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                donor.totalDonations >= 10
                    ? 'All levels unlocked! 🎉'
                    : 'Next Level: $nextLevel',
                style: TextStyle(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.onSurface,
                ),
              ),
              if (donor.totalDonations < 10)
                Text(
                  '$remaining more to go',
                  style: TextStyle(
                    fontSize: 11.sp,
                    color: AppTheme.primaryColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
          SizedBox(height: 8.h),
          ClipRRect(
            borderRadius: BorderRadius.circular(10.r),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.grey[200],
              valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
              minHeight: 6.h,
            ),
          ),
        ],
      ),
    );
  }
}
