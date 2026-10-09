from http.server import HTTPServer, BaseHTTPRequestHandler
import http
import click
from functools import partial
import json
from pathlib import Path
import requests
from requests.adapters import HTTPAdapter
from urllib3.util import Retry
from http.cookies import SimpleCookie
from datetime import datetime, timezone, timedelta

def request_retry(method, url, json=None, headers=None, cookies=None, timeout=5, max_retries=5):
    if headers is None:
        headers = {}

    session = requests.Session()
    
    # Configure retry logic
    retry_strategy = Retry(
        total=max_retries,                  # Total number of attempts
        backoff_factor=1,                   # Waits: 1s, 2s, 4s, 8s... between retries
        status_forcelist=[429, 500, 502, 503, 504], # Retry on these HTTP status codes
        raise_on_status=False               # Returns response instead of raising exception on last fail
    )
    
    # Mount the adapter to both HTTP and HTTPS protocols
    adapter = HTTPAdapter(max_retries=retry_strategy)
    session.mount("http://", adapter)
    session.mount("https://", adapter)
    
    try:
        # The session will automatically retry up to N times if it hits errors
        response = session.request(method=method.upper(), json=json, url=url, cookies=cookies, headers=headers, timeout=timeout)
        return response
    except requests.exceptions.RequestException as e:
        print(f"Request completely failed: {e}")
        raise(e)
    
def login(mattermost_url, user, password):
    payload = {
        "login_id": user,
        "password": password
    }

    try:
        print("login...")
        response = request_retry(method="POST", url=f"{mattermost_url}/api/v4/users/login", json=payload, headers={"X-Requested-With": "XMLHttpRequest"})
        print(f"finalizing...{response.status_code}")
    except Exception as e:
        print(e)
        raise(e)

    mmauthtoken = response.cookies["MMAUTHTOKEN"]
    mmcsrf = response.cookies["MMCSRF"]
    mmuserid = response.cookies["MMUSERID"]

    return mmauthtoken, mmcsrf, mmuserid

def create_team(mattermost_url, name, display_name, mmauthtoken):
    payload = {
        "name": name,
        "display_name": display_name,
        "type": "O"
    }
    cookies = {
        "MMAUTHTOKEN": mmauthtoken
    }

    try:
        print("create team...")
        response = request_retry(method="POST", url=f"{mattermost_url}/api/v4/teams", json=payload, headers={"X-Requested-With": "XMLHttpRequest"}, cookies=cookies)
        print(f"finalizing...{response.status_code}")
    except Exception as e:
        print(e)
        raise(e)

    try:
        print("get team...")
        response = request_retry(method="GET", url=f"{mattermost_url}/api/v4/users/me/teams", headers={"X-Requested-With": "XMLHttpRequest"}, cookies=cookies)
        print(f"finalizing...{response.status_code}")
    except Exception as e:
        print(e)
        raise(e)

    for team in response.json():
        if team['name'] == name:
            return team['id']

    return None

def create_channel(mattermost_url, team_id, name, display_name, mmauthtoken):
    payload = {
        "team_id": team_id,
        "name": name,
        "display_name": display_name,
        "type": "O"
    }
    cookies = {
        "MMAUTHTOKEN": mmauthtoken
    }

    try:
        print("create channels...")
        response = request_retry(method="POST", url=f"{mattermost_url}/api/v4/channels", json=payload, headers={"X-Requested-With": "XMLHttpRequest"}, cookies=cookies)
        print(f"finalizing...{response.status_code}")
    except Exception as e:
        print(e)
        raise(e)

    try:
        print("get channels...")
        response = request_retry(method="GET", url=f"{mattermost_url}/api/v4/channels", headers={"X-Requested-With": "XMLHttpRequest"}, cookies=cookies)
        print(f"finalizing...{response.status_code}")
    except Exception as e:
        print(e)
        raise(e)

    for channel in response.json():
        if channel['name'] == name:
            return channel['id']

    return None

def create_webhook(mattermost_url, channel_id, display_name, description, mmauthtoken):
    payload = {
        "channel_id": channel_id,
        "display_name": display_name,
        "description": description
    }
    cookies = {
        "MMAUTHTOKEN": mmauthtoken
    }

    try:
        print("create webhook...")
        response = request_retry(method="POST", url=f"{mattermost_url}/api/v4/hooks/incoming", json=payload, headers={"X-Requested-With": "XMLHttpRequest"}, cookies=cookies)
        print(f"finalizing...{response.status_code}")
    except Exception as e:
        print(e)
        raise(e)

    return response.json()['id']

