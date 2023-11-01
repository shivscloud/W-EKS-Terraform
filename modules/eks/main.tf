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

    # condition {
    #   test     = "StringEquals"
    #   variable = "${replace(aws_iam_openid_connect_provider.cluster.url, "https://", "")}:sub"
    #   values   = ["system:serviceaccount:default:aws-test"]
    # }

    principals {
      identifiers = [aws_iam_openid_connect_provider.cluster.arn]
      type        = "Federated"
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


provider "kubernetes" {
  config_path = data.aws_eks_cluster.cluster.kubeconfig
  host                   = data.aws_eks_cluster.cluster.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority.0.data)
  token                  = data.aws_eks_cluster_auth.cluster.token
}



# resource "helm_release" "ingress" {
#   name       = "ingress"
#   chart      = "aws-load-balancer-controller"
#   repository = "https://aws.github.io/eks-charts"
#   version    = "1.4.6"

#   set {
#     name  = "autoDiscoverAwsRegion"
#     value = "true"
#   }
#   set {
#     name  = "autoDiscoverAwsVpcID"
#     value = "true"
#   }
#   set {
#     name  = "clusterName"
#     value = aws_eks_cluster.eks_cluster.name
#   }
# }

