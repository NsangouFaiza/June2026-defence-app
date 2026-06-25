class LeaderboardModel {
  final int? id;
  final String name;
  final int donations;
  final int points;
  final String? badge;
  final int donors;

  LeaderboardModel({
    this.id,
    required this.name,
    required this.donations,
    required this.points,
    this.badge,
    this.donors = 0,
  });

  factory LeaderboardModel.fromJson(Map<String, dynamic> json) {
    return LeaderboardModel(
      id: json['id'] as int?,
      name: json['name'] ?? json['user']?['full_name'] ?? 'Anonymous',
      donations: json['donations'] ?? json['total_donations'] ?? 0,
      points: json['points'] ?? 0,
      badge: json['badge'],
      donors: json['donors'] ?? json['total_donors'] ?? 0,
    );
  }
}
