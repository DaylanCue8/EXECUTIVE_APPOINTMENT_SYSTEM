from app import db, app
from sqlalchemy import text
from sqlalchemy.exc import OperationalError


def main():
    try:
        with app.app_context():
            db.session.execute(text("ALTER TABLE appointments ADD COLUMN link VARCHAR(255) NULL;"))
            db.session.commit()
            print("ALTER TABLE executed: column 'link' added (if it didn't exist).")
    except OperationalError as e:
        print("OperationalError while executing ALTER TABLE:")
        print(e)
    except Exception as e:
        print("Unexpected error:")
        print(e)


if __name__ == '__main__':
    main()
