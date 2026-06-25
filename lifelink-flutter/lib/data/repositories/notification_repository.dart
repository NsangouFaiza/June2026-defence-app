import 'package:dio/dio.dart';
import '../services/api_service.dart';
import '../models/notification_model.dart';

class NotificationRepository {
  final ApiService _apiService = ApiService();

  Future<List<NotificationModel>> getNotifications() async {
    try {
      final response = await _apiService.get('/notifications/');
      return (response.data as List)
          .map((json) => NotificationModel.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw Exception('Failed to load notifications: $e');
    }
  }

  Future<void> markAsRead(int notificationId) async {
    try {
      await _apiService.post('/notifications/$notificationId/mark-read/');
    } catch (e) {
      throw Exception('Failed to mark notification as read: $e');
    }
  }

  Future<void> markAllAsRead() async {
    try {
      await _apiService.post('/notifications/mark-all-read/');
    } catch (e) {
      throw Exception('Failed to mark all notifications as read: $e');
    }
  }

  Future<int> getUnreadCount() async {
    try {
      final response = await _apiService.get('/notifications/unread-count/');
      return response.data['count'] as int;
    } catch (e) {
      throw Exception('Failed to get unread count: $e');
    }
  }
}
