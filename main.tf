# 1. Provider and Region
provider "aws" {
  region = "us-east-1"
}

# 2. Network: VPC
resource "aws_vpc" "devops_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "devops-lab-vpc"
  }
}

# 3. Network: Internet Gateway
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.devops_vpc.id
}

# 4. Network: Public Subnet
resource "aws_subnet" "public_subnet" {
  vpc_id                  = aws_vpc.devops_vpc.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true
  availability_zone       = "us-east-1a"
}

# 5. Network: Route Table
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

# 6. Security: Firewall (Security Group)
resource "aws_security_group" "devops_sg" {
  name        = "devops-lab-sg"
  description = "Allow SSH and Web traffic"
  vpc_id      = aws_vpc.devops_vpc.id

  # SSH Access
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Standard Web Traffic
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Docker App Traffic
  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Outbound (allow servers to talk to the internet)
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# 7. Keys: SSH Key Pair
resource "aws_key_pair" "devops_auth" {
  key_name   = "devops-key"
  public_key = file("devops-key.pub")
}

# 8. Compute: Nginx Proxy Server
resource "aws_instance" "proxy_server" {
  ami                    = "ami-080e1f13689e07408"
  instance_type          = "t2.micro"
  key_name               = aws_key_pair.devops_auth.key_name
  vpc_security_group_ids = [aws_security_group.devops_sg.id]
  subnet_id              = aws_subnet.public_subnet.id

  tags = {
    Name = "nginx-proxy"
  }
}

# 9. Compute: CI/CD Build Agent
resource "aws_instance" "build_agent" {
  ami                    = "ami-080e1f13689e07408"
  instance_type          = "t2.micro"
  key_name               = aws_key_pair.devops_auth.key_name
  vpc_security_group_ids = [aws_security_group.devops_sg.id]
  subnet_id              = aws_subnet.public_subnet.id

  tags = {
    Name = "build-agent"
  }
}

# 10. Outputs (IP addresses for Ansible)
output "proxy_ip" {
  value = aws_instance.proxy_server.public_ip
}

output "agent_ip" {
  value = aws_instance.build_agent.public_ip
}