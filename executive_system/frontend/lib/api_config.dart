class ApiConfig {
  static const String baseUrl = "http://192.168.254.102:5000";

  // Auth
  static const String login             = "$baseUrl/login";
  static const String register          = "$baseUrl/register";
  static const String updateToken       = "$baseUrl/update_token";

  // Meetings
  static const String getConfirmedMeetings      = "$baseUrl/get_confirmed_meetings";
  static const String getAwaitingBossApproval    = "$baseUrl/get_awaiting_boss_approval";
  static const String getPendingMeetings         = "$baseUrl/get_pending_meetings";
  static const String requestMeeting             = "$baseUrl/request_meeting";
  static const String getBookedSlots       = "$baseUrl/get_booked_slots";
  static const String getMeetingDetail     = "$baseUrl/meeting";

  static String userMeetings(int userId) => "$baseUrl/user_meetings/$userId";
  static String getChatMessages(int appointmentId) => "$baseUrl/chat_messages/$appointmentId";
  static const String sendChatMessage        = "$baseUrl/send_chat_message";
  static String getConversations(int userId) => "$baseUrl/conversations/$userId";

  // These need an ID appended
  static const String updateStatus         = "$baseUrl/update_status";
  static const String rescheduleMeeting    = "$baseUrl/reschedule_meeting";

  // Admin
  static const String adminUsers           = "$baseUrl/admin/users";
  static const String adminCreateUser      = "$baseUrl/admin/create_user";
  static const String adminAllAppointments = "$baseUrl/admin/all_appointments";
}