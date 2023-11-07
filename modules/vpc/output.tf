# output "vpc_id" {
#   value = aws_vpc.main.id
# }

output "vpc_id" {
  description = "The ID of the VPC"
  value       = module.vpc.vpc_id
}

# VPC Public Subnets
output "public_subnet_ids" {
  description = "List of IDs of public subnets"
  value       = module.vpc.public_subnets
}

# output "public_subnet_ids" {
#   value = aws_subnet.public[*].id
# }

# output "private_subnet_ids" {
#   value = aws_subnet.private_subnets[*].id
# }