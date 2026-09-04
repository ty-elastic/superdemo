import requests
from bs4 import BeautifulSoup
import click

def create_elasticsearch_connection(logstashui_url, es_url, es_apikey):
    # 1. Initialize a persistent session
    session = requests.Session()

    # 2. Add standard browser headers to look human
    session.headers.update({
        'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/152.0.0.0 Safari/537.36'
    })

    # 3. Navigate to the login page or entrypoint
    login_url = f"{logstashui_url}/ConnectionManager"
    response = session.get(login_url)

    soup = BeautifulSoup(response.text, 'html.parser')
    csrf_token = soup.find('input', {'name': 'csrfmiddlewaretoken'})['value']

    # 4. Prepare your payload containing form details AND the token
    payload = {
        'csrfmiddlewaretoken': csrf_token,
        'connection_type': "CENTRALIZED",
        'name': 'superdemo',
        "connection_mode": "url",
        "host": es_url,
        "port": "443",
        "auth_type": "apiKey",
        "api_key": es_apikey,
        "agent_policy": "packaged policy",
        "enrollment_token": "1",
        "package_manager": "apt"
    }

    # 5. Set headers to satisfy strict middleware checks
    headers = {
        "HX-Current-URL": f"{logstashui_url}/ConnectionManager/#",
        "HX-Request": "true",
        "HX-Target": "connectionForm",
        "HX-Trigger": "connectionForm",

        "Origin": f"{logstashui_url}",
        'Referer': f"{logstashui_url}/ConnectionManager/",              # Django often requires strict referer checks
        'X-CSRFToken': csrf_token          # Some systems require it as a header too
    }

    post_response = session.post(f"{logstashui_url}/ConnectionManager/AddConnection", data=payload, headers=headers)
    print(post_response.text)

@click.command()
@click.option('--logstashui_url', default="", help='address of kibana server')
@click.option('--es_url', default=None, help='address of iis server')
@click.option('--es_apikey', default="", help='address of elasticsearch server')
@click.argument('action')
def main(logstashui_url, es_url, es_apikey, action):

    if action == 'create_elasticsearch_connection':
        create_elasticsearch_connection(logstashui_url, es_url, es_apikey)

if __name__ == '__main__':
    main()