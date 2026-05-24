import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:table_calendar/table_calendar.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import '../dashboards/dashboard_widgets.dart';
import '../secretary_requests_page.dart';
import '../api_config.dart';
import '../app_theme.dart';

class SecretaryDashboard extends StatefulWidget {
  final int userId;
  const SecretaryDashboard({super.key, required this.userId});

  @override
  State<SecretaryDashboard> createState() => _SecretaryDashboardState();
}

class _SecretaryDashboardState extends State<SecretaryDashboard> {
  int pendingCount = 0;
  bool isLoading = true;
  bool isCalendarLoading = true;
  bool _calendarExpanded = true;
  IO.Socket? socket;

  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();
  List<dynamic> confirmedMeetings = [];

  @override
  void initState() {
    super.initState();
    fetchPendingCount();
    fetchConfirmedMeetings();
    _connectSocket();
  }

  void _connectSocket() {
    socket = IO.io(
      '${ApiConfig.baseUrl.replaceFirst('http', 'ws')}',
      <String, dynamic>{
        'transports': ['websocket'],
        'autoConnect': true,
      },
    );
    socket!.onConnect((_) =>
        debugPrint('Secretary dashboard connected to socket'));
    socket!.on('meeting_status_updated', (data) {
      fetchPendingCount();
      fetchConfirmedMeetings();
    });
    socket!.on('meeting_rescheduled', (data) {
      fetchPendingCount();
      fetchConfirmedMeetings();
    });
    socket!.on('new_meeting_request', (data) => fetchPendingCount());
    socket!.onDisconnect((_) =>
        debugPrint('Secretary dashboard disconnected from socket'));
  }

  @override
  void dispose() {
    socket?.disconnect();
    super.dispose();
  }

  Future<void> fetchPendingCount() async {
    try {
      final response =
          await http.get(Uri.parse(ApiConfig.getPendingMeetings));
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

  Future<void> fetchConfirmedMeetings() async {
    setState(() => isCalendarLoading = true);
    try {
      final response =
          await http.get(Uri.parse(ApiConfig.getConfirmedMeetings));
      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body);
        setState(() {
          confirmedMeetings = data;
          isCalendarLoading = false;
        });
      } else {
        setState(() => isCalendarLoading = false);
      }
    } catch (e) {
      debugPrint("Error fetching confirmed meetings: $e");
      setState(() => isCalendarLoading = false);
    }
  }

  // ── Time sort helper ───────────────────────────────────────────────────────
  /// Parses "9:00 AM", "10:30 AM", "5:00 PM" into a DateTime for sorting.
  DateTime _parseTime(String timeStr) {
    try {
      final clean = timeStr.trim().toUpperCase();
      final parts = clean.split(' ');
      if (parts.length < 2) return DateTime.now();
      final timeParts = parts[0].split(':');
      int hour = int.parse(timeParts[0]);
      final int minute =
          timeParts.length > 1 ? int.parse(timeParts[1]) : 0;
      final bool isPm = parts[1] == 'PM';
      if (isPm && hour != 12) hour += 12;
      if (!isPm && hour == 12) hour = 0;
      final now = DateTime.now();
      return DateTime(now.year, now.month, now.day, hour, minute);
    } catch (_) {
      return DateTime.now();
    }
  }

  // ── Calendar helpers ───────────────────────────────────────────────────────
  Map<DateTime, List<dynamic>> _eventsForCalendar() {
    final Map<DateTime, List<dynamic>> events = {};
    for (var meeting in confirmedMeetings) {
      final dateString = meeting['date'];
      if (dateString == null) continue;
      final parsed = DateTime.tryParse(dateString);
      if (parsed == null) continue;
      final key = DateTime(parsed.year, parsed.month, parsed.day);
      events.putIfAbsent(key, () => []).add(meeting);
    }
    return events;
  }

  /// Returns meetings for the day sorted by time ascending.
  List<dynamic> _meetingsForDay(DateTime day) {
    final raw = _eventsForCalendar()[
            DateTime(day.year, day.month, day.day)] ??
        [];
    final sorted = List<dynamic>.from(raw);
    sorted.sort((a, b) => _parseTime(a['time'] ?? '')
        .compareTo(_parseTime(b['time'] ?? '')));
    return sorted;
  }

  Color _priorityColor(String priority) {
    final p = priority.toLowerCase();
    if (p == 'low') return AppColors.success;
    if (p == 'normal' || p == 'medium') return AppColors.normal;
    if (p == 'high' || p == 'hard') return AppColors.error;
    return Colors.grey;
  }

