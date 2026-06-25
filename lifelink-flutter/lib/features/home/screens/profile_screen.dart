import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/providers.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/localization_service.dart';
import '../../../../data/repositories/auth_repository.dart';
import '../../../../data/models/user_model.dart';
import '../../../../core/constants/app_constants.dart';
import 'edit_profile_screen.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final localization = ref.watch(localizationServiceProvider);
    final authRepo = ref.watch(authRepositoryProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(localization.translate('profile')),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const EditProfileScreen(),
                ),
              );
            },
          ),
        ],
      ),
      body: FutureBuilder<UserModel>(
        future: authRepo.getProfile(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final user = snapshot.data!;

          return SingleChildScrollView(
            padding: EdgeInsets.all(16.w),
            child: Column(
              children: [
                // Profile Header
                Card(
                  child: Padding(
                    padding: EdgeInsets.all(24.w),
                    child: Column(
                      children: [
                        CircleAvatar(
                          radius: 50.r,
                          backgroundColor: AppTheme.primaryColor,
                          backgroundImage: user.profilePicture != null
                              ? NetworkImage(user.profilePicture!)
                              : null,
                          child: user.profilePicture == null
                              ? Text(
                                  user.fullName[0].toUpperCase(),
                                  style: TextStyle(
                                    fontSize: 40.sp,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                )
                              : null,
                        ),
                        SizedBox(height: 16.h),
                        Text(
                          user.fullName,
                          style: TextStyle(
                            fontSize: 24.sp,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          user.email,
                          style: TextStyle(
                            fontSize: 14.sp,
                            color: AppTheme.grey600,
                          ),
                        ),
                        SizedBox(height: 8.h),
                        Chip(
                          label: Text(user.role.replaceAll('_', ' ')),
                          backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: 24.h),

                // Personal Information
                Text(
                  'Personal Information',
                  style: TextStyle(
                    fontSize: 18.sp,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 16.h),
                Card(
                  child: Column(
                    children: [
                      _ProfileTile(
                        icon: Icons.bloodtype,
                        title: 'Blood Group',
                        value: user.bloodGroup ?? 'Not set',
                      ),
                      Divider(height: 1.h, indent: 56.w),
                      _ProfileTile(
                        icon: Icons.phone,
                        title: 'Phone',
                        value: user.phoneNumber ?? 'Not set',
                      ),
                      Divider(height: 1.h, indent: 56.w),
                      _ProfileTile(
                        icon: Icons.location_on,
                        title: 'Location',
                        value: '${user.city}, ${user.region}',
                      ),
                      Divider(height: 1.h, indent: 56.w),
                      _ProfileTile(
                        icon: Icons.cake,
                        title: 'Date of Birth',
                        value: user.dateOfBirth != null
                            ? '${user.dateOfBirth!.day}/${user.dateOfBirth!.month}/${user.dateOfBirth!.year}'
                            : 'Not set',
                      ),
                      Divider(height: 1.h, indent: 56.w),
                      _ProfileTile(
                        icon: Icons.calendar_today,
                        title: 'Member Since',
                        value: '${user.createdAt.day}/${user.createdAt.month}/${user.createdAt.year}',
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 24.h),

                // Settings
                Text(
                  localization.translate('settings'),
                  style: TextStyle(
                    fontSize: 18.sp,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 16.h),
                Card(
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.language),
                        title: Text(localization.translate('select_language')),
                        trailing: Text(user.language == 'en' ? 'English' : 'Français'),
                        onTap: () {
                          // Change language
                        },
                      ),
                      Divider(height: 1.h, indent: 56.w),
                      ListTile(
                        leading: const Icon(Icons.notifications),
                        title: Text(localization.translate('notifications')),
                        trailing: const Icon(Icons.arrow_forward_ios),
                        onTap: () {
                          // Notification settings
                        },
                      ),
                      Divider(height: 1.h, indent: 56.w),
                      ListTile(
                        leading: const Icon(Icons.lock),
                        title: Text('Change Password'),
                        trailing: const Icon(Icons.arrow_forward_ios),
                        onTap: () {
                          // Change password
                        },
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 24.h),

                // Logout Button
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () async {
                      final authRepo = ref.read(authRepositoryProvider);
                      await authRepo.logout();
                      if (mounted) {
                        // Navigate to login
                      }
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.error,
                      side: const BorderSide(color: AppTheme.error),
                      padding: EdgeInsets.symmetric(vertical: 16.h),
                    ),
                    child: Text(localization.translate('logout')),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ProfileTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;

  const _ProfileTile({
    required this.icon,
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: AppTheme.primaryColor),
      title: Text(title),
      trailing: Text(
        value,
        style: TextStyle(color: AppTheme.grey600),
      ),
    );
  }
}
