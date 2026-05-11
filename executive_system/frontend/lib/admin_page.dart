import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'api_config.dart';

class AdminPage extends StatefulWidget {
  const AdminPage({super.key});

  @override
  State<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage> {
  List users = [];
  List appointments = [];
  bool isLoading = true;

  final Color _asanaTeal = const Color(0xFF14C6B1);
  final Color _bgLight = const Color(0xFFF4F7F9);
  final Color _navy = const Color(0xFF1D2939);

  @override
  void initState() {
    super.initState();
    refreshData();
  }

  Future<void> refreshData() async {
    setState(() => isLoading = true);
    await fetchUsers();
    await fetchAppointments();
    setState(() => isLoading = false);
  }

  Future<void> fetchUsers() async {
    try {
      final response = await http.get(Uri.parse("${ApiConfig.baseUrl}/admin/users"));
      if (response.statusCode == 200) {
        setState(() => users = jsonDecode(response.body));
      }
    } catch (e) {
      debugPrint("Error fetching users: $e");
    }
  }

  Future<void> fetchAppointments() async {
    try {
      final response = await http.get(Uri.parse("${ApiConfig.baseUrl}/admin/all_appointments"));
      if (response.statusCode == 200) {
        setState(() => appointments = jsonDecode(response.body));
      }
    } catch (e) {
      debugPrint("Error fetching appointments: $e");
    }
  }

  Future<void> updateRole(int userId, String newRole) async {
    try {
      await http.post(
        Uri.parse("${ApiConfig.baseUrl}/admin/update_role/$userId"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"role": newRole}),
      );
      refreshData();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Role updated to $newRole"), backgroundColor: _asanaTeal),
      );
    } catch (e) {
      debugPrint("Error updating role: $e");
    }
  }

  Future<void> toggleActive(int userId, bool currentStatus) async {
    final endpoint = currentStatus ? 'deactivate_user' : 'reactivate_user';
    try {
      await http.post(
        Uri.parse("${ApiConfig.baseUrl}/admin/$endpoint/$userId"),
        headers: {"Content-Type": "application/json"},
      );
      refreshData();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(currentStatus ? "User deactivated" : "User reactivated"),
          backgroundColor: currentStatus ? Colors.orange : _asanaTeal,
        ),
      );
    } catch (e) {
      debugPrint("Error toggling user: $e");
    }
  }

  Future<void> deleteUser(int userId) async {
    try {
      await http.delete(Uri.parse("${ApiConfig.baseUrl}/admin/delete_user/$userId"));
      refreshData();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("User deleted"), backgroundColor: Colors.red),
      );
    } catch (e) {
      debugPrint("Error deleting user: $e");
    }
  }

  // ── Create User Dialog ────────────────────────────────────────
  void _showCreateUserDialog() {
    final usernameCtrl = TextEditingController();
    final passwordCtrl = TextEditingController();
    final fullNameCtrl = TextEditingController();
    String selectedRole = 'requester';
    bool obscure = true;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(Icons.person_add_rounded, color: _asanaTeal),
              const SizedBox(width: 8),
              Text("Create New User",
                  style: TextStyle(color: _navy, fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: fullNameCtrl,
                  decoration: InputDecoration(
                    labelText: "Full Name",
                    prefixIcon: const Icon(Icons.badge_outlined),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: usernameCtrl,
                  decoration: InputDecoration(
                    labelText: "Username",
                    prefixIcon: const Icon(Icons.person_outline),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: passwordCtrl,
                  obscureText: obscure,
                  decoration: InputDecoration(
                    labelText: "Password",
                    prefixIcon: const Icon(Icons.lock_outline),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    suffixIcon: IconButton(
                      icon: Icon(obscure ? Icons.visibility_off : Icons.visibility),
                      onPressed: () => setDialogState(() => obscure = !obscure),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: selectedRole,
                  decoration: InputDecoration(
                    labelText: "Role",
                    prefixIcon: const Icon(Icons.admin_panel_settings_outlined),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  items: ['admin', 'boss', 'secretary', 'requester']
                      .map((r) => DropdownMenuItem(
                            value: r,
                            child: Row(
                              children: [
                                Icon(_roleIcon(r), color: _roleColor(r), size: 16),
                                const SizedBox(width: 8),
                                Text(r[0].toUpperCase() + r.substring(1)),
                              ],
                            ),
                          ))
                      .toList(),
                  onChanged: (val) => setDialogState(() => selectedRole = val!),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _asanaTeal,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () async {
                if (fullNameCtrl.text.trim().isEmpty ||
                    usernameCtrl.text.trim().isEmpty ||
                    passwordCtrl.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Please fill in all fields")),
                  );
                  return;
                }
                try {
                  final response = await http.post(
                    Uri.parse("${ApiConfig.baseUrl}/admin/create_user"),
                    headers: {"Content-Type": "application/json"},
                    body: jsonEncode({
                      "username": usernameCtrl.text.trim(),
                      "password": passwordCtrl.text.trim(),
                      "full_name": fullNameCtrl.text.trim(),
                      "role": selectedRole,
                    }),
                  );
                  Navigator.pop(context);
                  if (response.statusCode == 201) {
                    refreshData();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text("User created successfully!"),
                        backgroundColor: _asanaTeal,
                      ),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("Username already exists"),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                } catch (e) {
                  debugPrint("Create user error: $e");
                }
              },
              child: const Text("Create", style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  // ── Change Role Dialog ────────────────────────────────────────
  void _showRoleDialog(int userId, String currentRole) {
    String selectedRole = currentRole;
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text("Change Role", style: TextStyle(fontWeight: FontWeight.bold)),
          content: DropdownButtonFormField<String>(
            value: selectedRole,
            decoration: InputDecoration(
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            ),
            items: ['admin', 'boss', 'secretary', 'requester']
                .map((r) => DropdownMenuItem(
                      value: r,
                      child: Row(
                        children: [
                          Icon(_roleIcon(r), color: _roleColor(r), size: 16),
                          const SizedBox(width: 8),
                          Text(r[0].toUpperCase() + r.substring(1)),
                        ],
                      ),
                    ))
                .toList(),
            onChanged: (val) => setDialogState(() => selectedRole = val!),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _asanaTeal,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () {
                Navigator.pop(context);
                updateRole(userId, selectedRole);
              },
              child: const Text("Save", style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  // ── Confirm Delete Dialog ─────────────────────────────────────
  void _confirmDelete(int userId, String name) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red),
            SizedBox(width: 8),
            Text("Delete User?", style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text("Are you sure you want to permanently delete \"$name\"? This cannot be undone."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              Navigator.pop(context);
              deleteUser(userId);
            },
            child: const Text("DELETE", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────
  Color _roleColor(String role) {
    switch (role) {
      case 'admin':     return Colors.purple;
      case 'boss':      return Colors.indigo;
      case 'secretary': return Colors.teal;
      case 'requester': return Colors.blue;
      default:          return Colors.grey;
    }
  }

  IconData _roleIcon(String role) {
    switch (role) {
      case 'admin':     return Icons.admin_panel_settings_rounded;
      case 'boss':      return Icons.business_center_rounded;
      case 'secretary': return Icons.support_agent_rounded;
      case 'requester': return Icons.person_rounded;
      default:          return Icons.person_outline;
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'confirmed':            return Colors.green;
      case 'pending':              return Colors.orange;
      case 'cancelled_by_boss':    return Colors.red;
      case 'rejected_by_secretary':return Colors.red;
      case 'completed':            return Colors.blueGrey;
      case 'rescheduled':          return Colors.blue;
      default:                     return Colors.grey;
    }
  }

  // ── BUILD ─────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          // Summary cards
          Padding(
            padding: const EdgeInsets.fromLTRB(0, 8, 0, 0),
            child: Row(
              children: [
                _summaryCard("Total Users", users.length.toString(), Icons.people_rounded, Colors.indigo),
                const SizedBox(width: 12),
                _summaryCard("Appointments", appointments.length.toString(), Icons.calendar_month_rounded, _asanaTeal),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Tab bar
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: TabBar(
              labelColor: _asanaTeal,
              unselectedLabelColor: Colors.grey,
              indicatorColor: _asanaTeal,
              indicatorSize: TabBarIndicatorSize.tab,
              tabs: const [
                Tab(icon: Icon(Icons.people_rounded), text: "Users"),
                Tab(icon: Icon(Icons.calendar_month_rounded), text: "Appointments"),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Tab content
          Expanded(
            child: isLoading
                ? Center(child: CircularProgressIndicator(color: _asanaTeal))
                : TabBarView(
                    children: [
                      // ── USERS TAB ──────────────────────────────
                      RefreshIndicator(
                        onRefresh: refreshData,
                        child: users.isEmpty
                            ? const Center(child: Text("No users found"))
                            : ListView.builder(
                                padding: const EdgeInsets.only(bottom: 80),
                                itemCount: users.length,
                                itemBuilder: (context, index) {
                                  final user = users[index];
                                  final bool isActive = user['is_active'] ?? true;
                                  final String role = user['role'] ?? 'requester';

                                  return Card(
                                    shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(14)),
                                    margin: const EdgeInsets.only(bottom: 10),
                                    color: isActive ? Colors.white : Colors.grey.shade100,
                                    child: Padding(
                                      padding: const EdgeInsets.all(14),
                                      child: Row(
                                        children: [
                                          // Avatar
                                          CircleAvatar(
                                            backgroundColor: _roleColor(role).withOpacity(0.15),
                                            child: Text(
                                              (user['full_name'] ?? 'U')[0].toUpperCase(),
                                              style: TextStyle(
                                                  color: _roleColor(role),
                                                  fontWeight: FontWeight.bold),
                                            ),
                                          ),
                                          const SizedBox(width: 12),

                                          // Info
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  user['full_name'] ?? '',
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 14,
                                                    color: isActive ? Colors.black87 : Colors.grey,
                                                  ),
                                                ),
                                                const SizedBox(height: 2),
                                                Text(
                                                  "@${user['username']}",
                                                  style: TextStyle(
                                                      fontSize: 12, color: Colors.grey.shade500),
                                                ),
                                                const SizedBox(height: 6),
                                                Row(
                                                  children: [
                                                    // Role badge (tappable)
                                                    GestureDetector(
                                                      onTap: () =>
                                                          _showRoleDialog(user['id'], role),
                                                      child: Container(
                                                        padding: const EdgeInsets.symmetric(
                                                            horizontal: 10, vertical: 3),
                                                        decoration: BoxDecoration(
                                                          color: _roleColor(role).withOpacity(0.1),
                                                          borderRadius: BorderRadius.circular(20),
                                                          border: Border.all(color: _roleColor(role)),
                                                        ),
                                                        child: Row(
                                                          mainAxisSize: MainAxisSize.min,
                                                          children: [
                                                            Icon(_roleIcon(role),
                                                                color: _roleColor(role), size: 11),
                                                            const SizedBox(width: 4),
                                                            Text(
                                                              role[0].toUpperCase() + role.substring(1),
                                                              style: TextStyle(
                                                                color: _roleColor(role),
                                                                fontSize: 11,
                                                                fontWeight: FontWeight.w600,
                                                              ),
                                                            ),
                                                            const SizedBox(width: 4),
                                                            Icon(Icons.edit,
                                                                size: 10, color: _roleColor(role)),
                                                          ],
                                                        ),
                                                      ),
                                                    ),
                                                    const SizedBox(width: 8),
                                                    // Inactive badge
                                                    if (!isActive)
                                                      Container(
                                                        padding: const EdgeInsets.symmetric(
                                                            horizontal: 8, vertical: 3),
                                                        decoration: BoxDecoration(
                                                          color: Colors.red.shade50,
                                                          borderRadius: BorderRadius.circular(20),
                                                          border:
                                                              Border.all(color: Colors.red.shade200),
                                                        ),
                                                        child: const Text(
                                                          "Inactive",
                                                          style: TextStyle(
                                                              color: Colors.red, fontSize: 11),
                                                        ),
                                                      ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ),

                                          // Action buttons
                                          Column(
                                            children: [
                                              IconButton(
                                                icon: Icon(
                                                  isActive
                                                      ? Icons.block_rounded
                                                      : Icons.check_circle_outline_rounded,
                                                  color: isActive ? Colors.orange : Colors.green,
                                                  size: 22,
                                                ),
                                                tooltip: isActive ? "Deactivate" : "Reactivate",
                                                onPressed: () =>
                                                    toggleActive(user['id'], isActive),
                                              ),
                                              IconButton(
                                                icon: const Icon(Icons.delete_outline_rounded,
                                                    color: Colors.red, size: 22),
                                                tooltip: "Delete",
                                                onPressed: () => _confirmDelete(
                                                    user['id'], user['full_name'] ?? 'this user'),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                      ),

                      // ── APPOINTMENTS TAB ───────────────────────
                      RefreshIndicator(
                        onRefresh: refreshData,
                        child: appointments.isEmpty
                            ? const Center(child: Text("No appointments found"))
                            : ListView.builder(
                                padding: const EdgeInsets.only(bottom: 16),
                                itemCount: appointments.length,
                                itemBuilder: (context, index) {
                                  final appt = appointments[index];
                                  final String status = appt['status'] ?? '';

                                  return Card(
                                    shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(14)),
                                    margin: const EdgeInsets.only(bottom: 10),
                                    child: Padding(
                                      padding: const EdgeInsets.all(14),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          // Title + status badge
                                          Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  appt['title'] ?? '',
                                                  style: const TextStyle(
                                                      fontWeight: FontWeight.bold, fontSize: 14),
                                                ),
                                              ),
                                              Container(
                                                padding: const EdgeInsets.symmetric(
                                                    horizontal: 10, vertical: 3),
                                                decoration: BoxDecoration(
                                                  color:
                                                      _statusColor(status).withOpacity(0.1),
                                                  borderRadius: BorderRadius.circular(20),
                                                  border:
                                                      Border.all(color: _statusColor(status)),
                                                ),
                                                child: Text(
                                                  status.replaceAll('_', ' '),
                                                  style: TextStyle(
                                                    color: _statusColor(status),
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 8),

                                          Row(children: [
                                            Icon(Icons.person_rounded,
                                                size: 13, color: Colors.grey.shade500),
                                            const SizedBox(width: 5),
                                            Text(appt['requester_name'] ?? '',
                                                style: TextStyle(
                                                    fontSize: 12, color: Colors.grey.shade600)),
                                          ]),
                                          const SizedBox(height: 3),

                                          Row(children: [
                                            Icon(Icons.schedule_rounded,
                                                size: 13, color: Colors.grey.shade500),
                                            const SizedBox(width: 5),
                                            Text("${appt['date']} at ${appt['time']}",
                                                style: TextStyle(
                                                    fontSize: 12, color: Colors.grey.shade600)),
                                          ]),

                                          if ((appt['meeting_type'] ?? '').isNotEmpty) ...[
                                            const SizedBox(height: 3),
                                            Row(children: [
                                              Icon(Icons.category_rounded,
                                                  size: 13, color: Colors.grey.shade500),
                                              const SizedBox(width: 5),
                                              Text(appt['meeting_type'],
                                                  style: TextStyle(
                                                      fontSize: 12,
                                                      color: Colors.grey.shade600)),
                                            ]),
                                          ],

                                          if ((appt['priority'] ?? '').isNotEmpty) ...[
                                            const SizedBox(height: 3),
                                            Row(children: [
                                              Icon(Icons.flag_rounded,
                                                  size: 13, color: Colors.grey.shade500),
                                              const SizedBox(width: 5),
                                              Text(appt['priority'],
                                                  style: TextStyle(
                                                      fontSize: 12,
                                                      color: Colors.grey.shade600)),
                                            ]),
                                          ],
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
          ),

          // Create user button
          Padding(
            padding: const EdgeInsets.fromLTRB(0, 12, 0, 0),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _showCreateUserDialog,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _asanaTeal,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                icon: const Icon(Icons.person_add_rounded, color: Colors.white),
                label: const Text("Create New User",
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Summary Card Widget ───────────────────────────────────────
  Widget _summaryCard(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value,
                    style: TextStyle(
                        fontSize: 22, fontWeight: FontWeight.bold, color: _navy)),
                Text(label,
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}