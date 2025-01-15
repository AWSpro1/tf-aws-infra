provider "aws" {
  profile = var.aws_profile
  region  = var.aws_region
}

# Fetch a list of available availability zones
data "aws_availability_zones" "available" {
  state = "available"
}

# VPC
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = {
    Name = "${var.environment}-vpc"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
  tags = {
    Name = "${var.environment}-igw"
  }
}

# Public Subnets
resource "aws_subnet" "public" {
  count                   = 3
  vpc_id                  = aws_vpc.main.id
  cidr_block              = cidrsubnet(var.vpc_cidr, 3, count.index)
  map_public_ip_on_launch = true
  availability_zone       = element(data.aws_availability_zones.available.names, count.index)
  tags = {
    Name = "${var.environment}-public-subnet-${count.index}"
  }
}

# Private Subnets
resource "aws_subnet" "private" {
  count             = 3
  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 3, count.index + 3)
  availability_zone = element(data.aws_availability_zones.available.names, count.index)
  tags = {
    Name = "${var.environment}-private-subnet-${count.index}"
  }
}

# Public Route Table
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  tags = {
    Name = "${var.environment}-public-rt"
  }
}

# Route for Internet Access
resource "aws_route" "public" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.igw.id
}

# Associate Public Subnets with the Public Route Table
resource "aws_route_table_association" "public_subnet_association" {
  count          = 3
  subnet_id      = element(aws_subnet.public.*.id, count.index)
  route_table_id = aws_route_table.public.id
}

# Private Route Table
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id
  tags = {
    Name = "${var.environment}-private-rt"
  }
}

# Associate Private Subnets with the Private Route Table
resource "aws_route_table_association" "private_subnet_association" {
  count          = 3
  subnet_id      = element(aws_subnet.private.*.id, count.index)
  route_table_id = aws_route_table.private.id
}

resource "aws_security_group" "application_security_group" {
  name   = "application_security_group"
  vpc_id = aws_vpc.main.id

  ingress {
    from_port = 22
    to_port   = 22
    protocol  = "tcp"

    # Allow ssh from anywhere
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port = 80
    to_port   = 80
    protocol  = "tcp"

    # Allow HTTP traffic from anywhere
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port = 443
    to_port   = 443
    protocol  = "tcp"

    # Allow HTTPS trafic from anywhere
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port = var.app_port
    to_port   = var.app_port
    protocol  = "tcp"

    #Allow traffic on application specific port 
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Egress rules for outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1" # Allow all outbound traffic
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "application_security_group"
  }
}

data "aws_ssm_parameter" "latest_ami" {
  name = "latest-ami-id"
}

resource "aws_instance" "application_instance" {
  ami                     = data.aws_ssm_parameter.latest_ami.value # Uses AMI ID taken from Parameter Store
  instance_type           = "t2.micro"
  subnet_id               = element(aws_subnet.public.*.id, 0)                 # Attach to the first public subnet
  vpc_security_group_ids  = [aws_security_group.application_security_group.id] # Attach the application security group
  disable_api_termination = false                                              # Allow termination of the instance

  root_block_device {
    volume_size           = 25    # Root volume size in GiB
    volume_type           = "gp2" # General Purpose SSD
    delete_on_termination = true  # Ensure volume is deleted when the instance is terminated
  }

  tags = {
    Name = "${var.environment}-application-instance"
  }
}
