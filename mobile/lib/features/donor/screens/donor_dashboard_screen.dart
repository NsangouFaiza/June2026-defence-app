import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/providers.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../data/models/donor_model.dart';
import '../../../widgets/floating_ai_assistant_button.dart';

class DonorDashboardScreen extends ConsumerWidget {
  const DonorDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final localization = ref.watch(localizationServiceProvider);
    final donorRepo = ref.watch(donorRepositoryProvider);
    final userAsync = ref.watch(currentUserProvider);
    final user = userAsync.value;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      floatingActionButton: const FloatingAiAssistantButton(),
      body: FutureBuilder<DonorModel?>(
        future: donorRepo.getCurrentDonorProfile(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error loading donor profile: ${snapshot.error}'));
          }

          final donor = snapshot.data;
          if (donor == null) {
            return Scaffold(
              floatingActionButton: const FloatingAiAssistantButton(),
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
                        // Create donor profile logic
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
              // Header Banner
              SliverToBoxAdapter(
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 20.h),
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
                        if (Navigator.canPop(context)) ...[
                          IconButton(
                            icon: const Icon(Icons.arrow_back, color: Colors.white),
                            onPressed: () => Navigator.pop(context),
                          ),
                          SizedBox(width: 4.w),
                        ],
                        // Profile Avatar
                        InkWell(
                          onTap: () => Navigator.of(context).pushNamed('/profile'),
                          child: Builder(
                            builder: (context) {
                              final user = ref.watch(currentUserProvider).value;
                              final pic = user?.fullProfilePictureUrl;
                              return Container(
                                width: 54.w,
                                height: 54.w,
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white, width: 2),
                                ),
                                child: pic != null && pic.isNotEmpty
                                    ? ClipOval(
                                        child: CachedNetworkImage(
                                          imageUrl: pic,
                                          fit: BoxFit.cover,
                                          errorWidget: (context, url, error) => Icon(
                                            Icons.person,
                                            color: Colors.white,
                                            size: 28.w,
                                          ),
                                        ),
                                      )
                                    : Icon(
                                        Icons.person,
                                        color: Colors.white,
                                        size: 28.w,
                                      ),
                              );
                            },
                          ),
                        ),
                        SizedBox(width: 14.w),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                user != null ? '${user.fullName} (${donor.donorIdCode})' : 'Donor ${donor.donorIdCode}',
                                style: TextStyle(
                                  fontSize: 13.sp,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white.withOpacity(0.95),
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
                                      height: 20.w,
                                      width: 20.w,
                                      fit: BoxFit.contain,
                                    ),
                                  ),
                                  SizedBox(width: 8.w),
                                  Expanded(
                                    child: Text(
                                      'LifeLink Donor Hub',
                                      style: TextStyle(
                                        fontSize: 18.sp,
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

                        InkWell(
                          onTap: () => Navigator.of(context).pushNamed('/notifications'),
                          child: Container(
                            width: 42.w,
                            height: 42.w,
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
                                  size: 22.w,
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
              SliverToBoxAdapter(child: SizedBox(height: 20.h)),

              // Donation Status & Eligibility Card
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20.w),
                  child: _buildDonationStatusCard(context, donor),
                ),
              ),
              SliverToBoxAdapter(child: SizedBox(height: 20.h)),

              // Impact Metrics Section
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20.w),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'YOUR DONATION IMPACT',
                        style: TextStyle(
                          fontSize: 12.sp,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      SizedBox(height: 12.h),
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
                              '${donor.totalUnits} ml',
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
              SliverToBoxAdapter(child: SizedBox(height: 24.h)),

              // My Donor Badge Section
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20.w),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'MY DONOR BADGE',
                        style: TextStyle(
                          fontSize: 12.sp,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      SizedBox(height: 12.h),
                      _buildMyBadgeSection(context, donor),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(child: SizedBox(height: 24.h)),

              // Responsive 2-Column Grid of Action Cards
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20.w),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'DONOR MANAGEMENT DASHBOARD',
                        style: TextStyle(
                          fontSize: 12.sp,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      SizedBox(height: 12.h),
                      GridView.count(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisCount: 2,
                        mainAxisSpacing: 14.h,
                        crossAxisSpacing: 14.w,
                        childAspectRatio: 1.1,
                        children: [
                          _buildActionCard(
                            title: 'Appointments',
                            description: 'Schedule & manage donation visits',
                            icon: Icons.calendar_month_rounded,
                            gradient: const [Color(0xFF1E88E5), Color(0xFF1565C0)],
                            onTap: () => Navigator.of(context).pushNamed('/appointment-history'),
                          ),
                          _buildActionCard(
                            title: 'Emergency Requests',
                            description: 'Pledge blood for urgent patient needs',
                            icon: Icons.notification_important_rounded,
                            gradient: const [Color(0xFFE53935), Color(0xFFC62828)],
                            onTap: () => Navigator.of(context).pushNamed('/blood-requests'),
                          ),
                          _buildActionCard(
                            title: 'Banks & Drives',
                            description: 'Find nearby centers & RSVP campaigns',
                            icon: Icons.location_city_rounded,
                            gradient: const [Color(0xFF43A047), Color(0xFF2E7D32)],
                            onTap: () => Navigator.of(context).pushNamed('/campaigns'),
                          ),
                          _buildActionCard(
                            title: 'My Donor Badge',
                            description: 'Official credential certificate',
                            icon: Icons.workspace_premium_rounded,
                            gradient: const [Color(0xFF8E24AA), Color(0xFF6A1B9A)],
                            onTap: () => Navigator.of(context).pushNamed('/digital-donor-badge'),
                          ),
                          _buildActionCard(
                            title: 'Health Records',
                            description: 'Track vitals & lab screening history',
                            icon: Icons.health_and_safety_rounded,
                            gradient: const [Color(0xFF00ACC1), Color(0xFF00838F)],
                            onTap: () => Navigator.of(context).pushNamed('/health-records'),
                          ),
                          _buildActionCard(
                            title: 'Check Eligibility',
                            description: 'Take pre-donation questionnaire',
                            icon: Icons.fact_check_rounded,
                            gradient: const [Color(0xFFFF9800), Color(0xFFF57C00)],
                            onTap: () => Navigator.of(context).pushNamed('/eligibility-check'),
                          ),
                          _buildActionCard(
                            title: 'Rewards & Badges',
                            description: 'Redeem points & level achievements',
                            icon: Icons.emoji_events_rounded,
                            gradient: const [Color(0xFFFFA000), Color(0xFFFF6F00)],
                            onTap: () => Navigator.of(context).pushNamed('/rewards'),
                          ),
                          _buildActionCard(
                            title: 'Find Hospital',
                            description: 'Search hospitals, GPS distances & contacts',
                            icon: Icons.local_hospital_rounded,
                            gradient: const [Color(0xFFD81B60), Color(0xFFAD1457)],
                            onTap: () => Navigator.of(context).pushNamed('/hospital-locator'),
                          ),
                          _buildActionCard(
                            title: 'Leaderboard',
                            description: 'Community rankings & hero donors',
                            icon: Icons.leaderboard_rounded,
                            gradient: const [Color(0xFF3F51B5), Color(0xFF303F9F)],
                            onTap: () => Navigator.of(context).pushNamed('/leaderboard'),
                          ),
                          _buildActionCard(
                            title: 'Direct Chat',
                            description: 'Chat with hospitals & staff',
                            icon: Icons.forum_rounded,
                            gradient: const [Color(0xFF009688), Color(0xFF00695C)],
                            onTap: () => Navigator.of(context).pushNamed('/chat-list'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(child: SizedBox(height: 24.h)),

              // Achievements Level Badges
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20.w),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Donor Level & Achievements',
                            style: TextStyle(
                              fontSize: 16.sp,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.onSurface,
                            ),
                          ),
                          TextButton(
                            onPressed: () => Navigator.of(context).pushNamed('/rewards'),
                            child: const Text('View All'),
                          ),
                        ],
                      ),
                      SizedBox(height: 12.h),
                      SizedBox(
                        height: 120.h,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          children: [
                            _buildAchievementBadge(
                              'Bronze Level',
                              '3+ Donations',
                              Icons.military_tech_rounded,
                              Colors.brown,
                              donor.totalDonations >= 3,
                            ),
                            SizedBox(width: 12.w),
                            _buildAchievementBadge(
                              'Silver Level',
                              '5+ Donations',
                              Icons.workspace_premium_rounded,
                              Colors.blueGrey,
                              donor.totalDonations >= 5,
                            ),
                            SizedBox(width: 12.w),
                            _buildAchievementBadge(
                              'Gold Level',
                              '8+ Donations',
                              Icons.emoji_events_rounded,
                              Colors.amber,
                              donor.totalDonations >= 8,
                            ),
                            SizedBox(width: 12.w),
                            _buildAchievementBadge(
                              'Platinum Level',
                              '10+ Donations',
                              Icons.stars_rounded,
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
              SliverToBoxAdapter(child: SizedBox(height: 80.h)),
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
      daysRemaining = 90 - daysPassed;
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
      padding: EdgeInsets.all(18.w),
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
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 52.w,
            height: 52.w,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(16.r),
            ),
            child: Icon(
              overallEligible ? Icons.check_circle_rounded : Icons.schedule_rounded,
              color: Colors.white,
              size: 30.w,
            ),
          ),
          SizedBox(width: 14.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  overallEligible ? 'Eligible to Donate' : 'Waiting / Restrained Period',
                  style: TextStyle(
                    fontSize: 15.sp,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 2.h),
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
                if (daysRemaining != null && daysRemaining > 0 && donor.lastDonationDate != null) ...[
                  SizedBox(height: 10.h),
                  Container(
                    padding: EdgeInsets.all(10.w),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10.r),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.event_available_rounded, color: Colors.white, size: 14),
                            SizedBox(width: 6.w),
                            Text(
                              'Next Eligible Date: ${donor.lastDonationDate!.add(const Duration(days: 90)).year}-${donor.lastDonationDate!.add(const Duration(days: 90)).month.toString().padLeft(2, '0')}-${donor.lastDonationDate!.add(const Duration(days: 90)).day.toString().padLeft(2, '0')}',
                              style: TextStyle(
                                fontSize: 11.sp,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 4.h),
                        Row(
                          children: [
                            const Icon(Icons.timer_outlined, color: Colors.white, size: 14),
                            SizedBox(width: 6.w),
                            Text(
                              'Countdown: $daysRemaining day${daysRemaining > 1 ? "s" : ""} remaining',
                              style: TextStyle(
                                fontSize: 11.sp,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (overallEligible) ...[
            SizedBox(width: 8.w),
            InkWell(
              onTap: () => Navigator.of(context).pushNamed('/book-appointment'),
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20.r),
                ),
                child: Text(
                  'Donate Now',
                  style: TextStyle(
                    fontSize: 11.sp,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.success,
                  ),
                ),
              ),
            ),
          ],
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
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, size: 28.w, color: color),
          SizedBox(height: 6.h),
          Text(
            value,
            style: TextStyle(
              fontSize: 22.sp,
              fontWeight: FontWeight.bold,
              color: AppTheme.onSurface,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 11.sp,
              color: AppTheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildActionCard({
    required String title,
    required String description,
    required IconData icon,
    required List<Color> gradient,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20.r),
        child: Container(
          padding: EdgeInsets.all(14.w),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: gradient,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20.r),
            boxShadow: [
              BoxShadow(
                color: gradient.first.withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: EdgeInsets.all(10.w),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.25),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: Colors.white, size: 26.w),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 2.h),
                  Text(
                    description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.85),
                      fontSize: 10.sp,
                    ),
                  ),
                ],
              ),
            ],
          ),
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
              size: 30.w,
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

  Widget _buildMyBadgeSection(BuildContext context, DonorModel donor) {
    final hasDonated = donor.totalDonations > 0;
    Color badgeColor = hasDonated ? const Color(0xFF8D6E63) : Colors.grey.shade600; // Bronze or Gray
    String emoji = hasDonated ? '🥉' : '🔒';
    List<Color> cardGradient = hasDonated 
        ? [const Color(0xFFD7CCC8), const Color(0xFF8D6E63)]
        : [Colors.grey.shade300, Colors.grey.shade500];

    if (hasDonated) {
      switch (donor.level.toLowerCase()) {
        case 'platinum':
          badgeColor = const Color(0xFF00ACC1);
          emoji = '💎';
          cardGradient = [const Color(0xFFE0F7FA), const Color(0xFF00ACC1)];
          break;
        case 'gold':
          badgeColor = const Color(0xFFF57F17);
          emoji = '🥇';
          cardGradient = [const Color(0xFFFFE082), const Color(0xFFFFD54F)];
          break;
        case 'silver':
          badgeColor = const Color(0xFF607D8B);
          emoji = '🥈';
          cardGradient = [const Color(0xFFECEFF1), const Color(0xFFB0BEC5)];
          break;
      }
    }

    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
        border: Border.all(color: badgeColor.withOpacity(0.2), width: 1.5),
      ),
      child: Row(
        children: [
          Container(
            width: 60.w,
            height: 60.w,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: cardGradient,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: badgeColor.withOpacity(0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            alignment: Alignment.center,
            child: Text(
              emoji,
              style: TextStyle(fontSize: 32.sp),
            ),
          ),
          SizedBox(width: 16.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  hasDonated ? 'Verified ${donor.level} Donor' : 'Donor Badge Pending',
                  style: TextStyle(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  hasDonated ? 'Official Certificate Issued' : 'Complete 1st donation to unlock',
                  style: TextStyle(
                    fontSize: 12.sp,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pushNamed('/digital-donor-badge'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12.r),
              ),
              padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
              elevation: 0,
            ),
            child: Text(
              hasDonated ? 'View Badge' : 'Open Draft',
              style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}