  // ── Meeting card ───────────────────────────────────────────────────────────
  Widget _buildCalendarMeetingCard(dynamic meeting) {
    final String title = meeting['title'] ?? 'Untitled';
    final String priority = meeting['priority'] ?? '';
    final String status = meeting['status'] ?? 'confirmed';
    final bool isRescheduled = status == 'rescheduled';
    final String time = meeting['time'] ?? '';
    final String meetingType = meeting['meeting_type'] ?? '';
    final String requester = meeting['requester_name'] ?? '';

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => _showMeetingDetailSheet(meeting),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: AppColors.secondary,
          borderRadius: BorderRadius.circular(14),
          border: Border(
            left: BorderSide(
              color: isRescheduled ? Colors.blue : AppColors.accent,
              width: 4,
            ),
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.border,
              blurRadius: 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                  if (isRescheduled)
                    _badge('Rescheduled', Colors.blue)
                  else if (priority.isNotEmpty)
                    _badge(priority, _priorityColor(priority)),
                ],
              ),
              if (requester.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  requester,
                  style: const TextStyle(fontSize: 12, color: AppColors.hint),
                ),
              ],
              const SizedBox(height: 10),
              Row(
                children: [
                  Icon(Icons.calendar_today, size: 14, color: AppColors.accent),
                  const SizedBox(width: 6),
                  Text(time, style: const TextStyle(fontSize: 13, color: AppColors.hint)),
                ],
              ),
              if (meetingType.isNotEmpty || (meeting['duration'] ?? '').toString().isNotEmpty) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    if (meetingType.isNotEmpty) ...[
                      Icon(Icons.meeting_room, size: 14, color: AppColors.hint),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(meetingType, style: const TextStyle(fontSize: 13, color: AppColors.hint)),
                      ),
                      const SizedBox(width: 16),
                    ],
                    if ((meeting['duration'] ?? '').toString().isNotEmpty) ...[
                      Icon(Icons.timelapse, size: 14, color: AppColors.hint),
                      const SizedBox(width: 6),
                      Text(
                        meeting['duration'],
                        style: const TextStyle(fontSize: 13, color: AppColors.hint),
                      ),
                    ],
                  ],
                ),
              ],
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

  Widget _badge(String label, Color color) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color),
      ),
      child: Text(
        label,
        style: TextStyle(
            color: color,
            fontSize: 11,
            fontWeight: FontWeight.w600),
      ),
    );
  }

  String _asString(dynamic value) {
    return value?.toString() ?? '';
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final selectedMeetings = _meetingsForDay(_selectedDay);
    final selectedDateLabel =
        '${_selectedDay.year}-${_selectedDay.month.toString().padLeft(2, '0')}-${_selectedDay.day.toString().padLeft(2, '0')}';

    return RefreshIndicator(
      onRefresh: () async {
        await fetchPendingCount();
        await fetchConfirmedMeetings();
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
                  // ── Queue section ──────────────────────────────────────
                  const Text(
                    "Queue Management",
                    style: TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold),
                  ),
              const SizedBox(height: 15),

              isLoading
                  ? const LinearProgressIndicator()
                  : buildStatCard(
                      "Pending Requests",
                      pendingCount.toString().padLeft(2, '0'),
                      Icons.list_alt_rounded,
                      Colors.orange,
                      fullWidth: true,
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
                    MaterialPageRoute(
                      builder: (context) => SecretaryRequestsPage(userId: widget.userId),
                    ),
                  );
                  fetchPendingCount();
                  fetchConfirmedMeetings();
                },
              ),

              const SizedBox(height: 30),

              // ── Calendar section ───────────────────────────────────
              const Text(
                "Meeting Calendar",
                style: TextStyle(
                    fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                "Tap a date to view scheduled meetings.",
                style: TextStyle(
                    fontSize: 12, color: Colors.grey.shade500),
              ),
              const SizedBox(height: 12),
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
                firstChild: isCalendarLoading
                    ? const LinearProgressIndicator()
                    : Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.04),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: TableCalendar(
                            firstDay: DateTime.now()
                                .subtract(const Duration(days: 365)),
                            lastDay: DateTime.now()
                                .add(const Duration(days: 365)),
                            focusedDay: _focusedDay,
                            calendarFormat: _calendarFormat,
                            selectedDayPredicate: (day) =>
                                isSameDay(_selectedDay, day),
                            eventLoader: _meetingsForDay,
                            onDaySelected: (selectedDay, focusedDay) {
                              setState(() {
                                _selectedDay = selectedDay;
                                _focusedDay = focusedDay;
                              });
                            },
                            onFormatChanged: (format) =>
                                setState(() => _calendarFormat = format),
                            headerStyle: const HeaderStyle(
                              formatButtonVisible: false,
                              titleCentered: true,
                              titleTextStyle: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            calendarStyle: CalendarStyle(
                              markerDecoration: BoxDecoration(
                                color: AppColors.accent,
                                shape: BoxShape.circle,
                              ),
                              selectedDecoration: BoxDecoration(
                                color: AppColors.primary,
                                shape: BoxShape.circle,
                              ),
                              todayDecoration: BoxDecoration(
                                color: AppColors.accent.withOpacity(0.4),
                                shape: BoxShape.circle,
                              ),
                              todayTextStyle: TextStyle(
                                color: AppColors.primary,
                                fontWeight: FontWeight.bold,
                              ),
                              weekendTextStyle: const TextStyle(
                                  color: AppColors.error),
                            ),
                          ),
                        ),
                      ),
                secondChild: const SizedBox(height: 0),
              ),

              const SizedBox(height: 20),

              // ── Meetings for selected day ───────────────────────────
Row(
  children: [
    Text(
      "Meetings for $selectedDateLabel",
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.bold,
      ),
    ),
    const SizedBox(width: 8),
    if (selectedMeetings.isNotEmpty)
      Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 8,
          vertical: 2,
        ),
        decoration: BoxDecoration(
          color: AppColors.accent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          '${selectedMeetings.length}',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
  ],
),

const SizedBox(height: 12),

if (selectedMeetings.isEmpty)
  Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(
      horizontal: 20,
      vertical: 28,
    ),
    decoration: BoxDecoration(
      color: Colors.grey.shade50,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(
        color: Colors.grey.shade200,
      ),
    ),
    child: Column(
      children: [
        Icon(
          Icons.event_available,
          size: 40,
          color: Colors.grey.shade300,
        ),
        const SizedBox(height: 12),
        Text(
          "No confirmed meetings on this day.\nThis date is fully available.",
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.grey.shade400,
            fontSize: 13,
          ),
        ),
      ],
    ),
  )
else
  ListView.builder(
    shrinkWrap: true,
    physics: const NeverScrollableScrollPhysics(),
    itemCount: selectedMeetings.length,
    itemBuilder: (_, index) =>
        _buildCalendarMeetingCard(selectedMeetings[index]),
  ),

const SizedBox(height: 32),
],
),
),
),
    );
}
}