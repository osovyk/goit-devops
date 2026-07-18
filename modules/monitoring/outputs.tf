output "namespace" {
  description = "Namespace Prometheus and Grafana are installed into"
  value       = var.namespace
}

output "grafana_admin_password_command" {
  description = "Command to retrieve the generated Grafana admin password (user: admin)"
  value       = "kubectl get secret --namespace ${var.namespace} grafana -o jsonpath=\"{.data.admin-password}\" | base64 --decode"
}

output "grafana_port_forward_command" {
  description = "Command to open Grafana on http://localhost:3000"
  value       = "kubectl port-forward svc/grafana 3000:80 -n ${var.namespace}"
}

output "prometheus_port_forward_command" {
  description = "Command to open the Prometheus UI on http://localhost:9090"
  value       = "kubectl port-forward svc/prometheus-server 9090:80 -n ${var.namespace}"
}
