import 'package:dio/dio.dart';
import '../services/api_service.dart';

class ReportRepository {
  final ApiService _apiService = ApiService();

  Future<Map<String, dynamic>> getMonthlyDonations() async {
    try {
      final response = await _apiService.get('/reports/monthly-donations/');
      return response.data as Map<String, dynamic>;
    } catch (e) {
      throw Exception('Failed to load monthly donations: $e');
    }
  }

  Future<Map<String, int>> getBloodStockByGroup() async {
    try {
      final response = await _apiService.get('/reports/blood-stock/');
      final data = response.data as Map<String, dynamic>;
      return data.map((key, value) => MapEntry(key, value as int));
    } catch (e) {
      throw Exception('Failed to load blood stock: $e');
    }
  }

  Future<Map<String, dynamic>> getStatistics() async {
    try {
      final response = await _apiService.get('/reports/statistics/');
      return response.data as Map<String, dynamic>;
    } catch (e) {
      throw Exception('Failed to load statistics: $e');
    }
  }

  Future<List<dynamic>> getDonationReports() async {
    try {
      final response = await _apiService.get('/reports/donations/');
      return response.data as List;
    } catch (e) {
      throw Exception('Failed to load donation reports: $e');
    }
  }

  Future<List<dynamic>> getEmergencyReports() async {
    try {
      final response = await _apiService.get('/reports/emergency/');
      return response.data as List;
    } catch (e) {
      throw Exception('Failed to load emergency reports: $e');
    }
  }
}
