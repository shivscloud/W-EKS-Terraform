resource "aws_eks_cluster" "eks_cluster" {
  name     = "my-eks-cluster"
  role_arn = aws_iam_role.eks_cluster_role.arn
  version  = "1.25"  # Replace with the desired EKS version
  vpc_config {
    subnet_ids = var.subnet_ids
  }
}

resource "aws_iam_role" "eks_cluster_role" {
  name = "my-eks-cluster-role"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "",
      "Effect": "Allow",
      "Principal": {
        "Service": "eks.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

resource "aws_eks_node_group" "eks_node_group" {
  cluster_name    = aws_eks_cluster.eks_cluster.name
  node_group_name = "my-eks-node-group"
  node_role_arn   = aws_iam_role.eks_node_group_role.arn
  instance_types = ["t2.large"]
  subnet_ids      = var.subnet_ids
  scaling_config {
    desired_size = 1
    min_size     = 1
    max_size     = 1
  }
}



resource "aws_iam_role" "eks_node_group_role" {
  name = "my-eks-node-group-role"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "",
      "Effect": "Allow",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

resource "aws_iam_policy" "alb_ingress_controller_policy2" {
  name        = "alb-ingress-controller-policy2"
  description = "Policy for the ALB Ingress Controller role"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = [
          "elasticloadbalancing:DescribeLoadBalancers",
          "elasticloadbalancing:DescribeListeners",
          "elasticloadbalancing:DescribeTargetGroups",
          "elasticloadbalancing:DescribeTargetHealth",
          "elasticloadbalancing:CreateLoadBalancer",
          "elasticloadbalancing:CreateTargetGroup",
          "elasticloadbalancing:CreateListener",
          "elasticloadbalancing:DeleteLoadBalancer",
          "elasticloadbalancing:DeleteTargetGroup",
          "elasticloadbalancing:DeleteListener",
          "elasticloadbalancing:ModifyListener",
        ],
        Effect   = "Allow",
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "alb_ingress_controller_role_policy_attachment2" {
  policy_arn = aws_iam_policy.alb_ingress_controller_policy2.arn
  role       = aws_iam_role.eks_node_group_role.name
}

resource "aws_iam_role_policy_attachment" "eks_role_policy_attachment" {
  role       = aws_iam_role.eks_cluster_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}
resource "aws_iam_role_policy_attachment" "eks_role_servicepolicy_attachment" {
  role       = aws_iam_role.eks_cluster_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSServicePolicy"
}
resource "aws_iam_role_policy_attachment" "eks_role_vpcpolicy_attachment" {
  role       = aws_iam_role.eks_cluster_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSVPCResourceController"
}

resource "aws_iam_role_policy_attachment" "eksnode_role_policy_attachment1" {
  role       = aws_iam_role.eks_node_group_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}
resource "aws_iam_role_policy_attachment" "eksnode_role_cni_attachment1" {
  role       = aws_iam_role.eks_node_group_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}


resource "aws_iam_role_policy_attachment" "eksnode_role_policy_attachment2" {
  role       = aws_iam_role.eks_node_group_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

output "eks_cluster_name" {
  value = aws_eks_cluster.eks_cluster.name
}

############################OIDC######################
data "aws_partition" "current" {}
data "tls_certificate" "eks" {
  url = aws_eks_cluster.eks_cluster.identity[0].oidc[0].issuer
}

resource "aws_iam_openid_connect_provider" "cluster" {
  depends_on = [ aws_eks_node_group.eks_node_group ]
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.eks.certificates[0].sha1_fingerprint]
  url             = aws_eks_cluster.eks_cluster.identity[0].oidc[0].issuer
}

###############EBS Volume policy attach to eks worker node rules
resource "aws_iam_policy" "ebs_policy" {
  name        = "ExamplePolicy"
  description = "Example IAM policy"
  policy      = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect   = "Allow",
        Action   = [
          "ec2:AttachVolume",
          "ec2:CreateSnapshot",
          "ec2:CreateTags",
          "ec2:CreateVolume",
          "ec2:DeleteSnapshot",
          "ec2:DeleteTags",
          "ec2:DeleteVolume",
          "ec2:DescribeInstances",
          "ec2:DescribeSnapshots",
          "ec2:DescribeTags",
          "ec2:DescribeVolumes",
          "ec2:DetachVolume",
        ],
        Resource  = "*",
      },
    ],
  })
}

resource "aws_iam_role_policy_attachment" "eksnode_role_ebspolicy_attachment1" {
  role       = aws_iam_role.eks_node_group_role.name
  policy_arn = aws_iam_policy.ebs_policy.arn
}

resource "aws_iam_role_policy_attachment" "eksnode_role_ebsaddon_attachment1" {
  role       = aws_iam_role.ebs_csi_iam_role.name
  policy_arn = aws_iam_policy.ebs_policy.arn
}

data "aws_iam_policy_document" "test_oidc_assume_role_policy" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    effect  = "Allow"

    condition {
      test     = "StringEquals"
      variable = "${replace(aws_iam_openid_connect_provider.cluster.url, "https://", "")}:sub"
      values   = ["system:serviceaccount:default:default"]
    }

    principals {
      identifiers = [aws_iam_openid_connect_provider.cluster.arn]
      type        = "Federated"
    }
  }
}

