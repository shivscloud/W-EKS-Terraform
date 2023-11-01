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

resource "null_resource" "kubeconfig" {
  depends_on = [module.eks]
  triggers = {
    # cluster_name = module.eks.cluster_name  # Replace with your EKS cluster name
    cluster_name = "my-eks-cluster"
  }
  # Use local-exec provisioner to run commands
  provisioner "local-exec" {
    command = <<EOT
      aws eks update-kubeconfig --name my-eks-cluster --region us-east-1
    EOT
  }
}

resource "null_resource" "alb_controller" {
  depends_on = [null_resource.kubeconfig]

  provisioner "local-exec" {
    command = "helm repo add eks https://aws.github.io/eks-charts && helm repo update eks && helm install aws-load-balancer-controller eks/aws-load-balancer-controller -n kube-system --set autoDiscoverClusterName=true --set clusterName=my-eks-cluster"
  }
}


# resource "null_resource" "ebs_csi_setup" {
#   depends_on = [null_resource.kubeconfig]  # Wait for kubeconfig to be created
#   # Use local-exec provisioner to run commands for EBS CSI driver setup
#   provisioner "local-exec" {
#     command = <<EOT
#       kubectl apply -k github.com/kubernetes-sigs/aws-ebs-csi-driver/deploy/kubernetes/overlays/stable/?ref=master
#       kubectl get pods -n kube-system
#     EOT
#   }
# }

##########################ALB Controller Installl##############################################

# data "http" "iam_policy_document" {
#   url = "https://raw.githubusercontent.com/kubernetes-sigs/aws-alb-ingress-controller/master/docs/examples/iam-policy.json"
# }

# resource "aws_iam_policy" "alb_ingress_controller_iam_policy" {
#   name        = "ALBIngressControllerIAMPolicy"
#   description = "ALB Ingress Controller IAM Policy"
#   path        = "/"

#   policy = data.http.iam_policy_document.body
# }