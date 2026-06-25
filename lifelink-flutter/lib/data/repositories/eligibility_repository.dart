import 'package:dio/dio.dart';
import '../services/api_service.dart';
import '../models/eligibility_check_model.dart';

class EligibilityRepository {
  final ApiService _apiService = ApiService();

  Future<EligibilityCheckModel> checkEligibility(Map<String, dynamic> data) async {
    try {
      final response = await _apiService.post('/eligibility/check/', data);
      return EligibilityCheckModel.fromJson(response.data);
    } catch (e) {
      throw Exception('Failed to check eligibility: $e');
    }
  }

  Future<List<EligibilityCheckModel>> getEligibilityHistory() async {
    try {
      final response = await _apiService.get('/eligibility/history/');
      return (response.data as List)
          .map((json) => EligibilityCheckModel.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw Exception('Failed to load eligibility history: $e');
    }
  }
}
