terraform {
  required_version = ">= 1.15.7"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

data "aws_eks_cluster_auth" "this" {
  name = module.eks.eks_cluster_name
}

provider "kubernetes" {
  host                   = module.eks.eks_cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.eks_cluster_certificate)
  token                  = data.aws_eks_cluster_auth.this.token
}

provider "helm" {
  kubernetes {
    host                   = module.eks.eks_cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.eks_cluster_certificate)
    token                  = data.aws_eks_cluster_auth.this.token
  }
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

  depends_on = [module.eks]
}

module "argo_cd" {
  source = "./modules/argo_cd"

  namespace     = var.argocd_namespace
  chart_version = var.argocd_chart_version

  git_repo_url    = var.git_repo_url
  helm_chart_path = "charts/django-app"
  target_revision = var.git_target_branch

  depends_on = [module.eks]
}

module "rds" {
  source = "./modules/rds"

  identifier             = var.rds_identifier
  use_aurora             = var.rds_use_aurora
  engine_family          = var.rds_engine_family
  engine_version         = var.rds_engine_version
  parameter_group_family = var.rds_parameter_group_family
  instance_class         = var.rds_instance_class
  multi_az               = var.rds_multi_az
  aurora_instance_count  = var.rds_aurora_instance_count

  db_name         = var.rds_db_name
  master_username = var.rds_master_username
  master_password = var.rds_master_password

  backup_retention_period = var.rds_backup_retention_period

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  # Django pods run in the public subnets (see module.eks.subnet_ids) — allow
  # the whole VPC CIDR rather than a single node security group id, since the
  # eks module doesn't expose one explicitly.
  allowed_cidr_blocks = [var.vpc_cidr_block]

  tags = {
    Project = "goit-devops"
  }
}
