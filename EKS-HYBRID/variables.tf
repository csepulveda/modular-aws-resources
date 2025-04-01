variable "proyect_name" {
  type        = string
  default     = "my-eks-cluster"
  description = "value for the eks cluster name vpc and other resources"
}

variable "region" {
  type        = string
  default     = "us-east-1"
  description = "region where the resources will be created"
}

variable "vpc_cidr" {
  type        = string
  default     = "10.0.0.0/16"
  description = "CIDR block for the VPC"
}

variable "eks_version" {
  type        = string
  default     = "1.32"
  description = "EKS version"
}