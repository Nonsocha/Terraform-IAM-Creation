# main.tf
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.40"
    }
  }
}

provider "aws" {
  region = "us-west-1"  # Update your region
}

# Get latest Amazon Linux 2 AMI
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}

# Security group for provisioning instance
resource "aws_security_group" "provisioning_sg" {
  name        = "provisioning-sg"
  description = "Allow SSH for provisioning"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # Restrict to your IP in production
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# EC2 instance to be provisioned
resource "aws_instance" "provisioning_instance" {
  ami           = data.aws_ami.amazon_linux.id
  instance_type = "t2.micro"
  key_name      = "terraform-key"  # REPLACE WITH YOUR KEY PAIR NAME
  vpc_security_group_ids = [aws_security_group.provisioning_sg.id]

  # Provisioner to install software
  provisioner "remote-exec" {
    inline = [
      "sudo yum update -y",
      "sudo yum install -y nginx",
      "sudo systemctl start nginx",
      "sudo systemctl enable nginx",
      "sudo yum install -y amazon-efs-utils",  # Example: Install EFS utilities
      "echo 'Custom AMI created on $(date)' | sudo tee /etc/motd"
    ]

    connection {
      type        = "ssh"
      user        = "ec2-user"
      private_key = file("C:\\Users\\WILLIAMS\\Downloads\\terraform-key.pem")   # PATH TO YOUR PRIVATE KEY
      host        = self.public_ip
    }
  }

  tags = {
    Name = "AMI-Provisioning-Instance"
  }
}

# Create AMI from the provisioned instance
resource "aws_ami_from_instance" "custom_ami" {
  name               = "custom-provisioned-ami-${formatdate("YYYYMMDD-hhmmss", timestamp())}"
  description        = "AMI with Nginx and EFS utilities"
  source_instance_id = aws_instance.provisioning_instance.id

  tags = {
    Environment = "Production"
    Source      = "Terraform"
  }
}

# Output AMI information
output "custom_ami_id" {
  value = aws_ami_from_instance.custom_ami.id
}

output "custom_ami_name" {
  value = aws_ami_from_instance.custom_ami.name
}