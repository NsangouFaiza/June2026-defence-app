import 'package:dio/dio.dart';
import '../services/api_service.dart';
import '../models/donor_reward_model.dart';
import '../models/badge_model.dart';

class RewardRepository {
  final ApiService _apiService = ApiService();

  Future<DonorRewardModel?> getMyRewards() async {
    try {
      final response = await _apiService.get('/rewards/my-rewards/');
      return DonorRewardModel.fromJson(response.data);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        return null;
      }
      throw Exception('Failed to load rewards: $e');
    } catch (e) {
      throw Exception('Failed to load rewards: $e');
    }
  }

  Future<List<BadgeModel>> getAvailableBadges() async {
    try {
      final response = await _apiService.get('/rewards/badges/');
      return (response.data as List)
          .map((json) => BadgeModel.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw Exception('Failed to load badges: $e');
    }
  }

  Future<List<dynamic>> getLeaderboard() async {
    try {
      final response = await _apiService.get('/rewards/leaderboard/');
      return response.data as List;
    } catch (e) {
      throw Exception('Failed to load leaderboard: $e');
    }
  }

  Future<void> claimBadge(int badgeId) async {
    try {
      await _apiService.post('/rewards/badges/$badgeId/claim/');
    } catch (e) {
      throw Exception('Failed to claim badge: $e');
    }
  }
}
