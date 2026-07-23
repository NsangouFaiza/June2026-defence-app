import 'dart:io';
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
  final String? senderDonorLevel;

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
    this.senderDonorLevel,
  });

  bool get isVoiceMessage => messageType == 'voice' || (attachmentUrl != null && attachmentUrl!.isNotEmpty);

  String? get fullVoiceUrl {
    if (attachmentUrl == null || attachmentUrl!.isEmpty) return null;
    
    String url = attachmentUrl!;
    try {
      if (Platform.isAndroid) {
        url = url.replaceAll('127.0.0.1:8000', '10.0.2.2:8000')
                 .replaceAll('localhost:8000', '10.0.2.2:8000');
      }
    } catch (_) {}

    if (url.startsWith('http://') || url.startsWith('https://')) {
      return url;
    }
    final server = ApiService.serverBaseUrl;
    final path = url.startsWith('/') ? url! : '/$url';
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
      senderDonorLevel: json['sender_donor_level'] ?? json['senderDonorLevel'],
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
