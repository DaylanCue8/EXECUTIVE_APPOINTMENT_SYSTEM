import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../boss_calendar_page.dart';
import '../api_config.dart';
import '../dashboards/dashboard_widgets.dart';

class BossDashboard extends StatefulWidget {
  final int userId;
  const BossDashboard({required this.userId});

  @override
  State<BossDashboard> createState() => _BossDashboardState();
}

class _BossDashboardState extends State<BossDashboard> {
  int todayCount = 0;
  int totalCount = 0;
  bool isLoading = true;

  final Color _asanaTeal = const Color(0xFF14C6B1);

  @override
  void initState() {
    super.initState();
    fetchMeetingStats();
  }

  Future<void> fetchMeetingStats() async {
    setState(() => isLoading = true);
    try {
      final response = await http.get(Uri.parse(ApiConfig.getConfirmedMeetings));
      if (response.statusCode == 200) {
        List data = jsonDecode(response.body);

        String today = DateTime.now().toIso8601String().split('T')[0];
        int todayMeetings = data.where((m) => m['date'] == today).length;

        setState(() {
          todayCount = todayMeetings;
          totalCount = data.length;
          isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching boss stats: $e");
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Today's Agenda",
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 15),

        isLoading
            ? const LinearProgressIndicator()
            : Row(
                children: [
                  Expanded(
                    child: buildStatCard(
                      "Today",
                      todayCount.toString().padLeft(2, '0'),
                      Icons.calendar_today,
                      _asanaTeal,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: buildStatCard(
                      "Total",
                      totalCount.toString().padLeft(2, '0'),
                      Icons.event_available,
                      Colors.deepPurple,
                    ),
                  ),
                ],
              ),

        const SizedBox(height: 15),

        buildActionCard(
          context,
          title: "View Full Calendar",
          subtitle: "Approve or Decline your schedule",
          icon: Icons.event_note_rounded,
          iconColor: _asanaTeal,
          onTap: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => BossCalendarPage()),
            );
            fetchMeetingStats();
          },
        ),
      ],
    );
  }
}