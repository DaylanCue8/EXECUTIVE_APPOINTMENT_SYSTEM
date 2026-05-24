import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'api_config.dart';

class MeetingDetailPage extends StatefulWidget {
  final int meetingId;

  const MeetingDetailPage({super.key, required this.meetingId});

  @override
  State<MeetingDetailPage> createState() => _MeetingDetailPageState();
}

class _MeetingDetailPageState extends State<MeetingDetailPage> {
  Map<String, dynamic>? meeting;
  bool isLoading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    _fetchMeeting();
  }

  Future<void> _fetchMeeting() async {
    setState(() {
      isLoading = true;
      error = null;
    });

    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.getMeetingDetail}/${widget.meetingId}'),
      );

      if (response.statusCode == 200) {
        setState(() {
          meeting = jsonDecode(response.body) as Map<String, dynamic>?;
          isLoading = false;
        });
      } else if (response.statusCode == 404) {
        setState(() {
          error = 'Meeting not found.';
          isLoading = false;
        });
      } else {
        setState(() {
          error = 'Unable to load meeting details.';
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        error = 'Failed to load meeting details.';
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Meeting Details'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: isLoading
            ? const Center(child: CircularProgressIndicator())
            : error != null
                ? Center(child: Text(error!, style: const TextStyle(color: Colors.red)))
                : _buildDetails(context),
      ),
    );
  }

  Widget _buildDetails(BuildContext context) {
    if (meeting == null) {
      return const Center(child: Text('No meeting details available.'));
    }

    final title = meeting!['title'] ?? 'Untitled';
    final description = meeting!['description'] ?? '';
    final date = meeting!['date'] ?? '';
    final time = meeting!['time'] ?? '';
    final status = meeting!['status'] ?? '';
    final requester = meeting!['requester_name'] ?? 'Unknown requester';
    final meetingType = meeting!['meeting_type'] ?? '';
    final priority = meeting!['priority'] ?? '';
    final duration = meeting!['duration'] ?? '';
    final attendees = meeting!['attendees'] ?? '';
    final contact = meeting!['contact'] ?? '';

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildChip('Status', status),
              _buildChip('Priority', priority),
              if (meetingType.isNotEmpty) _buildChip('Type', meetingType),
              if (duration.isNotEmpty) _buildChip('Duration', duration),
            ],
          ),
          const SizedBox(height: 24),
          _buildDetailRow(Icons.calendar_today, 'Date', date),
          const SizedBox(height: 12),
          _buildDetailRow(Icons.access_time, 'Time', time),
          const SizedBox(height: 12),
          _buildDetailRow(Icons.person, 'Requester', requester),
          if (contact.isNotEmpty) ...[
            const SizedBox(height: 12),
            _buildDetailRow(Icons.contact_mail, 'Contact', contact),
          ],
          if (attendees.isNotEmpty) ...[
            const SizedBox(height: 12),
            _buildDetailRow(Icons.group, 'Attendees', attendees),
          ],
          if (description.isNotEmpty) ...[
            const SizedBox(height: 24),
            const Text('Description', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            Text(description, style: const TextStyle(fontSize: 14, height: 1.4)),
          ],
        ],
      ),
    );
  }

  Widget _buildChip(String label, String value) {
    return Chip(
      label: Text('$label: $value'),
      backgroundColor: Colors.grey.shade100,
    );
  }

  Widget _buildDetailRow(IconData icon, String title, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: Colors.blueGrey),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(value, style: const TextStyle(fontSize: 14, color: Colors.black87)),
            ],
          ),
        ),
      ],
    );
  }
}
