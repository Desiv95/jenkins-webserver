
# ---------------- VPC ----------------
resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
}

# ---------------- Internet Gateway ----------------
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
}

# ---------------- Public Subnet ----------------
resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true
}

# ---------------- Route Table ----------------
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
}

# ---------------- Route Table Association ----------------
resource "aws_route_table_association" "public_assoc" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public_rt.id
}

# ---------------- Security Group ----------------
resource "aws_security_group" "web_sg" {
  name   = "nginx-flask-sg"
  vpc_id = aws_vpc.main.id

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

# ---------------- EC2 Instance ----------------
resource "aws_instance" "web" {
  ami                         = "ami-05d2d839d4f73aafb"
  instance_type               = var.instance_type
  key_name                    = var.key_name
  subnet_id                   = aws_subnet.public.id
  vpc_security_group_ids      = [aws_security_group.web_sg.id]
  associate_public_ip_address = true

  user_data = <<-EOF
#!/bin/bash
exec > /var/log/user-data.log 2>&1
set -ex

apt-get update -y
apt-get install -y python3-pip nginx

pip3 install flask gunicorn

# Create Flask app
cat <<EOF_APP > /home/ubuntu/app.py
from flask import Flask
app = Flask(__name__)

@app.route('/')
def hello():
    return "<h1>Hello from Flask via Nginx</h1>"

if __name__ == "__main__":
    app.run(host='127.0.0.1', port=5000)
EOF_APP

chown ubuntu:ubuntu /home/ubuntu/app.py

# Create systemd service for Gunicorn (BEST PRACTICE)
cat <<EOF_SERVICE > /etc/systemd/system/gunicorn.service
[Unit]
Description=Gunicorn Flask App
After=network.target

[Service]
User=ubuntu
WorkingDirectory=/home/ubuntu
ExecStart=/usr/local/bin/gunicorn --bind 127.0.0.1:5000 app:app
Restart=always

[Install]
WantedBy=multi-user.target
EOF_SERVICE

# Start Gunicorn properly
systemctl daemon-reexec
systemctl daemon-reload
systemctl start gunicorn
systemctl enable gunicorn

# Configure Nginx
cat <<EOF_NGINX > /etc/nginx/sites-available/default
server {
    listen 80;

    location / {
        proxy_pass http://127.0.0.1:5000;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    }
}
EOF_NGINX

systemctl restart nginx
systemctl enable nginx

  tags = {
    Name = "Nginx-Flask-Server"
  }
}
