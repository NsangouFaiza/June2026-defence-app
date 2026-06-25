import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/providers.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/localization_service.dart';
import '../../../../data/repositories/notification_repository.dart';
import '../../../../data/models/notification_model.dart';
import '../../../../core/constants/app_constants.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final localization = ref.watch(localizationServiceProvider);
    final notificationRepo = ref.watch(notificationRepositoryProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(localization.translate('notifications')),
        actions: [
          TextButton(
            onPressed: () async {
              await notificationRepo.markAllAsRead();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('All notifications marked as read')),
                );
              }
            },
            child: Text('Mark all read'),
          ),
        ],
      ),
      body: FutureBuilder<List<NotificationModel>>(
        future: notificationRepo.getNotifications(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final notifications = snapshot.data ?? [];

          if (notifications.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.notifications_off_outlined,
                    size: 80.sp,
                    color: AppTheme.grey400,
                  ),
                  SizedBox(height: 16.h),
                  Text(
                    'No notifications',
                    style: TextStyle(
                      fontSize: 18.sp,
                      color: AppTheme.grey600,
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: EdgeInsets.all(16.w),
            itemCount: notifications.length,
            itemBuilder: (context, index) {
              final notification = notifications[index];
              return Card(
                margin: EdgeInsets.only(bottom: 12.h),
                color: notification.isRead ? null : AppTheme.primaryColor.withOpacity(0.05),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: _getNotificationColor(notification.notificationType),
                    child: Icon(
                      _getNotificationIcon(notification.notificationType),
                      color: Colors.white,
                    ),
                  ),
                  title: Text(
                    notification.title,
                    style: TextStyle(
                      fontWeight: notification.isRead ? FontWeight.normal : FontWeight.bold,
                    ),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(notification.message),
                      SizedBox(height: 4.h),
                      Text(
                        _formatDate(notification.createdAt),
                        style: TextStyle(
                          fontSize: 12.sp,
                          color: AppTheme.grey500,
                        ),
                      ),
                    ],
                  ),
                  onTap: () async {
                    if (!notification.isRead) {
                      await notificationRepo.markAsRead(notification.id);
                    }
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }

  IconData _getNotificationIcon(String type) {
    switch (type) {
      case AppConstants.notifAppointmentReminder:
        return Icons.calendar_today;
      case AppConstants.notifEligibilityReminder:
        return Icons.check_circle;
      case AppConstants.notifEmergencyRequest:
        return Icons.emergency;
      case AppConstants.notifCampaign:
        return Icons.campaign;
      case AppConstants.notifRequestUpdate:
        return Icons.update;
      case AppConstants.notifDonationComplete:
        return Icons.volunteer_activism;
      case AppConstants.notifRewardEarned:
        return Icons.emoji_events;
      default:
        return Icons.notifications;
    }
  }

  Color _getNotificationColor(String type) {
    switch (type) {
      case AppConstants.notifAppointmentReminder:
        return AppTheme.info;
      case AppConstants.notifEligibilityReminder:
        return AppTheme.success;
      case AppConstants.notifEmergencyRequest:
        return AppTheme.error;
      case AppConstants.notifCampaign:
        return AppTheme.secondaryColor;
      case AppConstants.notifRequestUpdate:
        return AppTheme.warning;
      case AppConstants.notifDonationComplete:
        return AppTheme.accentColor;
      case AppConstants.notifRewardEarned:
        return AppTheme.warning;
      default:
        return AppTheme.grey500;
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} minutes ago';
    if (diff.inHours < 24) return '${diff.inHours} hours ago';
    if (diff.inDays < 7) return '${diff.inDays} days ago';
    return '${date.day}/${date.month}/${date.year}';
  }
}
