import 'package:dio/dio.dart';
import '../services/api_service.dart';
import '../models/donor_reward_model.dart';
import '../models/badge_model.dart';
import 'donor_repository.dart';

class RewardRepository {
  final ApiService _apiService = ApiService();

  Future<DonorRewardModel?> getMyRewards() async {
    try {
      // 1. Fetch current donor profile to get points and level
      final donorRepo = DonorRepository();
      final donor = await donorRepo.getCurrentDonorProfile();
      if (donor == null) return null;

      // 2. Fetch earned badges from my-rewards
      final response = await _apiService.get('/rewards/my-rewards/');
      final List<dynamic> rewardsList = response.data as List<dynamic>;
      
      final List<BadgeModel> badges = rewardsList.map<BadgeModel>((item) {
        final badgeJson = item['badge'] as Map<String, dynamic>;
        final awardedAtStr = item['awarded_at'] as String?;
        return BadgeModel(
          id: badgeJson['id'] as int?,
          name: badgeJson['name'] as String? ?? 'Unknown Badge',
          description: badgeJson['description'] as String? ?? '',
          type: badgeJson['type'] as String? ?? 'bronze',
          icon: badgeJson['icon'] as String? ?? 'star',
          earnedAt: awardedAtStr != null ? DateTime.parse(awardedAtStr) : null,
        );
      }).toList();

      // 3. Calculate level progress
      double progress = 0.0;
      if (donor.points >= 500) {
        progress = 1.0;
      } else if (donor.points >= 400) {
        progress = (donor.points - 400) / 100.0;
      } else if (donor.points >= 250) {
        progress = (donor.points - 250) / 150.0;
      } else {
        progress = donor.points / 250.0;
      }

      return DonorRewardModel(
        donorId: donor.id,
        totalPoints: donor.points,
        currentLevel: donor.level,
        levelProgress: progress,
        badges: badges,
      );
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
