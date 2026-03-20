provider "aws" {
  region = var.region
}

#  Security Group
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

#  EC2 Instance (Ubuntu)
resource "aws_instance" "web" {
  ami           = "ami-0e670eb768a5fc3d4" 
  instance_type = var.instance_type
  key_name      = var.key_name

  vpc_security_group_ids = [aws_security_group.web_sg.id]

  user_data = <<-EOF
              #!/bin/bash
              apt update -y
              apt install -y python3-pip nginx

              pip3 install flask gunicorn

              # Create Flask App
              cat <<EOT > /home/ubuntu/app.py
              from flask import Flask
              app = Flask(__name__)

              @app.route('/')
              def home():
                  return "Hello from Flask via Nginx 🚀"

              if __name__ == '__main__':
                  app.run(host='127.0.0.1', port=5000)
              EOT

              # Run app with Gunicorn
              nohup gunicorn -w 4 -b 127.0.0.1:5000 app:app &

              # Configure Nginx
              cat <<EOT > /etc/nginx/sites-available/default
              server {
                  listen 80;

                  location / {
                      proxy_pass http://127.0.0.1:5000;
                      proxy_set_header Host \$host;
                      proxy_set_header X-Real-IP \$remote_addr;
                  }
              }
              EOT

              systemctl restart nginx
              systemctl enable nginx
              EOF

  tags = {
    Name = "Nginx-Flask-Server"
  }
}