module "aws_load_balancer_controller_irsa_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "5.30.0"

  role_name = "aws-load-balancer-controller"

  attach_load_balancer_controller_policy = true

  oidc_providers = {
    ex = {
      provider_arn               = aws_iam_openid_connect_provider.cluster.arn 
      namespace_service_accounts = ["kube-system:aws-load-balancer-controller"]
    }
  }
}

resource "aws_iam_role" "ebs_csi_iam_role" {
  assume_role_policy = data.aws_iam_policy_document.test_oidc_assume_role_policy.json
  name               = "test-oidc"
}


resource "aws_eks_addon" "ebs_eks_addon" {
  depends_on = [ aws_eks_node_group.eks_node_group ]
  cluster_name = aws_eks_cluster.eks_cluster.name 
  addon_name   = "aws-ebs-csi-driver"
  service_account_role_arn = aws_iam_role.ebs_csi_iam_role.arn 
}

data "aws_eks_cluster" "cluster" {
  name = aws_eks_cluster.eks_cluster.name
}


# provider "kubernetes" {
#   config_path = data.aws_eks_cluster.cluster.kubeconfig
#   host                   = data.aws_eks_cluster.cluster.endpoint
#   cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority.0.data)
#   token                  = data.aws_eks_cluster_auth.cluster.token
# }

# Datasource: EKS Cluster Auth 
data "aws_eks_cluster_auth" "cluster" {
  name = aws_eks_cluster.eks_cluster.name
}

provider "helm" {
  kubernetes {
    host                   = aws_eks_cluster.eks_cluster.endpoint
    cluster_ca_certificate = base64decode(aws_eks_cluster.eks_cluster.certificate_authority.0.data)
    token                  = data.aws_eks_cluster_auth.cluster.token
  }
}



resource "aws_iam_role" "alb_ingress_controller_role" {
  name = "alb-ingress-controller-roledev"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole",
        Effect = "Allow",
        Principal = {
          Service = "eks.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_policy" "alb_ingress_controller_policy" {
  name        = "alb-ingress-controller-policy"
  description = "Policy for the ALB Ingress Controller role"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = [
          "elasticloadbalancing:DescribeLoadBalancers",
          "elasticloadbalancing:DescribeListeners",
          "elasticloadbalancing:DescribeTargetGroups",
          "elasticloadbalancing:DescribeTargetHealth",
          "elasticloadbalancing:CreateLoadBalancer",
          "elasticloadbalancing:CreateTargetGroup",
          "elasticloadbalancing:CreateListener",
          "elasticloadbalancing:DeleteLoadBalancer",
          "elasticloadbalancing:DeleteTargetGroup",
          "elasticloadbalancing:DeleteListener",
          "elasticloadbalancing:ModifyListener",
          "elasticloadbalancing:*",
        ],
        Effect   = "Allow",
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "alb_ingress_controller_role_policy_attachment" {
  policy_arn = aws_iam_policy.alb_ingress_controller_policy.arn
  role       = aws_iam_role.alb_ingress_controller_role.name
}

resource "aws_iam_role_policy_attachment" "ekscni_role_policy_attachment2" {
  role       = aws_iam_role.alb_ingress_controller_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}
# resource "helm_release" "aws_load_balancer_controller" {
#   name       = "aws-load-balancer-controller"
#   repository = "https://aws.github.io/eks-charts"
#   chart      = "aws-load-balancer-controller"

#   set {
#     name  = "autoDiscoverClusterName"
#     value = true
#   }
#    set {
#     name  = "serviceAccount.create"
#     value = "true"
#   }

#   set {
#     name  = "serviceAccount.name"
#     value = "aws-load-balancer-controller"
#   }

#   set {
#     name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
#     value = "${aws_iam_role.alb_ingress_controller_role.arn}"
#   }

#   set {
#     name  = "clusterName"
#     value = "my-eks-cluster"
#   }

#   set {
#     name  = "vpcId"
#     value = var.vpc_id
#   }

#   dynamic "set" {
#     for_each = var.subnet_ids
#     content {
#       name  = "subnetSelection.subnets[${set.key}]"
#       value = set.value
#     }
#   }

#   namespace = "kube-system"
# }

resource "helm_release" "aws_load_balancer_controller" {
  name = "aws-load-balancer-controller"

  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  namespace  = "kube-system"
  set {
    name  = "clusterName"
    value = aws_eks_cluster.eks_cluster.name
  }

  set {
    name  = "serviceAccount.name"
    value = "aws-load-balancer-controller"
  }

  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    # value = module.aws_load_balancer_controller_irsa_role.iam_role_arn
    value = "${aws_iam_role.alb_ingress_controller_role.arn}"
  }

    set {
    name  = "vpcId"
    value = var.vpc_id
  }

  dynamic "set" {
    for_each = var.subnet_ids
    content {
      name  = "subnetSelection.subnets[${set.key}]"
      value = set.value
    }
  }
}

# Resource: Kubernetes Ingress Class
# resource "kubernetes_ingress_class_v1" "ingress_class_default" {
#   depends_on = [helm_release.aws_load_balancer_controller]
#   metadata {
#     name = "my-aws-ingress-class"
#     annotations = {
#       "ingressclass.kubernetes.io/is-default-class" = "true"
#     }
#   }  
#   spec {
#     controller = "ingress.k8s.aws/alb"
#   }
# }

