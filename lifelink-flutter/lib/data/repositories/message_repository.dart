import 'package:dio/dio.dart';
import '../services/api_service.dart';
import '../models/conversation_model.dart';
import '../models/message_model.dart';

class MessageRepository {
  final ApiService _apiService = ApiService();

  Future<List<ConversationModel>> getConversations() async {
    try {
      final response = await _apiService.get('/messages/conversations/');
      return (response.data as List)
          .map((json) => ConversationModel.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw Exception('Failed to load conversations: $e');
    }
  }

  Future<ConversationModel> getOrCreateConversation(int otherUserId) async {
    try {
      final response = await _apiService.post('/messages/conversations/', {
        'other_user_id': otherUserId,
      });
      return ConversationModel.fromJson(response.data);
    } catch (e) {
      throw Exception('Failed to get conversation: $e');
    }
  }

  Future<List<MessageModel>> getMessages(int conversationId) async {
    try {
      final response = await _apiService.get('/messages/conversations/$conversationId/messages/');
      return (response.data as List)
          .map((json) => MessageModel.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw Exception('Failed to load messages: $e');
    }
  }

  Future<MessageModel> sendMessage(int conversationId, String content) async {
    try {
      final response = await _apiService.post('/messages/conversations/$conversationId/messages/', {
        'content': content,
      });
      return MessageModel.fromJson(response.data);
    } catch (e) {
      throw Exception('Failed to send message: $e');
    }
  }

  Future<void> markAsRead(int conversationId) async {
    try {
      await _apiService.post('/messages/conversations/$conversationId/mark-read/');
    } catch (e) {
      throw Exception('Failed to mark messages as read: $e');
    }
  }
}
