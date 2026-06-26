import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/localization_service.dart';
import '../../../../core/providers/providers.dart';
import '../../../../core/providers/theme_provider.dart';
import '../../../../features/auth/providers/auth_providers.dart';
import '../../../../data/repositories/auth_repository.dart';
import '../../../../data/models/user_model.dart';

class ProfileSettingsScreen extends ConsumerWidget {
  const ProfileSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final localization = ref.watch(localizationServiceProvider);
    final authRepo = ref.watch(authRepositoryProvider);
    final userAsync = ref.watch(currentUserProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(localization.translate('profile_settings')),
      ),
      body: userAsync.when(
        data: (user) => user != null ? _buildProfile(context, ref, user, localization) : const Center(child: Text('User not found')),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text('Error: $error')),
      ),
    );
  }

  Widget _buildProfile(
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
          // Profile Picture
          Center(
            child: Stack(
              children: [
                CircleAvatar(
                  radius: 60.r,
                  backgroundColor: AppTheme.primaryColor,
                  child: Text(
                    user.fullName.substring(0, 1).toUpperCase(),
                    style: TextStyle(
                      fontSize: 48.sp,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: CircleAvatar(
                    radius: 20.r,
                    backgroundColor: AppTheme.primaryColor,
                    child: IconButton(
                      icon: const Icon(Icons.camera_alt, size: 20, color: Colors.white),
                      onPressed: () {
                        // Change profile picture
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 32.h),

          // Personal Information
          Card(
            child: Padding(
              padding: EdgeInsets.all(16.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    localization.translate('personal_information'),
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  SizedBox(height: 16.h),
                  _buildInfoRow(context, localization.translate('full_name'), user.fullName),
                  _buildInfoRow(context, localization.translate('email'), user.email),
                  _buildInfoRow(context, localization.translate('phone'), user.phoneNumber),
                  _buildInfoRow(context, localization.translate('blood_group'), user.bloodGroup ?? 'N/A'),
                  _buildInfoRow(context, localization.translate('role'), user.role.toUpperCase()),
                ],
              ),
            ),
          ),
          SizedBox(height: 16.h),

          // Preferences
          Card(
            child: Padding(
              padding: EdgeInsets.all(16.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    localization.translate('preferences'),
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  SizedBox(height: 16.h),
                  SwitchListTile(
                    title: Text(localization.translate('push_notifications')),
                    subtitle: const Text('Receive push notifications'),
                    value: user.notificationPreferences ?? true,
                    onChanged: (value) async {
                      try {
                        await ref.read(authRepositoryProvider).updateProfile({
                          'notification_preferences': value,
                        });
                        ref.invalidate(currentUserProvider);
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Error: $e')),
                          );
                        }
                      }
                    },
                  ),
                  SwitchListTile(
                    title: Text(localization.translate('email_notifications')),
                    subtitle: const Text('Receive email notifications'),
                    value: user.emailNotifications ?? true,
                    onChanged: (value) async {
                      try {
                        await ref.read(authRepositoryProvider).updateProfile({
                          'email_notifications': value,
                        });
                        ref.invalidate(currentUserProvider);
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Error: $e')),
                          );
                        }
                      }
                    },
                  ),
                  SwitchListTile(
                    title: Text(localization.translate('dark_mode')),
                    subtitle: const Text('Enable dark mode'),
                    value: ref.watch(themeModeProvider) == ThemeMode.dark,
                    onChanged: (value) {
                      ref.read(themeModeProvider.notifier).toggleTheme(value);
                    },
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: 16.h),

          // Language Selection
          Card(
            child: ListTile(
              leading: const Icon(Icons.language_outlined),
              title: Text(localization.translate('language')),
              subtitle: Text(user.language == 'fr' ? 'Français' : 'English'),
              trailing: const Icon(Icons.arrow_forward_ios),
              onTap: () {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: Text(localization.translate('language')),
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ListTile(
                          title: const Text('English 🇬🇧'),
                          onTap: () async {
                            Navigator.of(context).pop();
                            await ref.read(localizationProvider.notifier).changeLanguage('en');
                            await ref.read(authRepositoryProvider).updateProfile({'language': 'en'});
                            ref.invalidate(currentUserProvider);
                          },
                        ),
                        ListTile(
                          title: const Text('Français 🇫🇷'),
                          onTap: () async {
                            Navigator.of(context).pop();
                            await ref.read(localizationProvider.notifier).changeLanguage('fr');
                            await ref.read(authRepositoryProvider).updateProfile({'language': 'fr'});
                            ref.invalidate(currentUserProvider);
                          },
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          SizedBox(height: 16.h),

          // Security
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.lock_outlined),
                  title: Text(localization.translate('change_password')),
                  trailing: const Icon(Icons.arrow_forward_ios),
                  onTap: () {
                    // Navigate to change password
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.security_outlined),
                  title: Text(localization.translate('security_settings')),
                  trailing: const Icon(Icons.arrow_forward_ios),
                  onTap: () {
                    // Navigate to security settings
                  },
                ),
              ],
            ),
          ),
          SizedBox(height: 32.h),

          // Logout Button
          ElevatedButton(
            onPressed: () async {
              await ref.read(authRepositoryProvider).logout();
              ref.invalidate(currentUserProvider);
              if (context.mounted) {
                Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.error,
              foregroundColor: Colors.white,
            ),
            child: Text(localization.translate('logout')),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(BuildContext context, String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120.w,
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.grey,
                fontSize: 14,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
