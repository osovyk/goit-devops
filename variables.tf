variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "eu-west-1"
}

variable "bucket_name" {
  description = "Name of the S3 bucket for Terraform state"
  type        = string
  default     = "rosovyk-terraform-state"
}

variable "dynamodb_table_name" {
  description = "Name of the DynamoDB table for state locking"
  type        = string
  default     = "terraform-locks"
}

variable "vpc_cidr_block" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnets" {
  description = "List of CIDR blocks for public subnets"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
}

variable "private_subnets" {
  description = "List of CIDR blocks for private subnets"
  type        = list(string)
  default     = ["10.0.4.0/24", "10.0.5.0/24", "10.0.6.0/24"]
}

variable "availability_zones" {
  description = "List of availability zones for subnets"
  type        = list(string)
  default     = ["eu-west-1a", "eu-west-1b", "eu-west-1c"]
}

variable "vpc_name" {
  description = "Name of the VPC"
  type        = string
  default     = "vpc"
}

variable "ecr_name" {
  description = "Name of the ECR repository"
  type        = string
  default     = "lesson-5-ecr"
}

variable "scan_on_push" {
  description = "Enable image scanning on push for ECR"
  type        = bool
  default     = true
}

variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
  default     = "lesson-7-eks"
}

variable "kubernetes_version" {
  description = "Kubernetes version for the EKS cluster"
  type        = string
  default     = "1.36"
}

variable "instance_type" {
  description = "EC2 instance type for the EKS worker nodes"
  type        = string
  default     = "t3.medium"
}

variable "desired_size" {
  description = "Desired number of worker nodes in the EKS node group"
  type        = number
  default     = 2
}

variable "max_size" {
  description = "Maximum number of worker nodes in the EKS node group"
  type        = number
  default     = 3
}

variable "min_size" {
  description = "Minimum number of worker nodes in the EKS node group"
  type        = number
  default     = 1
}

variable "jenkins_namespace" {
  description = "Kubernetes namespace to install Jenkins into"
  type        = string
  default     = "jenkins"
}

variable "jenkins_chart_version" {
  description = "Version of the jenkins/jenkins Helm chart"
  type        = string
  default     = "5.9.32"
}

variable "argocd_namespace" {
  description = "Kubernetes namespace to install Argo CD into"
  type        = string
  default     = "argocd"
}

variable "argocd_chart_version" {
  description = "Version of the argo/argo-cd Helm chart"
  type        = string
  default     = "10.1.2"
}

variable "git_repo_url" {
  description = "HTTPS URL of this git repository, used by Jenkins (push target) and Argo CD (sync source)"
  type        = string
  default     = "https://github.com/osovyk/goit-devops.git"
}

variable "git_target_branch" {
  description = "Branch Jenkins pushes tag bumps to and Argo CD tracks. This repo has no `main` — it's lesson-per-branch, so this must be updated each lesson."
  type        = string
  default     = "lesson-9"
}

variable "github_username" {
  description = "GitHub username used by Jenkins to push Helm chart tag bumps. Supply via terraform.tfvars (gitignored)."
  type        = string
  sensitive   = true
}

variable "github_token" {
  description = "GitHub personal access token (repo scope) used by Jenkins to push Helm chart tag bumps. Supply via terraform.tfvars (gitignored)."
  type        = string
  sensitive   = true
}
