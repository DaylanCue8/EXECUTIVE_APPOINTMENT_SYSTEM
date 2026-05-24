import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:table_calendar/table_calendar.dart';
import 'dart:convert';
import '../app_theme.dart';
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
  bool isLoadingConfirmed = true;
  bool _calendarExpanded = true;
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _selectedDay = DateTime.now();
  DateTime _focusedDay = DateTime.now();
  List bossMeetings = [];

  @override
  void initState() {
    super.initState();
    fetchMeetingStats();
    fetchBossMeetings();
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

  Future<void> fetchBossMeetings() async {
    setState(() => isLoadingConfirmed = true);
    try {
      final response = await http.get(Uri.parse(ApiConfig.getConfirmedMeetings));
      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body);
        setState(() {
          bossMeetings = data;
          isLoadingConfirmed = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching boss meetings: $e");
      setState(() => isLoadingConfirmed = false);
    }
  }


  Future<void> _updateMeetingStatus(int id, String status) async {
    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/update_status/$id'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'status': status}),
      );
      if (response.statusCode == 200) {
        await fetchMeetingStats();
        await fetchBossMeetings();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(status == 'confirmed' ? 'Meeting approved ✅' : 'Meeting rejected ❌'),
            backgroundColor: status == 'confirmed' ? AppColors.accent : AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      debugPrint("Error updating boss meeting: $e");
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to update meeting status'), behavior: SnackBarBehavior.floating),
      );
    }
  }

  List<dynamic> get _selectedDayBossMeetings {
    final selectedKey = _selectedDay.toIso8601String().split('T')[0];
    return bossMeetings.where((meeting) => (meeting['date'] ?? '') == selectedKey).toList();
  }

  List<dynamic> _meetingsForDay(DateTime day) {
    final key = DateTime(day.year, day.month, day.day).toIso8601String().split('T')[0];
    return bossMeetings.where((meeting) => (meeting['date'] ?? '') == key).toList();
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
                  buildStatCard(
                    "Today",
                    todayCount.toString().padLeft(2, '0'),
                    Icons.calendar_today,
                    AppColors.accent,
                  ),
                  const SizedBox(width: 12),
                  buildStatCard(
                    "Total",
                    totalCount.toString().padLeft(2, '0'),
                    Icons.event_available,
                    Colors.deepPurple,
                  ),
                ],
              ),

        const SizedBox(height: 15),

        buildActionCard(
          context,
          title: "View Full Calendar",
          subtitle: "Approve or Decline your schedule",
          icon: Icons.event_note_rounded,
          iconColor: AppColors.accent,
          onTap: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => BossCalendarPage(userId: widget.userId)),
            );
            await fetchMeetingStats();
            await fetchBossMeetings();
          },
        ),
        const SizedBox(height: 25),

        const Text(
          "Meeting calendar",
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const SizedBox(),
            TextButton.icon(
              onPressed: () => setState(() => _calendarExpanded = !_calendarExpanded),
              icon: Icon(
                _calendarExpanded ? Icons.expand_less : Icons.expand_more,
                size: 18,
                color: AppColors.accent,
              ),
              label: Text(
                _calendarExpanded ? 'Hide calendar' : 'Show calendar',
                style: const TextStyle(fontSize: 12),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        AnimatedCrossFade(
          duration: const Duration(milliseconds: 250),
          crossFadeState: _calendarExpanded
              ? CrossFadeState.showFirst
              : CrossFadeState.showSecond,
          firstChild: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.secondary,
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: AppColors.border),
            ),
            child: TableCalendar(
              firstDay: DateTime.now(),
              lastDay: DateTime.now().add(const Duration(days: 90)),
              focusedDay: _focusedDay,
              selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
              calendarFormat: _calendarFormat,
              eventLoader: _meetingsForDay,
              onDaySelected: (selectedDay, focusedDay) {
                if (selectedDay.weekday == DateTime.sunday) return;
                setState(() {
                  _selectedDay = selectedDay;
                  _focusedDay = focusedDay;
                });
              },
              onFormatChanged: (format) {
                setState(() => _calendarFormat = format);
              },
              calendarStyle: CalendarStyle(
                markerDecoration: BoxDecoration(
                  color: AppColors.accent,
                  shape: BoxShape.circle,
                ),
                selectedDecoration: BoxDecoration(
                  color: AppColors.accent,
                  shape: BoxShape.circle,
                ),
                todayDecoration: BoxDecoration(
                  color: AppColors.accent.withAlpha((0.3 * 255).round()),
                  shape: BoxShape.circle,
                ),
                todayTextStyle: TextStyle(
                  color: AppColors.accent,
                  fontWeight: FontWeight.bold,
                ),
                weekendTextStyle: const TextStyle(color: AppColors.error),
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
          secondChild: const SizedBox(height: 0),
        ),
            const SizedBox(height: 20),
            const Text(
              "Selected day meetings",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
        const SizedBox(height: 10),
        if (isLoadingConfirmed)
          const Center(child: CircularProgressIndicator())
        else if (_selectedDayBossMeetings.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 20),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: const [
                Icon(Icons.event_busy, size: 40, color: Colors.grey),
                SizedBox(height: 8),
                Text(
                  "No meetings scheduled for this date",
                  style: TextStyle(color: Colors.grey, fontSize: 14),
                ),
              ],
            ),
          )
        else
          Column(
            children: _selectedDayBossMeetings
                .map((meeting) => _buildBossMeetingPreview(meeting))
                .toList(),
          ),
      ],
    );
  }

  Widget _buildBossMeetingPreview(dynamic meeting) {
    final String meetingType = (meeting['meeting_type'] ?? '').toString();
    final String duration = (meeting['duration'] ?? '').toString();
    final String status = (meeting['status'] ?? '').toString();
    final bool isRescheduled = status == 'rescheduled';
    final bool needsApproval = status == 'secretary_approved' || isRescheduled;
    final Color accentColor = isRescheduled
        ? Colors.blue
        : status == 'secretary_approved'
            ? Colors.orange
            : AppColors.accent;

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(15),
        onTap: () => _showMeetingDetailSheet(meeting),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 4,
                    height: 40,
                    decoration: BoxDecoration(
                      color: accentColor,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          meeting['title'] ?? 'No Title',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          meeting['requester_name'] ?? '',
                          style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  if (status == 'secretary_approved')
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.orange),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.hourglass_top_rounded, color: Colors.orange, size: 12),
                          SizedBox(width: 3),
                          Text(
                            "Awaiting Approval",
                            style: TextStyle(color: Colors.orange, fontSize: 11, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    )
                  else if (isRescheduled)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.blue),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.event_repeat, color: Colors.blue, size: 12),
                          SizedBox(width: 3),
                          Text(
                            "Rescheduled",
                            style: TextStyle(color: Colors.blue, fontSize: 11, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Row(children: [
                Icon(Icons.schedule_rounded, size: 14, color: Colors.grey.shade500),
                const SizedBox(width: 5),
                Text(
                  meeting['time'] ?? '',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                ),
                if (duration.isNotEmpty) ...[
                  const SizedBox(width: 10),
                  Icon(Icons.timer_rounded, size: 14, color: Colors.grey.shade500),
                  const SizedBox(width: 4),
                  Text(
                    duration,
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                  ),
                ],
              ]),
              if (meetingType.isNotEmpty) ...[
                const SizedBox(height: 4),
                Row(children: [
                  Icon(Icons.category_rounded, size: 14, color: Colors.grey.shade500),
                  const SizedBox(width: 5),
                  Text(
                    meetingType,
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                  ),
                ]),
              ],
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 10),
              Text(
                meeting['description'] ?? '',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, color: Colors.black54),
              ),
              const SizedBox(height: 12),
              if (needsApproval)
                Row(children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _updateMeetingStatus(meeting['id'], 'cancelled_by_boss'),
                      icon: const Icon(Icons.cancel_outlined, size: 15, color: Colors.red),
                      label: const Text("Reject", style: TextStyle(color: Colors.red, fontSize: 12)),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.red),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _updateMeetingStatus(meeting['id'], 'confirmed'),
                      icon: const Icon(Icons.check_circle, size: 15, color: Colors.white),
                      label: const Text("Approve", style: TextStyle(color: Colors.white, fontSize: 12)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accent,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                ])
              else
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "Tap card to view full details",
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade400),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => _updateMeetingStatus(meeting['id'], 'cancelled_by_boss'),
                      icon: const Icon(Icons.cancel_outlined, size: 15, color: Colors.red),
                      label: const Text("Reject", style: TextStyle(color: Colors.red, fontSize: 12)),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.red),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _showMeetingDetailSheet(dynamic meeting) {
    final String title = meeting['title'] ?? 'Untitled meeting';
    final String description = (meeting['description'] ?? '').toString();
    final String meetingType = (meeting['meeting_type'] ?? '').toString();
    final String priority = (meeting['priority'] ?? '').toString();
    final String duration = (meeting['duration'] ?? '').toString();
    final String attendees = (meeting['attendees'] ?? meeting['other_attendees'] ?? '').toString();
    final String contact = (meeting['contact'] ?? meeting['contact_number'] ?? '').toString();
    final String link = _asString(meeting['link'] ?? meeting['resource_link'] ?? '');
    final String date = (meeting['date'] ?? '').toString();
    final String time = (meeting['time'] ?? '').toString();
    final String dateTime = date.isNotEmpty && time.isNotEmpty ? '$date at $time' : date.isNotEmpty ? date : time;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        maxChildSize: 0.95,
        minChildSize: 0.4,
        builder: (ctx, sc) => Container(
          decoration: const BoxDecoration(
            color: AppColors.secondary,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border.withAlpha((0.5 * 255).round()),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Expanded(
                child: ListView(
                  controller: sc,
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                  children: [
                    Text(title, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.primary)),
                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 12),
                    _detailRow(Icons.calendar_today, 'Date & Time', dateTime.isNotEmpty ? dateTime : 'Not scheduled'),
                    _detailRow(Icons.description, 'Description', description.isNotEmpty ? description : 'No description provided'),
                    _detailRow(Icons.meeting_room, 'Meeting Type', meetingType.isNotEmpty ? meetingType : 'Not specified'),
                    _detailRow(Icons.flag, 'Priority Level', priority.isNotEmpty ? priority : 'Not specified'),
                    _detailRow(Icons.timelapse, 'Expected Duration', duration.isNotEmpty ? duration : 'Not specified'),
                    _detailRow(Icons.group, 'Other Attendees', attendees.isNotEmpty ? attendees : 'None listed'),
                    _detailRow(Icons.phone, 'Contact Number', contact.isNotEmpty ? contact : 'Not provided'),
                    if (link.isNotEmpty) _detailRow(Icons.link, 'Link', link),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _detailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppColors.hint),
          const SizedBox(width: 12),
          SizedBox(
            width: 120,
            child: Text(label, style: TextStyle(fontSize: 13, color: AppColors.hint, fontWeight: FontWeight.w600)),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontSize: 13, color: AppColors.primary, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  String _asString(dynamic value) {
    return value?.toString() ?? '';
  }
}