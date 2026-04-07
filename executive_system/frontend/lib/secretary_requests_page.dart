import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class SecretaryRequestsPage extends StatefulWidget {
  @override
  _SecretaryRequestsPageState createState() => _SecretaryRequestsPageState();
}

class _SecretaryRequestsPageState extends State<SecretaryRequestsPage> {
  List requests = [];

  // Fetch pending meetings from Flask
  Future<void> fetchRequests() async {
    final response = await http.get(Uri.parse("http://192.168.254.101:5000/get_pending_meetings"));
    if (response.statusCode == 200) {
      setState(() => requests = jsonDecode(response.body));
    }
  }

  // Update status (Approve/Decline)
  Future<void> updateMeeting(int id, String status) async {
    await http.post(
      Uri.parse("http://192.168.254.101:5000/update_status/$id"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"status": status}),
    );
    fetchRequests(); // Refresh the list
  }

  @override
  void initState() {
    super.initState();
    fetchRequests();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Pending Requests")),
      body: requests.isEmpty 
          ? Center(child: Text("No pending requests"))
          : ListView.builder(
              itemCount: requests.length,
              itemBuilder: (context, index) {
                final r = requests[index];
                return Card(
                  margin: EdgeInsets.all(10),
                  child: ListTile(
                    title: Text(r['title']),
                    subtitle: Text("By: ${r['requester_name']}\nDate: ${r['date']} at ${r['time']}"),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(icon: Icon(Icons.check, color: Colors.green), onPressed: () => updateMeeting(r['id'], 'confirmed')),
                        IconButton(icon: Icon(Icons.close, color: Colors.red), onPressed: () => updateMeeting(r['id'], 'cancelled')),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}