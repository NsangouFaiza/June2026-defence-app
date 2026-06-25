import 'dart:convert';
import 'package:dio/dio.dart';
import '../services/api_service.dart';
import '../models/user_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthRepository {
  final ApiService _apiService = ApiService();

  Future<void> login(String email, String password) async {
    try {
      final response = await _apiService.post('/users/login/', {
        'email': email,
        'password': password,
      });

      final token = response.data['access'];
      final refreshToken = response.data['refresh'];

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('access_token', token);
      await prefs.setString('refresh_token', refreshToken);
      await prefs.setBool('is_logged_in', true);
      await prefs.setBool('has_seen_onboarding', true);
    } catch (e) {
      throw Exception('Login failed: ${e.toString()}');
    }
  }

  Future<void> register(Map<String, dynamic> data) async {
    try {
      await _apiService.post('/users/register/', data);
    } catch (e) {
      throw Exception('Registration failed: ${e.toString()}');
    }
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('access_token');
    await prefs.remove('refresh_token');
    await prefs.remove('is_logged_in');
  }

  Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('is_logged_in') ?? false;
  }

  Future<bool> hasSeenOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('has_seen_onboarding') ?? false;
  }

  Future<void> forgotPassword(String email) async {
    try {
      await _apiService.post('/users/forgot-password/', {
        'email': email,
      });
    } catch (e) {
      throw Exception('Failed to send reset email: ${e.toString()}');
    }
  }

  Future<UserModel?> getCurrentUser() async {
    try {
      final response = await _apiService.get('/users/me/');
      return UserModel.fromJson(response.data);
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        return null;
      }
      throw Exception('Failed to get user: ${e.toString()}');
    } catch (e) {
      throw Exception('Failed to get user: ${e.toString()}');
    }
  }

  Future<void> updateProfile(Map<String, dynamic> data) async {
    try {
      await _apiService.patch('/users/me/', data);
    } catch (e) {
      throw Exception('Failed to update profile: ${e.toString()}');
    }
  }

  Future<void> changePassword(String oldPassword, String newPassword) async {
    try {
      await _apiService.post('/users/change-password/', {
        'old_password': oldPassword,
        'new_password': newPassword,
      });
    } catch (e) {
      throw Exception('Failed to change password: ${e.toString()}');
    }
  }
}
