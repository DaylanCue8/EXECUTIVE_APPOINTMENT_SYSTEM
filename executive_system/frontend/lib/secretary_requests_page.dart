import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'api_config.dart';
import 'app_theme.dart';
import 'chat_page.dart';
import 'chat_list_page.dart';

class SecretaryRequestsPage extends StatefulWidget {
  final int userId;
  const SecretaryRequestsPage({super.key, required this.userId});

  @override
  State<SecretaryRequestsPage> createState() => _SecretaryRequestsPageState();
}

class _SecretaryRequestsPageState extends State<SecretaryRequestsPage> {
  // Tab 1 — new user requests
  List pendingRequests = [];

  // Tab 2 — boss rejected (needs action) + rescheduled (awaiting boss re-review)
  List rejectedByBoss = [];
  List rescheduledPending = [];

  // Tab 3 — boss schedule (confirmed only)
  List confirmedSchedule = [];

  bool isLoading = true;

  final Color _asanaTeal = const Color(0xFF14C6B1);
  final Color _bgLight   = const Color(0xFFF4F7F9);
  final Color _navy      = const Color(0xFF1D2939);
  final Color _gold      = const Color(0xFFC9A84C);

  @override
  void initState() {
    super.initState();
    refreshData();
  }

  Future<void> refreshData() async {
    setState(() => isLoading = true);
    await fetchAllData();
    setState(() => isLoading = false);
  }

  Future<void> fetchAllData() async {
    // ── /get_pending_meetings returns: pending | cancelled_by_boss | rescheduled ──
    try {
      final response =
          await http.get(Uri.parse(ApiConfig.getPendingMeetings));

      debugPrint('[Secretary] GET ${ApiConfig.getPendingMeetings}');
      debugPrint('[Secretary] status: ${response.statusCode}');
      debugPrint('[Secretary] body: ${response.body}');

      if (response.statusCode == 200) {
        final List all = jsonDecode(response.body);

        // Log every record so we can see what statuses come back
        for (var m in all) {
          debugPrint(
              '[Secretary] id=${m['id']}  status="${m['status']}"  title="${m['title']}"');
        }

        setState(() {
          pendingRequests  = all.where((m) => m['status'] == 'pending').toList();
          rejectedByBoss   = all.where((m) => m['status'] == 'cancelled_by_boss').toList();
          rescheduledPending = all.where((m) => m['status'] == 'rescheduled').toList();
        });

        debugPrint('[Secretary] pending=${pendingRequests.length}  '
            'rejectedByBoss=${rejectedByBoss.length}  '
            'rescheduled=${rescheduledPending.length}');
      }
    } catch (e) {
      debugPrint('[Secretary] Error fetching pending: $e');
    }

    // ── /get_confirmed_meetings returns: confirmed only ────────────────────────
    // (secretary Tab 3 shows confirmed meetings that boss has already approved)
    try {
      final response =
          await http.get(Uri.parse(ApiConfig.getConfirmedMeetings));
      if (response.statusCode == 200) {
        final List all = jsonDecode(response.body);
        setState(() {
          // Only show truly confirmed (boss-approved) meetings on the secretary's view
          confirmedSchedule =
              all.where((m) => m['status'] == 'confirmed').toList();
        });
      }
    } catch (e) {
      debugPrint('[Secretary] Error fetching confirmed: $e');
    }
  }

