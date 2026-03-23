from flask import Flask

app = Flask(__name__)

@app.route('/')
def home():
    return "Hello from Flask via Nginx "

@app.route('/health')
def health():
    return {"status": "ok"}, 200

# IMPORTANT:
# Do NOT rely on this for production when using Gunicorn
# Gunicorn will run the app using: app:app
if __name__ == '__main__':
    app.run(host='127.0.0.1', port=5000)
