import pymysql
import firebase_admin
from flask import Flask, jsonify, request
from flask_sqlalchemy import SQLAlchemy
from flask_cors import CORS
from flask_bcrypt import Bcrypt
from firebase_admin import credentials, messaging
from datetime import datetime, timedelta

pymysql.install_as_MySQLdb()

app = Flask(__name__)
CORS(app)
bcrypt = Bcrypt(app)

DB_USER = 'root'
DB_PASSWORD = ''
DB_HOST = 'localhost'
DB_NAME = 'executive_system'

app.config['SQLALCHEMY_DATABASE_URI'] = (
    f'mysql+pymysql://{DB_USER}:{DB_PASSWORD}@{DB_HOST}/{DB_NAME}'
)
app.config['SQLALCHEMY_TRACK_MODIFICATIONS'] = False

db = SQLAlchemy(app)

# ── Firebase ──────────────────────────────────────────────────────────────────
try:
    cred = credentials.Certificate("serviceAccountKey.json")
    firebase_admin.initialize_app(cred)
    print("Firebase Admin Initialized ✅")
except Exception as e:
    print(f"Firebase init error: {e}")


def send_push_notification(token, title, body, data=None):
    try:
        data_payload = {str(k): str(v) for k, v in (data or {}).items()}
        message = messaging.Message(
            notification=messaging.Notification(title=title, body=body),
            data=data_payload,
            android=messaging.AndroidConfig(
                priority='high',
                notification=messaging.AndroidNotification(
                    channel_id='high_importance_channel',
                    priority='max',
                ),
            ),
            token=token,
        )
        messaging.send(message)
        print(f"Push sent: {title}")
    except Exception as e:
        print(f"Push notification failed: {e}")


def format_time(value):
    if value is None:
        return ""
    if isinstance(value, timedelta):
        total_seconds = int(value.total_seconds())
        temp = datetime.min + timedelta(seconds=total_seconds)
        return temp.strftime("%I:%M %p").lstrip("0")
    return str(value)


# ── Models ────────────────────────────────────────────────────────────────────
class User(db.Model):
    __tablename__ = 'users'
    id        = db.Column(db.Integer, primary_key=True)
    username  = db.Column(db.String(50), unique=True, nullable=False)
    password  = db.Column(db.String(255), nullable=False)
    role      = db.Column(db.String(20), nullable=False)
    full_name = db.Column(db.String(100))
    fcm_token = db.Column(db.Text, nullable=True)
    is_active = db.Column(db.Boolean, default=True)

    def to_dict(self):
        return {
            "id": self.id,
            "username": self.username,
            "role": self.role,
            "full_name": self.full_name,
            "fcm_token": self.fcm_token,
            "is_active": self.is_active
        }


class Appointment(db.Model):
    __tablename__ = 'appointments'
    id               = db.Column(db.Integer, primary_key=True)
    title            = db.Column(db.String(100), nullable=False)
    description      = db.Column(db.Text)
    requester_id     = db.Column(db.Integer, db.ForeignKey('users.id'))
    appointment_date = db.Column(db.String(20))
    appointment_time = db.Column(db.String(20))
    status           = db.Column(db.String(20), default='pending')
    meeting_type     = db.Column(db.String(50), nullable=True)
    priority         = db.Column(db.String(20), nullable=True)
    duration         = db.Column(db.String(30), nullable=True)
    attendees        = db.Column(db.Text, nullable=True)
    contact          = db.Column(db.String(50), nullable=True)
    link             = db.Column(db.String(255), nullable=True)


