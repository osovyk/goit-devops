variable "cluster_name" {
  description = "Name of the EKS cluster Jenkins is deployed into"
  type        = string
}

variable "cluster_endpoint" {
  description = "API endpoint of the EKS cluster"
  type        = string
}

variable "cluster_ca" {
  description = "Base64-encoded certificate authority data for the EKS cluster"
  type        = string
}

variable "oidc_provider_arn" {
  description = "ARN of the EKS cluster's IAM OIDC provider (for IRSA)"
  type        = string
}

variable "oidc_provider_url" {
  description = "URL of the EKS cluster's IAM OIDC provider, without the https:// scheme"
  type        = string
}

variable "namespace" {
  description = "Kubernetes namespace to install Jenkins into"
  type        = string
  default     = "jenkins"
}

variable "chart_version" {
  description = "Version of the jenkins/jenkins Helm chart"
  type        = string
  default     = "5.9.32"
}

variable "ecr_repository_url" {
  description = "URL of the ECR repository the pipeline pushes Django images to"
  type        = string
}

variable "ecr_repository_arn" {
  description = "ARN of the ECR repository the pipeline pushes Django images to"
  type        = string
}

variable "aws_region" {
  description = "AWS region, exposed to pipelines as a global Jenkins env var"
  type        = string
}

variable "git_repo_url" {
  description = "HTTPS URL of the git repository containing the Helm chart to update"
  type        = string
}

variable "git_target_branch" {
  description = "Branch Jenkins pushes Helm chart tag bumps to"
  type        = string
}

variable "github_username" {
  description = "GitHub username used by Jenkins to push Helm chart tag bumps"
  type        = string
  sensitive   = true
}

variable "github_token" {
  description = "GitHub personal access token (repo scope) used by Jenkins to push Helm chart tag bumps"
  type        = string
  sensitive   = true
}
