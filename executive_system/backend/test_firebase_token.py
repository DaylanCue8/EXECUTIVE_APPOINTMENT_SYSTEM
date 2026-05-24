from google.oauth2 import service_account
import google.auth.transport.requests as tr_requests

SERVICE_ACCOUNT_FILE = 'serviceAccountKey.json'

def main():
    try:
        creds = service_account.Credentials.from_service_account_file(
            SERVICE_ACCOUNT_FILE,
            scopes=['https://www.googleapis.com/auth/firebase.messaging']
        )
        req = tr_requests.Request()
        creds.refresh(req)
        print('Access token obtained:')
        print(creds.token[:40] + '...')
    except Exception as e:
        print('Token refresh failed:')
        print(repr(e))

if __name__ == '__main__':
    main()
