from app import app, db, User, bcrypt

def create_admin_users():
    with app.app_context():
        # Define the users you want to add
        admins = [
            {"user": "boss_admin", "name": "The Executive", "role": "boss"},
            {"user": "sec_admin", "name": "The Secretary", "role": "secretary"}
        ]

        for person in admins:
            # Check if they already exist so you don't get errors
            existing = User.query.filter_by(username=person['user']).first()
            if not existing:
                # Hash the password 'daylancue1' correctly
                hashed = bcrypt.generate_password_hash('daylancue1').decode('utf-8')
                
                new_user = User(
                    username=person['user'],
                    password=hashed,
                    role=person['role'],
                    full_name=person['name']
                )
                db.session.add(new_user)
                print(f"Created {person['role']} successfully!")
        
        db.session.commit()

if __name__ == "__main__":
    create_admin_users()