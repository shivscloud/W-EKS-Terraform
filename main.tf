module "vpc" {
  # source             = "git::https://github.com/shivscloud/Tech-With-RS-Terraform-VPC.git"
  source             = "./modules/vpc"
  vpc_cidr           = "10.0.0.0/16"
  azs                = ["us-east-1a", "us-east-1b", "us-east-1c"]
  publicsubnet_cidr  = ["10.0.1.0/24", "10.0.2.0/24","10.0.3.0/24"]
  privatesubnet_cidr = ["10.0.2.0/24", "10.0.3.0/24"]
}

module "sg" {
  source = "./modules/sg"
  vpc_id = module.vpc.vpc_id
}

module "eks" {
  source     = "./modules/eks"
  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.public_subnet_ids
}