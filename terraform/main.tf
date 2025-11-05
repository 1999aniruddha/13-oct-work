terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# 🔹 Fetch the latest Ubuntu 20.04 LTS AMI for the region
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }
}

# 🔹 Security group allowing SSH + HTTP
resource "aws_security_group" "web_sg" {
  name        = "${var.name}-sg"
  description = "Allow HTTP and SSH traffic"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

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
    Name        = "${var.name}-sg"
    Environment = "CICD"
    ManagedBy   = "Jenkins"
  }
}

# 🔹 EC2 instance definition
resource "aws_instance" "web" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type                = var.instance_type
  key_name                     = var.key_name
  associate_public_ip_address   = true
  vpc_security_group_ids        = [aws_security_group.web_sg.id]

  tags = {
    Name        = var.name
    Environment = "CICD"
    ManagedBy   = "Jenkins"
  }
}

# 🔹 Output the instance public IP so Jenkins can pick it up
output "public_ip" {
  value       = aws_instance.web.public_ip
  description = "The public IP of the EC2 instance"
}

}




