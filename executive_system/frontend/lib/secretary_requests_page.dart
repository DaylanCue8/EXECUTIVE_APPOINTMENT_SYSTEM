import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class SecretaryRequestsPage extends StatefulWidget {
  @override
  _SecretaryRequestsPageState createState() => _SecretaryRequestsPageState();
}

class _SecretaryRequestsPageState extends State<SecretaryRequestsPage> {
  List requests = [];
  List confirmedSchedule = [];
  bool isLoading = true;

  final Color _asanaTeal = const Color(0xFF14C6B1);
  final Color _bgLight = const Color(0xFFF4F7F9);
  final String apiUrl = "http://192.168.254.101:5000";

  // 1. Fetch PENDING requests
  Future<void> fetchRequests() async {
    try {
      final response = await http.get(Uri.parse("$apiUrl/get_pending_meetings"));
      if (response.statusCode == 200) {
        setState(() => requests = jsonDecode(response.body));
      }
    } catch (e) {
      debugPrint("Error fetching requests: $e");
    }
  }

  // 2. Fetch CONFIRMED meetings
  Future<void> fetchConfirmed() async {
    try {
      final response = await http.get(Uri.parse("$apiUrl/get_confirmed_meetings"));
      if (response.statusCode == 200) {
        setState(() => confirmedSchedule = jsonDecode(response.body));
      }
    } catch (e) {
      debugPrint("Error fetching confirmed: $e");
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> refreshData() async {
    setState(() => isLoading = true);
    await fetchRequests();
    await fetchConfirmed();
  }

  // 3. Update status (This will write 'completed' to the DB)
  Future<void> updateMeeting(int id, String status) async {
    try {
      final response = await http.post(
        Uri.parse("$apiUrl/update_status/$id"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"status": status}),
      );
      if (response.statusCode == 200) {
        refreshData();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Meeting marked as $status"),
            backgroundColor: status == 'completed' ? Colors.blueGrey : _asanaTeal,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Action failed")));
    }
  }

  // Show a confirmation dialog before marking as done
  void _confirmComplete(int id, String title) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Mark as Completed?"),
        content: Text("This will move '$title' to history and remove it from the active schedule."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _asanaTeal),
            onPressed: () {
              Navigator.pop(context);
              updateMeeting(id, 'completed'); // This writes 'completed' to DB
            },
            child: const Text("Confirm", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    refreshData();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: _bgLight,
        appBar: AppBar(
          title: const Text("Secretary Portal", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)),
          backgroundColor: Colors.white,
          elevation: 0,
          actions: [
            IconButton(onPressed: refreshData, icon: const Icon(Icons.refresh, color: Colors.grey))
          ],
          bottom: TabBar(
            labelColor: _asanaTeal,
            unselectedLabelColor: Colors.grey,
            indicatorColor: _asanaTeal,
            indicatorWeight: 3,
            tabs: const [
              Tab(icon: Icon(Icons.pending_actions), text: "Pending"),
              Tab(icon: Icon(Icons.calendar_today), text: "Schedule"),
            ],
          ),
        ),
        body: isLoading 
          ? Center(child: CircularProgressIndicator(color: _asanaTeal))
          : TabBarView(
              children: [
                _buildList(requests, isPending: true),
                _buildList(confirmedSchedule, isPending: false),
              ],
            ),
      ),
    );
  }

  Widget _buildList(List data, {required bool isPending}) {
    return RefreshIndicator(
      onRefresh: refreshData,
      child: data.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.inbox, size: 60, color: Colors.grey.shade300),
                  const SizedBox(height: 10),
                  Text(isPending ? "No pending requests" : "No active schedule", 
                       style: const TextStyle(color: Colors.grey)),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: data.length,
              itemBuilder: (context, index) {
                final item = data[index];
                return Card(
                  elevation: 2,
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    title: Text(item['title'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.person, size: 14, color: Colors.grey),
                              const SizedBox(width: 5),
                              Text(item['requester_name'] ?? "Unknown", style: const TextStyle(color: Colors.black87)),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(Icons.access_time, size: 14, color: Colors.grey),
                              const SizedBox(width: 5),
                              Text("${item['date']} • ${item['time']}", style: const TextStyle(color: Colors.blueGrey)),
                            ],
                          ),
                        ],
                      ),
                    ),
                    trailing: isPending 
                      ? Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.check_circle, color: Colors.green, size: 28),
                              onPressed: () => updateMeeting(item['id'], 'confirmed'),
                            ),
                            IconButton(
                              icon: const Icon(Icons.cancel, color: Colors.red, size: 28),
                              onPressed: () => updateMeeting(item['id'], 'cancelled'),
                            ),
                          ],
                        )
                      : OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.blueGrey),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          onPressed: () => _confirmComplete(item['id'], item['title']),
                          child: const Text("DONE", style: TextStyle(color: Colors.blueGrey, fontSize: 12)),
                        ),
                  ),
                );
              },
            ),
    );
  }
}