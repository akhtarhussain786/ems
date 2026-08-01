import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/api_service.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with SingleTickerProviderStateMixin {
  List<dynamic> _conversations = [];
  List<dynamic> _messages = [];
  bool _loading = true;
  bool _inChat = false;
  String? _activeConversationId;
  String? _activeConversationName;
  final _msgCtrl = TextEditingController();
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _fetchConversations();
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _scrollController.dispose();
    _msgCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchConversations() async {
    setState(() => _loading = true);
    try {
      final res = await ApiService().get('chat/conversations');
      if (mounted && res['success'] == true) {
        setState(() => _conversations = res['data'] ?? []);
      }
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _fetchMessages(String conversationId, {String? name}) async {
    setState(() => _loading = true);
    try {
      final res = await ApiService().get('chat/messages/$conversationId');
      if (mounted && res['success'] == true) {
        setState(() {
          _messages = res['data'] ?? [];
          _activeConversationId = conversationId;
          _activeConversationName = name;
          _inChat = true;
        });
        // Scroll to bottom after messages load
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _scrollToBottom();
        });
      }
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _sendMessage() async {
    if (_msgCtrl.text.trim().isEmpty) return;

    HapticFeedback.lightImpact();
    final message = _msgCtrl.text.trim();
    _msgCtrl.clear();

    // Optimistically add message
    setState(() {
      _messages.add({
        'message': message,
        'is_me': true,
        'created_at': DateTime.now().toIso8601String(),
      });
    });
    _scrollToBottom();

    final res = await ApiService().post('chat/send', {
      'conversation_id': _activeConversationId,
      'message': message,
    });

    if (mounted && res['success'] == true) {
      // Refresh to get the actual message with server data
      _fetchMessages(_activeConversationId!, name: _activeConversationName);
    } else {
      // Show error
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('❌ Failed to send message'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(10)),
          ),
        ),
      );
      // Remove optimistic message
      setState(() {
        _messages.removeWhere((m) => m['message'] == message && m['is_me'] == true);
      });
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  String _formatTime(String dateStr) {
    if (dateStr.isEmpty) return '';
    try {
      final date = DateTime.parse(dateStr);
      final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
      final amPm = date.hour >= 12 ? 'PM' : 'AM';
      return '${hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')} $amPm';
    } catch (_) {
      return '';
    }
  }

  String _formatDate(String dateStr) {
    if (dateStr.isEmpty) return '';
    try {
      final date = DateTime.parse(dateStr);
      final now = DateTime.now();
      if (date.day == now.day && date.month == now.month && date.year == now.year) {
        return 'Today';
      } else if (date.day == now.day - 1 && date.month == now.month && date.year == now.year) {
        return 'Yesterday';
      } else {
        return '${date.day}/${date.month}/${date.year}';
      }
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      appBar: _buildGlassAppBar(),
      body: _loading
          ? const Center(
        child: CircularProgressIndicator(
          color: Color(0xFF1E3A5F),
          strokeWidth: 3,
        ),
      )
          : _inChat
          ? _buildChatView()
          : _buildConversationList(),
    );
  }

  // ==================== GLASS APP BAR ====================
  PreferredSizeWidget _buildGlassAppBar() {
    return AppBar(
      backgroundColor: const Color(0xFF1E3A5F),
      elevation: 0,
      toolbarHeight: 70,
      flexibleSpace: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF1E3A5F), Color(0xFF2A5298)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
      ),
      leading: _inChat
          ? IconButton(
        icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
        onPressed: () {
          HapticFeedback.lightImpact();
          setState(() {
            _inChat = false;
            _activeConversationId = null;
            _activeConversationName = null;
            _messages = [];
          });
        },
      )
          : null,
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: const BorderRadius.all(Radius.circular(12)),
              border: Border.all(
                color: Colors.white.withOpacity(0.1),
                width: 1,
              ),
            ),
            child: Image.asset(
              'assets/images/logo25.png',
              height: 32,
              width: 32,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) {
                return const Icon(
                  Icons.chat_rounded,
                  color: Colors.white,
                  size: 24,
                );
              },
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              ShaderMask(
                shaderCallback: (bounds) => const LinearGradient(
                  colors: [Colors.white, Colors.white70],
                ).createShader(bounds),
                child: Text(
                  _inChat ? (_activeConversationName ?? 'Chat') : 'YATHARTH',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              Text(
                _inChat ? 'Online' : 'Conversations',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.6),
                  fontSize: 9,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        ],
      ),
      actions: [
        Container(
          margin: const EdgeInsets.only(right: 4),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: const BorderRadius.all(Radius.circular(14)),
            border: Border.all(
              color: Colors.white.withOpacity(0.1),
              width: 1,
            ),
          ),
          child: IconButton(
            onPressed: () {
              HapticFeedback.lightImpact();
              if (_inChat) {
                _fetchMessages(_activeConversationId!, name: _activeConversationName);
              } else {
                _fetchConversations();
              }
            },
            icon: const Icon(
              Icons.refresh_rounded,
              color: Colors.white,
              size: 22,
            ),
            padding: const EdgeInsets.all(10),
            constraints: const BoxConstraints(),
          ),
        ),
        const SizedBox(width: 4),
      ],
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          bottom: Radius.circular(20),
        ),
      ),
      centerTitle: false,
    );
  }

  // ==================== CONVERSATION LIST ====================
  Widget _buildConversationList() {
    return RefreshIndicator(
      onRefresh: _fetchConversations,
      color: const Color(0xFF1E3A5F),
      child: _conversations.isEmpty
          ? _buildEmptyState()
          : FadeTransition(
        opacity: _fadeAnimation,
        child: ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: _conversations.length,
          itemBuilder: (_, i) {
            final c = _conversations[i];
            return _buildGlassConversationCard(c);
          },
        ),
      ),
    );
  }

  // ==================== GLASS CONVERSATION CARD ====================
  Widget _buildGlassConversationCard(Map<String, dynamic> c) {
    final name = c['name'] ?? 'Unknown';
    final lastMessage = c['last_message'] ?? '';
    final unread = c['unread'] == true;
    final time = c['last_message_time'] ?? '';

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        _fetchMessages(c['id'].toString(), name: name);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.all(Radius.circular(16)),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.08),
              spreadRadius: 1,
              blurRadius: 12,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            // Avatar with gradient border
            Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1E3A5F), Color(0xFF2A5298)],
                ),
                shape: BoxShape.circle,
              ),
              child: Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: const Color(0xFF1E3A5F).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    name.isNotEmpty ? name[0].toUpperCase() : '?',
                    style: const TextStyle(
                      color: Color(0xFF1E3A5F),
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          name,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: Color(0xFF1E3A5F),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (time.isNotEmpty)
                        Text(
                          _formatTime(time),
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey[400],
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          lastMessage.isEmpty ? 'No messages yet' : lastMessage,
                          style: TextStyle(
                            fontSize: 12,
                            color: unread ? const Color(0xFF1E3A5F) : Colors.grey[500],
                            fontWeight: unread ? FontWeight.w600 : FontWeight.normal,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (unread)
                        Container(
                          width: 10,
                          height: 10,
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Colors.red, Colors.redAccent],
                            ),
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==================== CHAT VIEW ====================
  Widget _buildChatView() {
    return Column(
      children: [
        Expanded(
          child: _messages.isEmpty
              ? Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.chat_bubble_outline_rounded,
                  size: 64,
                  color: Colors.grey[300],
                ),
                const SizedBox(height: 12),
                Text(
                  'No messages yet',
                  style: TextStyle(
                    color: Colors.grey[400],
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Start the conversation',
                  style: TextStyle(
                    color: Colors.grey[400],
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          )
              : ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.all(12),
            itemCount: _messages.length,
            itemBuilder: (_, i) {
              final msg = _messages[i];
              final isMe = msg['is_me'] == true;
              final time = msg['created_at'] ?? '';
              final showTime = i == 0 ||
                  (i > 0 && _messages[i-1]['is_me'] != isMe);

              return Column(
                children: [
                  if (showTime && time.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _formatDate(time),
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey[600],
                        ),
                      ),
                    ),
                  Align(
                    alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        gradient: isMe
                            ? const LinearGradient(
                          colors: [Color(0xFF1E3A5F), Color(0xFF2A5298)],
                        )
                            : null,
                        color: isMe ? null : Colors.white,
                        borderRadius: BorderRadius.only(
                          topLeft: const Radius.circular(14),
                          topRight: const Radius.circular(14),
                          bottomLeft: isMe ? const Radius.circular(14) : Radius.zero,
                          bottomRight: isMe ? Radius.zero : const Radius.circular(14),
                        ),
                        boxShadow: isMe
                            ? null
                            : [
                          BoxShadow(
                            color: Colors.grey.withOpacity(0.08),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      constraints: BoxConstraints(
                        maxWidth: MediaQuery.of(context).size.width * 0.75,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            msg['message'] ?? '',
                            style: TextStyle(
                              color: isMe ? Colors.white : Colors.black87,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _formatTime(time),
                            style: TextStyle(
                              fontSize: 9,
                              color: isMe ? Colors.white70 : Colors.grey[400],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        // Message Input
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.08),
                spreadRadius: 1,
                blurRadius: 12,
                offset: const Offset(0, -3),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: const BorderRadius.all(Radius.circular(25)),
                    border: Border.all(
                      color: Colors.grey[200]!,
                      width: 1,
                    ),
                  ),
                  child: TextField(
                    controller: _msgCtrl,
                    decoration: const InputDecoration(
                      hintText: 'Type a message...',
                      hintStyle: TextStyle(color: Colors.grey),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: _sendMessage,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF1E3A5F), Color(0xFF2A5298)],
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.send_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ==================== EMPTY STATE ====================
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.chat_bubble_outline_rounded,
            size: 64,
            color: Colors.grey[300],
          ),
          const SizedBox(height: 12),
          Text(
            'No conversations',
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Start a new conversation',
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}