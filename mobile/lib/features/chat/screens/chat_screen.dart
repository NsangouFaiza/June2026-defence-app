import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/localization_service.dart';
import '../../../../core/providers/providers.dart';
import '../../../../data/repositories/message_repository.dart';
import '../../../../data/models/conversation_model.dart';
import '../../../../data/models/message_model.dart';
import '../../../../data/services/api_service.dart';
import 'dart:io';
import 'dart:convert';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';

class ChatScreen extends ConsumerStatefulWidget {
  final int? conversationId;
  final int? otherUserId;

  const ChatScreen({
    super.key,
    this.conversationId,
    this.otherUserId,
  });

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  int? _conversationId;
  List<MessageModel> _messages = [];
  bool _isLoading = true;
  WebSocket? _webSocket;
  StreamSubscription? _webSocketSubscription;

  @override
  void initState() {
    super.initState();
    if (widget.conversationId != null) {
      _conversationId = widget.conversationId;
      _loadMessages();
      _connectWebSocket();
    } else if (widget.otherUserId != null) {
      _createConversation();
    }
  }

  Future<void> _createConversation() async {
    final messageRepo = ref.read(messageRepositoryProvider);
    try {
      final conversation = await messageRepo.getOrCreateConversation(widget.otherUserId!);
      setState(() => _conversationId = conversation.id);
      await _loadMessages();
      _connectWebSocket();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _loadMessages() async {
    if (_conversationId == null) return;

    setState(() => _isLoading = true);
    final messageRepo = ref.read(messageRepositoryProvider);
    try {
      final messages = await messageRepo.getMessages(_conversationId!);
      setState(() {
        _messages = messages;
        _isLoading = false;
      });
      _scrollToBottom();
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _connectWebSocket() async {
    if (_conversationId == null) return;

    _webSocket?.close();
    _webSocketSubscription?.cancel();

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token');
      if (token == null) return;

      final uri = Uri.parse(ApiService.baseUrl);
      final host = uri.host;
      final port = uri.port != 0 ? uri.port : 8000;
      final wsUrl = 'ws://$host:$port/ws/chat/$_conversationId/?token=$token';
      _webSocket = await WebSocket.connect(wsUrl);

      _webSocketSubscription = _webSocket!.listen(
        (data) {
          final Map<String, dynamic> payload = json.decode(data);
          if (payload['type'] == 'message') {
            final messageData = payload['message'];
            final message = MessageModel.fromJson(messageData);

            if (!_messages.any((m) => m.id == message.id)) {
              setState(() {
                _messages.add(message);
              });
              _scrollToBottom();
            }
          }
        },
        onError: (err) {
          debugPrint('WebSocket error: $err');
        },
        onDone: () {
          debugPrint('WebSocket closed');
        },
      );
    } catch (e) {
      debugPrint('Failed to connect to WebSocket: $e');
    }
  }

  Future<void> _sendMessage() async {
    final content = _messageController.text.trim();
    if (content.isEmpty || _conversationId == null) return;

    _messageController.clear();

    if (_webSocket != null && _webSocket!.readyState == WebSocket.open) {
      _webSocket!.add(json.encode({
        'type': 'message',
        'content': content,
      }));
      return;
    }

    final messageRepo = ref.read(messageRepositoryProvider);
    try {
      final message = await messageRepo.sendMessage(_conversationId!, content);
      setState(() => _messages.add(message));
      _scrollToBottom();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final localization = ref.watch(localizationServiceProvider);
    final currentUserAsync = ref.watch(currentUserProvider);
    final myId = currentUserAsync.value?.id ?? 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chat'),
      ),
      body: _conversationId == null
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : _messages.isEmpty
                          ? Center(
                              child: Text(
                                localization.translate('no_messages'),
                                style: Theme.of(context).textTheme.bodyLarge,
                              ),
                            )
                          : ListView.builder(
                              controller: _scrollController,
                              padding: EdgeInsets.all(16.w),
                              itemCount: _messages.length,
                              itemBuilder: (context, index) {
                                final message = _messages[index];
                                final isMe = message.senderId == myId;
                                return _buildMessageBubble(context, message, isMe);
                              },
                            ),
                ),
                Container(
                  padding: EdgeInsets.all(16.w),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, -2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _messageController,
                          decoration: const InputDecoration(
                            hintText: 'Type a message...',
                            border: OutlineInputBorder(),
                          ),
                          maxLines: null,
                          onSubmitted: (_) => _sendMessage(),
                        ),
                      ),
                      SizedBox(width: 8.w),
                      Container(
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor,
                          borderRadius: BorderRadius.circular(8.r),
                        ),
                        child: IconButton(
                          onPressed: _sendMessage,
                          icon: const Icon(Icons.send, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildMessageBubble(BuildContext context, MessageModel message, bool isMe) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.only(bottom: 8.h),
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        decoration: BoxDecoration(
          color: isMe ? AppTheme.primaryColor : Colors.grey[200],
          borderRadius: BorderRadius.circular(16.r).copyWith(
            bottomRight: isMe ? Radius.zero : Radius.circular(16.r),
            bottomLeft: isMe ? Radius.circular(16.r) : Radius.zero,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isMe)
              Text(
                message.senderName,
                style: TextStyle(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.bold,
                  color: isMe ? Colors.white70 : Colors.grey[600],
                ),
              ),
            if (!isMe) SizedBox(height: 4.h),
            Text(
              message.content,
              style: TextStyle(
                color: isMe ? Colors.white : Colors.black87,
              ),
            ),
            SizedBox(height: 4.h),
            Text(
              '${message.createdAt.hour}:${message.createdAt.minute.toString().padLeft(2, '0')}',
              style: TextStyle(
                fontSize: 10.sp,
                color: isMe ? Colors.white70 : Colors.grey[500],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _webSocket?.close();
    _webSocketSubscription?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}
