import 'badge_model.dart';

class DonorRewardModel {
  final int? id;
  final int donorId;
  final int totalPoints;
  final String currentLevel;
  final double levelProgress;
  final List<BadgeModel> badges;

  DonorRewardModel({
    this.id,
    required this.donorId,
    required this.totalPoints,
    required this.currentLevel,
    required this.levelProgress,
    required this.badges,
  });

  factory DonorRewardModel.fromJson(Map<String, dynamic> json) {
    return DonorRewardModel(
      id: json['id'] as int?,
      donorId: json['donor'] as int,
      totalPoints: json['total_points'] ?? 0,
      currentLevel: json['current_level'] ?? 'Bronze',
      levelProgress: (json['level_progress'] ?? 0.0).toDouble(),
      badges: (json['badges'] as List<dynamic>?)
              ?.map((badgeJson) => BadgeModel.fromJson(badgeJson as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}
