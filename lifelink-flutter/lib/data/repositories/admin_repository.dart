import 'package:dio/dio.dart';
import '../services/api_service.dart';
import '../models/user_model.dart';

class AdminRepository {
  final ApiService _apiService = ApiService();

  /// Extracts the most useful error message from a backend error response.
  static String errorMessage(Object e) {
    if (e is DioException) {
      final data = e.response?.data;
      if (data is Map) {
        final msg = data['error'] ?? data['detail'];
        if (msg != null) return msg.toString();
        if (data.isNotEmpty) {
          final first = data.values.first;
          return first is List && first.isNotEmpty ? first.first.toString() : first.toString();
        }
      }
      return e.message ?? 'Network error';
    }
    return e.toString().replaceFirst('Exception: ', '');
  }

  // ---------------------------------------------------------------- Users

  /// Raw admin user records (include hospital_name, last_login, is_verified...).
  Future<List<Map<String, dynamic>>> getUsers({String? search, String? role, bool? isActive}) async {
    try {
      final response = await _apiService.get('/admin/users/', queryParameters: {
        if (search != null && search.isNotEmpty) 'search': search,
        if (role != null) 'role': role,
        if (isActive != null) 'is_active': isActive.toString(),
      });
      return (response.data as List).cast<Map<String, dynamic>>();
    } catch (e) {
      throw Exception('Failed to load users: ${errorMessage(e)}');
    }
  }

  Future<List<UserModel>> getAllUsers() async {
    final users = await getUsers();
    return users.map((json) => UserModel.fromJson(json)).toList();
  }

  /// Full user profile incl. donor/patient profile, recent activity, payments and logins.
  Future<Map<String, dynamic>> getUserDetails(int userId) async {
    try {
      final response = await _apiService.get('/admin/users/$userId/');
      return response.data as Map<String, dynamic>;
    } catch (e) {
      throw Exception(errorMessage(e));
    }
  }

  Future<Map<String, dynamic>> createUser(Map<String, dynamic> data) async {
    try {
      final response = await _apiService.post('/admin/users/', data);
      return response.data as Map<String, dynamic>;
    } catch (e) {
      throw Exception(errorMessage(e));
    }
  }

  Future<Map<String, dynamic>> updateUser(int userId, Map<String, dynamic> data) async {
    try {
      final response = await _apiService.patch('/admin/users/$userId/', data);
      return response.data as Map<String, dynamic>;
    } catch (e) {
      throw Exception(errorMessage(e));
    }
  }

  Future<void> suspendUser(int userId) async {
    try {
      await _apiService.post('/admin/users/$userId/suspend/');
    } catch (e) {
      throw Exception(errorMessage(e));
    }
  }

  Future<void> activateUser(int userId) async {
    try {
      await _apiService.post('/admin/users/$userId/activate/');
    } catch (e) {
      throw Exception(errorMessage(e));
    }
  }

  Future<void> resetUserPassword(int userId, String newPassword) async {
    try {
      await _apiService.post('/admin/users/$userId/reset_password/', {'new_password': newPassword});
    } catch (e) {
      throw Exception(errorMessage(e));
    }
  }

  Future<void> deleteUser(int userId) async {
    try {
      await _apiService.delete('/admin/users/$userId/');
    } catch (e) {
      throw Exception(errorMessage(e));
    }
  }

  // ------------------------------------------------------------ Hospitals

  /// [subscription] can be 'active', 'expired' or 'deactivated'.
  Future<List<dynamic>> getAllHospitals({String? search, String? subscription}) async {
    try {
      final response = await _apiService.get('/admin/hospitals/', queryParameters: {
        if (search != null && search.isNotEmpty) 'search': search,
        if (subscription != null) 'subscription': subscription,
      });
      return response.data as List;
    } catch (e) {
      throw Exception('Failed to load hospitals: ${errorMessage(e)}');
    }
  }

  Future<Map<String, dynamic>> getHospital(int id) async {
    try {
      final response = await _apiService.get('/admin/hospitals/$id/');
      return response.data as Map<String, dynamic>;
    } catch (e) {
      throw Exception(errorMessage(e));
    }
  }

  Future<Map<String, dynamic>> createHospital(Map<String, dynamic> data) async {
    try {
      final response = await _apiService.post('/admin/hospitals/', data);
      return response.data as Map<String, dynamic>;
    } catch (e) {
      throw Exception(errorMessage(e));
    }
  }

  Future<Map<String, dynamic>> updateHospital(int id, Map<String, dynamic> data) async {
    try {
      final response = await _apiService.patch('/admin/hospitals/$id/', data);
      return response.data as Map<String, dynamic>;
    } catch (e) {
      throw Exception(errorMessage(e));
    }
  }

  Future<void> deleteHospital(int id) async {
    try {
      await _apiService.delete('/admin/hospitals/$id/');
    } catch (e) {
      throw Exception(errorMessage(e));
    }
  }

  Future<void> setHospitalActive(int id, bool active) async {
    try {
      await _apiService.post('/hospitals/$id/toggle_active/', {'action': active ? 'activate' : 'deactivate'});
    } catch (e) {
      throw Exception(errorMessage(e));
    }
  }

  Future<void> extendHospitalSubscription(int id, int months) async {
    try {
      await _apiService.post('/admin/hospitals/$id/extend_subscription/', {'months': months});
    } catch (e) {
      throw Exception(errorMessage(e));
    }
  }

  Future<List<Map<String, dynamic>>> getHospitalStaff(int hospitalId) async {
    try {
      final response = await _apiService.get('/admin/hospitals/$hospitalId/staff/');
      return (response.data as List).cast<Map<String, dynamic>>();
    } catch (e) {
      throw Exception(errorMessage(e));
    }
  }

  Future<void> assignHospitalStaff(int hospitalId, int userId, {String? position}) async {
    try {
      await _apiService.post('/admin/hospitals/$hospitalId/staff/', {
        'user_id': userId,
        if (position != null && position.isNotEmpty) 'position': position,
      });
    } catch (e) {
      throw Exception(errorMessage(e));
    }
  }

  Future<void> removeHospitalStaff(int hospitalId, int staffId) async {
    try {
      await _apiService.delete('/admin/hospitals/$hospitalId/staff/$staffId/');
    } catch (e) {
      throw Exception(errorMessage(e));
    }
  }

  // ----------------------------------------------------------- Statistics

  Future<Map<String, dynamic>> getSystemStatistics() async {
    try {
      final response = await _apiService.get('/admin/statistics/');
      return response.data as Map<String, dynamic>;
    } catch (e) {
      throw Exception('Failed to load statistics: $e');
    }
  }
}
