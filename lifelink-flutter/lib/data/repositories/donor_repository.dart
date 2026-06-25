import 'package:dio/dio.dart';
import '../services/api_service.dart';
import '../models/donor_model.dart';

class DonorRepository {
  final ApiService _apiService = ApiService();

  Future<List<DonorModel>> getDonors() async {
    try {
      final response = await _apiService.get('/donors/');
      return (response.data as List).map((json) => DonorModel.fromJson(json)).toList();
    } catch (e) {
      throw Exception('Failed to load donors: $e');
    }
  }

  Future<DonorModel?> getCurrentDonorProfile() async {
    try {
      final response = await _apiService.get('/donors/me/');
      return DonorModel.fromJson(response.data);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        return null;
      }
      throw Exception('Failed to load donor profile: $e');
    } catch (e) {
      throw Exception('Failed to load donor profile: $e');
    }
  }

  Future<DonorModel> getDonorById(int id) async {
    try {
      final response = await _apiService.get('/donors/$id/');
      return DonorModel.fromJson(response.data);
    } catch (e) {
      throw Exception('Failed to load donor: $e');
    }
  }

  Future<List<DonorModel>> searchDonors({
    String? bloodGroup,
    String? region,
    bool? isEligible,
  }) async {
    try {
      final params = <String, dynamic>{};
      if (bloodGroup != null) params['blood_group'] = bloodGroup;
      if (region != null) params['region'] = region;
      if (isEligible != null) params['is_eligible'] = isEligible;

      final response = await _apiService.get('/donors/search/', queryParameters: params);
      return (response.data as List).map((json) => DonorModel.fromJson(json)).toList();
    } catch (e) {
      throw Exception('Failed to search donors: $e');
    }
  }
}
