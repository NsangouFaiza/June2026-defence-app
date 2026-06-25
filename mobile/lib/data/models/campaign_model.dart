class CampaignModel {
  final int id;
  final String title;
  final String description;
  final String type;
  final String? imageUrl;
  final String? location;
  final DateTime startDate;
  final DateTime endDate;
  final int? participantsCount;
  final bool isActive;
  final DateTime? createdAt;

  CampaignModel({
    required this.id,
    required this.title,
    required this.description,
    required this.type,
    this.imageUrl,
    this.location,
    required this.startDate,
    required this.endDate,
    this.participantsCount,
    required this.isActive,
    this.createdAt,
  });

  factory CampaignModel.fromJson(Map<String, dynamic> json) {
    return CampaignModel(
      id: json['id'] as int,
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      type: json['type'] ?? 'donation',
      imageUrl: json['image_url'],
      location: json['location'],
      startDate: DateTime.parse(json['start_date']),
      endDate: DateTime.parse(json['end_date']),
      participantsCount: json['participants_count'],
      isActive: json['is_active'] ?? true,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'type': type,
      'image_url': imageUrl,
      'location': location,
      'start_date': startDate.toIso8601String(),
      'end_date': endDate.toIso8601String(),
      'is_active': isActive,
    };
  }
}
