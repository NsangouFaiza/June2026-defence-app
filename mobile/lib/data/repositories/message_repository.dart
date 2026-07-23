import 'dart:io' show Platform;
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:image_picker/image_picker.dart' show XFile;
import '../services/api_service.dart';
import '../models/conversation_model.dart';
import '../models/message_model.dart';
import '../models/contact_model.dart';

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

  Future<ConversationModel> getOrCreateConversation([int? otherUserId]) async {
    try {
      final payload = <String, dynamic>{};
      if (otherUserId != null && otherUserId > 0) {
        payload['other_user_id'] = otherUserId;
      }
      final response = await _apiService.post('/messages/conversations/', payload);
      return ConversationModel.fromJson(response.data);
    } on DioException catch (e) {
      final detail = e.response?.data is Map ? e.response?.data['error'] ?? e.response?.data['detail'] : null;
      throw Exception(detail ?? 'Unable to connect to chat service. Please try again.');
    } catch (e) {
      throw Exception('Unable to start conversation. Please check network connection.');
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

  Future<MessageModel> sendVoiceMessage(int conversationId, XFile voiceFile, int duration) async {
    try {
      final fileName = voiceFile.path.split('/').last.split(r'\').last;
      MultipartFile multipartFile;
      if (kIsWeb) {
        multipartFile = MultipartFile.fromBytes(
          await voiceFile.readAsBytes(),
          filename: fileName,
        );
      } else {
        multipartFile = await MultipartFile.fromFile(
          voiceFile.path,
          filename: fileName,
        );
      }
      final formData = FormData.fromMap({
        'voice_file': multipartFile,
        'voice_duration': duration,
        'content': '🎤 Voice Message',
        'message_type': 'voice',
      });

      final response = await _apiService.upload(
        '/messages/conversations/$conversationId/send-voice/',
        formData,
      );
      return MessageModel.fromJson(response.data);
    } catch (e) {
      throw Exception('Failed to send voice message: $e');
    }
  }

  Future<void> markAsRead(int conversationId) async {
    try {
      await _apiService.post('/messages/conversations/$conversationId/mark-read/');
    } catch (e) {
      throw Exception('Failed to mark messages as read: $e');
    }
  }

  Future<void> deleteConversation(int conversationId) async {
    try {
      await _apiService.delete('/messages/conversations/$conversationId/');
    } catch (e) {
      throw Exception('Failed to delete conversation: $e');
    }
  }

  Future<List<ContactModel>> getDonorContacts() async {
    try {
      final response = await _apiService.get('/users/contacts/donors/');
      return (response.data as List)
          .map((json) => ContactModel.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      // Fallback if endpoint fails
      try {
        final response = await _apiService.get('/donors/');
        return (response.data as List).map((json) {
          final u = json['user'] is Map ? json['user'] : {};
          return ContactModel(
            id: u['id'] ?? json['id'],
            userId: u['id'] ?? json['id'],
            fullName: u['full_name'] ?? 'Donor',
            email: u['email'] ?? '',
            phoneNumber: u['phone_number'] ?? '',
            role: 'donor',
            bloodGroup: u['blood_group'] ?? json['blood_group'],
            city: u['city'],
            region: u['region'],
            isEligible: json['is_eligible'] ?? true,
            donorCode: json['donor_code'],
          );
        }).toList();
      } catch (_) {
        throw Exception('Failed to load donor contacts: $e');
      }
    }
  }

  Future<List<ContactModel>> getPatientContacts() async {
    try {
      final response = await _apiService.get('/users/contacts/patients/');
      return (response.data as List)
          .map((json) => ContactModel.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      // Fallback
      try {
        final response = await _apiService.get('/patients/');
        return (response.data as List).map((json) {
          final u = json['user'] is Map ? json['user'] : {};
          return ContactModel(
            id: u['id'] ?? json['id'],
            userId: u['id'] ?? json['id'],
            fullName: u['full_name'] ?? 'Patient',
            email: u['email'] ?? '',
            phoneNumber: u['phone_number'] ?? '',
            role: 'patient',
            bloodGroup: u['blood_group'],
            city: u['city'],
            region: u['region'],
            medicalConditions: json['medical_conditions'],
            activeRequestsCount: json['active_requests_count'] ?? 0,
          );
        }).toList();
      } catch (_) {
        throw Exception('Failed to load patient contacts: $e');
      }
    }
  }

  Future<List<ContactModel>> getStaffContacts() async {
    try {
      final response = await _apiService.get('/users/contacts/staff/');
      return (response.data as List)
          .map((json) => ContactModel.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw Exception('Failed to load staff contacts: $e');
    }
  }
}
