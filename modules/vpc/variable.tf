variable "vpc_cidr" {
  type = string
}

variable "azs" {
  type = list(string)
}

variable "publicsubnet_cidr" {
  type = list(string)
}

variable "privatesubnet_cidr" {
  type = list(string)
}