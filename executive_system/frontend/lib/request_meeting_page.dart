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
  
  DateTime? selectedDate;
  TimeOfDay? selectedTime;

  // REPLACE with your Flask IP!
  final String apiUrl = "http://192.168.254.101:5000/request_meeting";

  // Date Picker Function
  Future<void> _pickDate() async {
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2027),
    );
    if (picked != null) setState(() => selectedDate = picked);
  }

  // Time Picker Function
  Future<void> _pickTime() async {
    TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (picked != null) setState(() => selectedTime = picked);
  }

  Future<void> _submitRequest() async {
    if (_titleController.text.isEmpty || selectedDate == null || selectedTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please fill all fields and pick date/time")),
      );
      return;
    }

    final response = await http.post(
      Uri.parse(apiUrl),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "title": _titleController.text,
        "description": _descController.text,
        "user_id": widget.userId,
        "date": selectedDate!.toIso8601String().split('T')[0],
        "time": selectedTime!.format(context),
      }),
    );

    if (response.statusCode == 201) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Meeting Request Sent Successfully!")),
      );
      Navigator.pop(context); // Go back to Dashboard
    } else {
      print("Error: ${response.body}");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("New Meeting Request")),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(labelText: "Meeting Title (e.g. Project Update)"),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _descController,
              decoration: const InputDecoration(labelText: "Description/Purpose"),
              maxLines: 3,
            ),
            const SizedBox(height: 20),
            
            // Date Picker Row
            ListTile(
              title: Text(selectedDate == null 
                ? "Select Date" 
                : "Date: ${selectedDate!.day}/${selectedDate!.month}/${selectedDate!.year}"),
              leading: const Icon(Icons.calendar_today, color: Colors.blue),
              onTap: _pickDate,
              tileColor: Colors.grey.shade100,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            
            const SizedBox(height: 10),

            // Time Picker Row
            ListTile(
              title: Text(selectedTime == null 
                ? "Select Time" 
                : "Time: ${selectedTime!.format(context)}"),
              leading: const Icon(Icons.access_time, color: Colors.blue),
              onTap: _pickTime,
              tileColor: Colors.grey.shade100,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),

            const Spacer(),
            
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _submitRequest,
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                child: const Text("SEND REQUEST", style: TextStyle(color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}