class CustomHeaderHandler(BaseHTTPRequestHandler):

    def do_HEAD(self):
        if '/_login' in self.path:
            host = self.headers.get('Host', f"{self.server.server_name}:{self.server.server_port}")
            #print(host)

            self.send_response(http.HTTPStatus.FOUND) # equivalent to 302
            # 2. Provide the destination URL in the 'Location' header
            self.send_header('Location', f"{self.redirect_path}")
            self.end_headers()

    def do_GET(self):
        if '/_login' in self.path:
            host = self.headers.get('Host', f"{self.server.server_name}:{self.server.server_port}")
            #print(host)

            self.send_response(http.HTTPStatus.FOUND) # equivalent to 302
            # 2. Provide the destination URL in the 'Location' header
            self.send_header('Location', f"{self.redirect_path}")
            self.end_headers()

    def do_POST(self):
        if '/_hooks' in self.path:
            
            print(self.headers.get('content-type'))
            if self.headers.get('content-type') != 'application/json':
                self.send_response(400)
                super().end_headers()
                return
                
            # read the message and convert it into a python dictionary
            length = int(self.headers.get('content-length'))
            payload = json.loads(self.rfile.read(length))

            print(payload)

            #host = self.headers.get('Host', f"{self.server.server_name}:{self.server.server_port}")
            response = requests.post(f"{self.mm_url + self.webhook_path}", json=payload, headers={'Accept': 'application/json'})
            print(response.text)

            # send the message back
            self.send_response(response.status_code)
            self.send_header('Content-type', 'text/plain')
            super().end_headers()
            self.wfile.write(response.text.encode('utf-8'))

    def __init__(self, mm_url, mmauthtoken, mmcsrf, mmuserid, redirect_path, webhook_path, *args, **kwargs):
        self.mm_url = mm_url
        self.mmauthtoken = mmauthtoken
        self.mmcsrf = mmcsrf
        self.mmuserid = mmuserid
        self.redirect_path = redirect_path
        self.webhook_path = webhook_path
        super().__init__(*args, **kwargs)

    def end_headers(self):

        host = self.headers.get('Host', f"{self.server.server_name}:{self.server.server_port}")

# 1. Initialize the SimpleCookie object
        cookie = SimpleCookie()
        
        # 2. Set the cookie value and attributes
        cookie["MMUSERID"] = self.mmuserid
        cookie["MMUSERID"]["path"] = "/"
       # cookie["MMUSERID"]["httponly"] = True  # Protects against XSS attacks
        cookie["MMUSERID"]["max-age"] = 15552000   # Expires in 1 hour (in seconds)
        future_utc = datetime.now(timezone.utc) + timedelta(hours=4320)
        cookie["MMUSERID"]["expires"] = future_utc.strftime("%a, %d %b %Y %H:%M:%S GMT")

        cookie["MMUSERID"]["expires"] = "Tue, 06 Apr 2027 18:40:52 GMT"

        cookie["MMAUTHTOKEN"] = self.mmauthtoken
        cookie["MMAUTHTOKEN"]["path"] = "/"
        cookie["MMAUTHTOKEN"]["httponly"] = True  # Protects against XSS attacks
        cookie["MMAUTHTOKEN"]["max-age"] = 15552000   # Expires in 1 hour (in seconds)
        future_utc = datetime.now(timezone.utc) + timedelta(hours=4320)
        cookie["MMAUTHTOKEN"]["expires"] = future_utc.strftime("%a, %d %b %Y %H:%M:%S GMT")

        cookie["MMCSRF"] = self.mmcsrf
        cookie["MMCSRF"]["path"] = "/"
        #cookie["MMCSRF"]["httponly"] = True  # Protects against XSS attacks
        cookie["MMCSRF"]["max-age"] = 15552000   # Expires in 1 hour (in seconds)
        future_utc = datetime.now(timezone.utc) + timedelta(hours=4320)
        cookie["MMCSRF"]["expires"] = future_utc.strftime("%a, %d %b %Y %H:%M:%S GMT")

        # 4. Output the Set-Cookie header string
        # cookie.output() generates headers formatted like: "Set-Cookie: user_session=xyz123abc; ..."
        for morsel in cookie.values():
            self.send_header("Set-Cookie", morsel.OutputString())

        # 2. Always call the parent class end_headers to finish the block
        super().end_headers()

def run_server(mm_url, mmauthtoken, mmcsrf, mmuserid, redirect_path, webhook_path):
    server_address = ('', 8000)
    handler = partial(CustomHeaderHandler, mm_url, mmauthtoken, mmcsrf, mmuserid, redirect_path, webhook_path)
    httpd = HTTPServer(server_address, handler)
    print("Serving on port 8000...")
    httpd.serve_forever()

@click.command()
@click.option('--mm_url', default="", help='')
@click.option('--mm_user', default="user", help='')
@click.option('--mm_password', default="password", help='')
@click.option('--mm_team', default="it", help='')
@click.option('--mm_channel', default="incidents", help='')
@click.option('--mm_webhook', default="elastic", help='')
@click.option('--redirect_path', default='/it/channels/incidents', help='')
def main(mm_url, mm_user, mm_password, mm_team, mm_channel, mm_webhook, redirect_path):

    mmauthtoken, mmcsrf, mmuserid = login(mm_url, mm_user, mm_password)
    print(mmauthtoken, mmcsrf, mmuserid)
    team_id = create_team(mm_url, mm_team, mm_team, mmauthtoken)
    print(team_id)
    channel_id = create_channel(mm_url, team_id, mm_channel, mm_channel, mmauthtoken)
    print(channel_id)
    webhook_id = create_webhook(mm_url, channel_id, mm_webhook, mm_webhook, mmauthtoken)
    print(webhook_id)

    webhook_path = f"/hooks/{webhook_id}"

    run_server(mm_url, mmauthtoken, mmcsrf, mmuserid, redirect_path, webhook_path)

if __name__ == '__main__':
    main()
