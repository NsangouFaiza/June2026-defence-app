import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/providers.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/localization_service.dart';
import '../../../../data/repositories/auth_repository.dart';
import '../../../../data/models/user_model.dart';
import '../../../widgets/floating_ai_assistant_button.dart';

class HomeDashboardScreen extends ConsumerWidget {
  const HomeDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final localization = ref.watch(localizationServiceProvider);
    final userAsync = ref.watch(currentUserProvider);

    return Scaffold(
      floatingActionButton: const FloatingAiAssistantButton(),
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              'assets/images/logo.png',
              height: 36.h,
              fit: BoxFit.contain,
            ),
            SizedBox(width: 8.w),
            Text(
              'LifeLink',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 20.sp,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () {
              Navigator.of(context).pushNamed('/notifications');
            },
          ),
          IconButton(
            icon: const Icon(Icons.person_outlined),
            onPressed: () {
              Navigator.of(context).pushNamed('/profile');
            },
          ),
        ],
      ),
      body: userAsync.when(
        data: (user) => user != null ? _buildDashboard(context, ref, user, localization) : const Center(child: Text('User not found')),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text('Error: $error')),
      ),
    );
  }

  Widget _buildDashboard(
    BuildContext context,
    WidgetRef ref,
    UserModel user,
    LocalizationService localization,
  ) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Welcome Card
          Card(
            color: AppTheme.primaryColor,
            child: Padding(
              padding: EdgeInsets.all(20.w),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 30.r,
                    backgroundColor: Colors.white,
                    child: Text(
                      user.fullName.substring(0, 1).toUpperCase(),
                      style: TextStyle(
                        fontSize: 24.sp,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                  ),
                  SizedBox(width: 16.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${localization.translate('welcome')},',
                          style: TextStyle(
                            fontSize: 14.sp,
                            color: Colors.white.withOpacity(0.9),
                          ),
                        ),
                        Text(
                          user.fullName,
                          style: TextStyle(
                            fontSize: 20.sp,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          user.role.toUpperCase(),
                          style: TextStyle(
                            fontSize: 12.sp,
                            color: Colors.white.withOpacity(0.8),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: 24.h),

          // Quick Actions
          Text(
            localization.translate('quick_actions'),
            style: Theme.of(context).textTheme.titleLarge,
          ),
          SizedBox(height: 16.h),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            mainAxisSpacing: 16.h,
            crossAxisSpacing: 16.w,
            childAspectRatio: 1.3,
            children: _getQuickActions(context, ref, user, localization),
          ),
          SizedBox(height: 24.h),

          // Recent Activity
          Text(
            localization.translate('recent_activity'),
            style: Theme.of(context).textTheme.titleLarge,
          ),
          SizedBox(height: 16.h),
          _buildRecentActivity(context, ref, localization),
        ],
      ),
    );
  }

  List<Widget> _getQuickActions(
    BuildContext context,
    WidgetRef ref,
    UserModel user,
    LocalizationService localization,
  ) {
    final role = user.role.toLowerCase();
    final actions = <Widget>[];

    if (role == 'donor') {
      actions.addAll([
        _buildActionCard(
          context,
          localization.translate('eligibility_check'),
          Icons.health_and_safety,
          AppTheme.success,
          () => Navigator.of(context).pushNamed('/eligibility-check'),
        ),
        _buildActionCard(
          context,
          localization.translate('book_appointment'),
          Icons.calendar_today,
          AppTheme.primaryColor,
          () => Navigator.of(context).pushNamed('/book-appointment'),
        ),
        _buildActionCard(
          context,
          localization.translate('donation_history'),
          Icons.history,
          AppTheme.warning,
          () => Navigator.of(context).pushNamed('/donation-history'),
        ),
        _buildActionCard(
          context,
          localization.translate('rewards'),
          Icons.emoji_events,
          Colors.purple,
          () => Navigator.of(context).pushNamed('/rewards'),
        ),
      ]);
    } else if (role == 'patient') {
      actions.addAll([
        _buildActionCard(
          context,
          localization.translate('search_blood'),
          Icons.search,
          AppTheme.primaryColor,
          () => Navigator.of(context).pushNamed('/blood-search'),
        ),
        _buildActionCard(
          context,
          localization.translate('request_blood'),
          Icons.assignment,
          AppTheme.success,
          () => Navigator.of(context).pushNamed('/blood-request'),
        ),
        _buildActionCard(
          context,
          localization.translate('emergency_request'),
          Icons.warning,
          AppTheme.error,
          () => Navigator.of(context).pushNamed('/emergency-request'),
        ),
        _buildActionCard(
          context,
          localization.translate('hospital_locator'),
          Icons.map,
          AppTheme.warning,
          () => Navigator.of(context).pushNamed('/hospital-locator'),
        ),
      ]);
    } else if (role == 'hospital_staff') {
      actions.addAll([
        _buildActionCard(
          context,
          localization.translate('blood_inventory'),
          Icons.inventory,
          AppTheme.primaryColor,
          () => Navigator.of(context).pushNamed('/blood-inventory'),
        ),
        _buildActionCard(
          context,
          localization.translate('blood_requests'),
          Icons.assignment,
          AppTheme.success,
          () => Navigator.of(context).pushNamed('/blood-requests'),
        ),
        _buildActionCard(
          context,
          localization.translate('appointments'),
          Icons.calendar_today,
          AppTheme.warning,
          () => Navigator.of(context).pushNamed('/manage-appointments'),
        ),
        _buildActionCard(
          context,
          localization.translate('donor_list'),
          Icons.people,
          Colors.purple,
          () => Navigator.of(context).pushNamed('/donor-list'),
        ),
      ]);
    } else if (role == 'system_admin' || role == 'blood_bank_admin') {
      actions.addAll([
        _buildActionCard(
          context,
          localization.translate('admin_panel'),
          Icons.admin_panel_settings,
          AppTheme.primaryColor,
          () => Navigator.of(context).pushNamed('/admin-panel'),
        ),
        _buildActionCard(
          context,
          localization.translate('reports'),
          Icons.bar_chart,
          AppTheme.success,
          () => Navigator.of(context).pushNamed('/reports'),
        ),
        _buildActionCard(
          context,
          localization.translate('campaigns'),
          Icons.campaign,
          AppTheme.warning,
          () => Navigator.of(context).pushNamed('/campaigns'),
        ),
        _buildActionCard(
          context,
          localization.translate('users'),
          Icons.people,
          Colors.purple,
          () => Navigator.of(context).pushNamed('/admin-panel'),
        ),
      ]);
    }

    return actions;
  }

  Widget _buildActionCard(
    BuildContext context,
    String title,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12.r),
        child: Padding(
          padding: EdgeInsets.all(16.w),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 32.w, color: color),
              SizedBox(height: 8.h),
              Text(
                title,
                style: TextStyle(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRecentActivity(
    BuildContext context,
    WidgetRef ref,
    LocalizationService localization,
  ) {
    // Placeholder for recent activity
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16.w),
        child: Column(
          children: [
            _buildActivityItem(
              Icons.calendar_today,
              'Appointment scheduled',
              '2 hours ago',
              AppTheme.primaryColor,
            ),
            Divider(height: 24.h),
            _buildActivityItem(
              Icons.volunteer_activism,
              'Donation completed',
              'Yesterday',
              AppTheme.success,
            ),
            Divider(height: 24.h),
            _buildActivityItem(
              Icons.notifications,
              'New campaign available',
              '2 days ago',
              AppTheme.warning,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActivityItem(
    IconData icon,
    String title,
    String time,
    Color color,
  ) {
    return Row(
      children: [
        CircleAvatar(
          radius: 20.r,
          backgroundColor: color.withOpacity(0.1),
          child: Icon(icon, size: 20.w, color: color),
        ),
        SizedBox(width: 12.w),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
              Text(
                time,
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
