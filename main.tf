# --- 1. PROVIDER CONFIGURATION ---
# Tells Terraform to use AWS and which version
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

# --- 2. NETWORK (VPC) ---
# Creates your private "sandbox" in the cloud
resource "aws_vpc" "devops_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  tags = {
    Name = "devops-lab-vpc"
  }
}

# The "Front Door" to let internet traffic in/out
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.devops_vpc.id
}

# A slice of the network where our servers will live
resource "aws_subnet" "public_subnet" {
  vpc_id                  = aws_vpc.devops_vpc.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true
  availability_zone       = "us-east-1a"
}

# The "GPS" that tells traffic to go through the Internet Gateway
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.devops_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
}

resource "aws_route_table_association" "public_assoc" {
  subnet_id      = aws_subnet.public_subnet.id
  route_table_id = aws_route_table.public_rt.id
}

# --- 3. SECURITY (FIREWALL) ---
# Rules to allow you to talk to your servers
resource "aws_security_group" "devops_sg" {
  name        = "devops-lab-sg"
  description = "Allow SSH and Web traffic"
  vpc_id      = aws_vpc.devops_vpc.id

  # SSH (Port 22) - So you can log in from your Mac
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # HTTP (Port 80) - For the web servers we will build
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow the servers to reach out to the internet (to download updates/Docker)
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# 1. Tell AWS about your Public Key
resource "aws_key_pair" "devops_auth" {
  key_name   = "devops-key"
  public_key = file("devops-key.pub") # This reads the file you just created
}

# 2. The Reverse Proxy Server (Ubuntu)
resource "aws_instance" "proxy_server" {
  instance_type          = "t2.micro" # Free Tier eligible
  ami                    = "ami-080e1f13689e07408" # Ubuntu 22.04 LTS in us-east-1
  key_name               = aws_key_pair.devops_auth.key_name
  vpc_security_group_ids = [aws_security_group.devops_sg.id]
  subnet_id              = aws_subnet.public_subnet.id

  tags = {
    Name = "nginx-proxy"
  }
}

# 3. The Build Agent Server (Ubuntu)
resource "aws_instance" "build_agent" {
  instance_type          = "t2.micro"
  ami                    = "ami-080e1f13689e07408"
  key_name               = aws_key_pair.devops_auth.key_name
  vpc_security_group_ids = [aws_security_group.devops_sg.id]
  subnet_id              = aws_subnet.public_subnet.id

  tags = {
    Name = "build-agent"
  }
}

# 4. Output the IPs so we know how to connect
output "proxy_ip" {
  value = aws_instance.proxy_server.public_ip
}

output "agent_ip" {
  value = aws_instance.build_agent.public_ip
}
