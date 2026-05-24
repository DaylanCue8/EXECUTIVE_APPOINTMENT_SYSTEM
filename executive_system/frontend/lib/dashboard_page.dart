import 'package:flutter/material.dart';
import 'app_theme.dart';
import 'dashboards/boss_dashboard.dart';
import 'dashboards/secretary_dashboard.dart';
import 'dashboards/requester_dashboard.dart';
import 'admin_page.dart';
import 'login_page.dart';
import 'notification_icon.dart'; // ✅ ADDED
import 'chat_list_page.dart';

class DashboardPage extends StatefulWidget {
  final String role;
  final String name;
  final int userId;

  DashboardPage({required this.role, required this.name, required this.userId});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final Color _primaryTeal = AppColors.accent;
  final Color _darkBg = AppColors.primary;

  bool get _isAdmin => widget.role.toLowerCase() == 'admin';

  @override
  Widget build(BuildContext context) {
    // Admin gets its own full-screen layout with bounded height
    if (_isAdmin) {
      return Scaffold(
        backgroundColor: const Color(0xFFF4F7F9),
        body: Column(
          children: [
            // Custom AppBar for admin (fixed height)
            Container(
              height: 120,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.primary, AppColors.primaryDark],
                ),
              ),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Hello, ${widget.name}",
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "ADMIN",
                            style: TextStyle(
                              color: _primaryTeal,
                              letterSpacing: 1.5,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          NotificationIcon(), // ✅ ADDED
                          IconButton(
                            onPressed: () => Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(builder: (_) => LoginPage()),
                            ),
                            icon: const Icon(Icons.logout, color: Colors.white),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // AdminPage fills the remaining screen space
            const Expanded(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: AdminPage(),
              ),
            ),
          ],
        ),
      );
    }

    // All other roles use the original CustomScrollView layout
    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          _buildSliverAppBar(),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
              child: _getDashboardByRole(),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final role = widget.role.toLowerCase();
          String pinned = 'secretary';
          if (role == 'secretary') pinned = 'boss';
          if (role == 'boss') pinned = 'secretary';

          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => ChatListPage(userId: widget.userId, pinnedRole: pinned)),
          );
          setState(() {});
        },
        backgroundColor: AppColors.accent,
        child: const Icon(Icons.chat_bubble),
      ),
    );
  }

  Widget _getDashboardByRole() {
    switch (widget.role.toLowerCase()) {
      case 'boss':
        return BossDashboard(userId: widget.userId);
      case 'secretary':
        return SecretaryDashboard(userId: widget.userId);
      case 'requester':
      default:
        return RequesterDashboard(userId: widget.userId);
    }
  }

  Widget _buildSliverAppBar() {
    return SliverAppBar(
      expandedHeight: 200.0,
      pinned: true,
      backgroundColor: Colors.transparent,
      elevation: 0,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
      ),
      flexibleSpace: ClipRRect(
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(32)),
        child: FlexibleSpaceBar(
          background: Container(
            padding: const EdgeInsets.only(left: 24, bottom: 24),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColors.primary, AppColors.primaryDark],
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.18),
                  blurRadius: 28,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Hello, ${widget.name}",
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  widget.role.toUpperCase(),
                  style: TextStyle(
                    color: _primaryTeal,
                    letterSpacing: 1.5,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        NotificationIcon(), // ✅ ADDED
        IconButton(
          onPressed: () => Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => LoginPage()),
          ),
          icon: const Icon(Icons.logout, color: Colors.white),
        ),
      ],
    );
  }
}