class ChatMessage(db.Model):
    __tablename__ = 'chat_messages'
    id = db.Column(db.Integer, primary_key=True)
    appointment_id = db.Column(db.Integer, db.ForeignKey('appointments.id'), nullable=False)
    sender_id = db.Column(db.Integer, db.ForeignKey('users.id'), nullable=False)
    receiver_id = db.Column(db.Integer, db.ForeignKey('users.id'), nullable=False)
    message = db.Column(db.Text, nullable=False)
    timestamp = db.Column(db.DateTime, default=datetime.utcnow)

    def to_dict(self):
        sender = db.session.get(User, self.sender_id)
        receiver = db.session.get(User, self.receiver_id)
        return {
            'id': self.id,
            'appointment_id': self.appointment_id,
            'sender_id': self.sender_id,
            'receiver_id': self.receiver_id,
            'sender_name': sender.full_name if sender else 'Unknown',
            'receiver_name': receiver.full_name if receiver else 'Unknown',
            'message': self.message,
            'timestamp': self.timestamp.isoformat() if self.timestamp else None,
        }

with app.app_context():
    db.create_all()


# ── STATUS FLOW ───────────────────────────────────────────────────────────────
#
#  User submits             → pending
#  Secretary approves       → secretary_approved    → Boss review queue
#  Secretary declines       → cancelled             → user notified
#  Boss approves            → confirmed             → Boss calendar
#  Boss rejects             → cancelled_by_boss     → Secretary "Boss Rejected" tab
#  Secretary reschedules    → rescheduled           → Boss approval queue again
#  Boss approves resched    → confirmed             → stays in Boss calendar
#  Boss rejects resched     → cancelled_by_boss     → Secretary "Boss Rejected" tab again
#  Meeting done             → completed
#
#  /get_pending_meetings            returns: pending | cancelled_by_boss | rescheduled (Secretary's queue)
#  /get_awaiting_boss_approval      returns: secretary_approved | rescheduled (Boss's approval queue)
#  /get_confirmed_meetings          returns: confirmed | rescheduled (Boss's confirmed calendar)
#
# ─────────────────────────────────────────────────────────────────────────────


# ── Auth ──────────────────────────────────────────────────────────────────────
@app.route('/register', methods=['POST'])
def register():
    data = request.get_json()
    hashed = bcrypt.generate_password_hash(data['password']).decode('utf-8')
    new_user = User(
        username=data['username'],
        password=hashed,
        role='requester',
        full_name=data['full_name'],
    )
    try:
        db.session.add(new_user)
        db.session.commit()
        return jsonify({"message": "User registered successfully!"}), 201
    except Exception:
        db.session.rollback()
        return jsonify({"error": "Username already exists"}), 400


@app.route('/login', methods=['POST'])
def login():
    data = request.get_json()
    user = User.query.filter_by(username=data['username']).first()
    if user and bcrypt.check_password_hash(user.password, data['password']):
        return jsonify({"message": "Login successful!", "user": user.to_dict()}), 200
    return jsonify({"message": "Invalid credentials"}), 401


@app.route('/update_token', methods=['POST'])
def update_token():
    data      = request.get_json()
    user_id   = data.get('user_id')
    fcm_token = data.get('fcm_token')
    if not user_id or not fcm_token:
        return jsonify({"message": "Missing data"}), 400
    user = db.session.get(User, user_id)
    if user:
        user.fcm_token = fcm_token
        db.session.commit()
        return jsonify({"message": "Token updated successfully"}), 200
    return jsonify({"message": "User not found"}), 404


# ── Meetings ──────────────────────────────────────────────────────────────────
@app.route('/request_meeting', methods=['POST'])
def request_meeting():
    data = request.get_json()
    existing = Appointment.query.filter_by(
        appointment_date=data['date'],
        appointment_time=data['time'],
        status='confirmed',
    ).first()
    if existing:
        return jsonify({"error": "This slot is already booked."}), 400

    new_appt = Appointment(
        title            = data['title'],
        description      = data.get('description', ''),
        requester_id     = data['user_id'],
        appointment_date = data['date'],
        appointment_time = data['time'],
        meeting_type     = data.get('meeting_type'),
        priority         = data.get('priority'),
        duration         = data.get('duration'),
        attendees        = data.get('attendees'),
        contact          = data.get('contact'),
        link             = data.get('link'),
    )
    db.session.add(new_appt)
    db.session.commit()

    # Notify secretary of new request
    secretary = User.query.filter_by(role='secretary').first()
    if secretary and secretary.fcm_token:
        requester = db.session.get(User, new_appt.requester_id)
        send_push_notification(
            secretary.fcm_token,
            "New Meeting Request 📅",
            f"'{new_appt.title}' requested by {requester.full_name} for {new_appt.appointment_date} at {format_time(new_appt.appointment_time)}.",
        )

    return jsonify({"message": "Meeting request sent!"}), 201


