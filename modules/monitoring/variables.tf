variable "namespace" {
  description = "Kubernetes namespace Prometheus and Grafana are installed into"
  type        = string
  default     = "monitoring"
}

variable "prometheus_chart_version" {
  description = "Version of the prometheus-community/prometheus chart"
  type        = string
}

variable "grafana_chart_version" {
  description = "Version of the grafana/grafana chart"
  type        = string
}

variable "metrics_server_chart_version" {
  description = "Version of the metrics-server/metrics-server chart (installed into kube-system for the HPA)"
  type        = string
}
