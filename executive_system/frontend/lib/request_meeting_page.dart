import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'api_config.dart';

class RequestMeetingPage extends StatefulWidget {
  final int userId;
  final DateTime? selectedDate;

  RequestMeetingPage({required this.userId, this.selectedDate});

  @override
  _RequestMeetingPageState createState() => _RequestMeetingPageState();
}

class _RequestMeetingPageState extends State<RequestMeetingPage> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descController = TextEditingController();
  final TextEditingController _attendeesController = TextEditingController();
  final TextEditingController _contactController = TextEditingController();

  final Color _navy = const Color(0xFF1D2939);
  final Color _navyLight = const Color(0xFF263347);
  final Color _gold = const Color(0xFFC9A84C);
  final Color _border = const Color(0xFF334155);
  final Color _hint = const Color(0xFF8A9AB0);
  final Color _asanaTeal = const Color(0xFF14C6B1);

  int selectedDayIndex = 0;
  String? selectedSlot;
  String? selectedMeetingType;
  String? selectedPriority;
  String? selectedDuration;

  final List<String> allSlots = [
    "9:00 AM", "10:30 AM", "2:00 PM", "4:30 PM", "5:00 PM"
  ];

  final List<String> meetingTypes = [
    "Budget Discussion",
    "Project Update",
    "Urgent Matter",
    "HR Concern",
    "Performance Review",
    "General Inquiry",
    "Strategic Planning",
    "Client Meeting",
  ];

  final List<Map<String, dynamic>> priorities = [
    {"label": "Low", "color": Color(0xFF4CAF50), "icon": Icons.arrow_downward_rounded},
    {"label": "Normal", "color": Color(0xFF2196F3), "icon": Icons.remove_rounded},
    {"label": "Urgent", "color": Color(0xFFF44336), "icon": Icons.priority_high_rounded},
  ];

  final List<String> durations = [
    "15 minutes",
    "30 minutes",
    "45 minutes",
    "1 hour",
    "1.5 hours",
    "2 hours",
  ];

  List<String> currentAvailableSlots = [];

  @override
  void initState() {
    super.initState();
    _initializeSelection();
  }

  void _initializeSelection() {
    List<DateTime> days = getWorkDays();

    if (widget.selectedDate != null) {
      int index = days.indexWhere((d) =>
          d.year == widget.selectedDate!.year &&
          d.month == widget.selectedDate!.month &&
          d.day == widget.selectedDate!.day);

      if (index != -1) {
        selectedDayIndex = index;
      }
    }

    _fetchBookedSlots(selectedDayIndex);
  }

  Future<void> _fetchBookedSlots(int dayIndex) async {
    List<DateTime> days = getWorkDays();
    String formattedDate = days[dayIndex].toIso8601String().split('T')[0];

    setState(() {
      selectedDayIndex = dayIndex;
      selectedSlot = null;
      currentAvailableSlots = [];
    });

    try {
      final response = await http.get(
        Uri.parse("${ApiConfig.getBookedSlots}?date=$formattedDate"),
      );
      if (response.statusCode == 200) {
        List<dynamic> bookedData = jsonDecode(response.body);
        List<String> bookedSlots =
            bookedData.map((e) => e.toString().trim()).toList();

        setState(() {
          currentAvailableSlots = allSlots
              .where((slot) => !bookedSlots.contains(slot.trim()))
              .toList();
        });
      }
    } catch (e) {
      debugPrint("Error fetching slots: $e");
    }
  }

  List<DateTime> getWorkDays() {
    List<DateTime> days = List.generate(
            14, (index) => DateTime.now().add(Duration(days: index)))
        .where((day) => day.weekday != DateTime.sunday)
        .toList();

    // If a selectedDate is provided and it's not in the current list, add it
    if (widget.selectedDate != null) {
      bool dateExists = days.any((day) =>
          day.year == widget.selectedDate!.year &&
          day.month == widget.selectedDate!.month &&
          day.day == widget.selectedDate!.day);

      if (!dateExists && widget.selectedDate!.weekday != DateTime.sunday) {
        days.add(widget.selectedDate!);
        // Sort the days to maintain chronological order
        days.sort((a, b) => a.compareTo(b));
      }
    }

    return days;
  }

  Future<void> _submitRequest() async {
    List<DateTime> days = getWorkDays();
    DateTime finalDate = days[selectedDayIndex];

    if (_titleController.text.isEmpty ||
        selectedSlot == null ||
        selectedMeetingType == null ||
        selectedPriority == null ||
        selectedDuration == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please fill all required fields"),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final response = await http.post(
      Uri.parse(ApiConfig.requestMeeting),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "title": _titleController.text,
        "description": _descController.text,
        "user_id": widget.userId,
        "date": finalDate.toIso8601String().split('T')[0],
        "time": selectedSlot,
        "meeting_type": selectedMeetingType,
        "priority": selectedPriority,
        "duration": selectedDuration,
        "attendees": _attendeesController.text,
        "contact": _contactController.text,
      }),
    );

    if (response.statusCode == 201) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text("Request Sent!"),
          backgroundColor: _asanaTeal,
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.pop(context);
    } else {
      var errorData = jsonDecode(response.body);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorData['error'] ?? "Failed to send request"),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    List<DateTime> days = getWorkDays();

    return Scaffold(
      backgroundColor: _navy,
      appBar: AppBar(
        backgroundColor: _navy,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: _hint, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "New Meeting Request",
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ),
      body: Column(
        children: [
          // HEADER STRIP
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 4, 24, 16),
            child: Row(
              children: [
                Container(
                  width: 4,
                  height: 28,
                  decoration: BoxDecoration(
                    color: _gold,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  "Fill in the details below",
                  style: TextStyle(color: _hint, fontSize: 13),
                ),
              ],
            ),
          ),

          // CONTENT CARD
          Expanded(
            child: Container(
              decoration: const BoxDecoration(
                color: Color(0xFFF4F7F9),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(28),
                  topRight: Radius.circular(28),
                ),
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [

                    // ── Meeting Title ──────────────────────────────
                    _buildLabel("Meeting Title *"),
                    const SizedBox(height: 8),
                    _buildInputField(
                      _titleController,
                      "e.g. Project System Review",
                      Icons.title_rounded,
                    ),
                    const SizedBox(height: 16),

                    // ── Description ───────────────────────────────
                    _buildLabel("Description"),
                    const SizedBox(height: 8),
                    _buildInputField(
                      _descController,
                      "What is this meeting about?",
                      Icons.description_rounded,
                      maxLines: 3,
                    ),
                    const SizedBox(height: 20),

                    // ── Meeting Type ──────────────────────────────
                    _buildLabel("Meeting Type *"),
                    const SizedBox(height: 8),
                    _buildDropdown(
                      value: selectedMeetingType,
                      hint: "Select meeting type",
                      icon: Icons.category_rounded,
                      items: meetingTypes,
                      onChanged: (val) =>
                          setState(() => selectedMeetingType = val),
                    ),
                    const SizedBox(height: 20),

                    // ── Priority ──────────────────────────────────
                    _buildLabel("Priority Level *"),
                    const SizedBox(height: 10),
                    Row(
                      children: priorities.map((p) {
                        bool isSelected = selectedPriority == p["label"];
                        return Expanded(
                          child: GestureDetector(
                            onTap: () =>
                                setState(() => selectedPriority = p["label"]),
                            child: Container(
                              margin: EdgeInsets.only(
                                right: p["label"] == "Urgent" ? 0 : 10,
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? (p["color"] as Color).withOpacity(0.12)
                                    : Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isSelected
                                      ? p["color"] as Color
                                      : Colors.grey.shade300,
                                  width: isSelected ? 2 : 1,
                                ),
                              ),
                              child: Column(
                                children: [
                                  Icon(
                                    p["icon"] as IconData,
                                    color: isSelected
                                        ? p["color"] as Color
                                        : Colors.grey,
                                    size: 20,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    p["label"] as String,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: isSelected
                                          ? p["color"] as Color
                                          : Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 20),

                    // ── Expected Duration ─────────────────────────
                    _buildLabel("Expected Duration *"),
                    const SizedBox(height: 8),
                    _buildDropdown(
                      value: selectedDuration,
                      hint: "How long will this take?",
                      icon: Icons.timer_rounded,
                      items: durations,
                      onChanged: (val) =>
                          setState(() => selectedDuration = val),
                    ),
                    const SizedBox(height: 20),

                    // ── Attendees ─────────────────────────────────
                    _buildLabel("Other Attendees"),
                    const SizedBox(height: 4),
                    Text(
                      "Names of other people joining this meeting",
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildInputField(
                      _attendeesController,
                      "e.g. Juan dela Cruz, Maria Santos",
                      Icons.group_rounded,
                      maxLines: 2,
                    ),
                    const SizedBox(height: 20),

                    // ── Contact ───────────────────────────────────
                    _buildLabel("Your Contact Number"),
                    const SizedBox(height: 4),
                    Text(
                      "In case the secretary needs to reach you for clarification",
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildInputField(
                      _contactController,
                      "e.g. 09XX-XXX-XXXX",
                      Icons.phone_rounded,
                    ),
                    const SizedBox(height: 28),

                    // ── Date Picker ───────────────────────────────
                    _buildLabel("Select Date *"),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 90,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: days.length,
                        controller: ScrollController(
                          initialScrollOffset: selectedDayIndex * 87.0,
                        ),
                        itemBuilder: (context, index) {
                          bool isSelected = selectedDayIndex == index;
                          return GestureDetector(
                            onTap: () => _fetchBookedSlots(index),
                            child: Container(
                              width: 75,
                              margin: const EdgeInsets.only(right: 12),
                              decoration: BoxDecoration(
                                color: isSelected ? _navy : Colors.white,
                                borderRadius: BorderRadius.circular(15),
                                border: Border.all(
                                  color: isSelected
                                      ? _gold
                                      : Colors.grey.shade300,
                                  width: isSelected ? 2 : 1,
                                ),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    ["Mon","Tue","Wed","Thu","Fri","Sat","Sun"]
                                        [days[index].weekday - 1],
                                    style: TextStyle(
                                      color: isSelected ? _gold : Colors.grey,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    days[index].day.toString(),
                                    style: TextStyle(
                                      color: isSelected
                                          ? Colors.white
                                          : Colors.black87,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 20,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),

                    const SizedBox(height: 24),

                    // ── Time Slots ────────────────────────────────
                    _buildLabel("Available Time Slots *"),
                    const SizedBox(height: 12),

                    currentAvailableSlots.isEmpty && selectedSlot == null
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Text(
                                "Checking availability...",
                                style: TextStyle(
                                  fontStyle: FontStyle.italic,
                                  color: Colors.grey.shade500,
                                ),
                              ),
                            ),
                          )
                        : currentAvailableSlots.isEmpty
                            ? Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Text(
                                    "No available slots for this day.",
                                    style: TextStyle(
                                      fontStyle: FontStyle.italic,
                                      color: Colors.grey.shade500,
                                    ),
                                  ),
                                ),
                              )
                            : Wrap(
                                spacing: 10,
                                runSpacing: 10,
                                children: currentAvailableSlots.map((slot) {
                                  bool isSelected = selectedSlot == slot;
                                  return GestureDetector(
                                    onTap: () => setState(() =>
                                        selectedSlot =
                                            isSelected ? null : slot),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 10,
                                      ),
                                      decoration: BoxDecoration(
                                        color: isSelected ? _navy : Colors.white,
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                          color: isSelected
                                              ? _gold
                                              : Colors.grey.shade300,
                                          width: isSelected ? 2 : 1,
                                        ),
                                      ),
                                      child: Text(
                                        slot,
                                        style: TextStyle(
                                          color: isSelected
                                              ? Colors.white
                                              : Colors.black87,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),

                    const SizedBox(height: 36),

                    // ── Submit Button ─────────────────────────────
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _submitRequest,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _gold,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        child: Text(
                          "SEND REQUEST",
                          style: TextStyle(
                            color: _navy,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.5,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.bold,
        color: Colors.black87,
      ),
    );
  }

  Widget _buildInputField(
    TextEditingController controller,
    String hint,
    IconData icon, {
    int maxLines = 1,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
          prefixIcon: Icon(icon, color: Colors.grey, size: 18),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.all(16),
        ),
      ),
    );
  }

  Widget _buildDropdown({
    required String? value,
    required String hint,
    required IconData icon,
    required List<String> items,
    required void Function(String?) onChanged,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          hint: Row(
            children: [
              Icon(icon, color: Colors.grey, size: 18),
              const SizedBox(width: 10),
              Text(
                hint,
                style: TextStyle(color: Colors.grey.shade400, fontSize: 13),
              ),
            ],
          ),
          icon: Icon(Icons.keyboard_arrow_down_rounded,
              color: Colors.grey.shade400),
          items: items
              .map((item) => DropdownMenuItem(
                    value: item,
                    child: Text(item,
                        style: const TextStyle(
                            fontSize: 13, color: Colors.black87)),
                  ))
              .toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}