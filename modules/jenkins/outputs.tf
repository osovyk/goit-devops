output "namespace" {
  description = "Kubernetes namespace Jenkins is installed into"
  value       = kubernetes_namespace.jenkins.metadata[0].name
}

output "admin_password_command" {
  description = "kubectl command to retrieve the Jenkins admin password"
  value       = "kubectl -n ${kubernetes_namespace.jenkins.metadata[0].name} exec --stdin --tty svc/jenkins -c jenkins -- /bin/cat /run/secrets/additional/chart-admin-password && echo"
}

output "jenkins_agent_role_arn" {
  description = "IAM role ARN assumed by the Jenkins agent service account (IRSA) for ECR push"
  value       = aws_iam_role.jenkins_agent.arn
}
