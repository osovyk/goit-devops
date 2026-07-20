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

variable "image_repository" {
  description = "Container image repository (ECR URL) injected into the Application as the image.repository Helm parameter. Empty string omits the override."
  type        = string
  default     = ""
}
