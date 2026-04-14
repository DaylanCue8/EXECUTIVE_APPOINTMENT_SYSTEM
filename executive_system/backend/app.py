import pymysql
import firebase_admin
from flask import Flask, jsonify, request
from flask_sqlalchemy import SQLAlchemy
from flask_cors import CORS
from flask_bcrypt import Bcrypt
from firebase_admin import credentials, messaging

# Fix for MySQL connection
pymysql.install_as_MySQLdb()

app = Flask(__name__)
CORS(app)
bcrypt = Bcrypt(app)

# --- DATABASE CONFIGURATION ---
DB_USER = 'root'
DB_PASSWORD = ''  
DB_HOST = 'localhost'
DB_NAME = 'executive_system'

app.config['SQLALCHEMY_DATABASE_URI'] = f'mysql+pymysql://{DB_USER}:{DB_PASSWORD}@{DB_HOST}/{DB_NAME}'
app.config['SQLALCHEMY_TRACK_MODIFICATIONS'] = False

db = SQLAlchemy(app)

# --- FIREBASE INITIALIZATION ---
try:
    cred = credentials.Certificate("serviceAccountKey.json")
    firebase_admin.initialize_app(cred)
    print("Firebase Admin Initialized ✅")
except Exception as e:
    print(f"Error initializing Firebase: {e}")

# --- NOTIFICATION HELPER ---
def send_push_notification(token, title, body):
    if not token:
        return
    try:
        message = messaging.Message(
            notification=messaging.Notification(title=title, body=body),
            token=token,
        )
        messaging.send(message)
        print('Notification sent successfully')
    except Exception as e:
        print('Error sending Firebase message:', e)

# --- DATABASE MODELS ---

class User(db.Model):
    __tablename__ = 'users'
    id = db.Column(db.Integer, primary_key=True)
    username = db.Column(db.String(50), unique=True, nullable=False)
    password = db.Column(db.String(255), nullable=False) 
    role = db.Column(db.String(20), nullable=False)      # boss, secretary, requester
    full_name = db.Column(db.String(100))
    fcm_token = db.Column(db.Text, nullable=True)

    def to_dict(self):
        return {
            "id": self.id,
            "username": self.username,
            "role": self.role,
            "full_name": self.full_name,
            "fcm_token": self.fcm_token
        }
    
class Appointment(db.Model):
    __tablename__ = 'appointments'
    id = db.Column(db.Integer, primary_key=True)
    title = db.Column(db.String(100), nullable=False)
    description = db.Column(db.Text)
    requester_id = db.Column(db.Integer, db.ForeignKey('users.id'))
    appointment_date = db.Column(db.String(20)) 
    appointment_time = db.Column(db.String(20)) 
    status = db.Column(db.String(20), default='pending') 

# --- API ENDPOINTS ---

@app.route('/register', methods=['POST'])
def register():
    data = request.get_json()
    hashed_password = bcrypt.generate_password_hash(data['password']).decode('utf-8')
    
    # --- FIX: Role is now strictly 'requester' for all new registrations ---
    new_user = User(
        username=data['username'],
        password=hashed_password, 
        role='requester', 
        full_name=data['full_name']
    )
    try:
        db.session.add(new_user)
        db.session.commit()
        return jsonify({"message": "User registered successfully!"}), 201
    except Exception as e:
        db.session.rollback()
        return jsonify({"error": "Username already exists"}), 400
    
@app.route('/login', methods=['POST'])
def login():
    data = request.get_json()
    user = User.query.filter_by(username=data['username']).first()
    if user and bcrypt.check_password_hash(user.password, data['password']):
        return jsonify({"message": "Login successful!", "user": user.to_dict()}), 200
    return jsonify({"message": "Invalid credentials"}), 401

