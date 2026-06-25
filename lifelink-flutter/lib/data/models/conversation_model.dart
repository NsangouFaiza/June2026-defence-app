import 'message_model.dart';

class ConversationModel {
  final int id;
  final int participant1Id;
  final String participant1Name;
  final int participant2Id;
  final String participant2Name;
  final MessageModel? lastMessage;
  final DateTime createdAt;
  final DateTime? updatedAt;

  ConversationModel({
    required this.id,
    required this.participant1Id,
    required this.participant1Name,
    required this.participant2Id,
    required this.participant2Name,
    this.lastMessage,
    required this.createdAt,
    this.updatedAt,
  });

  factory ConversationModel.fromJson(Map<String, dynamic> json) {
    return ConversationModel(
      id: json['id'] as int,
      participant1Id: json['participant1'] as int,
      participant1Name: json['participant1_name'] ?? 'Unknown',
      participant2Id: json['participant2'] as int,
      participant2Name: json['participant2_name'] ?? 'Unknown',
      lastMessage: json['last_message'] != null
          ? MessageModel.fromJson(json['last_message'])
          : null,
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'])
          : null,
    );
  }

  String getOtherParticipant(int currentUserId) {
    if (currentUserId == participant1Id) {
      return participant2Name;
    }
    return participant1Name;
  }

  int getOtherParticipantId(int currentUserId) {
    if (currentUserId == participant1Id) {
      return participant2Id;
    }
    return participant1Id;
  }
}
