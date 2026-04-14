import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class BossCalendarPage extends StatefulWidget {
  @override
  _BossCalendarPageState createState() => _BossCalendarPageState();
}

class _BossCalendarPageState extends State<BossCalendarPage> {
  List confirmedMeetings = [];
  bool isLoading = true;

  // Colors to match your Login/Register pages
  final Color _asanaTeal = const Color(0xFF14C6B1);
  final Color _bgLight = const Color(0xFFF4F7F9);

  Future<void> fetchConfirmed() async {
    setState(() => isLoading = true);
    try {
      final response = await http.get(Uri.parse("http://192.168.254.101:5000/get_confirmed_meetings"));
      if (response.statusCode == 200) {
        setState(() {
          confirmedMeetings = jsonDecode(response.body);
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Connection Error")));
    }
  }

  @override
  void initState() {
    super.initState();
    fetchConfirmed();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgLight,
      appBar: AppBar(
        title: const Text("Executive Schedule", style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.black87),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: fetchConfirmed)
        ],
      ),
      body: RefreshIndicator(
        onRefresh: fetchConfirmed,
        color: _asanaTeal,
        child: isLoading 
          ? Center(child: CircularProgressIndicator(color: _asanaTeal))
          : confirmedMeetings.isEmpty 
            ? _buildEmptyState()
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: confirmedMeetings.length,
                itemBuilder: (context, index) {
                  final m = confirmedMeetings[index];
                  return _buildMeetingCard(m);
                },
              ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return ListView( // ListView makes RefreshIndicator work even when empty
      children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.3),
        const Center(
          child: Column(
            children: [
              Icon(Icons.calendar_today_outlined, size: 80, color: Colors.grey),
              SizedBox(height: 16),
              Text("No confirmed meetings yet.", style: TextStyle(color: Colors.grey, fontSize: 16)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMeetingCard(dynamic m) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: _asanaTeal.withOpacity(0.1), shape: BoxShape.circle),
          child: Icon(Icons.event_available, color: _asanaTeal),
        ),
        title: Text(m['title'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 8.0),
          child: Text(
            "With: ${m['requester_name']}\nDate: ${m['date']}\nTime: ${m['time']}",
            style: TextStyle(color: Colors.grey.shade600, height: 1.4),
          ),
        ),
        isThreeLine: true,
      ),
    );
  }
}