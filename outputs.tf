output "s3_bucket_name" {
  description = "Name of the S3 bucket for Terraform state"
  value       = module.s3_backend.s3_bucket_name
}

output "dynamodb_table_name" {
  description = "Name of the DynamoDB table for state locking"
  value       = module.s3_backend.dynamodb_table_name
}

output "vpc_id" {
  description = "ID of the created VPC"
  value       = module.vpc.vpc_id
}

output "public_subnets" {
  description = "List of public subnet IDs"
  value       = module.vpc.public_subnets
}

output "private_subnets" {
  description = "List of private subnet IDs"
  value       = module.vpc.private_subnets
}

output "ecr_repository_url" {
  description = "URL of the ECR repository"
  value       = module.ecr.repository_url
}

output "eks_cluster_name" {
  description = "Name of the EKS cluster"
  value       = module.eks.eks_cluster_name
}

output "eks_cluster_endpoint" {
  description = "API endpoint of the EKS cluster"
  value       = module.eks.eks_cluster_endpoint
}

output "eks_node_role_arn" {
  description = "IAM role ARN for EKS worker nodes"
  value       = module.eks.eks_node_role_arn
}

output "jenkins_namespace" {
  description = "Kubernetes namespace Jenkins is installed into"
  value       = module.jenkins.namespace
}

output "jenkins_admin_password_command" {
  description = "Command to retrieve the Jenkins admin password"
  value       = module.jenkins.admin_password_command
}

output "argocd_namespace" {
  description = "Kubernetes namespace Argo CD is installed into"
  value       = module.argo_cd.namespace
}

output "argocd_admin_password_command" {
  description = "Command to retrieve the Argo CD initial admin password"
  value       = module.argo_cd.admin_password_command
}

output "rds_endpoint" {
  description = "RDS/Aurora connection endpoint"
  value       = module.rds.endpoint
}

output "rds_reader_endpoint" {
  description = "Aurora reader endpoint (null for standalone RDS)"
  value       = module.rds.reader_endpoint
}

output "rds_master_username" {
  description = "RDS/Aurora master username"
  value       = module.rds.master_username
}

output "rds_master_password" {
  description = "RDS/Aurora master password"
  value       = module.rds.master_password
  sensitive   = true
}
