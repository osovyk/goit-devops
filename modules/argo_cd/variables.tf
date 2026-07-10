variable "cluster_name" {
  description = "Name of the EKS cluster Argo CD is deployed into"
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

variable "namespace" {
  description = "Kubernetes namespace to install Argo CD into"
  type        = string
  default     = "argocd"
}

variable "chart_version" {
  description = "Version of the argo/argo-cd Helm chart"
  type        = string
  default     = "10.1.2"
}

variable "git_repo_url" {
  description = "HTTPS URL of the git repository containing the Helm chart Argo CD should track"
  type        = string
}

variable "helm_chart_path" {
  description = "Path within the git repository to the Helm chart Argo CD should sync"
  type        = string
  default     = "charts/django-app"
}

variable "target_revision" {
  description = "Git branch/tag Argo CD tracks for the Application"
  type        = string
  default     = "main"
}

variable "destination_namespace" {
  description = "Kubernetes namespace the Django app is deployed into"
  type        = string
  default     = "default"
}
