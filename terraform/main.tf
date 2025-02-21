# Provider configuration for AWS
provider "aws" {
  region = "us-east-1"  # Set the AWS region for resources
}

# Fetch the latest Ubuntu AMI dynamically based on filters
data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"] # Canonical (owner ID)
}

# Fetch the latest Amazon Linux 2 AMI dynamically based on filters
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }

  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# Fetch the default VPC
data "aws_vpc" "default" {
  default = true
}

# Fetch the default public subnets in the VPC
data "aws_subnet_ids" "default_public_subnets" {
  vpc_id = data.aws_vpc.default.id
}

# Security Group for EC2 instances (SSH, HTTP, HTTPS)
resource "aws_security_group" "web_sg" {
  name        = "web-server-sg"
  description = "Allow SSH, HTTPS and HTTP traffic"
  vpc_id      = data.aws_vpc.default.id

  # SSH ingress rule (port 22)
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # Change for better security
  }

  # HTTP ingress rule (port 80)
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # HTTPS ingress rule (port 443)
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Egress rule (allow all outbound traffic)
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "web-server-sg"
  }
}

# Security Group for the Application Load Balancer (ALB) (SSH, HTTP, HTTPS)
resource "aws_security_group" "alb_sg" {
  name        = "alb-sg"
  description = "Allow SSH, HTTPS and HTTP traffic"
  vpc_id      = data.aws_vpc.default.id

  # HTTP ingress rule (port 80)
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # HTTPS ingress rule (port 443)
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Egress rule (allow all outbound traffic)
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "alb-sg"
  }
}

# Use an existing Key Pair for EC2 instances (instead of generating one)
resource "aws_key_pair" "deployer" {
  key_name   = "web-server-key"
  public_key = file("server.pem")  # Ensure the corresponding public key exists
}

# Create the Ubuntu EC2 instance
resource "aws_instance" "web_ubuntu" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type
  key_name               = "web-server-key"
  vpc_security_group_ids = [aws_security_group.web_sg.id]

  # User data script for Ubuntu instance
  user_data = file("userdata_ubuntu.sh")
  tags = {
    Name = "ubuntu-web-server"
  }
}

# Create the Amazon Linux EC2 instance
resource "aws_instance" "web_linux" {
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = var.instance_type
  key_name               = "web-server-key"
  vpc_security_group_ids = [aws_security_group.web_sg.id]

  # User data script for Amazon Linux instance
  user_data = file("userdata_linux.sh")
  tags = {
    Name = "amazon-linux-web-server"
  }
}

# Variable for EC2 instance type
variable "instance_type" {
  description = "Instance type for EC2 instances"
  default     = "t3.micro"  # Modify this as needed
}

# Output the public IP of the Ubuntu instance
output "ubuntu_public_ip" {
  value = aws_instance.web_ubuntu.public_ip
}

# Output the public IP of the Amazon Linux instance
output "amazon_linux_public_ip" {
  value = aws_instance.web_linux.public_ip
}

# Application Load Balancer (ALB) configuration

# Create the Target Group for the ALB
resource "aws_lb_target_group" "web_target_group" {
  name     = "web-target-group"
  port     = 80
  protocol = "HTTP"
  vpc_id   = data.aws_vpc.default.id

  # Health check configuration for the target group
  health_check {
    path                = "/"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 3
    unhealthy_threshold = 3
  }

  tags = {
    Name = "web-target-group"
  }
}

# Register EC2 instances (both Ubuntu and Amazon Linux) with the Target Group
resource "aws_lb_target_group_attachment" "web_attachment_ubuntu" {
  target_group_arn = aws_lb_target_group.web_target_group.arn
  target_id        = aws_instance.web_ubuntu.id
  port             = 80
}

resource "aws_lb_target_group_attachment" "web_attachment_linux" {
  target_group_arn = aws_lb_target_group.web_target_group.arn
  target_id        = aws_instance.web_linux.id
  port             = 80
}

# Create the Application Load Balancer (ALB)
resource "aws_lb" "web_alb" {
  name               = "web-alb"
  internal           = false  # Make it external
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = data.aws_subnet_ids.default_public_subnets.ids  # Use default public subnets
  enable_deletion_protection = false

  enable_cross_zone_load_balancing = true

  tags = {
    Name = "web-alb"
  }
}

# Create the listener for the ALB (HTTP)
resource "aws_lb_listener" "web_listener" {
  load_balancer_arn = aws_lb.web_alb.arn
  port              = "80"
  protocol          = "HTTP"

  # Default action for the listener (return a fixed response)
  default_action {
    type             = "fixed-response"
    fixed_response {
      status_code = 200
      content_type = "text/plain"
      message_body = "OK"
    }
  }
}

# Output the DNS name of the ALB
output "alb_dns_name" {
  value = aws_lb.web_alb.dns_name
}
