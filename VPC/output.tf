output "vpc_id" {
    value       = module.vpc.vpc_id
    description = "The ID of the VPC"
}

output "private_subnets" {
    value       = module.vpc.private_subnets
    description = "The IDs of the private subnets"
}

output "control_plane_subnet_ids" {
    value       = module.vpc.intra_subnets
    description = "The IDs of the intra subnets"
}

