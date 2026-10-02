class AiChatMessage {
  final String id;
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final bool isError;
  final List<String> suggestions;
  final String? source;

  const AiChatMessage({
    required this.id,
    required this.text,
    required this.isUser,
    required this.timestamp,
    this.isError = false,
    this.suggestions = const [],
    this.source,
  });

  factory AiChatMessage.user(String text) {
    return AiChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      text: text,
      isUser: true,
      timestamp: DateTime.now(),
    );
  }

  factory AiChatMessage.assistant(
    String text, {
    List<String> suggestions = const [],
    String? source,
  }) {
    return AiChatMessage(
      id: (DateTime.now().millisecondsSinceEpoch + 1).toString(),
      text: text,
      isUser: false,
      timestamp: DateTime.now(),
      suggestions: suggestions,
      source: source,
    );
  }

  factory AiChatMessage.error(String text) {
    return AiChatMessage(
      id: (DateTime.now().millisecondsSinceEpoch + 1).toString(),
      text: text,
      isUser: false,
      timestamp: DateTime.now(),
      isError: true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'text': text,
      'isUser': isUser,
      'timestamp': timestamp.toIso8601String(),
      'isError': isError,
      'suggestions': suggestions,
      'source': source,
    };
  }

  factory AiChatMessage.fromJson(Map<String, dynamic> json) {
    return AiChatMessage(
      id: json['id'] as String? ?? '',
      text: json['text'] as String? ?? '',
      isUser: json['isUser'] as bool? ?? false,
      timestamp: json['timestamp'] != null
          ? DateTime.tryParse(json['timestamp'] as String) ?? DateTime.now()
          : DateTime.now(),
      isError: json['isError'] as bool? ?? false,
      suggestions: (json['suggestions'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      source: json['source'] as String?,
    );
  }
}
