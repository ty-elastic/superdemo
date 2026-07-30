import os
import time
import requests
from flask import Flask, request, jsonify

app = Flask(__name__)
SERVICE = os.getenv("MY_NAME", "Service")
PEER = os.getenv("PEER_URL", "http://localhost:5000")

@app.route("/hi", methods=['POST'])
def home():
  data = request.get_json()
  return f"Hello from {data['name']}!\n"

def send_periodic_requests():
  # Wait for the peer server to start up
  time.sleep(3)
  while True:
    try:
      response = requests.post(f"{PEER}/hi", json={'name': SERVICE})
      print(f"[{SERVICE}] Got reply: {response.text.strip()}")
    except Exception as e:
      print(f"[{SERVICE}] Could not reach peer: {e}")
    time.sleep(5)

if __name__ == "__main__":
  import threading

  t = threading.Thread(target=send_periodic_requests, daemon=True)
  t.start()
  app.run(host="0.0.0.0", port=80)