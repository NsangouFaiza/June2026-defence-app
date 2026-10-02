import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/providers/providers.dart';
import '../../../../data/models/ai_message_model.dart';

class AiChatScreen extends ConsumerStatefulWidget {
  const AiChatScreen({super.key});

  @override
  ConsumerState<AiChatScreen> createState() => _AiChatScreenState();
}

class _AiChatScreenState extends ConsumerState<AiChatScreen> with SingleTickerProviderStateMixin {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();

  final List<AiChatMessage> _messages = [];
  List<String> _suggestions = [];
  bool _isLoading = false;
  String _userRole = 'donor';
  String _userName = '';
  String? _lastFailedMessage;

  late AnimationController _typingAnimController;

  @override
  void initState() {
    super.initState();
    _typingAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeChat();
    });
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    _typingAnimController.dispose();
    super.dispose();
  }

  Future<void> _initializeChat() async {
    final userAsync = ref.read(currentUserProvider);
    final user = userAsync.value;
    if (user != null) {
      _userRole = user.role.toLowerCase();
      _userName = user.fullName;
    }

    // Load initial suggestions for role
    try {
      final suggestions = await ref.read(aiRepositoryProvider).getSuggestions(_userRole);
      if (mounted) {
        setState(() {
          _suggestions = suggestions;
        });
      }
    } catch (_) {}

    // Add initial welcome message tailored to role
    if (mounted) {
      setState(() {
        _messages.add(
          AiChatMessage.assistant(
            _getWelcomeMessage(_userRole, _userName),
            suggestions: _suggestions,
          ),
        );
      });
    }
  }

  String _getWelcomeMessage(String role, String name) {
    final displayName = name.isNotEmpty ? ' $name' : '';
    switch (role) {
      case 'donor':
        return 'Hello$displayName! 👋 I am your LifeLink AI Assistant.\n\n'
            'I can help you check donation eligibility, find nearby blood drives, '
            'book hospital appointments, track your digital donor badge, and explain donation guidelines. '
            'What would you like to know today?';
      case 'patient':
        return 'Hello$displayName! 👋 I am your LifeLink Virtual Guide.\n\n'
            'I am here to guide you through submitting blood requests, creating urgent emergency requests, '
            'checking blood pack compatibility, and managing your requests and receipts. How can I help you?';
      case 'hospital_staff':
      case 'blood_bank_staff':
        return 'Hello$displayName! 🏥 Welcome to your LifeLink Clinical Assistant.\n\n'
            'I can assist you with laboratory screening standards (HIV, Hep B/C, Syphilis), '
            'inventory statuses, unit quarantine procedures, and appointment validation. How can I assist your team?';
      case 'system_admin':
      case 'blood_bank_admin':
        return 'Hello$displayName! ⚙️ LifeLink Admin AI Assistant is active.\n\n'
            'Ask me about user roles, hospital verification, system audits, or platform workflows.';
      default:
        return 'Hello$displayName! 👋 Welcome to LifeLink.\n\n'
            'I can answer any questions about blood donation, patient emergency requests, and the LifeLink/NRH network.';
    }
  }

  String _getRoleLabel(String role) {
    switch (role) {
      case 'donor':
        return 'Donor Guide';
      case 'patient':
        return 'Patient Support';
      case 'hospital_staff':
      case 'blood_bank_staff':
        return 'Clinical & Lab Guide';
      case 'system_admin':
      case 'blood_bank_admin':
        return 'Admin Guide';
      default:
        return 'Virtual Assistant';
    }
  }

  Future<void> _handleSendMessage([String? predefinedText]) async {
    final text = (predefinedText ?? _textController.text).trim();
    if (text.isEmpty || _isLoading) return;

    if (predefinedText == null) {
      _textController.clear();
    }

    final userMsg = AiChatMessage.user(text);
    setState(() {
      _messages.add(userMsg);
      _isLoading = true;
      _lastFailedMessage = null;
    });

    _scrollToBottom();

    try {
      final aiRepo = ref.read(aiRepositoryProvider);
      final responseMsg = await aiRepo.sendMessage(
        message: text,
        role: _userRole,
        history: _messages,
      );

      if (mounted) {
        setState(() {
          _messages.add(responseMsg);
          _isLoading = false;
          if (responseMsg.suggestions.isNotEmpty) {
            _suggestions = responseMsg.suggestions;
          }
          if (responseMsg.isError) {
            _lastFailedMessage = text;
          }
        });
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _messages.add(
            AiChatMessage.error(
              'Could not connect to the LifeLink AI service. Please check your network connection and try again.',
            ),
          );
          _isLoading = false;
          _lastFailedMessage = text;
        });
        _scrollToBottom();
      }
    }
  }

  void _retryLastMessage() {
    if (_lastFailedMessage != null) {
      final msg = _lastFailedMessage!;
      _handleSendMessage(msg);
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent + 80.h,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _clearChat() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
        title: const Text('Reset Conversation?'),
        content: const Text('This will clear the current chat history with the LifeLink Assistant.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              setState(() {
                _messages.clear();
                _messages.add(
                  AiChatMessage.assistant(
                    _getWelcomeMessage(_userRole, _userName),
                    suggestions: _suggestions,
                  ),
                );
              });
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor, foregroundColor: Colors.white),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF7F9FC),
      appBar: AppBar(
        elevation: 1,
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        foregroundColor: isDark ? Colors.white : AppTheme.onSurface,
        titleSpacing: 0,
        title: Row(
          children: [
            // AI Assistant Avatar with Status Indicator
            Stack(
              children: [
                Container(
                  width: 42.w,
                  height: 42.w,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [AppTheme.primaryColor, AppTheme.primaryDark],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primaryColor.withOpacity(0.3),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.smart_toy_rounded,
                    color: Colors.white,
                    size: 22.w,
                  ),
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    width: 12.w,
                    height: 12.w,
                    decoration: BoxDecoration(
                      color: AppTheme.success,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                        width: 2.w,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(width: 12.w),
            // Header Title & Role Subtitle
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'LifeLink AI Assistant',
                    style: TextStyle(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : const Color(0xFF1A1A1A),
                    ),
                  ),
                  SizedBox(height: 2.h),
                  Row(
                    children: [
                      Text(
                        _getRoleLabel(_userRole),
                        style: TextStyle(
                          fontSize: 12.sp,
                          color: AppTheme.primaryColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        ' • Online',
                        style: TextStyle(
                          fontSize: 11.sp,
                          color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Reset Conversation',
            onPressed: _clearChat,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Messages List
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
                itemCount: _messages.length + (_isLoading ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index == _messages.length && _isLoading) {
                    return _buildTypingIndicator(isDark);
                  }
                  final msg = _messages[index];
                  return _buildMessageItem(msg, isDark);
                },
              ),
            ),

            // Quick Suggestions Chips (if any available)
            if (_suggestions.isNotEmpty && !_isLoading) _buildSuggestionsRow(isDark),

            // Text Input Field & Send Button
            _buildInputArea(isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildSuggestionsRow(bool isDark) {
    return Container(
      height: 44.h,
      margin: EdgeInsets.only(bottom: 6.h),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: 14.w),
        itemCount: _suggestions.length,
        separatorBuilder: (_, __) => SizedBox(width: 8.w),
        itemBuilder: (context, index) {
          final prompt = _suggestions[index];
          return ActionChip(
            elevation: 0,
            pressElevation: 1,
            backgroundColor: isDark ? const Color(0xFF262626) : const Color(0xFFEBF1F9),
            side: BorderSide(
              color: isDark ? Colors.grey.shade800 : AppTheme.primaryColor.withOpacity(0.18),
              width: 1,
            ),
            label: Text(
              prompt,
              style: TextStyle(
                fontSize: 12.sp,
                fontWeight: FontWeight.w500,
                color: isDark ? Colors.grey.shade200 : AppTheme.primaryDark,
              ),
            ),
            onPressed: () => _handleSendMessage(prompt),
          );
        },
      ),
    );
  }

  Widget _buildMessageItem(AiChatMessage message, bool isDark) {
    if (message.isUser) {
      return _buildUserBubble(message);
    } else if (message.isError) {
      return _buildErrorBubble(message, isDark);
    } else {
      return _buildAiBubble(message, isDark);
    }
  }

  Widget _buildUserBubble(AiChatMessage message) {
    return Padding(
      padding: EdgeInsets.only(bottom: 12.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          SizedBox(width: 48.w),
          Flexible(
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppTheme.primaryColor, AppTheme.primaryDark],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(18.r),
                  topRight: Radius.circular(18.r),
                  bottomLeft: Radius.circular(18.r),
                  bottomRight: Radius.circular(4.r),
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primaryColor.withOpacity(0.25),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    message.text,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14.5.sp,
                      height: 1.35,
                    ),
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    DateFormat('HH:mm').format(message.timestamp),
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 10.sp,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAiBubble(AiChatMessage message, bool isDark) {
    return Padding(
      padding: EdgeInsets.only(bottom: 14.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // AI Robot Avatar
          Container(
            width: 34.w,
            height: 34.w,
            margin: EdgeInsets.only(right: 8.w, top: 2.h),
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.primaryColor,
            ),
            child: Icon(Icons.smart_toy_rounded, color: Colors.white, size: 18.w),
          ),
          Flexible(
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(4.r),
                  topRight: Radius.circular(18.r),
                  bottomLeft: Radius.circular(18.r),
                  bottomRight: Radius.circular(18.r),
                ),
                border: Border.all(
                  color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SelectableText(
                    message.text,
                    style: TextStyle(
                      color: isDark ? Colors.grey.shade100 : const Color(0xFF212121),
                      fontSize: 14.sp,
                      height: 1.45,
                    ),
                  ),
                  SizedBox(height: 6.h),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        DateFormat('HH:mm').format(message.timestamp),
                        style: TextStyle(
                          color: isDark ? Colors.grey.shade500 : Colors.grey.shade500,
                          fontSize: 10.sp,
                        ),
                      ),
                      InkWell(
                        onTap: () {
                          Clipboard.setData(ClipboardData(text: message.text));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Copied response to clipboard'),
                              duration: Duration(seconds: 1),
                            ),
                          );
                        },
                        child: Row(
                          children: [
                            Icon(Icons.copy_rounded, size: 12.w, color: Colors.grey.shade500),
                            SizedBox(width: 4.w),
                            Text(
                              'Copy',
                              style: TextStyle(
                                fontSize: 10.sp,
                                color: Colors.grey.shade500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          SizedBox(width: 32.w),
        ],
      ),
    );
  }

  Widget _buildErrorBubble(AiChatMessage message, bool isDark) {
    return Padding(
      padding: EdgeInsets.only(bottom: 14.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34.w,
            height: 34.w,
            margin: EdgeInsets.only(right: 8.w, top: 2.h),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.red.shade700,
            ),
            child: Icon(Icons.error_outline_rounded, color: Colors.white, size: 18.w),
          ),
          Flexible(
            child: Container(
              padding: EdgeInsets.all(14.w),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF2A1717) : const Color(0xFFFFF1F1),
                borderRadius: BorderRadius.circular(16.r),
                border: Border.all(
                  color: Colors.red.shade300.withOpacity(0.5),
                  width: 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.warning_amber_rounded, color: Colors.red.shade700, size: 16.w),
                      SizedBox(width: 6.w),
                      Text(
                        'Service Notice',
                        style: TextStyle(
                          color: Colors.red.shade700,
                          fontWeight: FontWeight.bold,
                          fontSize: 13.sp,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 6.h),
                  Text(
                    message.text,
                    style: TextStyle(
                      color: isDark ? Colors.red.shade100 : Colors.red.shade900,
                      fontSize: 13.sp,
                      height: 1.35,
                    ),
                  ),
                  SizedBox(height: 10.h),
                  ElevatedButton.icon(
                    onPressed: _retryLastMessage,
                    icon: const Icon(Icons.refresh_rounded, size: 14),
                    label: const Text('Retry Query'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade700,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                      textStyle: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.bold),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.r)),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(width: 24.w),
        ],
      ),
    );
  }

  Widget _buildTypingIndicator(bool isDark) {
    return Padding(
      padding: EdgeInsets.only(bottom: 14.h),
      child: Row(
        children: [
          Container(
            width: 34.w,
            height: 34.w,
            margin: EdgeInsets.only(right: 8.w),
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.primaryColor,
            ),
            child: Icon(Icons.smart_toy_rounded, color: Colors.white, size: 18.w),
          ),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
              borderRadius: BorderRadius.circular(18.r),
              border: Border.all(
                color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'LifeLink Assistant is thinking',
                  style: TextStyle(
                    fontSize: 12.sp,
                    color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                    fontStyle: FontStyle.italic,
                  ),
                ),
                SizedBox(width: 8.w),
                SizedBox(
                  width: 14.w,
                  height: 14.w,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputArea(bool isDark) {
    return Container(
      padding: EdgeInsets.only(
        left: 12.w,
        right: 12.w,
        top: 8.h,
        bottom: 12.h,
      ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 16.w),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF1F3F6),
                borderRadius: BorderRadius.circular(24.r),
                border: Border.all(
                  color: isDark ? Colors.grey.shade700 : Colors.transparent,
                ),
              ),
              child: TextField(
                controller: _textController,
                focusNode: _focusNode,
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _handleSendMessage(),
                style: TextStyle(
                  fontSize: 14.sp,
                  color: isDark ? Colors.white : Colors.black87,
                ),
                decoration: InputDecoration(
                  hintText: 'Ask about donation, requests, or eligibility...',
                  hintStyle: TextStyle(
                    fontSize: 13.sp,
                    color: isDark ? Colors.grey.shade500 : Colors.grey.shade500,
                  ),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(vertical: 10.h),
                ),
              ),
            ),
          ),
          SizedBox(width: 8.w),
          Container(
            width: 44.w,
            height: 44.w,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppTheme.primaryColor, AppTheme.primaryDark],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primaryColor.withOpacity(0.35),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              shape: const CircleBorder(),
              child: IconButton(
                icon: _isLoading
                    ? SizedBox(
                        width: 18.w,
                        height: 18.w,
                        child: const CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : Icon(
                        Icons.send_rounded,
                        color: Colors.white,
                        size: 20.w,
                      ),
                onPressed: _isLoading ? null : _handleSendMessage,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