@app.route('/get_booked_slots', methods=['GET'])
def get_booked_slots():
    date   = request.args.get('date')
    booked = Appointment.query.filter_by(
        appointment_date=date, status='confirmed'
    ).all()
    return jsonify([format_time(a.appointment_time) for a in booked]), 200


# ── Secretary: pending queue ──────────────────────────────────────────────────
#  Returns ALL statuses the secretary needs to act on:
#    pending           → new user requests       (Tab 1: Review Queue)
#    cancelled_by_boss → boss rejected            (Tab 2: Boss Rejected)
#    rescheduled       → awaiting boss re-review  (Tab 2: Boss Rejected, greyed)
@app.route('/get_pending_meetings', methods=['GET'])
def get_pending():
    SECRETARY_STATUSES = ['pending', 'cancelled_by_boss', 'rescheduled']

    results = (
        db.session.query(Appointment, User)
        .join(User, Appointment.requester_id == User.id)
        .filter(Appointment.status.in_(SECRETARY_STATUSES))
        .order_by(
            Appointment.appointment_date.asc(),
            Appointment.appointment_time.asc(),
        )
        .all()
    )

    print(f"[get_pending_meetings] {len(results)} records")
    output = []
    for appt, user in results:
        print(f"  id={appt.id}  status={appt.status}  title={appt.title}")
        output.append({
            "id":             appt.id,
            "title":          appt.title,
            "description":    appt.description or "",
            "date":           str(appt.appointment_date),
            "time":           format_time(appt.appointment_time),
            "status":         appt.status,   # always send status so Flutter can filter
            "requester_name": user.full_name,
            "meeting_type":   appt.meeting_type or "",
            "priority":       appt.priority or "",
            "duration":       appt.duration or "",
            "attendees":      appt.attendees or "",
            "contact":        appt.contact or "",
            "link":           appt.link or "",
        })
    return jsonify(output), 200


@app.route('/chat_messages/<int:appointment_id>', methods=['GET'])
def get_chat_messages(appointment_id):
    messages = ChatMessage.query.filter_by(appointment_id=appointment_id).order_by(ChatMessage.timestamp.asc()).all()
    return jsonify([message.to_dict() for message in messages]), 200


@app.route('/conversations/<int:user_id>', methods=['GET'])
def get_conversations(user_id):
    # Return latest conversation threads for a user grouped by the other participant
    msgs = ChatMessage.query.filter(
        (ChatMessage.sender_id == user_id) | (ChatMessage.receiver_id == user_id)
    ).order_by(ChatMessage.timestamp.desc()).all()

    seen = {}
    output = []
    for m in msgs:
        other_id = m.sender_id if m.sender_id != user_id else m.receiver_id
        if other_id in seen:
            continue
        other = db.session.get(User, other_id)
        output.append({
            'other_id': other_id,
            'other_name': other.full_name if other else 'Unknown',
            'other_role': other.role if other else '',
            'last_message': m.message,
            'timestamp': m.timestamp.isoformat() if m.timestamp else None,
            'appointment_id': m.appointment_id,
        })
        seen[other_id] = True

    return jsonify(output), 200


