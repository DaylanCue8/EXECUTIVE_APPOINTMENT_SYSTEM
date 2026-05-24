import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'api_config.dart';
import 'chat_page.dart';

class ChatListPage extends StatefulWidget {
  final int userId;
  final String? pinnedRole; // e.g. 'boss' to pin boss first, or 'secretary' for boss view

  const ChatListPage({super.key, required this.userId, this.pinnedRole});

  @override
  State<ChatListPage> createState() => _ChatListPageState();
}

class _ChatListPageState extends State<ChatListPage> {
  bool _isLoading = true;
  List<dynamic> _conversations = [];

  @override
  void initState() {
    super.initState();
    _fetchConversations();
  }

  Future<void> _fetchConversations() async {
    setState(() => _isLoading = true);
    try {
      final resp = await http.get(Uri.parse(ApiConfig.getConversations(widget.userId)));
      if (resp.statusCode == 200) {
        final List data = jsonDecode(resp.body);
        List<dynamic> list = data;

        // If pinnedRole provided, put matching role first
        if (widget.pinnedRole != null) {
          list.sort((a, b) {
            final aPinned = (a['other_role'] == widget.pinnedRole) ? 0 : 1;
            final bPinned = (b['other_role'] == widget.pinnedRole) ? 0 : 1;
            if (aPinned != bPinned) return aPinned - bPinned;
            return (b['timestamp'] ?? '').compareTo(a['timestamp'] ?? '');
          });
        } else {
          list.sort((a, b) => (b['timestamp'] ?? '').compareTo(a['timestamp'] ?? ''));
        }

        // If pinnedRole is set and we want to filter (e.g., boss only sees secretary),
        // caller can rely on pinnedRole to present UI; here we only order and don't filter.

        if (mounted) {
          setState(() {
            _conversations = list;
          });
        }
      }
    } catch (e) {
      debugPrint('Fetch conversations failed: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Chats')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _conversations.isEmpty
              ? const Center(child: Text('No conversations yet'))
              : ListView.separated(
                  itemCount: _conversations.length,
                  separatorBuilder: (context, index) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final c = _conversations[i];
                    final title = c['other_name'] ?? 'Unknown';
                    final subtitle = c['last_message'] ?? '';
                    final ts = c['timestamp'] ?? '';

                    return ListTile(
                      leading: CircleAvatar(child: Text(title.isNotEmpty ? title[0] : '?')),
                      title: Text(title),
                      subtitle: Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis),
                      trailing: Text(ts.isNotEmpty ? ts.split('T').first : ''),
                      onTap: () {
                        final apptId = c['appointment_id'];
                        if (apptId == null) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No appointment conversation available')));
                          return;
                        }
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ChatPage(
                              appointmentId: apptId,
                              senderId: widget.userId,
                              receiverId: c['other_id'],
                              appointmentTitle: title,
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
    );
  }
}
