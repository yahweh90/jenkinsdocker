resource "aws_security_group" "alb_sg" {
  name        = "custom-alb-sg"
  description = "Security Group for Application Load Balancer"

  vpc_id = aws_vpc.custom_vpc.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "custom-alb-sg"
  }
}


//2. Security Group For EC2

resource "aws_security_group" "ec2_sg" {
  name        = "custom-ec2-sg"
  description = "Security Group for Webserver Instance"

  vpc_id = aws_vpc.custom_vpc.id

  ingress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    security_groups = [aws_security_group.alb_sg.id]

  }


  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "custom-ec2-sg"
  }
}

//3. Create The Application Load Balancer
resource "aws_lb" "app_lb" {
  name               = "custom-app-lb"
  load_balancer_type = "application"
  internal           = false
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = aws_subnet.public_subnet[*].id
  depends_on         = [aws_internet_gateway.internet_gateway]
}

//4. Create A Target Group

resource "aws_lb_target_group" "alb_ec2_tg" {
  name     = "custom-web-server-tg"
  port     = 80
  protocol = "HTTP"
  #target_type = "instance"
  vpc_id = aws_vpc.custom_vpc.id
  tags = {
    Name = "custom-alb_ec2_tg"

  }

}

//5. alb listener
resource "aws_lb_listener" "alb_listener" {
  load_balancer_arn = aws_lb.app_lb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.alb_ec2_tg.arn
  }
  tags = {
    Name = "custom-alb-listener"
  }
}

//6. Launch template for ec2 instance
resource "aws_launch_template" "ec2_launch_template" {
  name          = "custom-ec2-launch-template"
  image_id      = aws_ami_from_instance.example_ami.id
  instance_type = "t2.micro"

  network_interfaces {
    associate_public_ip_address = false
    security_groups             = [aws_security_group.ec2_sg.id]
  }

  user_data = filebase64("userdata.sh")

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "custom-ec2-web-server"
    }
  }
}

//7. Create Auto Scaling Group

resource "aws_autoscaling_group" "ec2_asg" {
  max_size            = 3
  min_size            = 2
  desired_capacity    = 2
  name                = "custom-web-server-asg"
  target_group_arns   = [aws_lb_target_group.alb_ec2_tg.arn]
  vpc_zone_identifier = aws_subnet.private_subnet[*].id

  launch_template {
    id      = aws_launch_template.ec2_launch_template.id
    version = "$Latest"
  }

  health_check_type = "EC2"
}

