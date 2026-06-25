class BadgeModel {
  final int? id;
  final String name;
  final String description;
  final String type;
  final String icon;
  final DateTime? earnedAt;

  BadgeModel({
    this.id,
    required this.name,
    required this.description,
    required this.type,
    required this.icon,
    this.earnedAt,
  });

  factory BadgeModel.fromJson(Map<String, dynamic> json) {
    return BadgeModel(
      id: json['id'] as int?,
      name: json['name'] ?? 'Unknown Badge',
      description: json['description'] ?? '',
      type: json['type'] ?? 'bronze',
      icon: json['icon'] ?? 'star',
      earnedAt: json['earned_at'] != null ? DateTime.parse(json['earned_at']) : null,
    );
  }
}