@app.route('/send_chat_message', methods=['POST'])
def send_chat_message():
    data = request.get_json()
    appointment_id = data.get('appointment_id')
    sender_id = data.get('sender_id')
    message_text = (data.get('message') or '').strip()

    if not appointment_id or not sender_id or not message_text:
        return jsonify({'message': 'appointment_id, sender_id, and message are required'}), 400

    appointment = db.session.get(Appointment, appointment_id)
    sender = db.session.get(User, sender_id)
    if not appointment:
        return jsonify({'message': 'Appointment not found'}), 404
    if not sender:
        return jsonify({'message': 'Sender not found'}), 404

    receiver_id = data.get('receiver_id')
    receiver = None
    if receiver_id:
        receiver = db.session.get(User, receiver_id)
    else:
        if sender.role == 'requester':
            receiver = User.query.filter_by(role='secretary').first()
        elif sender.role == 'secretary':
            receiver = User.query.filter_by(role='boss').first()
        elif sender.role == 'boss':
            receiver = User.query.filter_by(role='secretary').first()

    if not receiver:
        return jsonify({'message': 'Recipient could not be determined'}), 404

    chat = ChatMessage(
        appointment_id=appointment_id,
        sender_id=sender_id,
        receiver_id=receiver.id,
        message=message_text,
    )
    db.session.add(chat)
    db.session.commit()

    if receiver.fcm_token:
        send_push_notification(
            receiver.fcm_token,
            f'New message from {sender.full_name or sender.username}',
            message_text if len(message_text) < 100 else f'{message_text[:97]}...',
            data={
                'type': 'chat',
                'appointment_id': appointment_id,
                'sender_id': sender_id,
                'sender_name': sender.full_name or sender.username,
            },
        )

    return jsonify(chat.to_dict()), 201


# ── Boss: awaiting approval ───────────────────────────────────────────────────
#  Secretary has approved these, now boss needs to approve or reject
@app.route('/get_awaiting_boss_approval', methods=['GET'])
def get_awaiting_boss_approval():
    BOSS_APPROVAL_STATUSES = ['secretary_approved', 'rescheduled']

    results = (
        db.session.query(Appointment, User)
        .join(User, Appointment.requester_id == User.id)
        .filter(Appointment.status.in_(BOSS_APPROVAL_STATUSES))
        .order_by(
            Appointment.appointment_date.asc(),
            Appointment.appointment_time.asc(),
        )
        .all()
    )

    print(f"[get_awaiting_boss_approval] {len(results)} records")
    output = []
    for appt, user in results:
        output.append({
            "id":             appt.id,
            "title":          appt.title,
            "description":    appt.description or "",
            "date":           str(appt.appointment_date),
            "time":           format_time(appt.appointment_time),
            "status":         appt.status,
            "requester_name": user.full_name,
            "meeting_type":   appt.meeting_type or "",
            "priority":       appt.priority or "",
            "duration":       appt.duration or "",
            "attendees":      appt.attendees or "",
            "contact":        appt.contact or "",
            "link":           appt.link or "",
        })
    return jsonify(output), 200


# ── Boss: calendar ────────────────────────────────────────────────────────────
#  confirmed → approved by both secretary and boss (fully confirmed)
@app.route('/get_confirmed_meetings', methods=['GET'])
def get_confirmed_meetings():
    BOSS_STATUSES = ['confirmed']

    results = (
        db.session.query(Appointment, User)
        .join(User, Appointment.requester_id == User.id)
        .filter(Appointment.status.in_(BOSS_STATUSES))
        .order_by(
            Appointment.appointment_date.asc(),
            Appointment.appointment_time.asc(),
        )
        .all()
    )

    output = []
    for appt, user in results:
        output.append({
            "id":             appt.id,
            "title":          appt.title,
            "description":    appt.description or "",
            "date":           str(appt.appointment_date),
            "time":           format_time(appt.appointment_time),
            "status":         appt.status,   # always send status
            "requester_name": user.full_name,
            "meeting_type":   appt.meeting_type or "",
            "priority":       appt.priority or "",
            "duration":       appt.duration or "",
            "attendees":      appt.attendees or "",
            "contact":        appt.contact or "",
            "link":           appt.link or "",
        })
    return jsonify(output), 200


