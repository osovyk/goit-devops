terraform {
  required_version = ">= 1.15.7"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

module "s3_backend" {
  source      = "./modules/s3-backend"
  bucket_name = var.bucket_name
  table_name  = var.dynamodb_table_name
}

module "vpc" {
  source             = "./modules/vpc"
  vpc_cidr_block     = var.vpc_cidr_block
  public_subnets     = var.public_subnets
  private_subnets    = var.private_subnets
  availability_zones = var.availability_zones
  vpc_name           = var.vpc_name
}

module "ecr" {
  source       = "./modules/ecr"
  ecr_name     = var.ecr_name
  scan_on_push = var.scan_on_push
}

module "eks" {
  source             = "./modules/eks"
  cluster_name       = var.cluster_name
  kubernetes_version = var.kubernetes_version
  subnet_ids         = module.vpc.public_subnets
  instance_type      = var.instance_type
  desired_size       = var.desired_size
  max_size           = var.max_size
  min_size           = var.min_size
}

module "jenkins" {
  source = "./modules/jenkins"

  cluster_name      = module.eks.eks_cluster_name
  cluster_endpoint  = module.eks.eks_cluster_endpoint
  cluster_ca        = module.eks.eks_cluster_certificate
  oidc_provider_arn = module.eks.oidc_provider_arn
  oidc_provider_url = module.eks.oidc_provider_url

  namespace     = var.jenkins_namespace
  chart_version = var.jenkins_chart_version

  ecr_repository_url = module.ecr.repository_url
  ecr_repository_arn = module.ecr.repository_arn
  aws_region         = var.aws_region

  git_repo_url      = var.git_repo_url
  git_target_branch = var.git_target_branch
  github_username   = var.github_username
  github_token      = var.github_token
}

module "argo_cd" {
  source = "./modules/argo_cd"

  cluster_name     = module.eks.eks_cluster_name
  cluster_endpoint = module.eks.eks_cluster_endpoint
  cluster_ca       = module.eks.eks_cluster_certificate

  namespace     = var.argocd_namespace
  chart_version = var.argocd_chart_version

  git_repo_url    = var.git_repo_url
  helm_chart_path = "charts/django-app"
  target_revision = var.git_target_branch
}
