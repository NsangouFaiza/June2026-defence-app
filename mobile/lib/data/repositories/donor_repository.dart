import 'package:dio/dio.dart';
import '../services/api_service.dart';
import '../models/donor_model.dart';

class DonorRepository {
  final ApiService _apiService = ApiService();

  Future<List<DonorModel>> getDonors({
    String? bloodGroup,
    String? eligibility,
    String? region,
    String? city,
  }) async {
    try {
      final params = <String, dynamic>{};
      if (bloodGroup != null && bloodGroup.isNotEmpty && bloodGroup.toLowerCase() != 'all') {
        params['blood_group'] = bloodGroup;
      }
      if (eligibility != null && eligibility.isNotEmpty && eligibility.toLowerCase() != 'all') {
        params['eligibility'] = eligibility;
      }
      if (region != null && region.isNotEmpty && region.toLowerCase() != 'all') {
        params['region'] = region;
      }
      if (city != null && city.isNotEmpty && city.toLowerCase() != 'all') {
        params['city'] = city;
      }

      final response = await _apiService.get('/donors/', queryParameters: params.isEmpty ? null : params);
      return (response.data as List).map((json) => DonorModel.fromJson(json)).toList();
    } catch (e) {
      throw Exception('Failed to load donors: $e');
    }
  }


  Future<DonorModel?> getCurrentDonorProfile() async {
    try {
      final response = await _apiService.get('/donors/my_profile/');
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

  Future<DonorModel> updateEligibility(int id, String status, String reason) async {
    try {
      final response = await _apiService.post(
        '/donors/$id/update_eligibility/',
        {
          'status': status,
          'reason': reason,
        },
      );
      return DonorModel.fromJson(response.data);
    } catch (e) {
      if (e is DioException && e.response?.data != null) {
        final errorMsg = e.response?.data['error'] ?? e.response?.data['detail'] ?? e.toString();
        throw Exception(errorMsg);
      }
      throw Exception('Failed to update eligibility: $e');
    }
  }
}
