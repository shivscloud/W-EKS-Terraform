
# Create a VPC
resource "aws_vpc" "main" {
  cidr_block = var.vpc_cidr
}

# Create three public subnets
resource "aws_subnet" "public" {
  count           = 3
  vpc_id          = aws_vpc.main.id
  cidr_block      = element(var.publicsubnet_cidr, count.index)
  availability_zone = element(var.azs, count.index)
  map_public_ip_on_launch = true
}

# Create an internet gateway and associate it with the VPC
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
}

# Create a route table for the public subnets and associate it with the internet gateway
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
}

# Associate the public subnets with the public route table
resource "aws_route_table_association" "public" {
  count          = 3
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

resource "aws_route" "public" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"  # This matches all traffic (default route)
  gateway_id             = aws_internet_gateway.main.id  # Internet Gateway ID
}

