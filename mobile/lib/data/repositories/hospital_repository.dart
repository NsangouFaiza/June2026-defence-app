import 'package:dio/dio.dart';
import '../services/api_service.dart';
import '../models/hospital_model.dart';

class HospitalRepository {
  final ApiService _apiService = ApiService();

  Future<List<HospitalModel>> getHospitals() async {
    try {
      final response = await _apiService.get('/hospitals/');
      return (response.data as List)
          .map((json) => HospitalModel.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw Exception('Failed to load hospitals: $e');
    }
  }

  Future<HospitalModel?> getMyHospital() async {
    try {
      final response = await _apiService.get('/hospitals/my-hospital/');
      return HospitalModel.fromJson(response.data);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        return null;
      }
      throw Exception('Failed to load hospital: $e');
    } catch (e) {
      throw Exception('Failed to load hospital: $e');
    }
  }

  Future<HospitalModel> getHospitalById(int id) async {
    try {
      final response = await _apiService.get('/hospitals/$id/');
      return HospitalModel.fromJson(response.data);
    } catch (e) {
      throw Exception('Failed to load hospital: $e');
    }
  }

  Future<Map<String, dynamic>> getHospitalStatistics() async {
    try {
      final response = await _apiService.get('/hospitals/statistics/');
      return response.data as Map<String, dynamic>;
    } catch (e) {
      throw Exception('Failed to load statistics: $e');
    }
  }
}
