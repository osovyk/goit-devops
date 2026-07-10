output "namespace" {
  description = "Kubernetes namespace Argo CD is installed into"
  value       = var.namespace
}

output "admin_password_command" {
  description = "kubectl command to retrieve the Argo CD initial admin password"
  value       = "kubectl -n ${var.namespace} get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d && echo"
}
