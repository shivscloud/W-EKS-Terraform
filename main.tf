module "vpc" {
  # source             = "git::https://github.com/shivscloud/Tech-With-RS-Terraform-VPC.git"
  source             = "./modules/vpc"
  vpc_cidr           = "10.0.0.0/16"
  azs                = ["us-east-1a", "us-east-1b", "us-east-1c"]
  publicsubnet_cidr  = ["10.0.1.0/24", "10.0.2.0/24","10.0.3.0/24"]
  privatesubnet_cidr = ["10.0.20.0/24", "10.0.30.0/24"]
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




# resource "null_resource" "alb_controller" {
#   depends_on = [null_resource.kubeconfig]

#   provisioner "local-exec" {
#     command = "helm repo add eks https://aws.github.io/eks-charts && helm repo update eks && helm install aws-load-balancer-controller eks/aws-load-balancer-controller -n kube-system --set autoDiscoverClusterName=true --set clusterName=my-eks-cluster vpcId=vpc-0e4f210ad9fbd3919 subnets=subnet-02f91961901d07f84,subnet-07d42ff06bccde60a,subnet-00e865d0ca12d76c7"
#   }
# }






# resource "aws_iam_role_policy_attachment" "ekspodexecution_role_policy_attachment2" {
#   role       = aws_iam_role.alb_ingress_controller_role.name
#   policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_Pod_Execution_Role"
# }
# resource "null_resource" "alb_controller" {
#   depends_on = [null_resource.kubeconfig]

#   # Create an IAM role for the ALB Ingress Controller
#   provisioner "local-exec" {
#     command = <<EOT
#       # Install the AWS Load Balancer Controller using Helm
#       helm repo add eks https://aws.github.io/eks-charts
#       helm repo update eks
#       helm install aws-load-balancer-controller eks/aws-load-balancer-controller -n kube-system --set autoDiscoverClusterName=true --set clusterName=my-eks-cluster --set serviceAccount.annotations."eks.amazonaws.com/role-arn"="$(aws iam get-role --role-name alb-ingress-controller-role --query 'Role.Arn' --output text)"
#     EOT
#   }
# }


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

