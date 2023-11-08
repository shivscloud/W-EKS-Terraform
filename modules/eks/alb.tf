resource "aws_iam_role" "alb_ingress_controller_role" {
  name = "alb-ingress-controller-roledev"
  assume_role_policy = data.aws_iam_policy_document.test_oidc_assume_role_policy.json
}

resource "aws_iam_policy" "alb_ingress_controller_policy2" {
    name        = "alb-ingress-controller-policy2"  # Replace with your desired policy name
    description = "Your policy description"  # Replace with a description
  
    policy = file("alb.json")  # Use the downloaded JSON policy document
}


data "aws_iam_policy_document" "test_oidc_assume_role_policy" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    effect  = "Allow"

    condition {
      test     = "StringEquals"
      variable = "${replace(aws_iam_openid_connect_provider.cluster.url, "https://", "")}:aud"
      values   = ["sts.amazonaws.com"]
    }
    condition {
      test     = "StringEquals"
      variable = "${replace(aws_iam_openid_connect_provider.cluster.url, "https://", "")}:sub"
      values   = ["system:serviceaccount:kube-system:aws-load-balancer-controller"]
    }

    principals {
      identifiers = [aws_iam_openid_connect_provider.cluster.arn]
      type        = "Federated"
    }
  }
}

resource "aws_iam_role_policy_attachment" "alb_assume_role_attachment" {
  policy_arn = aws_iam_policy.alb_ingress_controller_policy2.arn
  role       = aws_iam_role.alb_ingress_controller_role.name
}

resource "aws_iam_role_policy_attachment" "ekscni_role_policy_attachment2" {
  role       = aws_iam_role.alb_ingress_controller_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

provider "helm" {
  kubernetes {
    host                   = aws_eks_cluster.eks_cluster.endpoint
    cluster_ca_certificate = base64decode(aws_eks_cluster.eks_cluster.certificate_authority.0.data)
    token                  = data.aws_eks_cluster_auth.cluster.token
  }
}

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