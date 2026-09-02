import 'dart:async';
import 'dart:convert';
import 'dart:io' show File, WebSocket;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:image_picker/image_picker.dart' show XFile;
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/providers/providers.dart';
import '../../../../core/services/permission_service.dart';
import '../../../../widgets/lifelink_app_bar.dart';

import '../../../../data/models/message_model.dart';
import '../../../../data/services/api_service.dart';
import '../widgets/voice_note_player_bubble.dart';

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

  // Voice Note Recording & Preview State
  final AudioRecorder _audioRecorder = AudioRecorder();
  AudioPlayer? _previewPlayer;
  bool _isRecording = false;
  bool _isPreviewing = false;
  bool _isPreviewPlaying = false;
  String? _recordedPath;
  int _recordingSeconds = 0;
  String? _otherUserName;
  Timer? _recordingTimer;
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _messageController.addListener(_onTextChanged);

    if (widget.conversationId != null) {
      _conversationId = widget.conversationId;
      _loadMessages();
      _connectWebSocket();
    } else {
      _createConversation();
    }
  }

  void _onTextChanged() {
    final hasText = _messageController.text.trim().isNotEmpty;
    if (hasText != _hasText) {
      setState(() => _hasText = hasText);
    }
  }

  Future<void> _createConversation() async {
    final messageRepo = ref.read(messageRepositoryProvider);
    try {
      final conversation = await messageRepo.getOrCreateConversation(widget.otherUserId);
      if (mounted) {
        final currentUserAsync = ref.read(currentUserProvider);
        final myId = currentUserAsync.value?.id ?? 0;
        final name = conversation.getOtherParticipant(myId);
        setState(() {
          _conversationId = conversation.id;
          if (name.isNotEmpty && name != 'Unknown') {
            _otherUserName = name;
          }
        });
        await _loadMessages();
        _connectWebSocket();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        final errorMsg = e.toString().replaceAll('Exception: ', '');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMsg),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }

  Future<void> _loadMessages() async {
    if (_conversationId == null) return;

    setState(() => _isLoading = true);
    final messageRepo = ref.read(messageRepositoryProvider);
    try {
      if (_otherUserName == null) {
        final conversations = await messageRepo.getConversations();
        final match = conversations.where((c) => c.id == _conversationId).firstOrNull;
        if (match != null) {
          final currentUserAsync = ref.read(currentUserProvider);
          final myId = currentUserAsync.value?.id ?? 0;
          _otherUserName = match.getOtherParticipant(myId);
        }
      }
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

  // --- Voice Note Methods ---

  Future<void> _startRecording() async {
    try {
      bool hasPermission = await _audioRecorder.hasPermission();
      if (!hasPermission) {
        if (mounted) {
          hasPermission = await PermissionService.requestMicrophonePermission(context);
        }
      }
      if (!hasPermission) return;

      String path;
      if (kIsWeb) {
        path = '';
        await _audioRecorder.start(
          const RecordConfig(encoder: AudioEncoder.aacLc),
          path: path,
        );
      } else {
        final tempDir = await getTemporaryDirectory();
        path = '${tempDir.path}/vn_${DateTime.now().millisecondsSinceEpoch}.m4a';
        await _audioRecorder.start(
          const RecordConfig(encoder: AudioEncoder.aacLc),
          path: path,
        );
      }

      if (mounted) {
        setState(() {
          _isRecording = true;
          _isPreviewing = false;
          _recordedPath = path;
          _recordingSeconds = 0;
        });

        _recordingTimer?.cancel();
        _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
          if (mounted && _isRecording) {
            setState(() => _recordingSeconds++);
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not start recording: ${e.toString()}'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }

  Future<void> _stopAndPreviewRecording() async {
    if (!_isRecording) return;
    _recordingTimer?.cancel();

    try {
      final path = await _audioRecorder.stop();
      if (path != null) {
        _recordedPath = path;
      }
      setState(() {
        _isRecording = false;
        _isPreviewing = true;
      });
    } catch (e) {
      debugPrint('Error stopping recorder: $e');
    }
  }

  Future<void> _cancelRecording() async {
    _recordingTimer?.cancel();
    if (_isRecording) {
      try {
        await _audioRecorder.stop();
      } catch (_) {}
    }
    if (_previewPlayer != null) {
      await _previewPlayer!.stop();
      await _previewPlayer!.dispose();
      _previewPlayer = null;
    }
    if (_recordedPath != null && _recordedPath!.isNotEmpty && !kIsWeb) {
      try {
        final file = File(_recordedPath!);
        if (await file.exists()) {
          await file.delete();
        }
      } catch (_) {}
    }
    setState(() {
      _isRecording = false;
      _isPreviewing = false;
      _isPreviewPlaying = false;
      _recordedPath = null;
      _recordingSeconds = 0;
    });
  }

  Future<void> _togglePreviewPlay() async {
    if (_recordedPath == null) return;

    if (_previewPlayer == null) {
      _previewPlayer = AudioPlayer();
      _previewPlayer!.onPlayerStateChanged.listen((state) {
        if (mounted) {
          setState(() => _isPreviewPlaying = state == PlayerState.playing);
        }
      });
      _previewPlayer!.onPlayerComplete.listen((_) {
        if (mounted) {
          setState(() => _isPreviewPlaying = false);
        }
      });
    }

    if (_isPreviewPlaying) {
      await _previewPlayer!.pause();
    } else {
      await _previewPlayer!.play(DeviceFileSource(_recordedPath!));
    }
  }

  Future<void> _sendVoiceNote() async {
    if (_conversationId == null) return;

    int duration = _recordingSeconds > 0 ? _recordingSeconds : 1;
    String? path = _recordedPath;

    if (_isRecording) {
      _recordingTimer?.cancel();
      try {
        path = await _audioRecorder.stop();
        _recordedPath = path;
      } catch (_) {}
    }

    if (path == null) return;

    if (_previewPlayer != null) {
      await _previewPlayer!.stop();
      await _previewPlayer!.dispose();
      _previewPlayer = null;
    }

    setState(() {
      _isRecording = false;
      _isPreviewing = false;
      _isPreviewPlaying = false;
      _recordedPath = null;
      _recordingSeconds = 0;
    });

    final messageRepo = ref.read(messageRepositoryProvider);
    try {
      final xfile = XFile(path);
      final message = await messageRepo.sendVoiceMessage(_conversationId!, xfile, duration);
      setState(() {
        _messages.add(message);
      });
      _scrollToBottom();

      if (_webSocket != null && _webSocket!.readyState == WebSocket.open) {
        _webSocket!.add(json.encode({
          'type': 'message',
          'message_id': message.id,
        }));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send voice message: ${e.toString()}')),
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

  String _formatTimer(int totalSecs) {
    final m = (totalSecs ~/ 60).toString().padLeft(1, '0');
    final s = (totalSecs % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final localization = ref.watch(localizationServiceProvider);
    final currentUserAsync = ref.watch(currentUserProvider);
    final myId = currentUserAsync.value?.id ?? 0;

    return Scaffold(
      appBar: LifeLinkAppBar(
        title: _otherUserName != null && _otherUserName!.isNotEmpty ? _otherUserName! : 'Direct Chat',
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
                _buildInputArea(context),
              ],
            ),
    );
  }

  Widget _buildInputArea(BuildContext context) {
    if (_isRecording) {
      return Container(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.delete_outline, color: AppTheme.error),
              onPressed: _cancelRecording,
            ),
            SizedBox(width: 8.w),
            Container(
              width: 10.w,
              height: 10.w,
              decoration: const BoxDecoration(
                color: AppTheme.error,
                shape: BoxShape.circle,
              ),
            ),
            SizedBox(width: 8.w),
            Text(
              _formatTimer(_recordingSeconds),
              style: TextStyle(
                fontSize: 16.sp,
                fontWeight: FontWeight.bold,
                color: AppTheme.error,
              ),
            ),
            const Spacer(),
            IconButton(
              icon: const Icon(Icons.stop_circle_outlined, color: AppTheme.primaryColor),
              onPressed: _stopAndPreviewRecording,
            ),
            SizedBox(width: 8.w),
            Container(
              decoration: BoxDecoration(
                color: AppTheme.primaryColor,
                borderRadius: BorderRadius.circular(8.r),
              ),
              child: IconButton(
                onPressed: _sendVoiceNote,
                icon: const Icon(Icons.send, color: Colors.white),
              ),
            ),
          ],
        ),
      );
    }

    if (_isPreviewing) {
      return Container(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.delete_outline, color: AppTheme.error),
              onPressed: _cancelRecording,
            ),
            SizedBox(width: 8.w),
            IconButton(
              icon: Icon(
                _isPreviewPlaying ? Icons.pause_circle_filled : Icons.play_circle_fill,
                color: AppTheme.primaryColor,
                size: 32.w,
              ),
              onPressed: _togglePreviewPlay,
            ),
            SizedBox(width: 8.w),
            Text(
              'Voice Note (${_formatTimer(_recordingSeconds)})',
              style: TextStyle(
                fontSize: 14.sp,
                fontWeight: FontWeight.w500,
              ),
            ),
            const Spacer(),
            Container(
              decoration: BoxDecoration(
                color: AppTheme.primaryColor,
                borderRadius: BorderRadius.circular(8.r),
              ),
              child: IconButton(
                onPressed: _sendVoiceNote,
                icon: const Icon(Icons.send, color: Colors.white),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
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
          if (_hasText)
            Container(
              decoration: BoxDecoration(
                color: AppTheme.primaryColor,
                borderRadius: BorderRadius.circular(8.r),
              ),
              child: IconButton(
                onPressed: _sendMessage,
                icon: const Icon(Icons.send, color: Colors.white),
              ),
            )
          else
            Container(
              decoration: BoxDecoration(
                color: AppTheme.primaryColor,
                borderRadius: BorderRadius.circular(8.r),
              ),
              child: IconButton(
                onPressed: _startRecording,
                icon: const Icon(Icons.mic, color: Colors.white),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(BuildContext context, MessageModel message, bool isMe) {
    final isVoice = message.isVoiceMessage || (message.fullVoiceUrl != null && message.fullVoiceUrl!.isNotEmpty);

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
                '${message.senderName}${_getDonorLevelEmoji(message.senderDonorLevel)}',
                style: TextStyle(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.bold,
                  color: isMe ? Colors.white70 : Colors.grey[600],
                ),
              ),
            if (!isMe) SizedBox(height: 4.h),
            if (isVoice && message.fullVoiceUrl != null)
              VoiceNotePlayerBubble(
                audioUrl: message.fullVoiceUrl!,
                durationSeconds: message.voiceDuration,
                isMe: isMe,
              )
            else
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
    _messageController.removeListener(_onTextChanged);
    _webSocket?.close();
    _webSocketSubscription?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    _recordingTimer?.cancel();
    _audioRecorder.dispose();
    _previewPlayer?.dispose();
    super.dispose();
  }

  String _getDonorLevelEmoji(String? level) {
    if (level == null) return '';
    switch (level.toLowerCase()) {
      case 'platinum':
        return ' 💎';
      case 'gold':
        return ' 🥇';
      case 'silver':
        return ' 🥈';
      case 'bronze':
        return ' 🥉';
      default:
        return '';
    }
  }
}
