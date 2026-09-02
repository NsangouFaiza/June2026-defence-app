import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart' show XFile;
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
    } on DioException catch (e) {
      final responseData = e.response?.data;
      if (responseData is Map) {
        if (responseData.containsKey('detail')) {
          final detailVal = responseData['detail'];
          if (detailVal is String) {
            throw Exception(detailVal);
          } else if (detailVal is List) {
            throw Exception(detailVal.join('\n'));
          } else {
            throw Exception(detailVal.toString());
          }
        }
        final errors = <String>[];
        responseData.forEach((key, value) {
          if (value is List) {
            errors.add(value.join(', '));
          } else {
            errors.add('$value');
          }
        });
        if (errors.isNotEmpty) {
          throw Exception(errors.join('\n'));
        }
      }
      if (e.response?.statusCode == 401) {
        throw Exception('Invalid email or password. Please verify your credentials.');
      } else if (e.response?.statusCode == 400) {
        throw Exception('Invalid input provided. Please enter a valid email and password.');
      } else if (e.response?.statusCode == 403) {
        throw Exception('Account access restricted or subscription expired.');
      } else if (e.response?.statusCode == 500) {
        throw Exception('Server error. Please try again later.');
      }
      throw Exception(e.message ?? 'Authentication failed');
    } catch (e) {
      throw Exception(e.toString().replaceAll('Exception: ', ''));
    }
  }


  Future<Map<String, dynamic>> register(Map<String, dynamic> data) async {
    try {
      final response = await _apiService.post('/users/register/', data);
      
      final token = response.data['access'];
      final refreshToken = response.data['refresh'];

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('access_token', token);
      await prefs.setString('refresh_token', refreshToken);
      await prefs.setBool('is_logged_in', true);
      await prefs.setBool('has_seen_onboarding', true);

      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      final responseData = e.response?.data;
      if (responseData is Map) {
        final errors = <String>[];
        responseData.forEach((key, value) {
          if (value is List) {
            errors.add('$key: ${value.join(", ")}');
          } else {
            errors.add('$key: $value');
          }
        });
        throw Exception(errors.join('\n'));
      }
      throw Exception(e.message ?? 'Unknown registration error');
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
      await _apiService.patch('/users/update-profile/', data);
    } catch (e) {
      throw Exception('Failed to update profile: ${e.toString()}');
    }
  }

  Future<void> changePassword(String currentPassword, String newPassword) async {
    try {
      final response = await _apiService.post('/users/change-password/', {
        'current_password': currentPassword,
        'old_password': currentPassword,
        'new_password': newPassword,
      });

      if (response.data is Map && response.data.containsKey('access')) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('access_token', response.data['access']);
        if (response.data.containsKey('refresh')) {
          await prefs.setString('refresh_token', response.data['refresh']);
        }
      }
    } on DioException catch (e) {
      final responseData = e.response?.data;
      if (responseData is Map) {
        if (responseData.containsKey('detail')) {
          throw Exception(responseData['detail']);
        }
        final errors = <String>[];
        responseData.forEach((key, value) {
          if (value is List) {
            errors.add(value.join(', '));
          } else {
            errors.add('$value');
          }
        });
        if (errors.isNotEmpty) {
          throw Exception(errors.join('\n'));
        }
      }
      throw Exception('Failed to change password. Please verify your current password.');
    } catch (e) {
      throw Exception(e.toString().replaceAll('Exception: ', ''));
    }
  }

  Future<Map<String, dynamic>> getSecuritySettings() async {
    try {
      final response = await _apiService.get('/users/security-settings/');
      return response.data as Map<String, dynamic>;
    } catch (e) {
      throw Exception('Failed to load security settings: ${e.toString()}');
    }
  }

  Future<Map<String, dynamic>> updateSecuritySettings(Map<String, dynamic> data) async {
    try {
      final response = await _apiService.post('/users/security-settings/update/', data);
      return response.data as Map<String, dynamic>;
    } catch (e) {
      throw Exception('Failed to update security settings: ${e.toString()}');
    }
  }

  Future<void> terminateSession({int? sessionId, bool terminateAllOthers = false}) async {
    try {
      await _apiService.post('/users/security-settings/terminate-session/', {
        if (sessionId != null) 'session_id': sessionId,
        'terminate_all_others': terminateAllOthers,
      });
    } catch (e) {
      throw Exception('Failed to terminate session: ${e.toString()}');
    }
  }

  Future<UserModel> uploadProfilePicture(XFile file) async {
    try {
      final response = await _apiService.uploadProfilePicture(file);
      return UserModel.fromJson(response.data);
    } catch (e) {
      throw Exception('Failed to upload profile picture: ${e.toString()}');
    }
  }

  Future<UserModel> deleteProfilePicture() async {
    try {
      final response = await _apiService.deleteProfilePicture();
      return UserModel.fromJson(response.data);
    } catch (e) {
      throw Exception('Failed to remove profile picture: ${e.toString()}');
    }
  }
}
