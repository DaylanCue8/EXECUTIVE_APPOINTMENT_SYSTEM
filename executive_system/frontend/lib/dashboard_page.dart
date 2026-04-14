import 'package:flutter/material.dart';
import 'login_page.dart';
import 'request_meeting_page.dart';
import 'secretary_requests_page.dart';
import 'boss_calendar_page.dart';

class DashboardPage extends StatelessWidget {
  final String role;
  final String name;
  final int userId;

  DashboardPage({required this.role, required this.name, required this.userId});

  final Color _primaryTeal = const Color(0xFF14C6B1);
  final Color _darkBg = const Color(0xFF1D2939);
  final Color _bgLight = const Color(0xFFF4F7F9);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgLight,
      body: CustomScrollView(
        slivers: [
          // 1. DYNAMIC HEADER
          _buildSliverAppBar(context),

          // 2. ROLE-SPECIFIC CONTENT
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (role == 'requester') _buildRequesterDashboard(context),
                  if (role == 'secretary') _buildSecretaryDashboard(context),
                  if (role == 'boss') _buildBossDashboard(context),
                  
                  const SizedBox(height: 30),
                  const Text("Account Actions", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
                  const SizedBox(height: 10),
                  _actionCard(
                    context,
                    title: "Settings & Profile",
                    subtitle: "Manage security and notifications",
                    icon: Icons.person_outline,
                    iconColor: Colors.blueGrey,
                    onTap: () {},
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- REQUESTER VIEW: FOCUS ON STATUS & BOOKING ---
  Widget _buildRequesterDashboard(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Your Appointments", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 15),
        Row(
          children: [
            _statCard("Pending", "2", Icons.hourglass_empty, Colors.orange),
            const SizedBox(width: 15),
            _statCard("Confirmed", "1", Icons.check_circle_outline, Colors.green),
          ],
        ),
        const SizedBox(height: 25),
        _actionCard(
          context,
          title: "New Request",
          subtitle: "Schedule a time with the Executive",
          icon: Icons.add_box_rounded,
          iconColor: _primaryTeal,
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => RequestMeetingPage(userId: userId))),
        ),
      ],
    );
  }

  // --- SECRETARY VIEW: FOCUS ON WORKLOAD & QUEUE ---
  Widget _buildSecretaryDashboard(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Queue Management", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 15),
        _statCard("Total Pending Requests", "08", Icons.list_alt_rounded, Colors.orange, fullWidth: true),
        const SizedBox(height: 15),
        _actionCard(
          context,
          title: "Review Requests",
          subtitle: "Approve or decline incoming meetings",
          icon: Icons.rate_review_rounded,
          iconColor: Colors.orange,
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => SecretaryRequestsPage())),
        ),
      ],
    );
  }

  // --- BOSS VIEW: FOCUS ON DAILY SCHEDULE ---
  Widget _buildBossDashboard(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Today's Agenda", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 15),
        _statCard("Meetings Today", "03", Icons.calendar_today, _primaryTeal, fullWidth: true),
        const SizedBox(height: 15),
        _actionCard(
          context,
          title: "View Full Calendar",
          subtitle: "See all confirmed appointments",
          icon: Icons.event_note_rounded,
          iconColor: _primaryTeal,
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => BossCalendarPage())),
        ),
      ],
    );
  }

  // --- SHARED UI COMPONENTS ---

  Widget _buildSliverAppBar(BuildContext context) {
    return SliverAppBar(
      expandedHeight: 180.0,
      pinned: true,
      backgroundColor: _darkBg,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          padding: const EdgeInsets.only(left: 20, bottom: 20),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [_darkBg, const Color(0xFF101828)]),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Hello, $name", style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold)),
              const SizedBox(height: 5),
              Text(role.toUpperCase(), style: TextStyle(color: _primaryTeal, letterSpacing: 1.5, fontSize: 12, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ),
      actions: [
        IconButton(
          onPressed: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => LoginPage())),
          icon: const Icon(Icons.logout, color: Colors.white),
        )
      ],
    );
  }

  Widget _statCard(String label, String value, IconData icon, Color color, {bool fullWidth = false}) {
    Widget card = Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade200)),
      child: Row(
        children: [
          Icon(icon, color: color, size: 30),
          const SizedBox(width: 15),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13)),
            ],
          )
        ],
      ),
    );
    return fullWidth ? SizedBox(width: double.infinity, child: card) : Expanded(child: card);
  }

  Widget _actionCard(BuildContext context, {required String title, required String subtitle, required IconData icon, required Color iconColor, required VoidCallback onTap}) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(backgroundColor: iconColor.withOpacity(0.1), child: Icon(icon, color: iconColor)),
              const SizedBox(width: 15),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  Text(subtitle, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                ]),
              ),
              const Icon(Icons.chevron_right, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }
}