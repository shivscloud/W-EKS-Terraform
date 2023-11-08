variable "vpc_id" {
  description = "ID of the VPC"
  type        = string
}

variable "subnet_ids" {
  description = "List of subnet IDs"
  type        = list(string)
  
}

variable "addons" {
  type = list(object({
    name    = string
    version = string
  }))

  default = [
    # {
    #   name    = "kube-proxy"
    #   version = "v1.21.2-eksbuild.2"
    # },
    # {
    #   name    = "vpc-cni"
    #   version = "v1.10.1-eksbuild.1"
    # },
    # {
    #   name    = "coredns"
    #   version = "v1.8.4-eksbuild.1"
    # },
    {
      name    = "aws-ebs-csi-driver"
      version = "v1.24.1-eksbuild.1"    }
  ]
}