import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class RequestMeetingPage extends StatefulWidget {
  final int userId;
  RequestMeetingPage({required this.userId});

  @override
  _RequestMeetingPageState createState() => _RequestMeetingPageState();
}

class _RequestMeetingPageState extends State<RequestMeetingPage> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descController = TextEditingController();

  final Color _asanaTeal = const Color(0xFF14C6B1);
  final Color _inputBg = const Color(0xFFF4F7F9);

  int selectedDayIndex = 0;
  String? selectedSlot;
  
  // These are ALL possible slots
  final List<String> allSlots = ["09:00 AM", "10:30 AM", "02:00 PM", "04:30 PM", "05:00 PM"];
  // This will store only the slots that aren't booked yet
  List<String> currentAvailableSlots = [];

  final String baseUrl = "http://192.168.254.101:5000";

  @override
  void initState() {
    super.initState();
    _fetchBookedSlots(0); // Fetch for today (or the first work day) on load
  }

  // --- NEW: FETCH BOOKED SLOTS FROM FLASK ---
  Future<void> _fetchBookedSlots(int dayIndex) async {
    List<DateTime> days = getWorkDays();
    String formattedDate = days[dayIndex].toIso8601String().split('T')[0];

    try {
      final response = await http.get(Uri.parse("$baseUrl/get_booked_slots?date=$formattedDate"));
      
      if (response.statusCode == 200) {
        List booked = jsonDecode(response.body);
        setState(() {
          selectedDayIndex = dayIndex;
          selectedSlot = null; // Reset selection when date changes
          // Filter out slots that are already in the "booked" list
          currentAvailableSlots = allSlots.where((slot) => !booked.contains(slot)).toList();
        });
      }
    } catch (e) {
      print("Error fetching slots: $e");
    }
  }

  List<DateTime> getWorkDays() {
    return List.generate(10, (index) => DateTime.now().add(Duration(days: index)))
        .where((day) => day.weekday != DateTime.sunday)
        .take(7)
        .toList();
  }

  Future<void> _submitRequest() async {
    List<DateTime> days = getWorkDays();
    DateTime finalDate = days[selectedDayIndex];

    if (_titleController.text.isEmpty || selectedSlot == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please fill all fields")));
      return;
    }

    final response = await http.post(
      Uri.parse("$baseUrl/request_meeting"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "title": _titleController.text,
        "description": _descController.text,
        "user_id": widget.userId,
        "date": finalDate.toIso8601String().split('T')[0],
        "time": selectedSlot,
      }),
    );

    if (response.statusCode == 201) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: const Text("Request Sent!"), backgroundColor: _asanaTeal),
      );
      Navigator.pop(context);
    } else {
      // Show error if someone else booked it while we were looking
      var errorData = jsonDecode(response.body);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorData['error'] ?? "Failed to send request")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    List<DateTime> days = getWorkDays();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("New Meeting Request", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildLabel("Meeting Title"),
            _buildInputField(_titleController, "e.g. Project System Review", Icons.title),
            const SizedBox(height: 20),
            _buildLabel("Description"),
            _buildInputField(_descController, "What is this meeting about?", Icons.description, maxLines: 3),
            const SizedBox(height: 30),

            // Date Section
            _buildLabel("Select Best Date"),
            const SizedBox(height: 12),
            SizedBox(
              height: 90,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: days.length,
                itemBuilder: (context, index) {
                  bool isSelected = selectedDayIndex == index;
                  return GestureDetector(
                    onTap: () => _fetchBookedSlots(index), // Trigger API call on tap
                    child: Container(
                      width: 75,
                      margin: const EdgeInsets.only(right: 12),
                      decoration: BoxDecoration(
                        color: isSelected ? _asanaTeal : _inputBg,
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"][days[index].weekday - 1],
                            style: TextStyle(color: isSelected ? Colors.white : Colors.grey, fontSize: 12),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            days[index].day.toString(),
                            style: TextStyle(color: isSelected ? Colors.white : Colors.black, fontWeight: FontWeight.bold, fontSize: 20),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 30),

            // Time Slot Section
            _buildLabel("Available Time Slots"),
            const SizedBox(height: 12),
            // Show a message if no slots are available for that day
            currentAvailableSlots.isEmpty 
              ? const Text("No available slots for this day.", style: TextStyle(color: Colors.red))
              : Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: currentAvailableSlots.map((slot) {
                    bool isSelected = selectedSlot == slot;
                    return ChoiceChip(
                      label: Text(slot),
                      selected: isSelected,
                      onSelected: (val) => setState(() => selectedSlot = val ? slot : null),
                      selectedColor: _asanaTeal,
                      labelStyle: TextStyle(color: isSelected ? Colors.white : Colors.black, fontWeight: FontWeight.w600),
                      backgroundColor: _inputBg,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      side: BorderSide.none,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    );
                  }).toList(),
                ),

            const SizedBox(height: 40),

            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: _submitRequest,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _asanaTeal,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  elevation: 0,
                ),
                child: const Text("SEND REQUEST", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(text, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black87)),
    );
  }

  Widget _buildInputField(TextEditingController controller, String hint, IconData icon, {int maxLines = 1}) {
    return Container(
      decoration: BoxDecoration(color: _inputBg, borderRadius: BorderRadius.circular(12)),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        decoration: InputDecoration(
          hintText: hint,
          prefixIcon: Icon(icon, color: Colors.grey, size: 20),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.all(16),
        ),
      ),
    );
  }
}