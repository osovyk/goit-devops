# Deployed after Prometheus so the provisioned data source resolves on first start.
# The grafana/grafana chart is marked deprecated upstream (Grafana Labs is moving
# to the operator), but it still ships current Grafana releases and is the chart
# this course's monitoring setup is built on.
resource "helm_release" "grafana" {
  name             = "grafana"
  repository       = "https://grafana.github.io/helm-charts"
  chart            = "grafana"
  version          = var.grafana_chart_version
  namespace        = var.namespace
  create_namespace = true

  values = [
    templatefile("${path.module}/values-grafana.yaml", {
      prometheus_url = "http://prometheus-server.${var.namespace}.svc:80"
    })
  ]

  depends_on = [helm_release.prometheus]
}
