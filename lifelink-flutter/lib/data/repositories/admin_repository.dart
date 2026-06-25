import 'package:dio/dio.dart';
import '../services/api_service.dart';
import '../models/user_model.dart';

class AdminRepository {
  final ApiService _apiService = ApiService();

  Future<List<UserModel>> getAllUsers() async {
    try {
      final response = await _apiService.get('/admin/users/');
      return (response.data as List).map((json) => UserModel.fromJson(json)).toList();
    } catch (e) {
      throw Exception('Failed to load users: $e');
    }
  }

  Future<void> suspendUser(int userId) async {
    try {
      await _apiService.post('/admin/users/$userId/suspend/');
    } catch (e) {
      throw Exception('Failed to suspend user: $e');
    }
  }

  Future<void> activateUser(int userId) async {
    try {
      await _apiService.post('/admin/users/$userId/activate/');
    } catch (e) {
      throw Exception('Failed to activate user: $e');
    }
  }

  Future<void> deleteUser(int userId) async {
    try {
      await _apiService.delete('/admin/users/$userId/');
    } catch (e) {
      throw Exception('Failed to delete user: $e');
    }
  }

  Future<List<dynamic>> getAllHospitals() async {
    try {
      final response = await _apiService.get('/admin/hospitals/');
      return response.data as List;
    } catch (e) {
      throw Exception('Failed to load hospitals: $e');
    }
  }

  Future<Map<String, dynamic>> getSystemStatistics() async {
    try {
      final response = await _apiService.get('/admin/statistics/');
      return response.data as Map<String, dynamic>;
    } catch (e) {
      throw Exception('Failed to load statistics: $e');
    }
  }
}