@app.route('/request_meeting', methods=['POST'])
def request_meeting():
    data = request.get_json()
    
    # Prevent requesting a slot that is already CONFIRMED
    existing = Appointment.query.filter_by(
        appointment_date=data['date'], 
        appointment_time=data['time'], 
        status='confirmed'
    ).first()

    if existing:
        return jsonify({"error": "This slot is already booked."}), 400

    new_appt = Appointment(
        title=data['title'],
        description=data['description'],
        requester_id=data['user_id'],
        appointment_date=data['date'],
        appointment_time=data['time']
    )
    db.session.add(new_appt)
    db.session.commit()
    return jsonify({"message": "Meeting request sent!"}), 201

@app.route('/get_booked_slots', methods=['GET'])
def get_booked_slots():
    date = request.args.get('date')
    booked = Appointment.query.filter_by(appointment_date=date, status='confirmed').all()
    return jsonify([appt.appointment_time for appt in booked]), 200

@app.route('/get_pending_meetings', methods=['GET'])
def get_pending():
    results = db.session.query(Appointment, User).join(User, Appointment.requester_id == User.id).filter(Appointment.status == 'pending').all()
    return jsonify([{
        "id": appt.id,
        "title": appt.title,
        "description": appt.description,
        "date": appt.appointment_date,
        "time": appt.appointment_time,
        "requester_name": user.full_name
    } for appt, user in results])

@app.route('/update_status/<int:appt_id>', methods=['POST'])
def update_status(appt_id):
    data = request.get_json()
    new_status = data['status']  # This can be 'confirmed', 'cancelled', or 'completed'
    appt = db.session.get(Appointment, appt_id)
    
    if not appt:
        return jsonify({"message": "Meeting not found"}), 404

    # Prevent double-booking logic
    if new_status == 'confirmed':
        collision = Appointment.query.filter(
            Appointment.id != appt_id,
            Appointment.appointment_date == appt.appointment_date,
            Appointment.appointment_time == appt.appointment_time,
            Appointment.status == 'confirmed'
        ).first()

        if collision:
            return jsonify({"error": "This slot was just booked by someone else."}), 400

    appt.status = new_status
    db.session.commit()
    
    # Send notifications only for specific status changes
    requester = db.session.get(User, appt.requester_id)
    if requester and requester.fcm_token:
        if new_status == 'confirmed':
            send_push_notification(
                requester.fcm_token, 
                "Meeting Approved! ✅", 
                f"Meeting '{appt.title}' is set for {appt.appointment_time}."
            )
        elif new_status == 'cancelled':
            send_push_notification(
                requester.fcm_token, 
                "Meeting Declined ❌", 
                f"Your request '{appt.title}' was declined."
            )
            
    return jsonify({"message": f"Status updated to {new_status}"}), 200

@app.route('/user_meetings/<int:user_id>', methods=['GET'])
def get_user_meetings(user_id):
    meetings = Appointment.query.filter_by(requester_id=user_id).all()
    output = []
    for m in meetings:
        output.append({
            "id": m.id,
            "title": m.title,
            "date": m.appointment_date,
            "time": m.appointment_time,
            "status": m.status
        })
    return jsonify(output), 200

@app.route('/update_token', methods=['POST'])
def update_token():
    data = request.get_json()
    user = db.session.get(User, data.get('user_id'))
    if user:
        user.fcm_token = data.get('fcm_token')
        db.session.commit()
        return jsonify({"message": "Token updated"}), 200
    return jsonify({"message": "User not found"}), 404

with app.app_context():
    db.create_all()

@app.route('/get_confirmed_meetings', methods=['GET'])
def get_confirmed_meetings():
    # Only show meetings where status is 'confirmed'
    # 'completed' meetings are filtered out so the Boss's list stays clean
    results = db.session.query(Appointment, User).join(
        User, Appointment.requester_id == User.id
    ).filter(Appointment.status == 'confirmed').all()

    output = []
    for appt, user in results:
        output.append({
            "id": appt.id,
            "title": appt.title,
            "description": appt.description,
            "date": appt.appointment_date,
            "time": appt.appointment_time,
            "requester_name": user.full_name
        })
    return jsonify(output), 200

if __name__ == '__main__':
    app.run(debug=True, host='0.0.0.0', port=5000)