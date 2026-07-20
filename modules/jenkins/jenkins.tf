resource "kubernetes_namespace_v1" "jenkins" {
  metadata {
    name = var.namespace
  }
}

resource "kubernetes_secret_v1" "github_credentials" {
  metadata {
    name      = "github-credentials"
    namespace = kubernetes_namespace_v1.jenkins.metadata[0].name
    labels = {
      "jenkins.io/credentials-type" = "usernamePassword"
    }
    annotations = {
      "jenkins.io/credentials-description" = "GitHub PAT used to push Helm chart tag bumps"
    }
  }

  type = "kubernetes.io/basic-auth"

  data = {
    username = var.github_username
    password = var.github_token
  }
}

resource "helm_release" "jenkins" {
  name       = "jenkins"
  repository = "https://charts.jenkins.io"
  chart      = "jenkins"
  version    = var.chart_version
  namespace  = kubernetes_namespace_v1.jenkins.metadata[0].name

  values = [
    templatefile("${path.module}/values.yaml", {
      ecr_repository_url     = var.ecr_repository_url
      aws_region             = var.aws_region
      git_repo_url           = var.git_repo_url
      git_target_branch      = var.git_target_branch
      jenkins_agent_role_arn = aws_iam_role.jenkins_agent.arn
    })
  ]
}
