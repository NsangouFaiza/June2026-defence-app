import '../services/api_service.dart';

class MessageModel {
  final int id;
  final int conversationId;
  final int senderId;
  final String senderName;
  final String content;
  final String? attachmentUrl;
  final String messageType;
  final int voiceDuration;
  final bool isRead;
  final DateTime createdAt;

  MessageModel({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.senderName,
    required this.content,
    this.attachmentUrl,
    this.messageType = 'text',
    this.voiceDuration = 0,
    required this.isRead,
    required this.createdAt,
  });

  bool get isVoiceMessage => messageType == 'voice' || (attachmentUrl != null && attachmentUrl!.isNotEmpty);

  String? get fullVoiceUrl {
    if (attachmentUrl == null || attachmentUrl!.isEmpty) return null;
    if (attachmentUrl!.startsWith('http://') || attachmentUrl!.startsWith('https://')) {
      return attachmentUrl;
    }
    final server = ApiService.serverBaseUrl;
    final path = attachmentUrl!.startsWith('/') ? attachmentUrl! : '/$attachmentUrl';
    return '$server$path';
  }

  factory MessageModel.fromJson(Map<String, dynamic> json) {
    return MessageModel(
      id: json['id'] as int,
      conversationId: json['conversation'] ?? json['conversation_id'] ?? 0,
      senderId: json['sender'] ?? json['sender_id'] ?? 0,
      senderName: json['sender_name'] ?? 'User',
      content: json['content'] ?? '',
      attachmentUrl: json['attachment'] ?? json['attachment_url'],
      messageType: json['message_type'] ?? (json['attachment'] != null ? 'voice' : 'text'),
      voiceDuration: json['voice_duration'] ?? 0,
      isRead: json['is_read'] ?? false,
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'conversation': conversationId,
      'sender': senderId,
      'content': content,
      'attachment_url': attachmentUrl,
      'message_type': messageType,
      'voice_duration': voiceDuration,
      'is_read': isRead,
    };
  }
}
