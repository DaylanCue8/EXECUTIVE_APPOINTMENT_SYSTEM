import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../dashboards/dashboard_widgets.dart';
import '../secretary_requests_page.dart';
import '../api_config.dart'; // ✅ ADDED

class SecretaryDashboard extends StatefulWidget {
  const SecretaryDashboard({super.key});

  @override
  State<SecretaryDashboard> createState() => _SecretaryDashboardState();
}

class _SecretaryDashboardState extends State<SecretaryDashboard> {
  int pendingCount = 0;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchPendingCount();
  }

  Future<void> fetchPendingCount() async {
    try {
      final response = await http.get(Uri.parse(ApiConfig.getPendingMeetings)); // ✅ CHANGED
      if (response.statusCode == 200) {
        List data = jsonDecode(response.body);
        setState(() {
          pendingCount = data.length;
          isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching count: $e");
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: fetchPendingCount,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Queue Management", 
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)
            ),
            const SizedBox(height: 15),

            isLoading 
              ? const LinearProgressIndicator() 
              : buildStatCard(
                  "Pending Requests", 
                  pendingCount.toString().padLeft(2, '0'), 
                  Icons.list_alt_rounded, 
                  Colors.orange, 
                  fullWidth: true
                ),

            const SizedBox(height: 15),

            buildActionCard(
              context,
              title: "Review Requests",
              subtitle: "Approve or handle Boss rejections",
              icon: Icons.rate_review_rounded,
              iconColor: Colors.orange,
              onTap: () async {
                await Navigator.push(
                  context, 
                  MaterialPageRoute(builder: (context) => SecretaryRequestsPage())
                );
                fetchPendingCount();
              },
            ),
            
            const SizedBox(height: 25),
            
            const Text(
              "System Status", 
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)
            ),
            const SizedBox(height: 10),
            _buildStatusTile("Server Connection", "Online", Icons.cloud_done, Colors.green),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusTile(String title, String status, IconData icon, Color color) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: color.withOpacity(0.1),
        child: Icon(icon, color: color, size: 20),
      ),
      title: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
      trailing: Text(status, style: TextStyle(color: color, fontWeight: FontWeight.bold)),
    );
  }
}