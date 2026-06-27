variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
}

variable "kubernetes_version" {
  description = "Kubernetes version for the EKS cluster"
  type        = string
}

variable "subnet_ids" {
  description = "List of subnet IDs for the EKS cluster and node group"
  type        = list(string)
}

variable "instance_type" {
  description = "EC2 instance type for the worker nodes"
  type        = string
}

variable "desired_size" {
  description = "Desired number of worker nodes in the node group"
  type        = number
}

variable "max_size" {
  description = "Maximum number of worker nodes in the node group"
  type        = number
}

variable "min_size" {
  description = "Minimum number of worker nodes in the node group"
  type        = number
}
