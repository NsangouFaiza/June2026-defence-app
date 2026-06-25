class MessageModel {
  final int id;
  final int conversationId;
  final int senderId;
  final String senderName;
  final String content;
  final String? attachmentUrl;
  final bool isRead;
  final DateTime createdAt;

  MessageModel({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.senderName,
    required this.content,
    this.attachmentUrl,
    required this.isRead,
    required this.createdAt,
  });

  factory MessageModel.fromJson(Map<String, dynamic> json) {
    return MessageModel(
      id: json['id'] as int,
      conversationId: json['conversation'] as int,
      senderId: json['sender'] as int,
      senderName: json['sender_name'] ?? 'Unknown',
      content: json['content'] ?? '',
      attachmentUrl: json['attachment_url'],
      isRead: json['is_read'] ?? false,
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'conversation': conversationId,
      'sender': senderId,
      'content': content,
      'attachment_url': attachmentUrl,
      'is_read': isRead,
    };
  }
}