# ── Update status ─────────────────────────────────────────────────────────────
@app.route('/update_status/<int:appt_id>', methods=['POST'])
def update_status(appt_id):
    data       = request.get_json()
    new_status = data['status']
    appt       = db.session.get(Appointment, appt_id)

    if not appt:
        return jsonify({"message": "Meeting not found"}), 404

    old_status  = appt.status
    appt.status = new_status
    db.session.commit()
    print(f"[update_status] id={appt_id}  {old_status} → {new_status}")

    requester = db.session.get(User, appt.requester_id)

    if new_status == 'secretary_approved':
        # Secretary approved, now waiting for boss approval
        boss = User.query.filter_by(role='boss').first()
        if boss and boss.fcm_token:
            send_push_notification(
                boss.fcm_token,
                "New Meeting Awaiting Approval 📋",
                f"'{appt.title}' from {requester.full_name if requester else 'User'} is ready for your review.",
            )

    elif new_status == 'confirmed':
        if requester and requester.fcm_token:
            send_push_notification(
                requester.fcm_token,
                "Meeting Approved! ✅",
                f"Your meeting '{appt.title}' is confirmed for "
                f"{appt.appointment_date} at {format_time(appt.appointment_time)}.",
            )

    elif new_status == 'cancelled':
        if requester and requester.fcm_token:
            send_push_notification(
                requester.fcm_token,
                "Meeting Declined ❌",
                f"Your request '{appt.title}' was not approved.",
            )

    elif new_status == 'cancelled_by_boss':
        # Notify secretary
        secretary = User.query.filter_by(role='secretary').first()
        if secretary and secretary.fcm_token:
            send_push_notification(
                secretary.fcm_token,
                "Meeting Rejected by Boss 🔄",
                f"'{appt.title}' was declined. Please reschedule.",
            )
        # Notify requester
        if requester and requester.fcm_token:
            send_push_notification(
                requester.fcm_token,
                "Meeting Under Review 🔄",
                f"Your meeting '{appt.title}' needs rescheduling. We'll update you soon.",
            )

    elif new_status == 'completed':
        if requester and requester.fcm_token:
            send_push_notification(
                requester.fcm_token,
                "Meeting Completed ✅",
                f"Your meeting '{appt.title}' has been marked as completed.",
            )

    return jsonify({"message": f"Status updated to {new_status}"}), 200


# ── Reschedule ────────────────────────────────────────────────────────────────
@app.route('/reschedule_meeting/<int:appt_id>', methods=['POST'])
def reschedule_meeting(appt_id):
    data = request.get_json()
    appt = db.session.get(Appointment, appt_id)

    if not appt:
        return jsonify({"message": "Meeting not found"}), 404

    appt.appointment_date = data['date']
    if data.get('time'):
        appt.appointment_time = data['time']

    # rescheduled → appears on boss calendar for re-review
    # also stays visible in secretary Tab 2 as "Awaiting boss re-review"
    appt.status = 'rescheduled'

    try:
        db.session.commit()
        print(f"[reschedule_meeting] id={appt_id} → rescheduled")

        requester = db.session.get(User, appt.requester_id)
        new_time  = data.get('time', format_time(appt.appointment_time))

        if requester and requester.fcm_token:
            send_push_notification(
                requester.fcm_token,
                "Meeting Rescheduled 🗓️",
                f"Your meeting '{appt.title}' has been moved to "
                f"{data['date']} at {new_time}.",
            )

        boss = User.query.filter_by(role='boss').first()
        if boss and boss.fcm_token:
            send_push_notification(
                boss.fcm_token,
                "Rescheduled Meeting Needs Review 🗓️",
                f"'{appt.title}' was rescheduled to {data['date']} at {new_time}. Please review.",
            )

        return jsonify({"message": "Meeting rescheduled successfully"}), 200
    except Exception as e:
        db.session.rollback()
        return jsonify({"error": str(e)}), 500


