import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class BossCalendarPage extends StatefulWidget {
  @override
  _BossCalendarPageState createState() => _BossCalendarPageState();
}

class _BossCalendarPageState extends State<BossCalendarPage> {
  List confirmedMeetings = [];

  Future<void> fetchConfirmed() async {
    final response = await http.get(Uri.parse("http://192.168.254.101:5000/get_confirmed_meetings"));
    if (response.statusCode == 200) {
      setState(() => confirmedMeetings = jsonDecode(response.body));
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
      appBar: AppBar(title: const Text("Boss's Schedule"), backgroundColor: Colors.blueGrey),
      body: confirmedMeetings.isEmpty 
          ? const Center(child: Text("No confirmed meetings for today."))
          : ListView.builder(
              itemCount: confirmedMeetings.length,
              itemBuilder: (context, index) {
                final m = confirmedMeetings[index];
                return Card(
                  color: Colors.blue.shade50,
                  margin: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
                  child: ListTile(
                    leading: const Icon(Icons.event_available, color: Colors.green),
                    title: Text(m['title'], style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text("With: ${m['requester_name']}\nAt: ${m['time']} (${m['date']})"),
                    isThreeLine: true,
                  ),
                );
              },
            ),
    );
  }
}