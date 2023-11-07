
# # Create a VPC
# resource "aws_vpc" "main" {
#   cidr_block = var.vpc_cidr
# }

# # Create three public subnets
# resource "aws_subnet" "public" {
#   count           = 3
#   vpc_id          = aws_vpc.main.id
#   cidr_block      = element(var.publicsubnet_cidr, count.index)
#   availability_zone = element(var.azs, count.index)
#   map_public_ip_on_launch = true
# }

# # Create an internet gateway and associate it with the VPC
# resource "aws_internet_gateway" "main" {
#   vpc_id = aws_vpc.main.id
# }

# # Create a route table for the public subnets and associate it with the internet gateway
# resource "aws_route_table" "public" {
#   vpc_id = aws_vpc.main.id
# }

# # Associate the public subnets with the public route table
# resource "aws_route_table_association" "public" {
#   count          = 3
#   subnet_id      = aws_subnet.public[count.index].id
#   route_table_id = aws_route_table.public.id
# }

# resource "aws_route" "public" {
#   route_table_id         = aws_route_table.public.id
#   destination_cidr_block = "0.0.0.0/0"  # This matches all traffic (default route)
#   gateway_id             = aws_internet_gateway.main.id  # Internet Gateway ID
# }

#######################################Module VPC##########################################
# AWS Availability Zones Datasource
data "aws_availability_zones" "available" {
}

# Create VPC Terraform Module
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  #version = "3.11.0"
  #version = "~> 3.11"
  version = "5.0.0"

  # VPC Basic Details
  name = "my-eks-cluster"
  cidr = var.vpc_cidr
  azs             = var.azs
  public_subnets  = var.publicsubnet_cidr
  private_subnets = var.privatesubnet_cidr  

  # Database Subnets
  # database_subnets = var.vpc_database_subnets
  # create_database_subnet_group = var.vpc_create_database_subnet_group
  # create_database_subnet_route_table = var.vpc_create_database_subnet_route_table
  # create_database_internet_gateway_route = true
  # create_database_nat_gateway_route = true
  
  # NAT Gateways - Outbound Communication
  enable_nat_gateway = true 
  single_nat_gateway = true

  # VPC DNS Parameters
  enable_dns_hostnames = true
  enable_dns_support   = true

  
  tags = {
    Environment = "dev"
  }
  # Additional Tags to Subnets
  public_subnet_tags = {
    Type = "Public Subnets"
    "kubernetes.io/role/elb" = 1    
    "kubernetes.io/cluster/my-eks-cluster" = "shared"        
  }
  private_subnet_tags = {
    Type = "private-subnets"
    "kubernetes.io/role/internal-elb" = 1    
    "kubernetes.io/cluster/my-eks-cluster" = "shared"    
  }

  # database_subnet_tags = {
  #   Type = "database-subnets"
  # }
  # Instances launched into the Public subnet should be assigned a public IP address.
  map_public_ip_on_launch = true  
}
