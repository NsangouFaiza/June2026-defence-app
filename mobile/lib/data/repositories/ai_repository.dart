import 'package:dio/dio.dart';
import '../models/ai_message_model.dart';
import '../services/api_service.dart';

class AiRepository {
  final ApiService _apiService;

  AiRepository({ApiService? apiService}) : _apiService = apiService ?? ApiService();

  /// Send user message to Django AI endpoint and receive structured response.
  Future<AiChatMessage> sendMessage({
    required String message,
    String? role,
    List<AiChatMessage>? history,
  }) async {
    try {
      final historyPayload = (history ?? [])
          .map((m) => {
                'isUser': m.isUser,
                'text': m.text,
              },)
          .toList();

      final response = await _apiService.post('/ai/chat/', {
        'message': message,
        'role': role ?? 'donor',
        'history': historyPayload,
      });

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data is Map<String, dynamic>
            ? response.data as Map<String, dynamic>
            : <String, dynamic>{};

        final replyText = data['reply'] as String? ??
            'I have received your query. How else can I assist with LifeLink?';

        final suggestions = (data['suggestions'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            <String>[];

        final source = data['source'] as String?;

        return AiChatMessage.assistant(
          replyText,
          suggestions: suggestions,
          source: source,
        );
      } else {
        throw Exception('Server returned status code: ${response.statusCode}');
      }
    } on DioException catch (e) {
      String errorMessage = 'The LifeLink AI service is temporarily unavailable. Please try again in a moment.';
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout) {
        errorMessage = 'Connection timed out. Please check your internet connection.';
      } else if (e.response?.data != null && e.response?.data is Map) {
        final detail = (e.response!.data as Map)['detail'];
        if (detail != null) {
          errorMessage = detail.toString();
        }
      }
      return AiChatMessage.error(errorMessage);
    } catch (e) {
      return AiChatMessage.error(
        'Unable to reach LifeLink AI assistant: ${e.toString()}',
      );
    }
  }

  /// Get starter suggestion chips based on the user's role.
  Future<List<String>> getSuggestions(String? role) async {
    try {
      final response = await _apiService.get(
        '/ai/suggestions/',
        queryParameters: role != null ? {'role': role} : null,
      );

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data is Map<String, dynamic>
            ? response.data as Map<String, dynamic>
            : <String, dynamic>{};
        return (data['suggestions'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            [];
      }
    } catch (_) {
      // Fallback suggestions on local failure
    }
    return [
      'Am I eligible to donate blood?',
      'How to make an emergency request?',
      'Where is the nearest blood bank?',
      'How do rewards and badges work?',
    ];
  }
}
