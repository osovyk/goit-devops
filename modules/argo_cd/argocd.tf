resource "helm_release" "argocd" {
  name             = "argocd"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  version          = var.chart_version
  namespace        = var.namespace
  create_namespace = true

  values = [file("${path.module}/values.yaml")]
}

resource "helm_release" "argocd_apps" {
  name      = "argocd-apps"
  chart     = "${path.module}/charts"
  namespace = var.namespace

  values = [
    yamlencode({
      argocdNamespace = var.namespace
      applications = [
        merge(
          {
            name                 = "django-app"
            project              = "default"
            repoURL              = var.git_repo_url
            targetRevision       = var.target_revision
            path                 = var.helm_chart_path
            destinationNamespace = var.destination_namespace
          },
          # The ECR repository URL is passed as a Helm parameter so it never
          # has to be hardcoded in the chart's values.yaml in git.
          var.image_repository != "" ? {
            helmParameters = [
              { name = "image.repository", value = var.image_repository },
            ]
          } : {}
        ),
      ]
    })
  ]

  depends_on = [helm_release.argocd]
}
