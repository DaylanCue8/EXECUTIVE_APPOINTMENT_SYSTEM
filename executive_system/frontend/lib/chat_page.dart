import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'api_config.dart';

class ChatPage extends StatefulWidget {
  final int appointmentId;
  final int senderId;
  final int? receiverId;
  final String appointmentTitle;

  const ChatPage({
    super.key,
    required this.appointmentId,
    required this.senderId,
    this.receiverId,
    required this.appointmentTitle,
  });

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  List<dynamic> _messages = [];
  bool _isLoading = true;
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    fetchMessages();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> fetchMessages() async {
    setState(() => _isLoading = true);
    try {
      final response = await http.get(
        Uri.parse(ApiConfig.getChatMessages(widget.appointmentId)),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (mounted) {
          setState(() {
            _messages = data;
          });
        }
      }
    } catch (e) {
      debugPrint('Chat fetch failed: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
      _scrollToBottom();
    }
  }

  Future<void> sendMessage() async {
    final messageText = _messageController.text.trim();
    if (messageText.isEmpty) return;

    setState(() => _isSending = true);
    try {
      final response = await http.post(
        Uri.parse(ApiConfig.sendChatMessage),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'appointment_id': widget.appointmentId,
          'sender_id': widget.senderId,
          'receiver_id': widget.receiverId,
          'message': messageText,
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        _messageController.clear();
        await fetchMessages();
      } else {
        debugPrint('Chat send failed: ${response.body}');
      }
    } catch (e) {
      debugPrint('Chat send error: $e');
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  String _formatTime(String? raw) {
    if (raw == null || raw.isEmpty) return '';
    try {
      final dateTime = DateTime.parse(raw);
      return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return raw;
    }
  }

  Widget _buildMessageBubble(dynamic message) {
    final isMine = message['sender_id'] == widget.senderId;
    final senderName = isMine ? 'You' : (message['sender_name'] ?? 'Partner');
    final timestamp = _formatTime(message['timestamp']);

    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.72),
        decoration: BoxDecoration(
          color: isMine ? const Color(0xFF14C6B1) : const Color(0xFFE5E5EA),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(isMine ? 18 : 4),
            bottomRight: Radius.circular(isMine ? 4 : 18),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              senderName,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isMine ? Colors.white70 : Colors.black54,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              message['message'] ?? '',
              style: TextStyle(
                fontSize: 14,
                color: isMine ? Colors.white : Colors.black87,
              ),
            ),
            if (timestamp.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                timestamp,
                style: TextStyle(
                  fontSize: 11,
                  color: isMine ? Colors.white70 : Colors.black45,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.appointmentTitle, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: fetchMessages,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _messages.isEmpty
                    ? const Center(child: Text('No messages yet. Start the conversation.'))
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        itemCount: _messages.length,
                        itemBuilder: (_, index) => _buildMessageBubble(_messages[index]),
                      ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      hintText: 'Type your message...',
                      border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    ),
                    minLines: 1,
                    maxLines: 4,
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _isSending ? null : sendMessage,
                  style: ElevatedButton.styleFrom(
                    shape: const CircleBorder(),
                    padding: const EdgeInsets.all(12),
                  ),
                  child: _isSending
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.send),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
