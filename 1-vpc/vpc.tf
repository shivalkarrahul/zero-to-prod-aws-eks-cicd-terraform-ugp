# `terraform/01-vpc/vpc.tf`
#
# Provisions a highly available VPC with public and private subnets across three Availability Zones.

# Get the list of available Availability Zones in the region.
data "aws_availability_zones" "available" {
  state = "available"
}

# 1. VPC: Our virtual network.
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr_block
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "${var.project_name}-vpc"
  }
}

# 2. Internet Gateway: Allows the VPC to communicate with the internet.
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
  tags = {
    Name = "${var.project_name}-igw"
  }
}

# 3. Public Subnets: Three subnets in different AZs for public-facing resources.
resource "aws_subnet" "public" {
  count                   = 3
  vpc_id                  = aws_vpc.main.id
  cidr_block              = cidrsubnet(var.vpc_cidr_block, 8, count.index)
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name                                      = "${var.project_name}-public-subnet-${count.index + 1}"
    "kubernetes.io/cluster/${var.project_name}-cluster" = "owned"
    "kubernetes.io/role/elb"                  = "1"
  }
}

# 4. Private Subnets: Three subnets for private, internal resources (EKS nodes).
resource "aws_subnet" "private" {
  count                   = 3
  vpc_id                  = aws_vpc.main.id
  cidr_block              = cidrsubnet(var.vpc_cidr_block, 8, count.index + 3) # Adjusted for non-overlapping CIDRs
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = false

  tags = {
    Name                                      = "${var.project_name}-private-subnet-${count.index + 1}"
    "kubernetes.io/cluster/${var.project_name}-cluster" = "owned"
    "kubernetes.io/role/internal-elb"         = "1"
  }
}

# 5. NAT Gateways and EIPs for private subnet internet access.
# Now we create three NAT gateways for high availability across three AZs.
resource "aws_eip" "nat" {
  count = 3
  domain = "vpc"
  tags = {
    Name = "${var.project_name}-nat-eip-${count.index + 1}"
  }
}

resource "aws_nat_gateway" "main" {
  count         = 3
  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id

  tags = {
    Name = "${var.project_name}-nat-gateway-${count.index + 1}"
  }
}

# 6. Route Tables for public and private subnets.
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "${var.project_name}-public-rt"
  }
}

resource "aws_route_table" "private" {
  count  = 3
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main[count.index].id
  }

  tags = {
    Name = "${var.project_name}-private-rt-${count.index + 1}"
  }
}

# 7. Route Table Associations.
resource "aws_route_table_association" "public" {
  count          = 3
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "private" {
  count          = 3
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[count.index].id
}