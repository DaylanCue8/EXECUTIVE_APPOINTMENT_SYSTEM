import 'package:flutter/material.dart';

// SHARED STAT CARD
Widget buildStatCard(String label, String value, IconData icon, Color color, {bool fullWidth = false}) {
  Widget card = Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(24),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.08),
          blurRadius: 28,
          offset: const Offset(0, 14),
        ),
      ],
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: color.withOpacity(0.14),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(icon, color: color, size: 28),
        ),
        const SizedBox(width: 18),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13)),
          ],
        )
      ],
    ),
  );
  return fullWidth ? SizedBox(width: double.infinity, child: card) : Expanded(child: card);
}

// SHARED ACTION CARD
Widget buildActionCard(BuildContext context, {
  required String title, 
  required String subtitle, 
  required IconData icon, 
  required Color iconColor, 
  required VoidCallback onTap
}) {
  return Material(
    color: Colors.white,
    borderRadius: BorderRadius.circular(24),
    elevation: 4,
    shadowColor: Colors.black.withOpacity(0.08),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.14),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: iconColor),
            ),
            const SizedBox(width: 18),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start, 
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 4),
                  Text(subtitle, style: const TextStyle(color: Colors.grey, fontSize: 13)),
                ]
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.grey),
          ],
        ),
      ),
    ),
  );
}