  Future<void> updateMeeting(int id, String status) async {
    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/update_status/$id'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'status': status}),
      );
      if (response.statusCode == 200) {
        await refreshData();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              status == 'secretary_approved'
                  ? 'Approved — sent to boss for final review ✅'
                  : status == 'confirmed'
                      ? 'Approved — sent to boss ✅'
                      : status == 'cancelled'
                          ? 'Request declined ❌'
                          : 'Marked as $status',
            ),
            backgroundColor: (status == 'secretary_approved' || status == 'confirmed')
                ? _asanaTeal
                : status == 'cancelled'
                    ? Colors.red
                    : Colors.blueGrey,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Action failed — check connection')),
      );
    }
  }

  // ── Priority helpers ──────────────────────────────────────────────────────
  Color _priorityColor(String p) {
    final s = p.toLowerCase();
    if (s == 'low') return const Color(0xFF10B981); // AppColors.success
    if (s == 'normal' || s == 'medium') return AppColors.normal;
    if (s == 'high' || s == 'hard') return const Color(0xFFEF4444); // AppColors.error
    return Colors.grey;
  }

  IconData _priorityIcon(String p) {
    switch (p.toLowerCase()) {
      case 'hard': return Icons.priority_high_rounded;
      case 'normal': return Icons.remove_rounded;
      case 'low':    return Icons.arrow_downward_rounded;
      default:       return Icons.help_outline;
    }
  }

  String _asString(dynamic value) {
    return value?.toString() ?? '';
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final int tab2Count = rejectedByBoss.length + rescheduledPending.length;

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: _bgLight,
        floatingActionButton: FloatingActionButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => ChatListPage(userId: widget.userId, pinnedRole: 'boss')),
            );
          },
          child: const Icon(Icons.chat_bubble),
        ),
        appBar: AppBar(
          title: const Text(
            'Secretary Portal',
            style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
          ),
          backgroundColor: Colors.white,
          elevation: 0,
          iconTheme: const IconThemeData(color: Colors.black87),
          bottom: TabBar(
            labelColor: _asanaTeal,
            unselectedLabelColor: Colors.grey,
            indicatorColor: _asanaTeal,
            tabs: [
              // Tab 1
              Tab(
                icon: const Icon(Icons.pending_actions),
                child: _tabLabel(
                  'Review Queue',
                  pendingRequests.length,
                  _asanaTeal,
                ),
              ),
              // Tab 2
              Tab(
                icon: const Icon(Icons.event_repeat),
                child: _tabLabel('Boss Rejected', tab2Count, Colors.orange),
              ),
              // Tab 3
              const Tab(
                icon: Icon(Icons.event_available),
                text: 'Boss Schedule',
              ),
            ],
          ),
        ),
        body: isLoading
            ? Center(child: CircularProgressIndicator(color: _asanaTeal))
            : TabBarView(
                children: [
                  _buildPendingList(),
                  _buildRejectedList(),
                  _buildConfirmedList(),
                ],
              ),
      ),
    );
  }

  Widget _tabLabel(String text, int count, Color badgeColor) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(text),
        if (count > 0) ...[
          const SizedBox(width: 5),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(
              color: badgeColor,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '$count',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ],
    );
  }

  // ── Tab 1: Review Queue (pending) ─────────────────────────────────────────
  Widget _buildPendingList() {
    return RefreshIndicator(
      onRefresh: refreshData,
      child: pendingRequests.isEmpty
          ? _emptyState(Icons.inbox_rounded, 'No pending requests')
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: pendingRequests.length,
              itemBuilder: (_, i) =>
                  _buildCard(pendingRequests[i], tabType: 'pending'),
            ),
    );
  }

  // ── Tab 2: Boss Rejected ──────────────────────────────────────────────────
  //  Section A — "Needs Rescheduling"   (cancelled_by_boss)  → orange, action button
  //  Section B — "Awaiting Boss Review" (rescheduled)        → blue, no action
  Widget _buildRejectedList() {
    return RefreshIndicator(
      onRefresh: refreshData,
      child: (rejectedByBoss.isEmpty && rescheduledPending.isEmpty)
          ? _emptyState(Icons.check_circle_outline, 'No rejected meetings')
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // ── Section A: Needs rescheduling ──────────────────────────
                if (rejectedByBoss.isNotEmpty) ...[
                  _sectionHeader(
                    icon: Icons.warning_amber_rounded,
                    color: Colors.orange,
                    label: 'Needs Rescheduling',
                    count: rejectedByBoss.length,
                  ),
                  const SizedBox(height: 8),
                  ...rejectedByBoss
                      .map((item) => _buildCard(item, tabType: 'rejected')),
                ],

                // ── Section B: Awaiting boss re-review ─────────────────────
                if (rescheduledPending.isNotEmpty) ...[
                  if (rejectedByBoss.isNotEmpty) const SizedBox(height: 16),
                  _sectionHeader(
                    icon: Icons.hourglass_top_rounded,
                    color: Colors.blue,
                    label: 'Awaiting Boss Re-review',
                    count: rescheduledPending.length,
                  ),
                  const SizedBox(height: 8),
                  ...rescheduledPending
                      .map((item) => _buildCard(item, tabType: 'rejected')),
                ],
              ],
            ),
    );
  }

  // ── Tab 3: Boss Schedule (confirmed) ─────────────────────────────────────
  Widget _buildConfirmedList() {
    return RefreshIndicator(
      onRefresh: refreshData,
      child: confirmedSchedule.isEmpty
          ? _emptyState(Icons.event_available, 'No confirmed meetings')
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: confirmedSchedule.length,
              itemBuilder: (_, i) =>
                  _buildCard(confirmedSchedule[i], tabType: 'confirmed'),
            ),
    );
  }

  // ── Shared card ───────────────────────────────────────────────────────────
  Widget _buildCard(dynamic item, {required String tabType}) {
    final String priority    = item['priority']     ?? '';
    final String meetingType = item['meeting_type'] ?? '';
    final String status      = item['status']       ?? '';

    Color accentColor;
    if (status == 'cancelled_by_boss') {
      accentColor = Colors.orange;
    } else if (status == 'rescheduled') {
      accentColor = Colors.blue;
    } else if (tabType == 'confirmed') {
      accentColor = Colors.blueGrey;
    } else {
      accentColor = _asanaTeal;
    }

    return Opacity(
      opacity: status == 'rescheduled' ? 0.75 : 1.0,
      child: Card(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        margin: const EdgeInsets.only(bottom: 12),
        child: InkWell(
          borderRadius: BorderRadius.circular(15),
          onTap: () => _showDetailSheet(item, tabType: tabType),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Header row ──────────────────────────────────────────────
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
                          Text(item['title'] ?? '',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 15)),
                          const SizedBox(height: 2),
                          Text(item['requester_name'] ?? '',
                              style: TextStyle(
                                  color: Colors.grey.shade500, fontSize: 12)),
                        ],
                      ),
                    ),
                    // Badge: "Awaiting Boss Review" for secretary_approved, "Sent to Boss" for rescheduled, else priority
                    if (status == 'secretary_approved')
                      _chip('Awaiting Boss Review', Icons.hourglass_top_rounded,
                          Colors.orange)
                    else if (status == 'rescheduled')
                      _chip('Sent to Boss', Icons.hourglass_top_rounded,
                          Colors.blue)
                    else if (priority.isNotEmpty)
                      _chip(priority, _priorityIcon(priority),
                          _priorityColor(priority)),
                  ],
                ),
                const SizedBox(height: 10),

                // ── Date / time / type ──────────────────────────────────────
                Row(children: [
                  Icon(Icons.schedule_rounded,
                      size: 13, color: Colors.grey.shade400),
                  const SizedBox(width: 4),
                  Text('${item['date']} · ${item['time']}',
                      style: TextStyle(
                          color: Colors.grey.shade500, fontSize: 12)),
                  if (meetingType.isNotEmpty) ...[
                    const SizedBox(width: 10),
                    Icon(Icons.category_rounded,
                        size: 13, color: Colors.grey.shade400),
                    const SizedBox(width: 4),
                    Text(meetingType,
                        style: TextStyle(
                            color: Colors.grey.shade500, fontSize: 12)),
                  ],
                ]),

                const SizedBox(height: 12),
                const Divider(height: 1),
                const SizedBox(height: 10),

                // ── Action area ─────────────────────────────────────────────
                _cardActions(item, tabType: tabType, status: status),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _cardActions(dynamic item,
      {required String tabType, required String status}) {
    if (tabType == 'pending') {
      // Reschedule + Approve
      return Row(children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => _showRescheduleSheet(item),
            icon: const Icon(Icons.event_repeat, size: 14),
            label:
                const Text('Reschedule', style: TextStyle(fontSize: 12)),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.blue,
              side: const BorderSide(color: Colors.blue),
              padding: const EdgeInsets.symmetric(vertical: 8),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () => updateMeeting(item['id'], 'secretary_approved'),
            icon: const Icon(Icons.check_circle, size: 14),
            label: const Text('Approve', style: TextStyle(fontSize: 12)),
            style: ElevatedButton.styleFrom(
              backgroundColor: _asanaTeal,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 8),
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ),
      ]);
    }

    if (tabType == 'rejected' && status == 'cancelled_by_boss') {
      // Reschedule & send to boss
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: () => _showRescheduleSheet(item),
          icon: const Icon(Icons.event_repeat, size: 14),
          label: const Text('Reschedule & Send to Boss',
              style: TextStyle(fontSize: 12)),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.orange,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 10),
            elevation: 0,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
      );
    }

    if (tabType == 'rejected' && status == 'rescheduled') {
      // Already sent — waiting
      return Row(children: [
        Icon(Icons.hourglass_top_rounded,
            size: 14, color: Colors.blue.shade300),
        const SizedBox(width: 6),
        Text('Waiting for boss to review...',
            style: TextStyle(fontSize: 12, color: Colors.blue.shade300)),
      ]);
    }

    // Tab 3: confirmed → Done button
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text('Tap to view details',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade400)),
        TextButton.icon(
          onPressed: () => updateMeeting(item['id'], 'completed'),
          icon: const Icon(Icons.done_all, size: 14, color: Colors.blueGrey),
          label: const Text('DONE',
              style: TextStyle(color: Colors.blueGrey, fontSize: 12)),
          style: TextButton.styleFrom(
            backgroundColor: Colors.blueGrey.withOpacity(0.1),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8)),
          ),
        ),
      ],
    );
  }

  // ── Detail bottom sheet ───────────────────────────────────────────────────
  void _showDetailSheet(dynamic item, {required String tabType}) {
    final String priority = item['priority'] ?? '';
    final String status   = item['status']   ?? '';

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
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2)),
              ),
              Expanded(
                child: ListView(
                  controller: sc,
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                  children: [
                    // Title + priority chip
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(item['title'] ?? '',
                              style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: _navy)),
                        ),
                        if (priority.isNotEmpty)
                          _chip(priority, _priorityIcon(priority),
                              _priorityColor(priority)),
                      ],
                    ),

                    // Status banners
                    if (status == 'cancelled_by_boss') ...[
                      const SizedBox(height: 10),
                      _banner(
                        icon: Icons.warning_amber_rounded,
                        color: Colors.orange,
                        text: 'Rejected by boss — reschedule to send back',
                      ),
                    ],
                    if (status == 'rescheduled') ...[
                      const SizedBox(height: 10),
                      _banner(
                        icon: Icons.hourglass_top_rounded,
                        color: Colors.blue,
                        text: 'Rescheduled — awaiting boss review',
                      ),
                    ],

                    const SizedBox(height: 20),
                    const Divider(),
                    const SizedBox(height: 12),

                    _detailRow(Icons.person_rounded, 'Requester',
                        item['requester_name'] ?? ''),
                    _detailRow(
                        Icons.category_rounded,
                        'Meeting Type',
                        (item['meeting_type'] ?? '').isEmpty
                            ? '—'
                            : item['meeting_type']),
                    _detailRow(Icons.calendar_today_rounded, 'Date & Time',
                        '${item['date']} at ${item['time']}'),
                    _detailRow(
                        Icons.timer_rounded,
                        'Duration',
                        (item['duration'] ?? '').isEmpty
                            ? '—'
                            : item['duration']),
                    _detailRow(
                        Icons.group_rounded,
                        'Attendees',
                        (item['attendees'] ?? '').isEmpty
                            ? 'None listed'
                            : item['attendees']),
                    _detailRow(
                        Icons.phone_rounded,
                        'Contact',
                        (item['contact'] ?? '').isEmpty
                            ? 'Not provided'
                            : item['contact']),
                    if (_asString(item['link']).isNotEmpty || _asString(item['resource_link']).isNotEmpty)
                      _detailRow(
                        Icons.link_rounded,
                        'Link',
                        _asString(item['link']).isNotEmpty
                            ? _asString(item['link'])
                            : _asString(item['resource_link']),
                      ),
                    if (_asString(item['attachment_link']).isNotEmpty)
                      _detailRow(
                        Icons.attach_file,
                        'Additional Link',
                        _asString(item['attachment_link']),
                      ),

                    const SizedBox(height: 4),
                    const Divider(),
                    const SizedBox(height: 8),
                    Text('Description',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey.shade600)),
                    const SizedBox(height: 6),
                    Text(
                      (item['description'] ?? '').isEmpty
                          ? 'No description provided.'
                          : item['description'],
                      style: const TextStyle(fontSize: 14, height: 1.5),
                    ),
                    const SizedBox(height: 28),

                    // ── Sheet action buttons ─────────────────────────────────
                    if (tabType == 'pending') ...[
                      Row(children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              Navigator.pop(ctx);
                              _showRescheduleSheet(item);
                            },
                            icon: const Icon(Icons.event_repeat, size: 18),
                            label: const Text('Reschedule'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.blue,
                              side: const BorderSide(color: Colors.blue),
                              padding:
                                  const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () {
                              Navigator.pop(ctx);
                              updateMeeting(item['id'], 'confirmed');
                            },
                            icon: const Icon(Icons.check_circle, size: 18),
                            label: const Text('Approve'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _asanaTeal,
                              foregroundColor: Colors.white,
                              padding:
                                  const EdgeInsets.symmetric(vertical: 14),
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                      ]),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Navigator.pop(ctx);
                            updateMeeting(item['id'], 'cancelled');
                          },
                          icon: const Icon(Icons.cancel_outlined, size: 18),
                          label: const Text('Decline Request'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red,
                            side: const BorderSide(color: Colors.red),
                            padding:
                                const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                    ] else if (tabType == 'rejected' &&
                        status == 'cancelled_by_boss') ...[
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pop(ctx);
                            _showRescheduleSheet(item);
                          },
                          icon: const Icon(Icons.event_repeat, size: 18),
                          label:
                              const Text('Reschedule & Send to Boss'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange,
                            foregroundColor: Colors.white,
                            padding:
                                const EdgeInsets.symmetric(vertical: 14),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                    ] else if (tabType == 'rejected' &&
                        status == 'rescheduled') ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.blue.shade200),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.hourglass_top_rounded,
                                color: Colors.blue, size: 18),
                            SizedBox(width: 8),
                            Text('Awaiting boss review...',
                                style: TextStyle(
                                    color: Colors.blue,
                                    fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    ] else if (tabType == 'confirmed') ...[
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pop(ctx);
                            updateMeeting(item['id'], 'completed');
                          },
                          icon: const Icon(Icons.done_all, size: 18),
                          label: const Text('Mark as Done'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blueGrey,
                            foregroundColor: Colors.white,
                            padding:
                                const EdgeInsets.symmetric(vertical: 14),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.pop(ctx);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ChatPage(
                                appointmentId: item['id'],
                                senderId: widget.userId,
                                appointmentTitle: item['title'] ?? 'Conversation',
                              ),
                            ),
                          );
                        },
                        icon: const Icon(Icons.chat_bubble_outline, size: 18),
                        label: const Text('Chat with Boss'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.blue,
                          side: const BorderSide(color: Colors.blue),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Reschedule sheet ──────────────────────────────────────────────────────
  void _showRescheduleSheet(dynamic item) {
    DateTime selectedDate = DateTime.parse(item['date']);
    String? selectedTime;

    const timeSlots = [
      '9:00 AM', '10:30 AM', '2:00 PM', '4:30 PM', '5:00 PM'
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
            left: 24, right: 24, top: 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Reschedule Meeting',
                  style: TextStyle(
                      fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(item['title'],
                  style: TextStyle(
                      color: Colors.grey.shade500, fontSize: 13)),
              const SizedBox(height: 12),
              _banner(
                icon: Icons.info_outline,
                color: Colors.blue,
                text:
                    'After rescheduling, the meeting will be sent back to the boss for review.',
              ),
              const SizedBox(height: 16),
              ListTile(
                tileColor: _bgLight,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                leading: Icon(Icons.calendar_month, color: _asanaTeal),
                title: Text(
                    'New Date: ${selectedDate.toIso8601String().split('T')[0]}'),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: ctx,
                    initialDate: selectedDate,
                    firstDate: DateTime.now(),
                    lastDate:
                        DateTime.now().add(const Duration(days: 90)),
                  );
                  if (picked != null) {
                    setModal(() => selectedDate = picked);
                  }
                },
              ),
              const SizedBox(height: 16),
              const Text('Select New Time Slot',
                  style: TextStyle(
                      fontSize: 13, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: timeSlots.map((slot) {
                  final bool sel = selectedTime == slot;
                  return GestureDetector(
                    onTap: () =>
                        setModal(() => selectedTime = sel ? null : slot),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 9),
                      decoration: BoxDecoration(
                        color: sel ? _navy : Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: sel ? _gold : Colors.grey.shade300,
                          width: sel ? 2 : 1,
                        ),
                      ),
                      child: Text(slot,
                          style: TextStyle(
                            color: sel ? Colors.white : Colors.black87,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          )),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _asanaTeal,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  onPressed: () async {
                    await _submitReschedule(
                      item['id'],
                      selectedDate.toIso8601String().split('T')[0],
                      selectedTime,
                    );
                    if (ctx.mounted) Navigator.pop(ctx);
                  },
                  child: const Text('RESCHEDULE & SEND TO BOSS',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submitReschedule(
      int id, String date, String? time) async {
    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/reschedule_meeting/$id'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'date': date,
          if (time != null) 'time': time,
        }),
      );
      if (response.statusCode == 200) {
        await refreshData();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Rescheduled — sent to boss 🗓️'),
            backgroundColor: _asanaTeal,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      debugPrint('Reschedule Error: $e');
    }
  }

  // ── Shared helpers ────────────────────────────────────────────────────────
  Widget _chip(String label, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 12),
          const SizedBox(width: 3),
          Text(label,
              style: TextStyle(
                  color: color,
                  fontSize: 11,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _banner(
      {required IconData icon,
      required Color color,
      required String text}) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text,
                style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w600,
                    fontSize: 12)),
          ),
        ],
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
            width: 100,
            child: Text(label,
                style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade500,
                    fontWeight: FontWeight.w500)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(
                    fontSize: 13,
                    color: Colors.black87,
                    fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader({
    required IconData icon,
    required Color color,
    required String label,
    required int count,
  }) {
    return Row(children: [
      Icon(icon, size: 16, color: color),
      const SizedBox(width: 6),
      Text(label,
          style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: color)),
      const SizedBox(width: 8),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text('$count',
            style: TextStyle(
                fontSize: 11,
                color: color,
                fontWeight: FontWeight.bold)),
      ),
    ]);
  }

  Widget _emptyState(IconData icon, String msg) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 48, color: Colors.grey.shade300),
          const SizedBox(height: 8),
          Text(msg, style: TextStyle(color: Colors.grey.shade400)),
        ],
      ),
    );
  }
}