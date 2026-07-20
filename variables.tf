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
  description = "EC2 instance type for the EKS worker nodes. This AWS account has a hard Free-Tier-only restriction, so this must stay one of the free-tier-eligible x86_64 types (t3.micro, t3.small, c7i-flex.large, m7i-flex.large)."
  type        = string
  default     = "m7i-flex.large"
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
  default     = "5.9.39"
}

variable "argocd_namespace" {
  description = "Kubernetes namespace to install Argo CD into"
  type        = string
  default     = "argocd"
}

variable "argocd_chart_version" {
  description = "Version of the argo/argo-cd Helm chart"
  type        = string
  default     = "10.1.4"
}

variable "git_repo_url" {
  description = "HTTPS URL of this git repository, used by Jenkins (push target) and Argo CD (sync source)"
  type        = string
  default     = "https://github.com/osovyk/goit-devops.git"
}

variable "git_target_branch" {
  description = "Branch Jenkins pushes tag bumps to and Argo CD tracks. This repo has no `main` — it's lesson-per-branch, so this must be updated each lesson."
  type        = string
  default     = "final-project"
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

variable "rds_identifier" {
  description = "Base name for the RDS/Aurora resources"
  type        = string
  default     = "final-project-db"
}

variable "rds_use_aurora" {
  description = "true creates an Aurora cluster, false creates a standalone RDS instance"
  type        = bool
  default     = false
}

variable "rds_engine_family" {
  description = "Database engine family: \"postgres\" or \"mysql\""
  type        = string
  default     = "postgres"
}

variable "rds_engine_version" {
  description = "Database engine version, must match rds_engine_family/rds_use_aurora"
  type        = string
  default     = "17.6"
}

variable "rds_parameter_group_family" {
  description = "Parameter group family matching rds_engine_family/rds_engine_version/rds_use_aurora"
  type        = string
  default     = "postgres17"
}

variable "rds_instance_class" {
  description = "Instance class for the RDS/Aurora instance(s). This AWS account is Free-Tier-restricted — db.t3.micro is the only confirmed-working class."
  type        = string
  default     = "db.t3.micro"
}

variable "rds_multi_az" {
  description = "Enable Multi-AZ for a standalone RDS instance (ignored when rds_use_aurora = true)"
  type        = bool
  default     = false
}

variable "rds_aurora_instance_count" {
  description = "Number of Aurora cluster instances (only used when rds_use_aurora = true)"
  type        = number
  default     = 1
}

variable "rds_db_name" {
  description = "Name of the default database"
  type        = string
  default     = "myapp"
}

variable "rds_master_username" {
  description = "Master username for the database. Avoid \"admin\" — it's a reserved word for the postgres engine on RDS."
  type        = string
  default     = "dbadmin"
}

variable "rds_master_password" {
  description = "Master password for the database. Leave null (do not set in *.tfvars) to have the module generate one."
  type        = string
  default     = null
  sensitive   = true
}

variable "rds_backup_retention_period" {
  description = "Number of days to retain automated RDS/Aurora backups. Free-Tier-restricted AWS accounts may cap this below the module's own default (7)."
  type        = number
  default     = 1
}

variable "monitoring_namespace" {
  description = "Kubernetes namespace for Prometheus and Grafana"
  type        = string
  default     = "monitoring"
}

variable "prometheus_chart_version" {
  description = "Version of the prometheus-community/prometheus chart"
  type        = string
  default     = "29.18.0"
}

variable "grafana_chart_version" {
  description = "Version of the grafana/grafana chart"
  type        = string
  default     = "10.5.15"
}

variable "metrics_server_chart_version" {
  description = "Version of the metrics-server/metrics-server chart (required by the django-app HPA)"
  type        = string
  default     = "3.13.1"
}
