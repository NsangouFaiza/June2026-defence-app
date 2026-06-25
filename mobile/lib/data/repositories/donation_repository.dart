import 'package:dio/dio.dart';
import '../services/api_service.dart';
import '../models/donation_model.dart';

class DonationRepository {
  final ApiService _apiService = ApiService();

  Future<List<DonationModel>> getDonationHistory() async {
    try {
      final response = await _apiService.get('/donations/');
      return (response.data as List)
          .map((json) => DonationModel.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw Exception('Failed to load donation history: $e');
    }
  }

  Future<DonationModel> recordDonation(Map<String, dynamic> data) async {
    try {
      final response = await _apiService.post('/donations/', data);
      return DonationModel.fromJson(response.data);
    } catch (e) {
      throw Exception('Failed to record donation: $e');
    }
  }

  Future<DonationModel> verifyDonation(int id) async {
    try {
      final response = await _apiService.post('/donations/$id/verify/');
      return DonationModel.fromJson(response.data);
    } catch (e) {
      throw Exception('Failed to verify donation: $e');
    }
  }
}
