# Availability zones = separate data centres in the region (ap-south-1a, 1b ...).
data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  azs = slice(data.aws_availability_zones.available.names, 0, var.az_count)
}

resource "aws_vpc" "this" {
  cidr_block           = var.cidr
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = {
    Name = "vpc-${var.name}"
  }
}

# PUBLIC subnets (one per AZ): only for internet-facing load balancers and
# the NAT gateway. cidrsubnet() cuts the VPC range into pieces:
# 10.10.0.0/24, 10.10.1.0/24
resource "aws_subnet" "public" {
  count             = var.az_count
  vpc_id            = aws_vpc.this.id
  availability_zone = local.azs[count.index]
  cidr_block        = cidrsubnet(var.cidr, 8, count.index)
  tags = {
    Name                     = "${var.name}-public-${local.azs[count.index]}"
    "kubernetes.io/role/elb" = "1" # "put internet-facing load balancers here"
  }
}

# PRIVATE subnets (one per AZ): the Kubernetes nodes live here, with no
# public IPs. 10.10.16.0/20, 10.10.32.0/20
resource "aws_subnet" "private" {
  count             = var.az_count
  vpc_id            = aws_vpc.this.id
  availability_zone = local.azs[count.index]
  cidr_block        = cidrsubnet(var.cidr, 4, count.index + 1)
  tags = {
    Name                              = "${var.name}-private-${local.azs[count.index]}"
    "kubernetes.io/role/internal-elb" = "1"
  }
}

# Door to the internet for the public subnets.
resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id
  tags = {
    Name = "igw-${var.name}"
  }
}

# FIXED public IP for everything leaving the cluster (MongoDB Atlas allow-list).
resource "aws_eip" "nat" {
  domain = "vpc"
  tags = {
    Name = "eip-${var.name}-nat"
  }
}

# ONE NAT gateway (cost saving). Production would use one per AZ so a
# whole-AZ outage can't cut the nodes off from the internet.
resource "aws_nat_gateway" "this" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public[0].id
  tags = {
    Name = "nat-${var.name}"
  }
  depends_on = [aws_internet_gateway.this]
}

# Routing: public subnets -> internet gateway; private subnets -> NAT.
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.this.id
  }
  tags = {
    Name = "rt-${var.name}-public"
  }
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.this.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.this.id
  }
  tags = {
    Name = "rt-${var.name}-private"
  }
}

resource "aws_route_table_association" "public" {
  count          = var.az_count
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "private" {
  count          = var.az_count
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}
