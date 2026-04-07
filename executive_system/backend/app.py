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
DB_PASSWORD = ''  # Ensure your MySQL password is here
DB_HOST = 'localhost'
DB_NAME = 'executive_system'

app.config['SQLALCHEMY_DATABASE_URI'] = f'mysql+pymysql://{DB_USER}:{DB_PASSWORD}@{DB_HOST}/{DB_NAME}'
app.config['SQLALCHEMY_TRACK_MODIFICATIONS'] = False

db = SQLAlchemy(app)

# --- FIREBASE INITIALIZATION ---
try:
    # Ensure serviceAccountKey.json is in the same folder as app.py
    cred = credentials.Certificate("serviceAccountKey.json")
    firebase_admin.initialize_app(cred)
    print("Firebase Admin Initialized ✅")
except Exception as e:
    print(f"Error initializing Firebase: {e}")

# --- NOTIFICATION HELPER ---
def send_push_notification(token, title, body):
    if not token:
        print("DEBUG: No token provided. Skipping notification.")
        return
    try:
        message = messaging.Message(
            notification=messaging.Notification(
                title=title,
                body=body,
            ),
            token=token,
        )
        response = messaging.send(message)
        print('Notification sent successfully:', response)
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
    fcm_token = db.Column(db.Text, nullable=True)        # Store phone's unique ID

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
    status = db.Column(db.String(20), default='pending') # pending, confirmed, cancelled

# --- API ENDPOINTS ---

@app.route('/')
def index():
    return jsonify({"message": "Executive System API is Running!"})

@app.route('/register', methods=['POST'])
def register():
    data = request.get_json()
    # Hash the password before saving
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
        return jsonify({"message": "User registered successfully!"}), 201
    except Exception as e:
        db.session.rollback()
        return jsonify({"error": str(e)}), 400
    
@app.route('/login', methods=['POST'])
def login():
    data = request.get_json()
    user = User.query.filter_by(username=data['username']).first()
    
    # Check hashed password
    if user and bcrypt.check_password_hash(user.password, data['password']):
        return jsonify({
            "message": "Login successful!",
            "user": user.to_dict()
        }), 200
    else:
        return jsonify({"message": "Invalid credentials"}), 401

@app.route('/update_token', methods=['POST'])
def update_token():
    data = request.get_json()
    user_id = data.get('user_id')
    new_token = data.get('fcm_token')
    
    user = db.session.get(User, user_id)
    if user:
        user.fcm_token = new_token
        db.session.commit()
        print(f"DEBUG: Token updated for user {user.username}")
        return jsonify({"message": "Token updated"}), 200
    return jsonify({"message": "User not found"}), 404

@app.route('/request_meeting', methods=['POST'])
def request_meeting():
    data = request.get_json()
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

@app.route('/get_pending_meetings', methods=['GET'])
def get_pending():
    results = db.session.query(Appointment, User).join(User, Appointment.requester_id == User.id).filter(Appointment.status == 'pending').all()
    output = []
    for appt, user in results:
        output.append({
            "id": appt.id,
            "title": appt.title,
            "date": appt.appointment_date,
            "time": appt.appointment_time,
            "requester_name": user.full_name
        })
    return jsonify(output)

@app.route('/update_status/<int:appt_id>', methods=['POST'])
def update_status(appt_id):
    data = request.get_json()
    appt = db.session.get(Appointment, appt_id)
    
    if appt:
        appt.status = data['status']
        db.session.commit()
        
        # Notify the Requester if approved
        if data['status'] == 'confirmed':
            requester = db.session.get(User, appt.requester_id)
            if requester and requester.fcm_token:
                send_push_notification(
                    requester.fcm_token, 
                    "Meeting Approved! ✅", 
                    f"Hi {requester.full_name}, your meeting '{appt.title}' is confirmed for {appt.appointment_time}."
                )
            else:
                print(f"DEBUG: No token found for user ID {appt.requester_id}. Notification skipped.")
                
        return jsonify({"message": f"Status updated to {data['status']}"}), 200
    return jsonify({"message": "Meeting not found"}), 404

# Create tables automatically
with app.app_context():
    db.create_all()

if __name__ == '__main__':
    # Use host='0.0.0.0' so your phone can reach the server via PC IP
    app.run(debug=True, host='0.0.0.0', port=5000)