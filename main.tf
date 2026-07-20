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
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
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

  # Worker nodes live in private subnets; these tags let the in-tree AWS cloud
  # provider discover which subnets to place Service LoadBalancers into.
  public_subnet_tags = {
    "kubernetes.io/role/elb"                    = "1"
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
  }
  private_subnet_tags = {
    "kubernetes.io/role/internal-elb"           = "1"
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
  }
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
  subnet_ids         = module.vpc.private_subnets
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

  # Injected as a Helm parameter on the Application so the ECR URL (account id)
  # never has to be hardcoded in charts/django-app/values.yaml.
  image_repository = module.ecr.repository_url

  depends_on = [module.eks]
}

# Sensitive runtime settings for the Django app. Kept out of git entirely:
# the chart's Deployment reads them via envFrom from this Secret, while the
# ConfigMap in the chart carries only non-sensitive values.
resource "random_password" "django_secret_key" {
  length  = 50
  special = false
}

resource "kubernetes_secret" "django_app" {
  metadata {
    name      = "django-app-secrets"
    namespace = "default"
  }

  data = {
    SECRET_KEY        = random_password.django_secret_key.result
    POSTGRES_HOST     = split(":", module.rds.endpoint)[0]
    POSTGRES_PASSWORD = module.rds.master_password
  }

  depends_on = [module.eks]
}

module "monitoring" {
  source = "./modules/monitoring"

  namespace                    = var.monitoring_namespace
  prometheus_chart_version     = var.prometheus_chart_version
  grafana_chart_version        = var.grafana_chart_version
  metrics_server_chart_version = var.metrics_server_chart_version

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

  # Django pods run on nodes in the private subnets — allow the whole VPC CIDR
  # rather than a single node security group id, since the eks module doesn't
  # expose one explicitly.
  allowed_cidr_blocks = [var.vpc_cidr_block]

  tags = {
    Project = "goit-devops"
  }
}
