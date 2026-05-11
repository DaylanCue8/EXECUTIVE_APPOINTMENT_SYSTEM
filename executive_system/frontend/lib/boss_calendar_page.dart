import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'api_config.dart';

class BossCalendarPage extends StatefulWidget {
  @override
  _BossCalendarPageState createState() => _BossCalendarPageState();
}

class _BossCalendarPageState extends State<BossCalendarPage> {
  List confirmedMeetings = [];
  bool isLoading = true;

  final Color _asanaTeal = const Color(0xFF14C6B1);
  final Color _navy = const Color(0xFF1D2939);
  final Color _gold = const Color(0xFFC9A84C);

  @override
  void initState() {
    super.initState();
    fetchConfirmed();
  }

  Future<void> fetchConfirmed() async {
    if (!mounted) return;
    setState(() => isLoading = true);
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
            isLoading = false;
          });
        }
      } else {
        if (mounted) setState(() => isLoading = false);
      }
    } catch (e) {
      debugPrint("[BossCalendar] Fetch Error: $e");
      if (mounted) setState(() => isLoading = false);
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
        await fetchConfirmed();
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
        await fetchConfirmed();
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
    switch (priority.toLowerCase()) {
      case 'urgent':
        return Colors.red;
      case 'normal':
        return Colors.blue;
      case 'low':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  IconData _priorityIcon(String priority) {
    switch (priority.toLowerCase()) {
      case 'urgent':
        return Icons.priority_high_rounded;
      case 'normal':
        return Icons.remove_rounded;
      case 'low':
        return Icons.arrow_downward_rounded;
      default:
        return Icons.help_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    final grouped = _groupMeetings();
    final dates = grouped.keys.toList()..sort();

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7F9),
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
              onRefresh: fetchConfirmed,
              child: dates.isEmpty
                  ? _buildEmptyState()
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: dates.length,
                      itemBuilder: (context, index) {
                        String date = dates[index];
                        List meetings = grouped[date]!;
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
                      },
                    ),
            ),
    );
  }

  Widget _buildMeetingCard(dynamic m) {
    final String priority = m['priority'] ?? '';
    final String meetingType = m['meeting_type'] ?? '';
    final String duration = m['duration'] ?? '';
    final String status = m['status'] ?? 'confirmed';

    // Rescheduled meetings get a blue left accent to stand out
    final bool isRescheduled = status == 'rescheduled';
    final Color accentColor = isRescheduled ? Colors.blue : _asanaTeal;

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
                  if (isRescheduled)
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
              if (isRescheduled)
                // Rescheduled → Approve or Reject
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
            color: Colors.white,
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
                  color: Colors.grey.shade300,
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
                              color: _navy,
                            ),
                          ),
                        ),
                        if (isRescheduled)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.blue.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(20),
                              border:
                                  Border.all(color: Colors.blue),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.event_repeat,
                                    color: Colors.blue, size: 14),
                                SizedBox(width: 4),
                                Text("Rescheduled",
                                    style: TextStyle(
                                      color: Colors.blue,
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

                    // Rescheduled info banner
                    if (isRescheduled) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(10),
                          border:
                              Border.all(color: Colors.blue.shade200),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.event_repeat,
                                color: Colors.blue, size: 18),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                "This meeting was rescheduled by the secretary. Please review and approve or reject.",
                                style: TextStyle(
                                  color: Colors.blue,
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
                    _detailRow(Icons.person_rounded, "Requested by",
                        m['requester_name'] ?? ''),
                    _detailRow(
                        Icons.category_rounded,
                        "Meeting Type",
                        (m['meeting_type'] ?? '').isEmpty
                            ? '—'
                            : m['meeting_type']),
                    _detailRow(Icons.calendar_today_rounded,
                        "Date & Time",
                        "${m['date']} at ${m['time']}"),
                    _detailRow(
                        Icons.timer_rounded,
                        "Duration",
                        (m['duration'] ?? '').isEmpty
                            ? '—'
                            : m['duration']),
                    _detailRow(
                        Icons.group_rounded,
                        "Attendees",
                        (m['attendees'] ?? '').isEmpty
                            ? 'None listed'
                            : m['attendees']),
                    _detailRow(
                        Icons.phone_rounded,
                        "Contact",
                        (m['contact'] ?? '').isEmpty
                            ? 'Not provided'
                            : m['contact']),
                    const SizedBox(height: 4),
                    const Divider(),
                    const SizedBox(height: 8),
                    Text(
                      "Description",
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      (m['description'] ?? '').isEmpty
                          ? 'No description provided.'
                          : m['description'],
                      style:
                          const TextStyle(fontSize: 14, height: 1.5),
                    ),
                    const SizedBox(height: 28),

                    // Rescheduled → Approve + Reject buttons
                    if (isRescheduled) ...[
                      Row(children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              Navigator.pop(context);
                              _confirmReject(m['id']);
                            },
                            icon: const Icon(Icons.cancel_outlined,
                                color: Colors.red),
                            label: const Text("Reject",
                                style: TextStyle(color: Colors.red)),
                            style: OutlinedButton.styleFrom(
                              side:
                                  const BorderSide(color: Colors.red),
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
                              backgroundColor: _asanaTeal,
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
                              color: Colors.red),
                          label: const Text(
                              "Reject & Send Back to Secretary",
                              style: TextStyle(color: Colors.red)),
                          style: OutlinedButton.styleFrom(
                            side:
                                const BorderSide(color: Colors.red),
                            padding: const EdgeInsets.symmetric(
                                vertical: 14),
                            shape: RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.circular(12)),
                          ),
                        ),
                      ),
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

  Widget _detailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: Colors.grey.shade500),
          const SizedBox(width: 12),
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade500,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                  fontSize: 13,
                  color: Colors.black87,
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