# ── User's own meetings ───────────────────────────────────────────────────────
@app.route('/user_meetings/<int:user_id>', methods=['GET'])
def get_user_meetings(user_id):
    meetings = Appointment.query.filter_by(requester_id=user_id).all()
    output = []
    for m in meetings:
        output.append({
            "id":           m.id,
            "title":        m.title,
            "description":  m.description or "",
            "date":         m.appointment_date,
            "time":         format_time(m.appointment_time),
            "status":       m.status,
            "meeting_type": m.meeting_type or "",
            "priority":     m.priority or "",
            "duration":     m.duration or "",
            "attendees":    m.attendees or "",
            "contact":      m.contact or "",
            "link":         m.link or "",
        })
    return jsonify(output), 200

# ─── ADMIN ROUTES ───────────────────────────────────────────────

# Get all users
@app.route('/admin/users', methods=['GET'])
def get_all_users():
    users = User.query.all()
    return jsonify([u.to_dict() for u in users]), 200

# Create a user with any role (admin, boss, secretary, requester)
@app.route('/admin/create_user', methods=['POST'])
def create_user():
    data = request.get_json()

    allowed_roles = ['admin', 'boss', 'secretary', 'requester']
    if data.get('role') not in allowed_roles:
        return jsonify({"error": "Invalid role"}), 400

    hashed_password = bcrypt.generate_password_hash(data['password']).decode('utf-8')
    new_user = User(
        username=data['username'],
        password=hashed_password,
        role=data['role'],
        full_name=data['full_name']
    )
    try:
        db.session.add(new_user)
        db.session.commit()
        return jsonify({"message": "User created successfully!"}), 201
    except Exception as e:
        db.session.rollback()
        return jsonify({"error": "Username already exists"}), 400

# Update a user's role
@app.route('/admin/update_role/<int:user_id>', methods=['POST'])
def update_role(user_id):
    data = request.get_json()
    allowed_roles = ['admin', 'boss', 'secretary', 'requester']
    if data.get('role') not in allowed_roles:
        return jsonify({"error": "Invalid role"}), 400

    user = db.session.get(User, user_id)
    if not user:
        return jsonify({"error": "User not found"}), 404

    user.role = data['role']
    db.session.commit()
    return jsonify({"message": f"Role updated to {data['role']}"}), 200

# Deactivate a user (soft delete using a new is_active column)
@app.route('/admin/deactivate_user/<int:user_id>', methods=['POST'])
def deactivate_user(user_id):
    user = db.session.get(User, user_id)
    if not user:
        return jsonify({"error": "User not found"}), 404

    user.is_active = False
    db.session.commit()
    return jsonify({"message": "User deactivated"}), 200

# Reactivate a user
@app.route('/admin/reactivate_user/<int:user_id>', methods=['POST'])
def reactivate_user(user_id):
    user = db.session.get(User, user_id)
    if not user:
        return jsonify({"error": "User not found"}), 404

    user.is_active = True
    db.session.commit()
    return jsonify({"message": "User reactivated"}), 200

# Delete a user permanently
@app.route('/admin/delete_user/<int:user_id>', methods=['DELETE'])
def delete_user(user_id):
    user = db.session.get(User, user_id)
    if not user:
        return jsonify({"error": "User not found"}), 404

    db.session.delete(user)
    db.session.commit()
    return jsonify({"message": "User deleted"}), 200

# Get all appointments (admin overview)
@app.route('/admin/all_appointments', methods=['GET'])
def get_all_appointments():
    results = db.session.query(Appointment, User).join(
        User, Appointment.requester_id == User.id
    ).order_by(Appointment.appointment_date.asc()).all()

    output = []
    for appt, user in results:
        output.append({
            "id": appt.id,
            "title": appt.title,
            "description": appt.description or "",
            "date": str(appt.appointment_date),
            "time": format_time(appt.appointment_time),
            "status": appt.status,
            "requester_name": user.full_name,
            "meeting_type": appt.meeting_type or "",
            "priority": appt.priority or "",
            "duration": appt.duration or "",
        })
    return jsonify(output), 200


if __name__ == '__main__':
    app.run(debug=True, host='0.0.0.0', port=5000)