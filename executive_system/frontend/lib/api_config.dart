class ApiConfig {
  static const String baseUrl = "http://192.168.254.123:5000";

  // Auth
  static const String login             = "$baseUrl/login";
  static const String register          = "$baseUrl/register";
  static const String updateToken       = "$baseUrl/update_token";

  // Meetings
  static const String getConfirmedMeetings = "$baseUrl/get_confirmed_meetings";
  static const String getPendingMeetings   = "$baseUrl/get_pending_meetings";
  static const String requestMeeting       = "$baseUrl/request_meeting";
  static const String getBookedSlots       = "$baseUrl/get_booked_slots";

  // These need an ID appended
  static const String updateStatus         = "$baseUrl/update_status";
  static const String rescheduleMeeting    = "$baseUrl/reschedule_meeting";

  // Admin
  static const String adminUsers           = "$baseUrl/admin/users";
  static const String adminCreateUser      = "$baseUrl/admin/create_user";
  static const String adminAllAppointments = "$baseUrl/admin/all_appointments";
}