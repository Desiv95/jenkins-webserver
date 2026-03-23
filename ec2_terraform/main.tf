provider "aws" {
  region = var.region
}

# Security Group
resource "aws_security_group" "web_sg" {
  name = "nginx-flask-sg"

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# EC2 Instance (Ubuntu)
resource "aws_instance" "web" {
  ami           = "ami-05d2d839d4f73aafb"
  instance_type = var.instance_type
  key_name      = var.key_name

  vpc_security_group_ids = [aws_security_group.web_sg.id]

  user_data_replace_on_change = true

  user_data = <<-EOF
#!/bin/bash

# Avoid interactive prompts
export DEBIAN_FRONTEND=noninteractive

# Update system
apt-get update -y

# Install packages
apt-get install -y python3-pip nginx

# Install Python dependencies
pip3 install flask gunicorn

# Move to ubuntu home
cd /home/ubuntu

# Create Flask app
cat <<EOT > app.py
from flask import Flask
app = Flask(__name__)

@app.route('/')
def home():
    return "Hello from Flask via Nginx 🚀"
EOT

# Change ownership (important)
chown ubuntu:ubuntu /home/ubuntu/app.py

# Run Gunicorn as ubuntu user
sudo -u ubuntu nohup gunicorn -w 4 -b 127.0.0.1:5000 app:app > /home/ubuntu/app.log 2>&1 &

# Configure Nginx
cat <<EOT > /etc/nginx/sites-available/default
server {
    listen 80;

    location / {
        proxy_pass http://127.0.0.1:5000;
        proxy_set_header Host \\$host;
        proxy_set_header X-Real-IP \\$remote_addr;
    }
}
EOT

# Restart Nginx
systemctl restart nginx
systemctl enable nginx

EOF

  tags = {
    Name = "Nginx-Flask-Server"
  }
}
