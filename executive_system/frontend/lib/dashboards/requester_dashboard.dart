import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:table_calendar/table_calendar.dart';
import 'package:socket_io_client/socket_io_client.dart' as socket_io;
import '../dashboards/dashboard_widgets.dart';
import '../chat_page.dart';
import '../chat_list_page.dart';
import '../request_meeting_page.dart';
import '../api_config.dart';
import '../app_theme.dart';

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
  bool _calendarExpanded = true;

  // Approved meetings list
  List<Map<String, dynamic>> confirmedMeetings = [];
  // Pending meetings list (for requester to manage their pending requests)
  List<Map<String, dynamic>> pendingMeetings = [];

  socket_io.Socket? socket;

  @override
  void initState() {
    super.initState();
    fetchMyMeetings();
    _connectSocket();
  }

  void _connectSocket() {
    socket = socket_io.io(
      ApiConfig.baseUrl.replaceFirst('http', 'ws'),
      <String, dynamic>{
        'transports': ['websocket'],
        'autoConnect': true,
      },
    );

    socket!.onConnect((_) {
      debugPrint('Requester dashboard connected to socket');
    });

    socket!.on('meeting_status_updated', (data) {
      debugPrint('Requester received meeting_status_updated: $data');
      fetchMyMeetings();
    });

    socket!.on('meeting_rescheduled', (data) {
      debugPrint('Requester received meeting_rescheduled: $data');
      fetchMyMeetings();
    });

    socket!.onDisconnect((_) {
      debugPrint('Requester dashboard disconnected from socket');
    });
  }

  @override
  void dispose() {
    socket?.disconnect();
    super.dispose();
  }

  Future<void> fetchMyMeetings() async {
    setState(() => isLoading = true);
    try {
      final response = await http.get(
        Uri.parse(ApiConfig.userMeetings(widget.userId)),
      );
      if (response.statusCode == 200) {
        List data = jsonDecode(response.body);
        setState(() {
          pendingCount = data.where((m) => m['status'] == 'pending').length;
          confirmedCount = data.where((m) => m['status'] == 'confirmed').length;

          // Extract pending and confirmed meetings for display
          pendingMeetings = data
            .where((m) => m['status'] == 'pending')
            .map<Map<String, dynamic>>((m) => Map<String, dynamic>.from(m))
            .toList();

          confirmedMeetings = data
            .where((m) => m['status'] == 'confirmed')
            .map<Map<String, dynamic>>((m) => Map<String, dynamic>.from(m))
            .toList();

          // Sort by date ascending
          pendingMeetings.sort((a, b) => (a['date'] ?? '').compareTo(b['date'] ?? ''));
          confirmedMeetings.sort((a, b) => (a['date'] ?? '').compareTo(b['date'] ?? ''));

          isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching meetings: $e");
      setState(() => isLoading = false);
    }
  }

  /// Returns a color based on meeting priority
  Color _priorityColor(String priority) {
    final p = priority.toLowerCase();
    if (p == 'low') return AppColors.success;
    if (p == 'normal' || p == 'medium') return AppColors.normal;
    if (p == 'high' || p == 'hard') return AppColors.error;
    return AppColors.border;
  }

  String _asString(dynamic value) {
    return value?.toString() ?? '';
  }

  Widget _buildApprovedMeetingCard(Map<String, dynamic> meeting) {
    final String priority = _asString(meeting['priority']);
    final String meetingType = _asString(meeting['meeting_type']);
    final String duration = _asString(meeting['duration']);
    final String attendees = _asString(meeting['attendees']);
    final String contact = _asString(meeting['contact']);
    final String date = _asString(meeting['date']);
    final String time = _asString(meeting['time']);
    final String resourceLink = _asString(meeting['link']).isNotEmpty
        ? _asString(meeting['link'])
        : _asString(meeting['resource_link']);
    final String attachmentLink = _asString(meeting['attachment_link']);
    final String cardLink = resourceLink.isNotEmpty ? resourceLink : attachmentLink;

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => _showDetailSheet(meeting),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: AppColors.secondary,
          borderRadius: BorderRadius.circular(14),
          border: Border(
            left: BorderSide(color: AppColors.accent, width: 4),
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
              // Title row with status badge
              Row(
                children: [
                  Expanded(
                    child: Text(
                      meeting['title'] ?? 'Untitled',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.successLight,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.success),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_circle, size: 12, color: AppColors.success),
                        const SizedBox(width: 4),
                        Text(
                          'Approved',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.success,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Date & Time
              Row(
                children: [
                  Icon(Icons.calendar_today, size: 14, color: AppColors.accent),
                  const SizedBox(width: 6),
                  Text(date, style: const TextStyle(fontSize: 13, color: AppColors.hint)),
                  const SizedBox(width: 16),
                  Icon(Icons.access_time, size: 14, color: AppColors.accent),
                  const SizedBox(width: 6),
                  Text(time, style: const TextStyle(fontSize: 13, color: AppColors.hint)),
                ],
              ),

              // Meeting type & duration (if available)
              if (meetingType.isNotEmpty || duration.isNotEmpty) ...[
                const SizedBox(height: 6),
                Row(
                  children: [
                    if (meetingType.isNotEmpty) ...[
                      Icon(Icons.meeting_room, size: 14, color: AppColors.hint),
                      const SizedBox(width: 6),
                      Text(meetingType, style: const TextStyle(fontSize: 13, color: AppColors.hint)),
                      const SizedBox(width: 16),
                    ],
                    if (duration.isNotEmpty) ...[
                      Icon(Icons.timelapse, size: 14, color: AppColors.hint),
                      const SizedBox(width: 6),
                      Text(duration, style: const TextStyle(fontSize: 13, color: AppColors.hint)),
                    ],
                  ],
                ),
              ],

              // Contact and attendees
              if (contact.isNotEmpty || attendees.isNotEmpty) ...[
                const SizedBox(height: 6),
                if (contact.isNotEmpty)
                  Row(
                    children: [
                      Icon(Icons.phone, size: 14, color: AppColors.hint),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(contact, style: const TextStyle(fontSize: 13, color: AppColors.hint), overflow: TextOverflow.ellipsis),
                      ),
                    ],
                  ),
                if (attendees.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(Icons.group, size: 14, color: AppColors.hint),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(attendees, style: const TextStyle(fontSize: 13, color: AppColors.hint), overflow: TextOverflow.ellipsis),
                      ),
                    ],
                  ),
                ],
              ],

              // Description (if available)
              if ((meeting['description'] ?? '').isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(meeting['description'], style: const TextStyle(fontSize: 13, color: Colors.black45), maxLines: 3, overflow: TextOverflow.ellipsis),
              ],

              // Link / image resources
              if (resourceLink.isNotEmpty || attachmentLink.isNotEmpty) ...[
                const SizedBox(height: 8),
                if (resourceLink.isNotEmpty) ...[
                  _buildResourceTile(resourceLink, 'Link'),
                  const SizedBox(height: 8),
                ],
                if (attachmentLink.isNotEmpty) ...[
                  _buildResourceTile(attachmentLink, 'Additional Link'),
                  const SizedBox(height: 8),
                ],
              ],

              // Priority badge (if available)
              if (priority.isNotEmpty) ...[
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(color: _priorityColor(priority).withAlpha((0.12 * 255).round()), borderRadius: BorderRadius.circular(12)),
                      child: Text('${priority[0].toUpperCase()}${priority.substring(1)} Priority', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _priorityColor(priority))),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _cancelMeeting(dynamic meetingId) async {
    try {
      final resp = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/update_status/$meetingId'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'status': 'cancelled'}),
      );
      if (!mounted) return;
      if (resp.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Meeting cancelled')),
        );
        fetchMyMeetings();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to cancel meeting')),
        );
      }
    } catch (e) {
      debugPrint('Error cancelling meeting: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error cancelling meeting')),
      );
    }
  }

  void _showDetailSheet(dynamic item) {
    final String priority = _asString(item['priority']);
    final String status = _asString(item['status']);
    final String date = _asString(item['date']);
    final String time = _asString(item['time']);
    final String description = _asString(item['description']);
    final String meetingType = _asString(item['meeting_type']);
    final String duration = _asString(item['duration']);
    final String attendees = _asString(item['attendees']);
    final String contact = _asString(item['contact']);
    final String resourceLink = _asString(item['link']).isNotEmpty ? _asString(item['link']) : _asString(item['resource_link']);
    final String attachmentLink = _asString(item['attachment_link']);

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
              Container(margin: const EdgeInsets.only(top: 12), width: 40, height: 4, decoration: BoxDecoration(color: AppColors.border.withAlpha((0.5 * 255).round()), borderRadius: BorderRadius.circular(2))),
              Expanded(
                child: ListView(
                  controller: sc,
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: Text(item['title'] ?? '', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.primary))),
                        if (priority.isNotEmpty) _chip(priority, Icons.flag, _priorityColor(priority)),
                      ],
                    ),
                    const SizedBox(height: 20),
                    const Divider(),
                    const SizedBox(height: 12),
                    _detailRow(Icons.calendar_today_rounded, 'Date & Time', '$date at $time'),
                    _detailRow(Icons.description, 'Description', description.isNotEmpty ? description : 'No description provided'),
                    _detailRow(Icons.meeting_room, 'Meeting Type', meetingType.isNotEmpty ? meetingType : 'Not specified'),
                    _detailRow(Icons.flag, 'Priority Level', priority.isNotEmpty ? priority : 'Not specified'),
                    _detailRow(Icons.timelapse, 'Expected Duration', duration.isNotEmpty ? duration : 'Not specified'),
                    _detailRow(Icons.group, 'Other Attendees', attendees.isNotEmpty ? attendees : 'None listed'),
                    _detailRow(Icons.phone, 'Contact Number', contact.isNotEmpty ? contact : 'Not provided'),
                    if (resourceLink.isNotEmpty) _detailRow(Icons.link, 'Link', resourceLink),
                    if (attachmentLink.isNotEmpty) _detailRow(Icons.attach_file, 'Additional Link', attachmentLink),
                    const SizedBox(height: 28),
                    // Cancel button for pending meetings
                    if (status.toLowerCase() == 'pending') ...[const SizedBox(height: 8), Row(children: [Expanded(child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: AppColors.error), onPressed: () async { Navigator.of(context).pop(); await _cancelMeeting(item['id']); }, child: const Text('Cancel Request')))]),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _chip(String label, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: color.withAlpha((0.1 * 255).round()), borderRadius: BorderRadius.circular(20), border: Border.all(color: color)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(icon, color: color, size: 12), const SizedBox(width: 3), Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600))]),
    );
  }

  Widget _detailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(icon, size: 18, color: AppColors.hint), const SizedBox(width: 12), SizedBox(width: 100, child: Text(label, style: TextStyle(fontSize: 13, color: AppColors.hint, fontWeight: FontWeight.w500))), Expanded(child: Text(value, style: const TextStyle(fontSize: 13, color: AppColors.primary, fontWeight: FontWeight.w600)))]),
    );
  }

  Widget _buildResourceTile(String resourceLink, [String label = 'Link']) {
    final bool isImage = resourceLink.toLowerCase().endsWith('.png') ||
        resourceLink.toLowerCase().endsWith('.jpg') ||
        resourceLink.toLowerCase().endsWith('.jpeg') ||
        resourceLink.toLowerCase().endsWith('.gif');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.hint,
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Icon(Icons.link, size: 14, color: AppColors.accent),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                resourceLink,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.accent,
                  decoration: TextDecoration.underline,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 2,
              ),
            ),
          ],
        ),
        if (isImage) ...[
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.network(
              resourceLink,
              height: 120,
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Container(
                height: 120,
                color: AppColors.border.withAlpha((0.25 * 255).round()),
                alignment: Alignment.center,
                child: const Text(
                  'Image failed to load',
                  style: TextStyle(fontSize: 12, color: Colors.black45),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        SingleChildScrollView(
          child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Your Meetings",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 15),

          isLoading
              ? const LinearProgressIndicator()
              : Row(
                  children: [
                    buildStatCard(
                      "Pending",
                      pendingCount.toString().padLeft(2, '0'),
                      Icons.hourglass_empty,
                      Colors.orange,
                      onTap: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => RequesterPendingPage(userId: widget.userId),
                          ),
                        );
                        fetchMyMeetings();
                      },
                    ),
                    const SizedBox(width: 15),
                    buildStatCard(
                      "Confirmed",
                      confirmedCount.toString().padLeft(2, '0'),
                      Icons.check_circle_outline,
                      Colors.green,
                    ),
                  ],
                ),

          const SizedBox(height: 25),
          const Text(
            "Select a Date to Request",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Meeting calendar',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              TextButton.icon(
                onPressed: () => setState(() => _calendarExpanded = !_calendarExpanded),
                icon: Icon(
                  _calendarExpanded ? Icons.expand_less : Icons.expand_more,
                  size: 18,
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
                  ).then((_) => fetchMyMeetings());
                },
                onFormatChanged: (format) {
                  setState(() => _calendarFormat = format);
                },
                calendarStyle: CalendarStyle(
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
                  weekendTextStyle:
                      const TextStyle(color: AppColors.error),
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

            // ── Approved Meetings Section ──────────────────────────────────
          const SizedBox(height: 30),
          Row(
            children: [
              const Text(
                "Approved Meetings",
                style:
                    TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(width: 10),
              if (!isLoading && confirmedMeetings.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF14C6B1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${confirmedMeetings.length}',
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

          if (isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: CircularProgressIndicator(),
              ),
            )
          else if (confirmedMeetings.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 30),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                children: [
                  Icon(Icons.event_available,
                      size: 40, color: Colors.grey.shade300),
                  const SizedBox(height: 10),
                  Text(
                    "No approved meetings yet",
                    style: TextStyle(
                      color: Colors.grey.shade400,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: confirmedMeetings.length,
              itemBuilder: (context, index) =>
                  _buildApprovedMeetingCard(confirmedMeetings[index]),
            ),

          const SizedBox(height: 20),
        ],
      ),
    ),   // closes SingleChildScrollView

      ],
    );
  }    // closes build()
} 

class RequesterPendingPage extends StatefulWidget {
  final int userId;
  const RequesterPendingPage({super.key, required this.userId});

  @override
  State<RequesterPendingPage> createState() => _RequesterPendingPageState();
}

class _RequesterPendingPageState extends State<RequesterPendingPage> {
  bool isLoading = true;
  List<Map<String, dynamic>> pendingMeetings = [];

  @override
  void initState() {
    super.initState();
    fetchPendingMeetings();
  }

  Future<void> fetchPendingMeetings() async {
    setState(() => isLoading = true);
    try {
      final response = await http.get(
        Uri.parse(ApiConfig.userMeetings(widget.userId)),
      );
      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body);
        setState(() {
          pendingMeetings = data
              .where((m) => m['status'] == 'pending')
              .map<Map<String, dynamic>>((m) => Map<String, dynamic>.from(m))
              .toList();
          pendingMeetings.sort((a, b) => (a['date'] ?? '').compareTo(b['date'] ?? ''));
          isLoading = false;
        });
      } else {
        setState(() => isLoading = false);
      }
    } catch (e) {
      debugPrint('Error fetching pending meetings: $e');
      setState(() => isLoading = false);
    }
  }

  Future<void> _cancelMeeting(int meetingId) async {
    try {
      final resp = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/update_status/$meetingId'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'status': 'cancelled'}),
      );
      if (!mounted) return;
      if (resp.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Meeting cancelled')),
        );
        fetchPendingMeetings();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to cancel meeting')),
        );
      }
    } catch (e) {
      debugPrint('Error cancelling meeting: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error cancelling meeting')),
      );
    }
  }

  String _asString(dynamic value) {
    return value?.toString() ?? '';
  }

  Color _priorityColor(String priority) {
    final p = priority.toLowerCase();
    if (p == 'low') return AppColors.success;
    if (p == 'normal' || p == 'medium') return AppColors.normal;
    if (p == 'high' || p == 'hard') return AppColors.error;
    return AppColors.border;
  }

  Widget _buildPendingMeetingCard(Map<String, dynamic> meeting) {
    final String date = _asString(meeting['date']);
    final String time = _asString(meeting['time']);
    final String priority = _asString(meeting['priority']);
    final String meetingType = _asString(meeting['meeting_type']);
    final String duration = _asString(meeting['duration']);
    final String link = _asString(meeting['link']).isNotEmpty
        ? _asString(meeting['link'])
        : _asString(meeting['resource_link']);

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => _showDetailSheet(meeting),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: AppColors.secondary,
          borderRadius: BorderRadius.circular(14),
          border: Border(
            left: BorderSide(color: AppColors.warning, width: 4),
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
                      meeting['title'] ?? 'Untitled',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.warningLight,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.warning),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.hourglass_empty, size: 12, color: AppColors.warning),
                        const SizedBox(width: 4),
                        Text(
                          'Pending',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.warning,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.calendar_today, size: 14, color: AppColors.accent),
                  const SizedBox(width: 6),
                  Text(date, style: const TextStyle(fontSize: 13, color: AppColors.hint)),
                  const SizedBox(width: 16),
                  Icon(Icons.access_time, size: 14, color: AppColors.accent),
                  const SizedBox(width: 6),
                  Text(time, style: const TextStyle(fontSize: 13, color: AppColors.hint)),
                ],
              ),
              if (meetingType.isNotEmpty || duration.isNotEmpty) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    if (meetingType.isNotEmpty) ...[
                      Icon(Icons.meeting_room, size: 14, color: AppColors.hint),
                      const SizedBox(width: 6),
                      Text(meetingType, style: const TextStyle(fontSize: 13, color: AppColors.hint)),
                      const SizedBox(width: 16),
                    ],
                    if (duration.isNotEmpty) ...[
                      Icon(Icons.timelapse, size: 14, color: AppColors.hint),
                      const SizedBox(width: 6),
                      Text(duration, style: const TextStyle(fontSize: 13, color: AppColors.hint)),
                    ],
                  ],
                ),
              ],
              if (link.isNotEmpty) ...[
                const SizedBox(height: 8),
                _buildResourceTile(link, 'Link'),
              ],
              if (priority.isNotEmpty) ...[
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        color: _priorityColor(priority).withAlpha((0.12 * 255).round()),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${priority[0].toUpperCase()}${priority.substring(1)} Priority',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: _priorityColor(priority),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
            ),
          ),
        ),
    );
  }



  void _showDetailSheet(Map<String, dynamic> meeting) {
    final String title = _asString(meeting['title']);
    final String description = _asString(meeting['description']);
    final String date = _asString(meeting['date']);
    final String time = _asString(meeting['time']);
    final String contact = _asString(meeting['contact']);
    final String attendees = _asString(meeting['attendees']);
    final String meetingType = _asString(meeting['meeting_type']);
    final String duration = _asString(meeting['duration']);
    final String priority = _asString(meeting['priority']);
    final String resourceLink = _asString(meeting['link']).isNotEmpty
        ? _asString(meeting['link'])
        : _asString(meeting['resource_link']);
    final String attachmentLink = _asString(meeting['attachment_link']);

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
              Container(margin: const EdgeInsets.only(top: 12), width: 40, height: 4, decoration: BoxDecoration(color: AppColors.border.withAlpha((0.5 * 255).round()), borderRadius: BorderRadius.circular(2))),
              Expanded(
                child: ListView(
                  controller: sc,
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                  children: [
                    Text(title, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.primary)),
                    const SizedBox(height: 20),
                    const Divider(),
                    const SizedBox(height: 12),
                    _detailRow(Icons.calendar_today, 'Date & Time', '$date at $time'),
                    _detailRow(Icons.description, 'Description', description.isNotEmpty ? description : 'No description provided'),
                    _detailRow(Icons.category, 'Meeting Type', meetingType.isNotEmpty ? meetingType : 'Not specified'),
                    _detailRow(Icons.flag, 'Priority Level', priority.isNotEmpty ? priority : 'Not specified'),
                    _detailRow(Icons.timelapse, 'Expected Duration', duration.isNotEmpty ? duration : 'Not specified'),
                    _detailRow(Icons.group, 'Other Attendees', attendees.isNotEmpty ? attendees : 'None listed'),
                    _detailRow(Icons.phone, 'Contact Number', contact.isNotEmpty ? contact : 'Not provided'),
                    if (resourceLink.isNotEmpty) _detailRow(Icons.link, 'Link', resourceLink),
                    if (attachmentLink.isNotEmpty) _detailRow(Icons.attach_file, 'Additional Link', attachmentLink),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.pop(ctx);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ChatPage(
                                appointmentId: meeting['id'],
                                senderId: widget.userId,
                                appointmentTitle: title,
                              ),
                            ),
                          );
                        },
                        icon: const Icon(Icons.chat_bubble_outline),
                        label: const Text('Message Secretary'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.accent,
                          side: BorderSide(color: AppColors.accent),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                    ElevatedButton(
                      onPressed: () async {
                        Navigator.of(context).pop();
                        await _cancelMeeting(meeting['id']);
                      },
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
                      child: const Text('Cancel Request'),
                    ),
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
          SizedBox(width: 100, child: Text(label, style: TextStyle(fontSize: 13, color: AppColors.hint, fontWeight: FontWeight.w600))),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 14, color: AppColors.primary))),
        ],
      ),
    );
  }

  Widget _buildResourceTile(String resourceLink, [String label = 'Link']) {
    final bool isImage = resourceLink.toLowerCase().endsWith('.png') ||
        resourceLink.toLowerCase().endsWith('.jpg') ||
        resourceLink.toLowerCase().endsWith('.jpeg') ||
        resourceLink.toLowerCase().endsWith('.gif');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.hint,
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Icon(Icons.link, size: 14, color: AppColors.accent),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                resourceLink,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.accent,
                  decoration: TextDecoration.underline,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 2,
              ),
            ),
          ],
        ),
        if (isImage) ...[
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.network(
              resourceLink,
              height: 120,
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Container(
                height: 120,
                color: AppColors.border.withAlpha((0.25 * 255).round()),
                alignment: Alignment.center,
                child: const Text(
                  'Image failed to load',
                  style: TextStyle(fontSize: 12, color: Colors.black45),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pending Requests'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 1,
      ),
      backgroundColor: const Color(0xFFF4F7F9),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : pendingMeetings.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(Icons.hourglass_empty, size: 40, color: Colors.grey),
                      SizedBox(height: 10),
                      Text('No pending requests', style: TextStyle(color: Colors.grey, fontSize: 14)),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: pendingMeetings.length,
                  itemBuilder: (context, index) => _buildPendingMeetingCard(pendingMeetings[index]),
                ),
    );
  }
}
