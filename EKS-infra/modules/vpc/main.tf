# ==========================================
# 1. NETWORKING (VPC, Subnets, NAT Gateways)
# ==========================================

resource "aws_vpc" "eks_vpc" {
  cidr_block           = var.vpc_cidr

  tags = {
    Name = "microservices-eks-vpc"
    "kubernetes.io/cluster/${var.cluster_name}-cluster" = "shared"
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.eks_vpc.id
  tags   = { Name = "eks-igw" }
}

# Public Subnets (For Load Balancers)
resource "aws_subnet" "public_1" {
  vpc_id            = aws_vpc.eks_vpc.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "ap-southeast-1a"
  map_public_ip_on_launch = true

  tags = {
    Name = "eks-public-ap-southeast-1a"
    "kubernetes.io/cluster/${var.cluster_name}-cluster" = "shared"
    "kubernetes.io/role/elb"                  = "1" # Core tag for public ALBs/ELBs
  }
}

resource "aws_subnet" "public_2" {
  vpc_id            = aws_vpc.eks_vpc.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "ap-southeast-1b"
  map_public_ip_on_launch = true

  tags = {
    Name = "eks-public-ap-southeast-1b"
    "kubernetes.io/cluster/${var.cluster_name}-cluster" = "shared"
    "kubernetes.io/role/elb"                  = "1"
  }
}

# Private Subnets (For EKS Compute Nodes)
resource "aws_subnet" "private_1" {
  vpc_id            = aws_vpc.eks_vpc.id
  cidr_block        = "10.0.3.0/24"
  availability_zone = "ap-southeast-1a"

  tags = {
    Name = "eks-private-ap-southeast-1a"
    "kubernetes.io/cluster/${var.cluster_name}-cluster" = "shared"
    "kubernetes.io/role/internal-elb"         = "1" # Core tag for internal load balancers
  }
}

resource "aws_subnet" "private_2" {
  vpc_id            = aws_vpc.eks_vpc.id
  cidr_block        = "10.0.4.0/24"
  availability_zone = "ap-southeast-1b"

  tags = {
    Name = "eks-private-ap-southeast-1b"
    "kubernetes.io/cluster/${var.cluster_name}-cluster" = "shared"
    "kubernetes.io/role/internal-elb"         = "1"
  }
}

# NAT Gateway resources (Allows nodes in private subnets to pull images from Docker Hub)
resource "aws_eip" "nat_1" {
  domain = "vpc"
  tags   = { Name = "eks-nat1-eip" }
}

resource "aws_nat_gateway" "nat_1" {
  allocation_id = aws_eip.nat_1.id
  subnet_id     = aws_subnet.public_1.id
  tags          = { Name = "eks-nat1-gateway" }
  depends_on    = [aws_internet_gateway.igw]
}

resource "aws_eip" "nat_2" {
  domain = "vpc"
  tags   = { Name = "eks-nat2-eip" }
}

resource "aws_nat_gateway" "nat_2" {
  allocation_id = aws_eip.nat_2.id
  subnet_id     = aws_subnet.public_2.id
  tags          = { Name = "eks-nat2-gateway" }
  depends_on    = [aws_internet_gateway.igw]
}

# Route Tables
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.eks_vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
  tags = { Name = "eks-public-rt" }
}

resource "aws_route_table" "private_1" {
  vpc_id = aws_vpc.eks_vpc.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_1.id
  }
  tags = { Name = "eks-private-rt1" }
}

resource "aws_route_table" "private_2" {
  vpc_id = aws_vpc.eks_vpc.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_2.id
  }
  tags = { Name = "eks-private-rt2" }
}

# Route Table Associations
resource "aws_route_table_association" "public_1" {
  subnet_id      = aws_subnet.public_1.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "public_2" {
  subnet_id      = aws_subnet.public_2.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "private_1" {
  subnet_id      = aws_subnet.private_1.id
  route_table_id = aws_route_table.private_1.id
}

resource "aws_route_table_association" "private_2" {
  subnet_id      = aws_subnet.private_2.id
  route_table_id = aws_route_table.private_2.id
}