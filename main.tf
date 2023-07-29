# main.tf

# Provider Configuration
provider "aws" {
  region = "ap-south-1" # Change to your desired AWS region

  access_key = "AKIARTK54MSXNJSVQE52"    # Sample access key (for testing purposes only)
  secret_key = "eeTd7uCFBNEGlGZbEiQPvrz/5vOgfqQXHBGf7K7S"   # Sample secret access key (for testing purposes only)
}

# VPC Configuration
resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "MyVPC"
  }
}

# Public Subnet Configuration
resource "aws_subnet" "public1" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "ap-south-1a" # Change to your desired availability zone
  tags = {
    Name = "PublicSubnet1"
  }
}

resource "aws_subnet" "public2" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "ap-south-1b" # Change to your desired availability zone
  tags = {
    Name = "PublicSubnet2"
  }
}

# Internet Gateway Configuration
resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.main.id
}

# Route Table Configuration for Public Subnets
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }
}

# Associate Public Subnets with the Public Route Table
resource "aws_route_table_association" "public1" {
  subnet_id      = aws_subnet.public1.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "public2" {
  subnet_id      = aws_subnet.public2.id
  route_table_id = aws_route_table.public.id
}

# Security Group Configuration
resource "aws_security_group" "alb_sg" {
  name_prefix = "ALB-SG"

  # Inbound rule for SSH (port 22)
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Inbound rule for HTTP (port 80)
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Outbound rule to allow all traffic to the internet
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  vpc_id = aws_vpc.main.id
}

# Launch Configuration for EC2 Instances
resource "aws_launch_configuration" "example" {
  name_prefix          = "ex-"
  image_id             = "ami-0f5ee92e2d63afc18" # Replace with your desired AMI ID
  instance_type        = "t2.micro" # Change to your desired instance type
  security_groups      = [aws_security_group.alb_sg.id]
  associate_public_ip_address = true

  # Add user_data to install Apache2
  user_data = <<-EOF
            #!/bin/bash
            apt-get update
            apt-get install -y apache2
            systemctl enable apache2
            systemctl start apache2
            nohup git clone https://github.com/SumanthSamuel/AWS_Project1 /var/www/html/AWS_Project1 > /dev/null 2>&1 &
            echo '
            <VirtualHost *:80>
                DocumentRoot /var/www/html/AWS_Project1
                <Directory /var/www/html/AWS_Project1>
                    Options Indexes FollowSymLinks MultiViews
                    AllowOverride All
                    Order allow,deny
                    allow from all
                </Directory>
            </VirtualHost>
            ' > /etc/apache2/sites-available/000-default.conf
            systemctl restart apache2
            EOF



  # Add any additional configurations as required
}

# Application Load Balancer Configuration
resource "aws_lb" "example" {
  name               = "example-lb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = [aws_subnet.public1.id, aws_subnet.public2.id]

  # Add any additional configurations as required
}

# Target Group for ALB
resource "aws_lb_target_group" "example" {
  name_prefix      = "ex-tg-"
  port             = 80
  protocol         = "HTTP"
  vpc_id           = aws_vpc.main.id

  # Add any additional configurations as required
}

# ALB Listener Configuration
resource "aws_lb_listener" "example" {
  load_balancer_arn = aws_lb.example.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    target_group_arn = aws_lb_target_group.example.arn
    type             = "forward"
  }
}

# Auto Scaling Group Configuration
resource "aws_autoscaling_group" "example" {
  name_prefix          = "ex-asg-"
  vpc_zone_identifier = [aws_subnet.public1.id, aws_subnet.public2.id]
  launch_configuration = aws_launch_configuration.example.name
  min_size             = 2
  max_size             = 3
  target_group_arns    = [aws_lb_target_group.example.arn]

  # Add any additional configurations as required
}
