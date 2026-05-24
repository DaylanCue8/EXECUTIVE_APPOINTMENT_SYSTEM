import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'api_config.dart';
import 'app_theme.dart';
import 'chat_page.dart';
import 'chat_list_page.dart';

class BossCalendarPage extends StatefulWidget {
  final int userId;
  const BossCalendarPage({super.key, required this.userId});

  @override
  _BossCalendarPageState createState() => _BossCalendarPageState();
}

class _BossCalendarPageState extends State<BossCalendarPage> {
  List awaitingApprovalMeetings = [];
  List confirmedMeetings = [];
  bool isLoading = true;

  final Color _asanaTeal = const Color(0xFF14C6B1);
  final Color _navy = const Color(0xFF1D2939);
  final Color _gold = const Color(0xFFC9A84C);

  @override
  void initState() {
    super.initState();
    fetchBossData();
  }

  Future<void> fetchBossData() async {
    setState(() => isLoading = true);
    await Future.wait([
      fetchAwaitingApproval(),
      fetchConfirmed(),
    ]);
    if (mounted) setState(() => isLoading = false);
  }

  Future<void> fetchAwaitingApproval() async {
    try {
      final response = await http.get(Uri.parse(ApiConfig.getAwaitingBossApproval));
      debugPrint("[BossCalendar] awaiting approval status: ${response.statusCode}");
      debugPrint("[BossCalendar] awaiting approval body: ${response.body}");

      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body);
        if (mounted) {
          setState(() {
            awaitingApprovalMeetings = data;
          });
        }
      }
    } catch (e) {
      debugPrint("[BossCalendar] Awaiting approval fetch error: $e");
    }
  }

  Future<void> fetchConfirmed() async {
    try {
      final response =
          await http.get(Uri.parse(ApiConfig.getConfirmedMeetings));
      debugPrint("[BossCalendar] fetch status: ${response.statusCode}");
      debugPrint("[BossCalendar] body: ${response.body}");

      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body);
        if (mounted) {
          setState(() {
            confirmedMeetings = data;
          });
        }
      }
    } catch (e) {
      debugPrint("[BossCalendar] Fetch Error: $e");
    }
  }

  // ── REJECT: Sets status to cancelled_by_boss → goes back to Secretary ──
  Future<void> rejectMeeting(int id) async {
    debugPrint("[BossCalendar] Rejecting meeting ID=$id");
    try {
      final url = "${ApiConfig.baseUrl}/update_status/$id";
      debugPrint("[BossCalendar] POST → $url");

      final response = await http.post(
        Uri.parse(url),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"status": "cancelled_by_boss"}),
      );

      debugPrint(
          "[BossCalendar] reject response: ${response.statusCode} ${response.body}");

      if (response.statusCode == 200) {
        await fetchBossData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text(
                  "Meeting rejected — secretary has been notified 🔄"),
              backgroundColor: Colors.orange.shade700,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } else {
        final errorBody = jsonDecode(response.body);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  "Failed: ${errorBody['message'] ?? response.statusCode}"),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint("[BossCalendar] Reject Error: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Network error: $e"),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  // ── APPROVE rescheduled: Sets status to confirmed ──
  Future<void> approveMeeting(int id) async {
    debugPrint("[BossCalendar] Approving rescheduled meeting ID=$id");
    try {
      final url = "${ApiConfig.baseUrl}/update_status/$id";
      final response = await http.post(
        Uri.parse(url),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"status": "confirmed"}),
      );

      if (response.statusCode == 200) {
        await fetchBossData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text("Meeting approved ✅"),
              backgroundColor: _asanaTeal,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint("[BossCalendar] Approve Error: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Approve failed: $e"),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  // ── Group meetings by date ────────────────────────────────────
  Map<String, List<dynamic>> _groupMeetings() {
    Map<String, List<dynamic>> grouped = {};
    for (var m in confirmedMeetings) {
      String date = m['date'] ?? "Unknown Date";
      grouped.putIfAbsent(date, () => []).add(m);
    }
    return grouped;
  }

  // ── Priority helpers ──────────────────────────────────────────
  Color _priorityColor(String priority) {
    final p = priority.toLowerCase();
    if (p == 'low') return AppColors.success;
    if (p == 'normal' || p == 'medium') return AppColors.normal;
    if (p == 'high' || p == 'hard') return AppColors.error;
    return Colors.grey;
  }

  IconData _priorityIcon(String priority) {
    switch (priority.toLowerCase()) {
      case 'hard':
        return Icons.priority_high_rounded;
      case 'normal':
        return Icons.remove_rounded;
      case 'low':
        return Icons.arrow_downward_rounded;
      default:
        return Icons.help_outline;
    }
  }

  String _asString(dynamic value) {
    return value?.toString() ?? '';
  }

  @override
  Widget build(BuildContext context) {
    final grouped = _groupMeetings();
    final dates = grouped.keys.toList()..sort();

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7F9),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => ChatListPage(userId: widget.userId, pinnedRole: 'secretary')),
          );
        },
        child: const Icon(Icons.chat),
      ),
      appBar: AppBar(
        title: const Text(
          "Executive Schedule",
          style:
              TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
      ),
      body: isLoading
          ? Center(child: CircularProgressIndicator(color: _asanaTeal))
          : RefreshIndicator(
              onRefresh: fetchBossData,
              child: (awaitingApprovalMeetings.isEmpty && confirmedMeetings.isEmpty)
                  ? _buildEmptyState()
                  : ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        if (awaitingApprovalMeetings.isNotEmpty) ...[
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  "Awaiting Your Approval",
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: _navy,
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.orange.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  '${awaitingApprovalMeetings.length} pending',
                                  style: TextStyle(
                                    color: Colors.orange.shade800,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          ...awaitingApprovalMeetings
                              .map((m) => _buildMeetingCard(m))
                              .toList(),
                          const SizedBox(height: 24),
                        ],
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                "Executive Schedule",
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: _navy,
                                ),
                              ),
                            ),
                            if (confirmedMeetings.isNotEmpty)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: _asanaTeal.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  '${confirmedMeetings.length} confirmed',
                                  style: TextStyle(
                                    color: _asanaTeal,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        if (confirmedMeetings.isEmpty)
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
                                  "No confirmed meetings yet",
                                  style: TextStyle(
                                    color: Colors.grey.shade400,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          )
                        else ...dates.map((date) {
                          final meetings = grouped[date]!;
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                    vertical: 10, horizontal: 4),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 4,
                                      height: 18,
                                      decoration: BoxDecoration(
                                        color: _asanaTeal,
                                        borderRadius:
                                            BorderRadius.circular(2),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      date,
                                      style: TextStyle(
                                        color: _asanaTeal,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: _asanaTeal.withOpacity(0.1),
                                        borderRadius:
                                            BorderRadius.circular(10),
                                      ),
                                      child: Text(
                                        "${meetings.length} meeting${meetings.length > 1 ? 's' : ''}",
                                        style: TextStyle(
                                            color: _asanaTeal,
                                            fontSize: 11),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              ...meetings
                                  .map((m) => _buildMeetingCard(m))
                                  .toList(),
                              const SizedBox(height: 10),
                            ],
                          );
                        }).toList(),
                      ],
                    ),
            ),
    );
  }

  Widget _buildMeetingCard(dynamic m) {
    final String priority = m['priority'] ?? '';
    final String meetingType = m['meeting_type'] ?? '';
    final String duration = m['duration'] ?? '';
    final String status = m['status'] ?? 'confirmed';

    final bool isRescheduled = status == 'rescheduled';
    final bool needsApproval = status == 'secretary_approved' || isRescheduled;
    final Color accentColor = isRescheduled
        ? Colors.blue
        : status == 'secretary_approved'
            ? Colors.orange
            : _asanaTeal;

    return Card(
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(15),
        onTap: () => _showDetailSheet(m),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title + rescheduled badge OR priority badge
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
                          m['title'] ?? "No Title",
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          m['requester_name'] ?? '',
                          style: TextStyle(
                              color: Colors.grey.shade500, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  if (status == 'secretary_approved')
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.orange),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.hourglass_top_rounded,
                              color: Colors.orange, size: 12),
                          SizedBox(width: 3),
                          Text("Awaiting Approval",
                              style: TextStyle(
                                color: Colors.orange,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              )),
                        ],
                      ),
                    )
                  else if (isRescheduled)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.blue),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.event_repeat,
                              color: Colors.blue, size: 12),
                          SizedBox(width: 3),
                          Text("Rescheduled",
                              style: TextStyle(
                                color: Colors.blue,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              )),
                        ],
                      ),
                    )
                  else if (priority.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color:
                            _priorityColor(priority).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                        border:
                            Border.all(color: _priorityColor(priority)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(_priorityIcon(priority),
                              color: _priorityColor(priority), size: 12),
                          const SizedBox(width: 3),
                          Text(
                            priority,
                            style: TextStyle(
                              color: _priorityColor(priority),
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),

              // Time + duration
              Row(children: [
                Icon(Icons.schedule_rounded,
                    size: 14, color: Colors.grey.shade500),
                const SizedBox(width: 5),
                Text(
                  m['time'] ?? '',
                  style: TextStyle(
                      color: Colors.grey.shade600, fontSize: 13),
                ),
                if (duration.isNotEmpty) ...[
                  const SizedBox(width: 10),
                  Icon(Icons.timer_rounded,
                      size: 14, color: Colors.grey.shade500),
                  const SizedBox(width: 4),
                  Text(
                    duration,
                    style: TextStyle(
                        color: Colors.grey.shade600, fontSize: 13),
                  ),
                ],
              ]),

              if (meetingType.isNotEmpty) ...[
                const SizedBox(height: 4),
                Row(children: [
                  Icon(Icons.category_rounded,
                      size: 14, color: Colors.grey.shade500),
                  const SizedBox(width: 5),
                  Text(
                    meetingType,
                    style: TextStyle(
                        color: Colors.grey.shade600, fontSize: 13),
                  ),
                ]),
              ],

              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 10),

              // Action row
              if (needsApproval)
                Row(children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _confirmReject(m['id']),
                      icon: const Icon(Icons.cancel_outlined,
                          size: 15, color: Colors.red),
                      label: const Text("Reject",
                          style:
                              TextStyle(color: Colors.red, fontSize: 12)),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.red),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _confirmApprove(m['id']),
                      icon: const Icon(Icons.check_circle,
                          size: 15, color: Colors.white),
                      label: const Text("Approve",
                          style: TextStyle(
                              color: Colors.white, fontSize: 12)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _asanaTeal,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                ])
              else
                // Confirmed → only Reject
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "Tap card to view full details",
                      style: TextStyle(
                          fontSize: 11, color: Colors.grey.shade400),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => _confirmReject(m['id']),
                      icon: const Icon(Icons.cancel_outlined,
                          size: 15, color: Colors.red),
                      label: const Text("Reject",
                          style:
                              TextStyle(color: Colors.red, fontSize: 12)),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.red),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
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

  // ── Full detail sheet for boss ────────────────────────────────
  void _showDetailSheet(dynamic m) {
    final String priority = m['priority'] ?? '';
    final String status = m['status'] ?? 'confirmed';
    final bool isRescheduled = status == 'rescheduled';
    final String description = _asString(m['description']);
    final String meetingType = _asString(m['meeting_type']);
    final String duration = _asString(m['duration']);
    final String attendees = _asString(m['attendees']);
    final String contact = _asString(m['contact']);
    final String link = _asString(m['link']).isNotEmpty
        ? _asString(m['link'])
        : _asString(m['resource_link']);
    final String attachmentLink = _asString(m['attachment_link']);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.95,
        minChildSize: 0.4,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(
            color: AppColors.secondary,
            borderRadius:
                BorderRadius.vertical(top: Radius.circular(24)),
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
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            m['title'] ?? '',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                        if (status == 'secretary_approved')
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.warningLight,
                              borderRadius: BorderRadius.circular(20),
                              border:
                                  Border.all(color: AppColors.warning),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.hourglass_top_rounded,
                                    color: AppColors.warning, size: 14),
                                SizedBox(width: 4),
                                Text("Awaiting Approval",
                                    style: TextStyle(
                                      color: AppColors.warning,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    )),
                              ],
                            ),
                          )
                        else if (isRescheduled)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.accentLight,
                              borderRadius: BorderRadius.circular(20),
                              border:
                                  Border.all(color: AppColors.accent),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.event_repeat,
                                    color: AppColors.accent, size: 14),
                                SizedBox(width: 4),
                                Text("Rescheduled",
                                    style: TextStyle(
                                      color: AppColors.accent,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    )),
                              ],
                            ),
                          )
                        else if (priority.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: _priorityColor(priority)
                                  .withOpacity(0.12),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                  color: _priorityColor(priority)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(_priorityIcon(priority),
                                    color: _priorityColor(priority),
                                    size: 14),
                                const SizedBox(width: 4),
                                Text(
                                  priority,
                                  style: TextStyle(
                                    color: _priorityColor(priority),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),

                    // Awaiting approval info banner
                    if (status == 'secretary_approved') ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.warningLight,
                          borderRadius: BorderRadius.circular(10),
                          border:
                              Border.all(color: AppColors.warning),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.hourglass_top_rounded,
                                color: AppColors.warning, size: 18),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                "This request has been approved by the secretary and is waiting for your final review.",
                                style: TextStyle(
                                  color: AppColors.warning,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ] else if (isRescheduled) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.accentLight,
                          borderRadius: BorderRadius.circular(10),
                          border:
                              Border.all(color: AppColors.accent),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.event_repeat,
                                color: AppColors.accent, size: 18),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                "This meeting was rescheduled by the secretary. Please review and approve or reject.",
                                style: TextStyle(
                                  color: AppColors.accent,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 20),
                    const Divider(),
                    const SizedBox(height: 12),
                    _detailRow(Icons.calendar_today_rounded, "Date & Time", "${m['date']} at ${m['time']}"),
                    _detailRow(Icons.description, "Description", description.isNotEmpty ? description : "No description provided"),
                    _detailRow(Icons.meeting_room, "Meeting Type", meetingType.isNotEmpty ? meetingType : "Not specified"),
                    _detailRow(Icons.flag, "Priority Level", priority.isNotEmpty ? priority : "Not specified"),
                    _detailRow(Icons.timer_rounded, "Expected Duration", duration.isNotEmpty ? duration : "Not specified"),
                    _detailRow(Icons.group_rounded, "Other Attendees", attendees.isNotEmpty ? attendees : "None listed"),
                    _detailRow(Icons.phone_rounded, "Contact Number", contact.isNotEmpty ? contact : "Not provided"),
                    if (link.isNotEmpty) _detailRow(Icons.link, "Link", link),
                    if (attachmentLink.isNotEmpty) _detailRow(Icons.attach_file, "Additional Link", attachmentLink),
                    const SizedBox(height: 28),

                    // Awaiting approval → Approve + Reject buttons
                    if (status == 'secretary_approved' || isRescheduled) ...[
                      Row(children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              Navigator.pop(context);
                              _confirmReject(m['id']);
                            },
                            icon: const Icon(Icons.cancel_outlined,
                                color: AppColors.error),
                            label: const Text("Reject",
                                style: TextStyle(color: AppColors.error)),
                            style: OutlinedButton.styleFrom(
                              side:
                                  const BorderSide(color: AppColors.error),
                              padding: const EdgeInsets.symmetric(
                                  vertical: 14),
                              shape: RoundedRectangleBorder(
                                  borderRadius:
                                      BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () {
                              Navigator.pop(context);
                              _confirmApprove(m['id']);
                            },
                            icon: const Icon(Icons.check_circle,
                                color: Colors.white),
                            label: const Text("Approve",
                                style:
                                    TextStyle(color: Colors.white)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.accent,
                              padding: const EdgeInsets.symmetric(
                                  vertical: 14),
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                  borderRadius:
                                      BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                      ]),
                    ] else ...[
                      // Confirmed → Reject & Send Back
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Navigator.pop(context);
                            _confirmReject(m['id']);
                          },
                          icon: const Icon(Icons.cancel_outlined,
                              color: AppColors.error),
                          label: const Text(
                              "Reject & Send Back to Secretary",
                              style: TextStyle(color: AppColors.error)),
                          style: OutlinedButton.styleFrom(
                            side:
                                const BorderSide(color: AppColors.error),
                            padding: const EdgeInsets.symmetric(
                                vertical: 14),
                            shape: RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ChatPage(
                                appointmentId: m['id'],
                                senderId: widget.userId,
                                appointmentTitle: m['title'] ?? 'Conversation',
                              ),
                            ),
                          );
                        },
                        icon: const Icon(Icons.chat_bubble_outline,
                            size: 18, color: AppColors.accent),
                        label: const Text('Chat with Secretary',
                            style: TextStyle(color: AppColors.accent)),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: AppColors.accent),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
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
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppColors.hint),
          const SizedBox(width: 12),
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: AppColors.hint,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmReject(int id) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: const Text("Reject Meeting?",
            style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text(
            "This meeting will be sent back to the secretary for rescheduling."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("CANCEL",
                style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              rejectMeeting(id);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text("YES, REJECT",
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _confirmApprove(int id) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: const Text("Approve Rescheduled Meeting?",
            style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text(
            "This will confirm the new date and time for the meeting."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("CANCEL",
                style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              approveMeeting(id);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF14C6B1),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text("YES, APPROVE",
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return ListView(
      children: [
        const SizedBox(height: 200),
        Center(
          child: Column(
            children: [
              Icon(Icons.event_available,
                  size: 60, color: Colors.grey.shade300),
              const SizedBox(height: 12),
              Text(
                "No confirmed meetings.",
                style: TextStyle(color: Colors.grey.shade400),
              ),
            ],
          ),
        ),
      ],
    );
  }
}