import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:table_calendar/table_calendar.dart';
import '../dashboards/dashboard_widgets.dart';
import '../request_meeting_page.dart';
import '../api_config.dart';

class RequesterDashboard extends StatefulWidget {
  final int userId;
  const RequesterDashboard({super.key, required this.userId});

  @override
  State<RequesterDashboard> createState() => _RequesterDashboardState();
}

class _RequesterDashboardState extends State<RequesterDashboard> {
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  int pendingCount = 0;
  int confirmedCount = 0;
  bool isLoading = true;

  final Color _asanaTeal = const Color(0xFF14C6B1);

  @override
  void initState() {
    super.initState();
    fetchMyMeetings();
  }

  Future<void> fetchMyMeetings() async {
    setState(() => isLoading = true);
    try {
      final response = await http.get(
        Uri.parse("${ApiConfig.baseUrl}/user_meetings/${widget.userId}"),
      );
      if (response.statusCode == 200) {
        List data = jsonDecode(response.body);
        setState(() {
          pendingCount = data.where((m) => m['status'] == 'pending').length;
          confirmedCount = data.where((m) => m['status'] == 'confirmed').length;
          isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching meetings: $e");
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Your Appointments",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 15),

          isLoading
              ? const LinearProgressIndicator()
              : Row(
                  children: [
                    Expanded(
                      child: buildStatCard(
                        "Pending",
                        pendingCount.toString().padLeft(2, '0'),
                        Icons.hourglass_empty,
                        Colors.orange,
                      ),
                    ),
                    const SizedBox(width: 15),
                    Expanded(
                      child: buildStatCard(
                        "Confirmed",
                        confirmedCount.toString().padLeft(2, '0'),
                        Icons.check_circle_outline,
                        Colors.green,
                      ),
                    ),
                  ],
                ),

          const SizedBox(height: 25),
          const Text(
            "Select a Date to Request",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),

          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: TableCalendar(
              firstDay: DateTime.now(),
              lastDay: DateTime.now().add(const Duration(days: 90)),
              focusedDay: _focusedDay,
              calendarFormat: _calendarFormat,
              selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
              onDaySelected: (selectedDay, focusedDay) {
                // Block Sundays
                if (selectedDay.weekday == DateTime.sunday) return;

                setState(() {
                  _selectedDay = selectedDay;
                  _focusedDay = focusedDay;
                });

                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => RequestMeetingPage(
                      userId: widget.userId,
                      selectedDate: selectedDay,
                    ),
                  ),
                ).then((_) => fetchMyMeetings()); // Refresh on return
              },
              onFormatChanged: (format) {
                setState(() => _calendarFormat = format);
              },
              calendarStyle: CalendarStyle(
                selectedDecoration: BoxDecoration(
                  color: _asanaTeal,
                  shape: BoxShape.circle,
                ),
                todayDecoration: BoxDecoration(
                  color: _asanaTeal.withOpacity(0.3),
                  shape: BoxShape.circle,
                ),
                todayTextStyle: TextStyle(
                  color: _asanaTeal,
                  fontWeight: FontWeight.bold,
                ),
                weekendTextStyle: const TextStyle(color: Colors.redAccent),
              ),
              headerStyle: const HeaderStyle(
                formatButtonVisible: false,
                titleCentered: true,
                titleTextStyle: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}