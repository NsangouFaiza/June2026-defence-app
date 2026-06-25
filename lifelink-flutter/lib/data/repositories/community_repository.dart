import 'package:dio/dio.dart';
import '../services/api_service.dart';
import '../models/leaderboard_model.dart';

class CommunityRepository {
  final ApiService _apiService = ApiService();

  Future<List<LeaderboardModel>> getTopDonors() async {
    try {
      final response = await _apiService.get('/community/leaderboard/donors/');
      return (response.data as List)
          .map((json) => LeaderboardModel.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw Exception('Failed to load top donors: $e');
    }
  }

  Future<List<LeaderboardModel>> getTopRegions() async {
    try {
      final response = await _apiService.get('/community/leaderboard/regions/');
      return (response.data as List)
          .map((json) => LeaderboardModel.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw Exception('Failed to load top regions: $e');
    }
  }

  Future<Map<String, dynamic>> getImpactStatistics() async {
    try {
      final response = await _apiService.get('/community/impact/');
      return response.data as Map<String, dynamic>;
    } catch (e) {
      throw Exception('Failed to load impact statistics: $e');
    }
  }

  Future<Map<String, dynamic>> getMonthlyImpact() async {
    try {
      final response = await _apiService.get('/community/impact/monthly/');
      return response.data as Map<String, dynamic>;
    } catch (e) {
      throw Exception('Failed to load monthly impact: $e');
    }
  }

  Future<List<dynamic>> getHospitalContributions() async {
    try {
      final response = await _apiService.get('/community/impact/hospitals/');
      return response.data as List;
    } catch (e) {
      throw Exception('Failed to load hospital contributions: $e');
    }
  }
}
