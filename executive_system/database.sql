CREATE DATABASE executive_system;
USE executive_system;

-- 1. Users Table
CREATE TABLE users (
    id INT AUTO_INCREMENT PRIMARY KEY,
    username VARCHAR(50) UNIQUE NOT NULL,
    password VARCHAR(255) NOT NULL,
    role ENUM('admin', 'boss', 'secretary', 'requester') NOT NULL,
    full_name VARCHAR(100)
);

-- 2. Appointments Table
CREATE TABLE appointments (
    id INT AUTO_INCREMENT PRIMARY KEY,
    title VARCHAR(100) NOT NULL,
    description TEXT,
    requester_id INT,
    appointment_date DATE,
    appointment_time TIME,
    status ENUM('pending', 'secretary_approved', 'confirmed', 'cancelled', 'cancelled_by_boss', 'rescheduled', 'completed') DEFAULT 'pending',
    meeting_type VARCHAR(50),
    priority VARCHAR(20),
    duration VARCHAR(30),
    attendees TEXT,
    contact VARCHAR(50),
    link VARCHAR(255),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (requester_id) REFERENCES users(id)
);

-- 3. Chat messages table
CREATE TABLE chat_messages (
    id INT AUTO_INCREMENT PRIMARY KEY,
    appointment_id INT NOT NULL,
    sender_id INT NOT NULL,
    receiver_id INT NOT NULL,
    message TEXT NOT NULL,
    timestamp DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (appointment_id) REFERENCES appointments(id),
    FOREIGN KEY (sender_id) REFERENCES users(id),
    FOREIGN KEY (receiver_id) REFERENCES users(id)
);