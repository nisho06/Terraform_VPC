resource "aws_vpc" "terraform_vpc" {
  cidr_block = var.cidr

  tags = {
    "project" = "terraform"
  }

}

resource "aws_subnet" "subnet1" {
  // refer the above VPC using aws_vpc.terraform_vpc 
  vpc_id                  = aws_vpc.terraform_vpc.id
  cidr_block              = "10.0.0.0/24"
  availability_zone       = "eu-west-2a"
  map_public_ip_on_launch = true
  tags = {
    "project" = "terraform"
  }
}

resource "aws_subnet" "subnet2" {
  // refer the above VPC using aws_vpc.terraform_vpc 
  vpc_id            = aws_vpc.terraform_vpc.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "eu-west-2b"
  // The below configuration makes the difference between public and private subnets.
  map_public_ip_on_launch = true
  tags = {
    "project" = "terraform"
  }
}

resource "aws_internet_gateway" "terraform_igw" {
  vpc_id = aws_vpc.terraform_vpc.id
  tags = {
    "project" = "terraform"
  }
}

// Create route table for the public subnet
resource "aws_route_table" "rtb_terraform" {
  vpc_id = aws_vpc.terraform_vpc.id

  // Single route which has the destination of 0.0.0.0/0 and the targe of aws_internet_gateway.terraform_igw.id 
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.terraform_igw.id
  }

  tags = {
    "project" = "terraform"
  }
}

// associate the route table with the public subnet 1
resource "aws_route_table_association" "rtb_subnet_association_1" {
  route_table_id = aws_route_table.rtb_terraform.id
  subnet_id      = aws_subnet.subnet1.id
}

// associate the route table with the public subnet 2
resource "aws_route_table_association" "rtb_subnet_association_2" {
  route_table_id = aws_route_table.rtb_terraform.id
  subnet_id      = aws_subnet.subnet2.id
}

resource "aws_security_group" "sg_subnet" {
  name   = "sg_subnet"
  vpc_id = aws_vpc.terraform_vpc.id

  // Allowing inbound traffic to port 80 from all the ip ranges (HTTP communication)
  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  // Allowing inbound traffic to port 22 from all the ip ranges (SSH communication)
  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  // Allowing outbound traffic to all the ports and all the ip ranges
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    "project" = "terraform"
  }

}

// AWS S3 bucket configuration is as follows. If you want enable more configurations like static website hosting, bucket versioning etc, 
// then you need to create different resource and point out to this S3 bucket.

// Note:- s3 bucket name needs to be unique across global.
resource "aws_s3_bucket" "s3_terraform" {
  bucket = "s3-terraform-nisho"

  tags = {
    "project" = "terraform"
  }
}

resource "aws_instance" "server-west-2a" {
  ami                         = "ami-07c1b39b7b3d2525d"
  instance_type               = "t2.micro"
  subnet_id                   = aws_subnet.subnet1.id
  associate_public_ip_address = true
  vpc_security_group_ids      = [aws_security_group.sg_subnet.id]
  user_data                   = base64encode(file("ec2_1.sh"))

  tags = {
    "project" = "terraform"
  }
}

resource "aws_instance" "server-west-2b" {
  ami                         = "ami-07c1b39b7b3d2525d"
  instance_type               = "t2.micro"
  subnet_id                   = aws_subnet.subnet2.id
  associate_public_ip_address = true
  vpc_security_group_ids      = [aws_security_group.sg_subnet.id]
  user_data                   = base64encode(file("ec2_2.sh"))

  tags = {
    "project" = "terraform"
  }
}

resource "aws_lb" "lb_terraform" {
  name               = "lb-terraform"
  internal           = false
  load_balancer_type = "application"

  security_groups = [aws_security_group.sg_subnet.id]

  // Provide subnet association to the load balancer.
  subnets = [aws_subnet.subnet1.id, aws_subnet.subnet2.id]

  tags = {
    "project" = "terraform"
  }
}

resource "aws_lb_target_group" "target_group_terraform" {
  name     = "tg-terraform"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.terraform_vpc.id

  health_check {
    path = "/"
    port = "traffic-port"
  }

  tags = {
    "project" = "terraform"
  }
}

resource "aws_lb_target_group_attachment" "target_group_attachement_subnet1_terraform" {
  target_group_arn = aws_lb_target_group.target_group_terraform.arn
  target_id        = aws_instance.server-west-2a.id
  port             = 80

}

resource "aws_lb_target_group_attachment" "target_group_attachement_subnet2_terraform" {
  target_group_arn = aws_lb_target_group.target_group_terraform.arn
  target_id        = aws_instance.server-west-2b.id
  port             = 80

}

resource "aws_lb_listener" "lb_listener" {
  load_balancer_arn = aws_lb.lb_terraform.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    target_group_arn = aws_lb_target_group.target_group_terraform.arn
    type             = "forward"
  }

  tags = {
    "project" = "terraform"
  }

}

output "loadBalancerDns" {
  value = aws_lb.lb_terraform.dns_name

}
